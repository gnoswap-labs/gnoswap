// type Pool describes a single Pool's state
// A pool is identified with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	// token0 is the package name of the first token
	token0 string
	// token1 is the package name of the second token
	token1 string

	// fee is the fee tier of the pool
	fee bigint
	// tickSpacing is the spacing between ticks
	tickSpacing bigint
	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	maxLiquidityPerTick bigint

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0 bigint
	feeGrowthGlobal1 bigint

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees bigint
	// liquidity is the total amount of liquidity in the pool
	liquidity bigint

	// ticks is a mapping from tick index to tick
	ticks map[bigint]*Tick
	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps map[bigint]*bigint
	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions map[string]*Position
}

func NewPool(
	token0 string,
	token1 string,
	fee bigint,
	tickSpacing bigint,
	sqrtPrice bigint,
	tick bigint,
) *Pool {
	maxLiquidityPerTick := TickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	// _tick := TickMathGetTickAtSqrtRatio(_sqrtPrice)
	// sqrtPrice := TickMathGetSqrtRatioAtTick(_sqrtPrice)

	slot0 := Slot0 {
		sqrtPrice, // sqrtPrice
		tick, // tick
		0, // feeProtocol
		true, // unlocked
	}

	return &Pool {
		token0: token0,
		token1: token1,
		fee: fee,
		tickSpacing: tickSpacing,
		maxLiquidityPerTick: maxLiquidityPerTick,
		slot0: slot0,
		feeGrowthGlobal0: bigint(0),
		feeGrowthGlobal1: bigint(0),
		protocolFees: bigint(0),
		liquidity: bigint(0),
		ticks: make(map[bigint]*Tick),
		tickBitmaps: make(map[bigint]*bigint),
		positions: make(map[string]*Position),
	}
}

// Mint adds liquidity to the pool
func (pool *Pool) Mint(
	recipient std.Address,
	tickLower bigint,
	tickUpper bigint,
	amount bigint,
) (bigint, bigint) {
	require(amount > 0, "must be amount > 0")

	_, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			recipient,
			tickLower,
			tickUpper,
			amount,
		},
	)

	amount0 := bigint(amount0Int)
	amount1 := bigint(amount1Int)
	require(amount0 >= 0, "FIX MINUS // Mint #1")
	require(amount1 >= 0, "FIX MINUS // Mint #2")

	var balance0Before, balance1Before bigint

	if (amount0 > 0) {
		balance0Before = BalanceOf(pool.token0, GetOrigPkgAddr())
		err := TransferFrom(pool.token0, GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount0))
		if err != nil {
			panic("token0.TransferFrom failed")
		}
		require(balance0Before + amount0 <= BalanceOf(pool.token0, GetOrigPkgAddr()), "[X] balance0")
	}

	if (amount1 > 0) {
		balance1Before = BalanceOf(pool.token1, GetOrigPkgAddr())
		err := TransferFrom(pool.token1, GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount1))
		if err != nil {
			panic("token1.TransferFrom failed")
		}
		require(balance1Before + amount1 <= BalanceOf(pool.token1, GetOrigPkgAddr()), "[X] balance1")
	}
	return amount0, amount1
}

func (pool *Pool) Burn(
	tickLower bigint,
	tickUpper bigint,
	amount bigint,
) (bigint, bigint) {
	require(amount > 0, "must be amount > 0")

	position, amount0Int, amount1Int := pool.modifyPosition(
		ModifyPositionParams{
			GetOrigCaller(),
			tickLower,
			tickUpper,
			-amount,
		},
	)

	amount0, amount1 := -amount0Int, -amount1Int

	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 = amount0 + position.tokensOwed0
		position.tokensOwed1 = amount1 + position.tokensOwed1
	}

	key := PositionGetKey(GetOrigCaller(), tickLower, tickUpper)
	pool.positions[key] = position
	return amount0, amount1
}

