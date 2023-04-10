package gnoswap

import (
	"std"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/grc/grc20"

	"gno.land/r/foo"
	"gno.land/r/bar"
	// "gno.land/r/baz"
	// "gno.land/r/qux"
)


type Slot0 struct {
	// the current price
	sqrtPrice bigdec
	
	// the current tick
	tick bigint

	// the current protocol fee as a percentage of the swap fee taken on withdrawal represented as an integer denominator (1/x)%
	feeProtocol uint64

	// whether the pool is locked
	unlocked bool
}

type ProtocolFees struct {
	token0 bigdec 
	token1 bigdec 
}

type ModifyPositionParams struct {
	// the address that owns the position
	owner std.Address

	// the lower and upper tick of the position
	tickLower bigint // int64
	tickUpper bigint // int64

	// any change in liquidity
	liquidityDelta bigdec
}

var (
	// factory std.Address
	// token0 std.Address
	// token1 std.Address
	token0 *grc20.AdminToken
	token1 *grc20.AdminToken
	fee uint64
	tickSpacing bigint
	maxLiquidityPerTick bigint
	
	slot0 Slot0
	
	feeGrowthGlobal0 bigdec
	feeGrowthGlobal1 bigdec
	
	protocolFees ProtocolFees
	liquidity bigdec

	ticks avl.Tree
	tickBitmap avl.Tree
	positions avl.Tree
	ok bool // for avl.Tree Get()
)

func Init(
	_fee uint64,
	_tickSpacing bigint,
	_sqrtPrice bigdec,
	_tick bigint,
) {
	fee = _fee
	tickSpacing = _tickSpacing
	maxLiquidityPerTick = TickTickSpacingToMaxLiquidityPerTick(_tickSpacing)

	token0 = foo.GetGRC20()
	token1 = bar.GetGRC20()

	cardinality := 0
	cardinalityNext := 0

	slot0 = Slot0 {
		_sqrtPrice, // sqrtPrice
		_tick, // tick
		0, // feeProtocol
		true, // unlocked
	}
}

func Mint(
	recipient std.Address,
	tickLower bigint, // uint64
	tickUpper bigint, // uint64
	amount bigdec,
) (amount0, amount1 bigdec) {
	require(amount > 0, "must be amount > 0")

	_, amount0Dec, amount1Dec := modifyPosition(
		ModifyPositionParams{
			recipient,
			tickLower,
			tickUpper,
			amount,
		},
	)

	amount0 := amount0Dec
	amount1 := amount1Dec

	var balance0Before, balance1Before bigint

	/// XXX Callback unavailable
	if (amount0 > 0) {
		blanace0Before = token0.BalanceOf(GetOrigPkgAddr())
		token0.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), amount0) /// data type
		require(balance0Before + amount0 <= token0.BalanceOf(GetOrigPkgAddr()), "balance0")
	}

	if (amount1 > 0) {
		blanace1Before = token1.BalanceOf(GetOrigPkgAddr())
		token1.TransferFrom(GetOrigPkgAddr(), GetOrigCaller(), GetOrigPkgAddr(), amount1)
		require(balance1Before + amount1 <= token1.BalanceOf(GetOrigPkgAddr()), "balance1")
	}

	return amount0, amount1
}


func Burn(
	tickLower bigint,
	tickUpper bigint,
	amount bigint
) (bigint, bigint) {
	checkTicks(tickLower, tickUpper)
	reqiuire(amount > 0, "must be amoutn > 0")

	position, amount0Dec, amount1Dec := modifyPosition(
		ModifyPositionParams{
			GetOrigCaller(),
			tickLower,
			tickUpper,
			bigint(-amount)
		}
	)

	amount0 := bigint(-amount0Int)
	amount1 := bigint(-amount1Int)

	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 = amount0 + position.tokensOwed0
		position.tokensOwed1 = amount1 + position.tokensOwed1
	}

	key := positionGet(GetOrigCaller(), tickLower, tickUpper)
	positions.Set(key, position)
	return amount0, amount1
}

