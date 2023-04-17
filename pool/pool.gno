package gnoswap

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"

	"gno.land/p/demo/ufmt"

	"gno.land/r/foo"
	"gno.land/r/bar"
	// "gno.land/r/baz"
	// "gno.land/r/qux"
)


type Slot0 struct {
	sqrtPrice bigint
	tick bigint
	feeProtocol bigint
	unlocked bool
}

type ProtocolFees struct {
	token0 bigint 
	token1 bigint 
}

type ModifyPositionParams struct {
	// the address that owns the position
	owner std.Address

	// the lower and upper tick of the position
	tickLower bigint
	tickUpper bigint

	// any change in liquidity
	liquidityDelta bigint
}

type SwapCache struct {
	feeProtocol bigint
	liquidityStart bigint
	blockTimestamp bigint
}

type SwapState struct {
	amountSpecifiedRemaining bigint
	amountCalculated bigint
	sqrtPrice bigint
	tick bigint
	feeGrowthGlobal bigint
	protocolFee bigint
	liquidity bigint
}

type StepComputations struct {
	sqrtPriceStart bigint
	tickNext bigint
	initialized bool
	sqrtPriceNext bigint
	amountIn bigint
	amountOut bigint
	feeAmount bigint
}

var (
 	// factory std.Address
  // token0 std.Address
  // token1 std.Address
	token0 *grc20.AdminToken
	token1 *grc20.AdminToken
	fee bigint
	tickSpacing bigint
	maxLiquidityPerTick bigint
	
	slot0 Slot0
	
	feeGrowthGlobal0 bigint
	feeGrowthGlobal1 bigint
	
	protocolFees ProtocolFees
	liquidity bigint

	ticks map[bigint]TickInfo = make(map[bigint]TickInfo)
	tickBitmaps map[bigint]bigint = make(map[bigint]bigint)
	positions map[string]PositionInfo = make(map[string]PositionInfo)
)

func Init(
	_fee bigint,
	_tickSpacing bigint,
	_sqrtPrice bigint,
	_tick bigint,
) {
	fee = _fee // swap fee, not protocol fee
	tickSpacing = _tickSpacing
	maxLiquidityPerTick = TickTickSpacingToMaxLiquidityPerTick(_tickSpacing)

	token0 = foo.GetGRC20()
	token1 = bar.GetGRC20()

	cardinality := 0
	cardinalityNext := 0

	// _tick := TickMathGetTickAtSqrtRatio(_sqrtPrice)
	// sqrtPrice := TickMathGetSqrtRatioAtTick(_sqrtPrice)

	slot0 = Slot0 {
		_sqrtPrice, // sqrtPrice
		_tick, // tick
		0, // feeProtocol
		true, // unlocked
	}
}

func Mint(
	recipient std.Address,
	tickLower bigint,
	tickUpper bigint,
	amount bigint,
) (bigint, bigint) {
	require(amount > 0, "must be amount > 0")

	_, amount0Int, amount1Int := modifyPosition(
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
		balance0Before = BalanceOf(token0, GetOrigPkgAddr())
		err := token0.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount0))
		if err != nil {
			panic("token0.TransferFrom failed")
		}
		require(balance0Before + amount0 <= BalanceOf(token0, GetOrigPkgAddr()), "[X] balance0")
	}

	if (amount1 > 0) {
		balance1Before = BalanceOf(token1, GetOrigPkgAddr())
		err := token1.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount1))
		if err != nil {
			panic("token1.TransferFrom failed")
		}
		require(balance1Before + amount1 <= BalanceOf(token1, GetOrigPkgAddr()), "[X] balance1")
	}
	return amount0, amount1
}


func Burn(
	tickLower bigint,
	tickUpper bigint,
	amount bigint,
) (bigint, bigint) {
	require(amount > 0, "must be amount > 0")

	position, amount0Int, amount1Int := modifyPosition(
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
	positions[key] = position
	return amount0, amount1
}

func Collect(
	recipient std.Address, 
	tickLower bigint, 
	tickUpper bigint, 
	amount0Requested bigint, 
	amount1Requested bigint,
) (bigint, bigint) {
	key := PositionGetKey(GetOrigCaller(), tickLower, tickUpper)
	position := positions[key]

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
		token0.Transfer(GetOrigPkgAddr(), recipient, uint64(amount0))
	}

	if (amount1 > 0) {
		position.tokensOwed1 -= amount1
		token1.Transfer(GetOrigPkgAddr(), recipient, uint64(amount1))
	}

	positions[key] = position

	return amount0, amount1
}

