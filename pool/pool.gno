import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"

	"gno.land/p/demo/ufmt"

	"gno.land/r/foo"
	"gno.land/r/bar"
)


type Slot0 struct {
	sqrtPriceX96 bigint
	tick bigint
	feeProtocol bigint
	unlocked bool
}

type ProtocolFees struct {
	token0 bigint 
	token1 bigint 
}

type ModifyPositionParams struct {
	owner std.Address
	tickLower bigint
	tickUpper bigint
	liquidityDelta bigint
}

type SwapCache struct {
	feeProtocol bigint
	liquidityStart bigint
}

type SwapState struct {
	amountSpecifiedRemaining bigint
	amountCalculated bigint
	sqrtPriceX96 bigint
	tick bigint
	feeGrowthGlobalX128 bigint
	protocolFee bigint
	liquidity bigint
}

type StepComputations struct {
	sqrtPriceStartX96 bigint
	tickNext bigint
	initialized bool
	sqrtPriceNextX96 bigint
	amountIn bigint
	amountOut bigint
	feeAmount bigint
}

// type Pool describes a single Pool's state
// A pool is identified with a unique key (token0, token1, fee), where token0 < token1
type Pool struct {
	// token0 is the package name of the first token
	token0 *grc20.AdminToken
	// token1 is the package name of the second token
	token1 *grc20.AdminToken

	// fee is the fee tier of the pool

	fee bigint
	// tickSpacing is the spacing between ticks
	tickSpacing bigint
	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	maxLiquidityPerTick bigint

	// slot0 is the current tick and price of the pool
	slot0 Slot0

	feeGrowthGlobal0X128 bigint
	feeGrowthGlobal1X128 bigint

	// protocolFees is the amount of fees collected by the protocol
	// collected by CollectFeeProtocol()
	protocolFees bigint
	// liquidity is the total amount of liquidity in the pool
	liquidity bigint

	// ticks is a mapping from tick index to tick
	ticks map[bigint]*TickInfo
	// tickBitmaps is a mapping from tick index to tick bitmap
	tickBitmaps map[bigint]*bigint
	// positions maps the key (caller, lower tick, upper tick) to a unique position
	positions map[string]*PositionInfo
}