func (pool *Pool) Collect(
	recipient std.Address, 
	tickLower bigint, 
	tickUpper bigint, 
	amount0Requested bigint, 
	amount1Requested bigint,
) (bigint, bigint) {
	key := PositionGetKey(GetOrigCaller(), tickLower, tickUpper)
	position := pool.positions[key]

	var amount0, amount1 bigint

	if amount0Requested > position.tokensOwed0 {
		amount0 = position.tokensOwed0
	} else {
		amount0 = amount0Requested
	}

	if amount1Requested > position.tokensOwed1 {
		amount1 = position.tokensOwed1
	} else {
		amount1 = amount1Requested
	}

	if (amount0 > 0) {
		position.tokensOwed0 -= amount0
		Transfer(pool.token0, GetOrigPkgAddr(), recipient, uint64(amount0))
	}

	if (amount1 > 0) {
		position.tokensOwed1 -= amount1
		Transfer(pool.token1, GetOrigPkgAddr(), recipient, uint64(amount1))
	}

	pool.positions[key] = position

	return amount0, amount1
}

func (pool *Pool) Swap(
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimit bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "must be amountSpecified > 0")

	slot0Start := pool.slot0
	require(slot0Start.unlocked, "LOK")

	var feeProtocol, feeGrowthGlobal bigint

	if zeroForOne {
		require(sqrtPriceLimit < slot0Start.sqrtPrice && sqrtPriceLimit > MIN_SQRT_RATIO, "SPL T")
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobal = pool.feeGrowthGlobal0
	} else {
		require(sqrtPriceLimit > slot0Start.sqrtPrice && sqrtPriceLimit < MAX_SQRT_RATIO, "SPL F")
		feeProtocol = slot0Start.feeProtocol >> 4 // >> 4 is / 16
		feeGrowthGlobal = pool.feeGrowthGlobal1
	}

	pool.slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: pool.liquidity,
		blockTimestamp: GetTimestamp(),
		feeProtocol: feeProtocol,
	}
	
	exactInput := amountSpecified > 0
	
	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPrice: slot0Start.sqrtPrice,
			tick: slot0Start.tick,
			feeGrowthGlobal: pool.feeGrowthGlobal0,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPrice: slot0Start.sqrtPrice,
			tick: slot0Start.tick,
			feeGrowthGlobal: pool.feeGrowthGlobal1,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	}

	
	for state.amountSpecifiedRemaining > 0 && state.sqrtPrice != sqrtPriceLimit {
		var step StepComputations

		step.sqrtPriceStart = state.sqrtPrice
		
		step.tickNext, step.initialized = TickBitmapNextInitializedTickWithInOneWord(
			state.tick,
			pool.tickSpacing,
			zeroForOne,
		)

		if step.tickNext < MIN_TICK {
			step.tickNext = MIN_TICK
		} else if step.tickNext > MAX_TICK {
			step.tickNext = MAX_TICK
		}

		step.sqrtPriceNext = TickMathGetSqrtRatioAtTick(step.tickNext)

		var sqrtRatioTarget bigint
		if zeroForOne {
			if step.sqrtPriceNext < sqrtPriceLimit {
				sqrtRatioTarget = sqrtPriceLimit
			} else {
				sqrtRatioTarget = step.sqrtPriceNext
			}
		} else {
			if step.sqrtPriceNext > sqrtPriceLimit {
				sqrtRatioTarget = sqrtPriceLimit
			} else {
				sqrtRatioTarget = step.sqrtPriceNext
			}
		}
				
		state.sqrtPrice, step.amountIn, step.amountOut, step.feeAmount = SwapMathComputeSwapStep(
			state.sqrtPrice,
			sqrtRatioTarget,
			state.liquidity,
			state.amountSpecifiedRemaining,
			pool.fee,
		)

		if exactInput {
			state.amountSpecifiedRemaining = state.amountSpecifiedRemaining - bigint(step.amountIn + step.feeAmount)
			state.amountCalculated = state.amountCalculated - bigint(step.amountOut)
		} else {
			state.amountSpecifiedRemaining = state.amountSpecifiedRemaining + bigint(step.amountOut)
			state.amountCalculated = state.amountCalculated + bigint(step.amountIn + step.feeAmount)
		}

		if cache.feeProtocol > 0 {
			delta := step.feeAmount / cache.feeProtocol
			step.feeAmount = step.feeAmount - delta
			state.protocolFee = state.protocolFee + delta
		}

		if state.liquidity > 0 {
			state.feeGrowthGlobal = state.feeGrowthGlobal + step.feeAmount / state.liquidity
		}
		
		if state.sqrtPrice == step.sqrtPriceNext {
			if step.initialized {
				var fee0, fee1 bigint
				
				if (zeroForOne) {
					fee0 = state.feeGrowthGlobal
					fee1 = pool.feeGrowthGlobal1
				} else {
					fee0 = pool.feeGrowthGlobal0
					fee1 = state.feeGrowthGlobal
				}

				liquidityNet := TickCross(
					step.tickNext,
					fee0,
					fee1,
					cache.blockTimestamp,
				)

				if zeroForOne {
					liquidityNet = -liquidityNet
				}

				state.liquidity = LiquidityMathAddDelta(state.liquidity, liquidityNet)
			}

			if zeroForOne {
				state.tick = step.tickNext -1 
			} else {
				state.tick = step.tickNext
			}
		} else if state.sqrtPrice != step.sqrtPriceStart {
			state.tick = TickMathGetTickAtSqrtRatio(state.sqrtPrice)
		}
	}

	if state.tick != slot0Start.tick {
		pool.slot0.sqrtPrice = state.sqrtPrice
		pool.slot0.tick = state.tick
		// pool.slot0.observationIndex = obervationIndex
		// pool.slot0.observationCardinality = observationCardinality
	} else {
		pool.slot0.sqrtPrice = state.sqrtPrice
	}

	if cache.liquidityStart != state.liquidity {
		pool.liquidity = state.liquidity
	}


	if zeroForOne {
		pool.feeGrowthGlobal0 = state.feeGrowthGlobal
		if state.protocolFee > 0 {
			pool.protocolFees.token0 = pool.protocolFees.token0 + state.protocolFee
		}
	} else {
		pool.feeGrowthGlobal1 = state.feeGrowthGlobal
		if state.protocolFee > 0 {
			pool.protocolFees.token1 = pool.protocolFees.token1 + state.protocolFee
		}
	}

	var amount0, amount1 bigint
	if zeroForOne == exactInput {
		amount0 = bigint(amountSpecified - state.amountSpecifiedRemaining)
		amount1 = bigint(state.amountCalculated)
	} else {
		amount0 = bigint(state.amountCalculated)
		amount1 = bigint(amountSpecified - state.amountSpecifiedRemaining)
	}
	
	if zeroForOne {
		if amount1 < 0 {
			Transfer(pool.token1, GetOrigPkgAddr(), recipient, uint64(-amount1))
		}
		balance0Before := BalanceOf(pool.token0, GetOrigPkgAddr())
		TransferFrom(pool.token0, GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount0))
		require(balance0Before + bigint(amount0) <= BalanceOf(pool.token0, GetOrigPkgAddr()), "IIA0")
	} else {
		if amount0 < 0 {
			Transfer(pool.token0, GetOrigPkgAddr(), recipient, uint64(-amount0))
		}
		balance1Before := BalanceOf(pool.token1, GetOrigPkgAddr())
		TransferFrom(pool.token1, GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount1))
		require(balance1Before + bigint(amount1) <= BalanceOf(pool.token1, GetOrigPkgAddr()), "IIA1")
	}

	pool.slot0.unlocked = true;

	return amount0, amount1
}