func Swap(
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimit bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "must be amountSpecified > 0")

	slot0Start := slot0
	require(slot0Start.unlocked, "LOK")

	var feeProtocol, feeGrowthGlobal bigint

	if zeroForOne {
		require(sqrtPriceLimit < slot0Start.sqrtPrice && sqrtPriceLimit > MIN_SQRT_RATIO, "SPL T")
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobal = feeGrowthGlobal0
	} else {
		require(sqrtPriceLimit > slot0Start.sqrtPrice && sqrtPriceLimit < MAX_SQRT_RATIO, "SPL F")
		feeProtocol = slot0Start.feeProtocol >> 4 // >> 4 is / 16
		feeGrowthGlobal = feeGrowthGlobal1
	}

	slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: liquidity,
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
			feeGrowthGlobal: feeGrowthGlobal0,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPrice: slot0Start.sqrtPrice,
			tick: slot0Start.tick,
			feeGrowthGlobal: feeGrowthGlobal1,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	}

	
	for state.amountSpecifiedRemaining > 0 && state.sqrtPrice != sqrtPriceLimit {
		var step StepComputations

		step.sqrtPriceStart = state.sqrtPrice
		
		step.tickNext, step.initialized = TickBitmapNextInitializedTickWithInOneWord(
			state.tick,
			tickSpacing,
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
			fee,
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
					fee1 = feeGrowthGlobal1
				} else {
					fee0 = feeGrowthGlobal0
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
		slot0.sqrtPrice = state.sqrtPrice
		slot0.tick = state.tick
		// slot0.observationIndex = obervationIndex
		// slot0.observationCardinality = observationCardinality
	} else {
		slot0.sqrtPrice = state.sqrtPrice
	}

	if cache.liquidityStart != state.liquidity {
		liquidity = state.liquidity
	}


	if zeroForOne {
		feeGrowthGlobal0 = state.feeGrowthGlobal
		if state.protocolFee > 0 {
			protocolFees.token0 = protocolFees.token0 + state.protocolFee
		}
	} else {
		feeGrowthGlobal1 = state.feeGrowthGlobal
		if state.protocolFee > 0 {
			protocolFees.token1 = protocolFees.token1 + state.protocolFee
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
			token1.Transfer(GetOrigPkgAddr(), recipient, uint64(-amount1))
		}
		balance0Before := BalanceOf(token0, GetOrigPkgAddr())
		token0.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount0))
		require(balance0Before + bigint(amount0) <= BalanceOf(token0, GetOrigPkgAddr()), "IIA0")
	} else {
		if amount0 < 0 {
			token0.Transfer(GetOrigPkgAddr(), recipient, uint64(-amount0))
		}
		balance1Before := BalanceOf(token1, GetOrigPkgAddr())
		token1.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), uint64(amount1))
		require(balance1Before + bigint(amount1) <= BalanceOf(token1, GetOrigPkgAddr()), "IIA1")
	}

	slot0.unlocked = true;

	return amount0, amount1
}

func SetFeeProtocol(feeProtocol0, feeProtocol1 bigint) {
	require (
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
		(feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		"Invalid fee protocol",
	)
	slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // << 4 is * 16
}

func CollectFeeProtocol(
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	// XXX check owner, IT IS PROTOCOL FEE NOT SWAP FEE
	var amount0, amount1 bigint

	if amount0Requested > protocolFees.token0 {
		amount0 = protocolFees.token0
	} else {
		amount0 = amount0Requested
	}

	if amount1Requested > protocolFees.token1 {
		amount1 = protocolFees.token1
	} else {
		amount1 = amount1Requested
	}


	if amount0 > 0 {
		if amount0 == protocolFees.token0 {
			amount0--
		}
		protocolFees.token0 -= amount0

		// XXX
		// Currently GRC20 expect uint for amount
		// token0.Transfer(recipient, uint64(amount0))
		err := token0.Transfer(GetOrigPkgAddr(), recipient, uint64(amount0))
		if err != nil {
			panic(err)
		}
	}

	if amount1 > 0 {

		if amount1 == protocolFees.token1 {
			amount1--
		}
		protocolFees.token1 -= amount1

		err := token1.Transfer(GetOrigPkgAddr(), recipient, uint64(amount1))
		if err != nil {
			panic(err)
		}
	}

	return amount0, amount1
}


func modifyPosition(params ModifyPositionParams) (PositionInfo, bigint, bigint) {
	checkTicks(params.tickLower, params.tickUpper)

	position := updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		slot0.tick,
	)

	var amount0, amount1 bigint

	if params.liquidityDelta != 0 {
		if (slot0.tick < params.tickLower) {
			amount0 = SqrtPriceMathGetAmount0Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		} else if (slot0.tick < params.tickUpper) {
			liquidityBefore := liquidity

			// XXX write oracle
			amount0 = SqrtPriceMathGetAmount0Delta(
				slot0.sqrtPrice,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				slot0.sqrtPrice,
				params.liquidityDelta,
			)

			liquidity = LiquidityMathAddDelta(liquidityBefore, params.liquidityDelta)

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

func updatePosition(
	owner std.Address,
	tickLower bigint,
	tickUpper bigint,
	liquidityDelta bigint,
	tick bigint,
) (PositionInfo) {
	// key code is at L#615

	var _feeGrowthGlobal0 bigint = feeGrowthGlobal0
	var _feeGrowthGlobal1 bigint = feeGrowthGlobal1
	var flippedLower, flippedUpper bool

	if (liquidityDelta != 0) {
		time := GetTimestamp()
		// XXX write oracle entry
		flippedLower = TickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0,
			_feeGrowthGlobal1,
			// secondsPerLiquidityCumulative,
			time, 
			false,
			maxLiquidityPerTick,
		)

		flippedUpper = TickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0,
			_feeGrowthGlobal1,
			// secondsPerLiquidityCumulative,
			time,
			true,
			maxLiquidityPerTick,
		)

		if (flippedLower) {
			TickBitmapFlipTick(tickLower, tickSpacing)
		}

		if (flippedUpper) {
			TickBitmapFlipTick(tickUpper, tickSpacing)
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