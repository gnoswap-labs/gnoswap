package gnoswap

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

var (
	token0 *grc20.AdminToken
	token1 *grc20.AdminToken
	fee bigint
	tickSpacing bigint
	maxLiquidityPerTick bigint
	
	slot0 Slot0
	
	feeGrowthGlobal0X128 bigint
	feeGrowthGlobal1X128 bigint
	
	protocolFees ProtocolFees
	liquidity bigint

	ticks map[bigint]TickInfo = make(map[bigint]TickInfo)
	tickBitmaps map[bigint]bigint = make(map[bigint]bigint)
	positions map[string]PositionInfo = make(map[string]PositionInfo)
)

func Init(
	_fee bigint,
	_tickSpacing bigint,
	_sqrtPriceX96 bigint,
	// _tick bigint,
) {
	fee = _fee // swap fee, not protocol fee
	tickSpacing = _tickSpacing
	maxLiquidityPerTick = TickTickSpacingToMaxLiquidityPerTick(_tickSpacing)

	token0 = foo.GetGRC20()
	token1 = bar.GetGRC20()

	tick := TickMathGetTickAtSqrtRatio(_sqrtPriceX96)

	slot0 = Slot0 {
		_sqrtPriceX96, // sqrtPriceX96
		tick, // tick
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
			recipient, // owner
			tickLower, // tickLower
			tickUpper, // tickUpper
			amount,		 // liquidityDelta
		},
	)

	amount0 := bigint(amount0Int)
	amount1 := bigint(amount1Int)
	isUnsigned(amount0, "pool.gno__Mint__amount0")
	isUnsigned(amount1, "pool.gno__Mint__amount1")

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
	isUnsigned(amount0, "pool.gno__Burn__amount0")
	isUnsigned(amount1, "pool.gno__Burn__amount1")


	if amount0 > 0 || amount1 > 0 {
		position.tokensOwed0 += amount0
		position.tokensOwed1 += amount1
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
	isUnsigned(amount0Requested, "pool.gno__Collect__amount0Requested")
	isUnsigned(amount1Requested, "pool.gno__Collect__amount1Requested")

	key := PositionGetKey(GetOrigCaller(), tickLower, tickUpper)
	position := positions[key]

	var amount0, amount1 bigint

	if amount0Requested > position.tokensOwed0 {
		amount0 = position.tokensOwed0
	} else {
		amount0 = amount0Requested
	}
	isUnsigned(amount0, "pool.gno__Collect__amount0")

	if amount1Requested > position.tokensOwed1 {
		amount1 = position.tokensOwed1
	} else {
		amount1 = amount1Requested
	}
	isUnsigned(amount1, "pool.gno__Collect__amount1")

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
	sqrtPriceLimitX96 bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "must be amountSpecified > 0")

	slot0Start := slot0
	require(slot0Start.unlocked, "LOK")

	var feeProtocol, feeGrowthGlobalX128 bigint

	if zeroForOne {
		require(sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO, "SPL-T")
		feeProtocol = slot0Start.feeProtocol % 16
		feeGrowthGlobalX128 = feeGrowthGlobal0X128
	} else {
		require(sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO, "SPL-F")
		feeProtocol = slot0Start.feeProtocol >> 4 // ( >> 4 ) ==  ( / 16 )
		feeGrowthGlobalX128 = feeGrowthGlobal1X128
	}

	slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: liquidity,
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
			feeGrowthGlobalX128: feeGrowthGlobal0X128,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated: 0,
			sqrtPriceX96: slot0Start.sqrtPriceX96,
			tick: slot0Start.tick,
			feeGrowthGlobalX128: feeGrowthGlobal1X128,
			protocolFee: 0,
			liquidity: cache.liquidityStart,
		}
	}

	for state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		var step StepComputations

		step.sqrtPriceStartX96 = state.sqrtPriceX96
		
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
			fee,
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
			isUnsigned(delta, "pool.gno__Swap__delta")
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
					fee1 = feeGrowthGlobal1X128
				} else {
					fee0 = feeGrowthGlobal0X128
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
		slot0.sqrtPriceX96 = state.sqrtPriceX96
		slot0.tick = state.tick
	} else {
		slot0.sqrtPriceX96 = state.sqrtPriceX96
	}

	if cache.liquidityStart != state.liquidity {
		liquidity = state.liquidity
	}


	if zeroForOne {
		feeGrowthGlobal0X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			protocolFees.token0 += state.protocolFee
		}
	} else {
		feeGrowthGlobal1X128 = state.feeGrowthGlobalX128
		if state.protocolFee > 0 {
			protocolFees.token1 += state.protocolFee
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
	isUnsigned(feeProtocol0, "pool.gno__SetFeeProtocol__feeProtocol0")
	isUnsigned(feeProtocol1, "pool.gno__SetFeeProtocol__feeProtocol1")

	require (
		(feeProtocol0 == 0 || (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
		(feeProtocol1 == 0 || (feeProtocol1 >= 4 && feeProtocol1 <= 10)),
		"Invalid fee protocol",
	)
	slot0.feeProtocol = feeProtocol0 + (feeProtocol1 << 4) // ( << 4 ) = ( * 16 )
}

func CollectProtocol(
	recipient std.Address,
	amount0Requested bigint,
	amount1Requested bigint,
) (bigint, bigint) {
	isUnsigned(amount0Requested, "pool.gno__CollectProtocol__amount0Requested")
	isUnsigned(amount1Requested, "pool.gno__CollectProtocol__amount1Requested")

	// // XXX
	// if (GetOrigCaller() != factoryOwner) {
	// 	panic("NO OWNER")
	// }

	var amount0, amount1 bigint

	if amount0Requested > protocolFees.token0 {
		amount0 = protocolFees.token0
	} else {
		amount0 = amount0Requested
	}
	isUnsigned(amount0, "pool.gno__CollectProtocol__amount0")

	if amount1Requested > protocolFees.token1 {
		amount1 = protocolFees.token1
	} else {
		amount1 = amount1Requested
	}
	isUnsigned(amount1, "pool.gno__CollectProtocol__amount1")

	if amount0 > 0 {
		if amount0 == protocolFees.token0 {
			amount0--
		}
		protocolFees.token0 -= amount0

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

			amount0 = SqrtPriceMathGetAmount0Delta(
				slot0.sqrtPriceX96,
				TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)

			amount1 = SqrtPriceMathGetAmount1Delta(
				TickMathGetSqrtRatioAtTick(params.tickLower),
				slot0.sqrtPriceX96,
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
	var _feeGrowthGlobal0X128 bigint = feeGrowthGlobal0X128
	var _feeGrowthGlobal1X128 bigint = feeGrowthGlobal1X128
	var flippedLower, flippedUpper bool

	if (liquidityDelta != 0) {
		flippedLower = TickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			maxLiquidityPerTick,
		)

		flippedUpper = TickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
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
}