func (pool *Pool) SetFeeProtocol(feeProtocol0, feeProtocol1 bigint) {
	require (
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
		(feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		"Invalid fee protocol",
	)
	pool.slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // << 4 is * 16
}

func (pool *Pool) CollectFeeProtocol(
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	// XXX check owner, IT IS PROTOCOL FEE NOT SWAP FEE
	var amount0, amount1 bigint

	if amount0Requested > pool.protocolFees.token0 {
		amount0 = pool.protocolFees.token0
	} else {
		amount0 = amount0Requested
	}

	if amount1Requested > pool.protocolFees.token1 {
		amount1 = pool.protocolFees.token1
	} else {
		amount1 = amount1Requested
	}


	if amount0 > 0 {
		if amount0 == pool.protocolFees.token0 {
			amount0--
		}
		pool.protocolFees.token0 -= amount0

		// XXX
		// Currently GRC20 expect uint for amount
		// token0.Transfer(recipient, uint64(amount0))
		err := Transfer(pool.token0, GetOrigPkgAddr(), recipient, uint64(amount0))
		if err != nil {
			panic(err)
		}
	}

	if amount1 > 0 {

		if pool.amount1 == pool.protocolFees.token1 {
			amount1--
		}
		pool.protocolFees.token1 -= amount1

		err := Transfer(pool.token1, GetOrigPkgAddr(), recipient, uint64(amount1))
		if err != nil {
			panic(err)
		}
	}

	return amount0, amount1
}

func (pool *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, bigint, bigint) {
	checkTicks(params.tickLower, params.tickUpper)

	position := pool.updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		pool.slot0.tick,
	)

	var amount0, amount1 bigint

	if params.liquidityDelta != 0 {
		if (pool.slot0.tick < params.tickLower) {
			amount0 = SqrtPriceMathGetAmount0Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		} else if (pool.slot0.tick < params.tickUpper) {
			liquidityBefore := pool.liquidity

			// XXX write oracle
			amount0 = SqrtPriceMathGetAmount0Delta(
				pool.slot0.sqrtPrice,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPrice,
				params.liquidityDelta,
			)

			pool.liquidity = LiquidityMathAddDelta(liquidityBefore, params.liquidityDelta)

		} else {
			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		}
	}

	return position, amount0, amount1
}