func Collect(
	recipient std.Address, 
	tickLower bigint, 
	tickUpper bigint, 
	amount0Requested bigint, 
	amount1Request bigint
) (bigint, bigint) {
	key := positionGet(std.GetOrigCaller(), tickLower, tickUpper)
	position := positions[key]
	
	var amount0, amount1 bigint

	if amount0Requested > position.tokensOwed0 {
		amount0 = position.tokensOwed0
	} else {
		amount0 = amount0Requested
	}

	if amount1Request > position.tokensOwed1 {
		amount1 = position.tokensOwed1
	} else {
		amount1 = amount1Request
	}

	if (amount0 > 0) {
		position.tokensOwed0 -= amount0
		Token0.Transfer(std.GetOrigPkgAddr(), recipient, uint64(amount0))
	}

	if (amount1 > 0) {
		position.tokensOwed1 -= amount1
		Token1.Transfer(std.GetOrigPkgAddr(), recipient, uint64(amount1))
	}

	positions[key] = position

	return amount0, amount1
}

func Swap(
	pool std.Address,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimit bigint,
) (bigint, bigint) {
	require(amountSpecified > 0, "must be amountSpecified > 0")

	slot0Start := slot0
	require(slot0Start.unlocked, "LOK")

	var feeProtocol bigint
	var feeGrowthGlobal bigint

	if zeroForOne {
		require(sqrtPriceLimit < slot0Start.sqrtPrice && sqrtPriceLimit > MIN_SQRT_RATIO, "SPL")
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobal = feeGrowthGlobal0
	} else {
		require(sqrtPriceLimit > slot0Start.sqrtPrice && sqrtPriceLimit < MAX_SQRT_RATIO, "SPL")
		feeProtocol = slot0Start.feeProtocol >> 4
		feeGrowthGlobal = feeGrowthGlobal1
	}

	slot0.unlocked = false

	cache := SwapCache{
		feeProtocol: feeProtocol,
		liquidityStart: liquidity,
		blockTimestamp: bigint(GetTimestamp()),
	}

	exactInput := amountSpecified > 0

	state := SwapState{
		amountSpecifiedRemaining: amountSpecified,
		amountCalculated: 0,
		sqrtPrice: slot0Start.sqrtPrice,
		tick: slot0Start.tick,
		feeGrowthGlobal: feeGrowthGlobal,
		protocolFee: 0,
		liquidity: cache.liquidityStart,
	}


	for state.amountSpecifiedRemaining != 0 && state.sqrtPrice != sqrtPriceLimit {
		var step StepComputations

		step.sqrtPriceStart = state.sqrtPrice
		step.tickNext, step.initialized = nextInitializedTickWithinOneWord(
			tickBitmap,
			state.tick,
			tickSpacing,
			zeroForOne,
		)

		if step.tickNext < MIN_TICK {
			step.tickNext = MIN_TICK
		} else if step.tickNext > MAX_TICK {
			step.tickNext = MAX_TICK
		}

		step.sqrtPriceNext = getSqrtRatioAtTick(step.tickNext)

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

		state.sqrtPrice, step.amountIn, step.amountOut, step.feeAmount = computeSwapStep(
			state.sqrtPrice,
			sqrtRatioTarget,
			state.liquidity,
			state.amountSpecifiedRemaining,
			fee,
		)

		if exactInput {
			state.amountSpecifiedRemaining -= bigint(safemath.Add(step.amountIn, step.feeAmount))
			state.amountCalculated -= bigint(step.amountOut)
		} else {
			state.amountSpecifiedRemaining += bigint(step.amountOut)
			state.amountCalculated += bigint(safemath.Add(step.amountIn, step.feeAmount))
		}

		if cache.feeProtocol > 0 {
			delta := safemath.Div(step.feeAmount, cache.feeProtocol)
			step.feeAmount = safemath.Sub(step.feeAmount, delta)
			state.protocolFee = safemath.Add(delta, state.protocolFee)
		}

		if state.liquidity > 0 {
			state.feeGrowthGlobal = safemath.Add(state.feeGrowthGlobal, safemath.Div(step.feeAmount, state.liquidity))
		}

		if state.sqrtPrice == step.sqrtPriceNext {
			if step.initialized {
				var fee0X bigint
				var fee1X bigint
				
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

				state.liquidity = state.liquidity + liquidityNet
			}

			if zeroForOne {
				state.tick = step.tickNext -1 
			} else {
				state.tick = step.tickNext
			}
		} else if state.sqrtPrice != step.sqrtPriceNext {
			state.tick = getTickAtSqrtRatio(state.sqrtPrice)
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
			protocolFees.token0 = safemath.Add(protocolFees.token0, state.protocolFee)
		}
	} else {
		feeGrowthGlobal1 = state.feeGrowthGlobal
		if state.protocolFee > 0 {
			protocolFees.token1 = safemath.Add(protocolFees.token1, state.protocolFee)
		}
	}

	var amount0 bigint
	var amount1 bigint

	if zeroForOne == exactInput {
		amount0 = bigint(amountSpecified - state.amountSpecifiedRemaining)
		amount1 = bigint(state.amountCalculated)
	} else {
		amount0 = bigint(state.amountCalculated)
		amount1 = bigint(amountSpecified - state.amountSpecifiedRemaining)
	}

	if zeroForOne {
		if amount1 < 0 {
			Token1.Transfer(GetOrigPkgAddr(), recipient, uint64(-amount1))
		}
		balance0Before := Balance0()
		Token0.TransferFrom(std.GetOrigPkgAddr(), std.GetOrigCaller(), std.GetOrigPkgAddr(), uint64(amount0))

		require(blanace0Before + amount0 <= Balance0(), "IIA0")
	} else {
		if amount0 < 0 {
			Token0.Transfer(std.GetOrigPkgAddr(), recipient, uint64(-amount0))
		}
		balance1Before := Balance1()
		Token1.TransferFrom(std.GetOrigPkgAddr(), std.GetOrigCaller(), std.GetOrigPkgAddr(), uint64(amount1))
		require(safemath.Add(balance1Before, bigint(amount1)) <= Balance1(), "IIA1")
	}

	slot0.unlocked = true;

	return amount0, amount1
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



func modifyPosition(params ModifyPositionParams) (position PositionInfo, amount0, amount1 bigdec) {
	checkTicks(params.tickLower, params.tickUpper)
	var _slot0 Slot0 = slot0

	position = updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		_slot0.tick,
	)

	if (params.liquidityDelta != 0) {
		if (_slot0.tick < params.tickLower) {
			amount0 = SqrtPriceMathGetAmount0Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		} else if (_slot0.tick < params.tickUpper) {
			var liquidityBefore bigdec = liquidity

			// XXX write oracle entry
			amount0 = SqrtPriceMathGetAmount0Delta(
				_slot0.sqrtPrice,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)

			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				_slot0.sqrtPrice,
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
}


func updatePosition(
	owner std.Address,
	tickLower bigint, // uint64
	tickUpper bigint, // uint64
	liquidityDelta bigdec,
	tick bigint, // uint64
) (position PositionInfo) {
	// _key := PositionGet(owner, tickLower, tickUpper)
	// position, ok = positions.Get(_key)
	// if !ok {
	// 	panic("position not found POOL")
	// }

	var _feeGrowthGlobal0 bigdec = feeGrowthGlobal0
	var _feeGrowthGlobal1 bigdec = feeGrowthGlobal1

	var flippedLower bool
	var flippedUpper bool

	if (liquidityDelta != 0) {
		time := GetTimestamp()
		// XXX write oracle entry
		flippedLower = TicksUpdate(
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

		flippedUpper = TicksUpdate(
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

	feeGrowthInside0, feeGrowthInside1 := TicksGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0,
		_feeGrowthGlobal1,
	)

	_key := PositionGet(owner, tickLower, tickUpper)
	position = PositionUpdate(
		_key, // XXX
		liquidityDelta,
		feeGrowthInside0,
		feeGrowthInside1,
	)

	if (liquidityDelta < 0) {
		if (flippedLower) {
			TicksClear(tickLower)
		}

		if (flippedUpper) {
			TicksClear(tickUpper)
		}
	}

	return position
}


func SetFeeProtocol(feeProtocol0, feeProtocol1 bigint) {
	require (
		(feeProtocol0 == 0 || (feeProtocol >= 4 && feeProtocol <= 10)) &&
		(feeProtocol1 == 0 || (feeProtocol >= 4 && feeProtocol <= 10)),
		"Invalid fee protocol",
	)
	slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4)
}

func CollectProtocol(
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (amount0, amount1 bigint) {
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
		// Need to force it to use bigint or bigdec
		Token0.Transfer(std.GetOrigPkgAddr(), recipient, uint64 (amount0))
	}

	if amount1 > 0 {
		if amount1 == protocolFees.token1 {
			amount1--
		}
		protocolFees.token1 -= amount1
		Token1.Transfer(std.GetOrigPkgAddr(), recipient, uint64 (amount1))
	}

	return amount0, amount1
}