func NewPool(
	token0 string,
	token1 string,
	fee bigint,
	tickSpacing bigint,
	sqrtPriceX96 bigint,
	tick bigint,
) *Pool {
	maxLiquidityPerTick := TickTickSpacingToMaxLiquidityPerTick(tickSpacing)
	// sqrtPrice := TickMathGetSqrtRatioAtTick(_sqrtPrice)
	tick := TickMathGetTickAtSqrtRatio(_sqrtPriceX96)

	slot0 := Slot0 {
		sqrtPriceX96, // sqrtPrice
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
			recipient, // owner
			tickLower, // tickLower
			tickUpper, // tickUpper
			amount,		 // liquidityDelta
		},
	)

	amount0 := bigint(amount0Int)
	amount1 := bigint(amount1Int)
	requireUnsigned(amount0, "pool.gno__Mint__amount0")
	requireUnsigned(amount1, "pool.gno__Mint__amount1")

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
	requireUnsigned(amount0, "pool.gno__Burn__amount0")
	requireUnsigned(amount1, "pool.gno__Burn__amount1")


	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 += amount0
		position.tokensOwed1 += amount1
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
	requireUnsigned(amount0Requested, "pool.gno__Collect__amount0Requested")
	requireUnsigned(amount1Requested, "pool.gno__Collect__amount1Requested")

	key := PositionGetKey(GetOrigCaller(), tickLower, tickUpper)
	position := pool.positions[key]

	var amount0, amount1 bigint

	if amount0Requested > position.tokensOwed0 {
		amount0 = position.tokensOwed0
	} else {
		amount0 = amount0Requested
	}
	requireUnsigned(amount0, "pool.gno__Collect__amount0")

	if amount1Requested > position.tokensOwed1 {
		amount1 = position.tokensOwed1
	} else {
		amount1 = amount1Requested
	}
	requireUnsigned(amount1, "pool.gno__Collect__amount1")

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
	sqrtPriceLimitX96 bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "must be amountSpecified > 0")

	slot0Start := pool.slot0
	require(slot0Start.unlocked, "LOK")

	var feeProtocol, feeGrowthGlobalX128 bigint

	if zeroForOne {
		require(sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO, "SPL-T")
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = pool.feeGrowthGlobal0X128
	} else {
		require(sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO, "SPL-F")
		feeProtocol = slot0Start.feeProtocol >> 4 // ( >> 4 ) ==  ( / 16 )
		feeGrowthGlobalX128 = feeGrowthGlobal1X128
	}

	pool.slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: pool.liquidity,
		feeProtocol: feeProtocol,
	}
	
	exactInput := amountSpecified > 0
	
	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPriceX96: slot0Start.sqrtPriceX96,
			tick: slot0Start.tick,
			feeGrowthGlobalX128: pool.feeGrowthGlobal0X128,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPriceX96: slot0Start.sqrtPriceX96,
			tick: slot0Start.tick,
			feeGrowthGlobalX128: pool.feeGrowthGlobal1X128,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	}

	for state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		var step StepComputations

		step.sqrtPriceStartX96 = state.sqrtPriceX96
		
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

		step.sqrtPriceNextX96 = TickMathGetSqrtRatioAtTick(step.tickNext)

		var _sqrtRatioTarget bigint
		if zeroForOne {
			if step.sqrtPriceNextX96 < sqrtPriceLimitX96 {
				_sqrtRatioTarget = sqrtPriceLimitX96
			} else {
				_sqrtRatioTarget = step.sqrtPriceNextX96
			}
		} else {
			if step.sqrtPriceNextX96 > sqrtPriceLimitX96 {
				_sqrtRatioTarget = sqrtPriceLimitX96
			} else {
				_sqrtRatioTarget = step.sqrtPriceNextX96
			}
		}

		state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = SwapMathComputeSwapStep(
			state.sqrtPriceX96,
			_sqrtRatioTarget,
			state.liquidity,
			state.amountSpecifiedRemaining,
			pool.fee,
		)

		if exactInput {
			state.amountSpecifiedRemaining -= step.amountIn + step.feeAmount
			state.amountCalculated -= step.amountOut
		} else {
			state.amountSpecifiedRemaining += step.amountOut
			state.amountCalculated += (step.amountIn + step.feeAmount)
		}

		if cache.feeProtocol > 0 {
			delta := step.feeAmount / cache.feeProtocol
			requireUnsigned(delta, "pool.gno__Swap__delta")
			step.feeAmount -= delta
			state.protocolFee += delta
		}
	
		if state.liquidity > 0 {
			state.feeGrowthGlobalX128 += (step.feeAmount * Q128 / state.liquidity)
		}
		
		if state.sqrtPriceX96 == step.sqrtPriceNextX96 {
			if step.initialized {
				var fee0, fee1 bigint
				
				if (zeroForOne) {
					fee0 = state.feeGrowthGlobalX128
					fee1 = pool.feeGrowthGlobal1X128
				} else {
					fee0 = pool.feeGrowthGlobal0X128
					fee1 = state.feeGrowthGlobalX128
				}

				liquidityNet := TickCross(
					step.tickNext,
					fee0,
					fee1,
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
		} else if state.sqrtPriceX96 != step.sqrtPriceStartX96 {
			state.tick = TickMathGetTickAtSqrtRatio(state.sqrtPriceX96)
		}
	}

	if state.tick != slot0Start.tick {
		pool.slot0.sqrtPriceX96 = state.sqrtPriceX96
		pool.slot0.tick = state.tick
	} else {
		pool.slot0.sqrtPriceX96 = state.sqrtPriceX96
	}

	if cache.liquidityStart != state.liquidity {
		pool.liquidity = state.liquidity
	}


	if zeroForOne {
		pool.feeGrowthGlobal0X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			pool.protocolFees.token0 += state.protocolFee
		}
	} else {
		pool.feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			pool.protocolFees.token1 += state.protocolFee
		}
	}

	var amount0, amount1 bigint
	if zeroForOne == exactInput {
		amount0 = amountSpecified - state.amountSpecifiedRemaining
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = amountSpecified - state.amountSpecifiedRemaining
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

// TODO: is it safe to expose this?
func (pool *Pool) SetFeeProtocol(feeProtocol0, feeProtocol1 bigint) {
	requireUnsigned(feeProtocol0, "pool.gno__SetFeeProtocol__feeProtocol0")
	requireUnsigned(feeProtocol1, "pool.gno__SetFeeProtocol__feeProtocol1")

	require (
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
		(feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		"Invalid fee protocol",
	)
	pool.slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )
}

// TODO: is it safe to expose this?
func (pool *Pool) CollectFeeProtocol(
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	requireUnsigned(amount0Requested, "pool.gno__CollectProtocol__amount0Requested")
	requireUnsigned(amount1Requested, "pool.gno__CollectProtocol__amount1Requested")

	// // XXX
	// if (GetOrigCaller() != factoryOwner) {
	// 	panic("NO OWNER")
	// }

	var amount0, amount1 bigint

	if amount0Requested > pool.protocolFees.token0 {
		amount0 = pool.protocolFees.token0
	} else {
		amount0 = amount0Requested
	}
	requireUnsigned(amount0, "pool.gno__CollectProtocol__amount0")

	if amount1Requested > pool.protocolFees.token1 {
		amount1 = pool.protocolFees.token1
	} else {
		amount1 = amount1Requested
	}
	requireUnsigned(amount1, "pool.gno__CollectProtocol__amount1")

	if amount0 > 0 {
		if amount0 == pool.protocolFees.token0 {
			amount0--
		}
		pool.protocolFees.token0 -= amount0

		err := pool.token0.Transfer(GetOrigPkgAddr(), recipient, uint64(amount0))
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

			amount0 = SqrtPriceMathGetAmount0Delta(
				pool.slot0.sqrtPriceX96,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)

			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPriceX96,
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
	var _feeGrowthGlobal0X128 bigint = pool.feeGrowthGlobal0X128
	var _feeGrowthGlobal1X128 bigint = pool.feeGrowthGlobal1X128
	var flippedLower, flippedUpper bool

	if (liquidityDelta != 0) {
		flippedLower = TickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			pool.maxLiquidityPerTick,
			pool.ticks[tick],
		)

		(pool.ticks[tick], flippedUpper) = TickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
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

	feeGrowthInside0X128, feeGrowthInside1X128 := TickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	key := PositionGetKey(owner, tickLower, tickUpper)
	position := PositionUpdateWithKey(
		key, 
		liquidityDelta,
		feeGrowthInside0X128,
		feeGrowthInside1X128,
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

// GRC20 TransferFrom mockup. Replace with the actual one once inter-contract calls are supported
func TransferFrom(token string, from std.Address, to std.Address, amount bigint, callback string, args []string) error {
	println("say hello from A, going to call B")

	// call := "gno.land/r/demo/greet#Greet#hey&hi&ho"

	call := std.EncodeMsgCall(token, "TransferFrom", []string{from.String(), to.String(), amount.String()})
	callback := std.EncodeMsgCall(GetOrigPkgAddr(), callback, args)

	std.Send(call, callback)

}