func (pool *Pool) updatePosition(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
	liquidityDelta bigint,
	tick bigint,
) (PositionInfo) {
	// key code is at L#615

	var _feeGrowthGlobal0 bigint = pool.feeGrowthGlobal0
	var _feeGrowthGlobal1 bigint = pool.feeGrowthGlobal1
	var flippedLower, flippedUpper bool

	if (liquidityDelta != 0) {
		time := GetTimestamp()
		// XXX write oracle entry
		(pool.ticks[tick], flippedLower) = TickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0,
			_feeGrowthGlobal1,
			// secondsPerLiquidityCumulative,
			time, 
			false,
			pool.maxLiquidityPerTick,
			pool.ticks[tick],
		)

		(pool.ticks[tick], flippedUpper) = TickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0,
			_feeGrowthGlobal1,
			// secondsPerLiquidityCumulative,
			time,
			true,
			pool.maxLiquidityPerTick,
			pool.ticks[tick],
		)

		if (flippedLower) {
			TickBitmapFlipTick(tickLower, pool.tickSpacing)
		}

		if (flippedUpper) {
			TickBitmapFlipTick(tickUpper, pool.tickSpacing)
		}
	}

	feeGrowthInside0, feeGrowthInside1 := TickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0,
		_feeGrowthGlobal1,
	)

	key := PositionGetKey(owner, tickLower, tickUpper)
	position := PositionUpdateWithKey(
		key, 
		liquidityDelta,
		feeGrowthInside0,
		feeGrowthInside1,
	)


	if (liquidityDelta < 0) {
		if (flippedLower) {
			TickClear(tickLower)
		}

		if (flippedUpper) {
			TickClear(tickUpper)
		}
	}
	return position
}

func require(cond bool, msg string) {
	if !cond {
		panic(msg)
	}
}

func checkTicks(tickLower, tickUpper bigint) {
	require(tickLower < tickUpper, "TLU")
	require(tickLower >= MIN_TICK, "TL")
	require(tickUpper <= MAX_TICK, "TU")
}

// XXX pubsub
func emit(event interface{}) {}

// GRC20 TransferFrom mockup. Replace with the actual one once inter-contract calls are supported
func TransferFrom(token string, from std.Address, to std.Address, amount bigint, callback string, args []string) error {
	println("say hello from A, going to call B")

	// call := "gno.land/r/demo/greet#Greet#hey&hi&ho"

	call := std.EncodeMsgCall(token, "TransferFrom", []string{from.String(), to.String(), amount.String()})
	callback := std.EncodeMsgCall(GetOrigPkgAddr(), callback, args)

	std.Send(call, callback)
}