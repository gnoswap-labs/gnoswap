package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// calc amount0, amount1 from liquidity
func getAmountsFromLiquidity(
	pToken0 string,
	pToken1 string,
	pFee uint16,
	tickLower int32,
	tickUpper int32,
	liquidityAmount bigint,
	tick int32,
) (bigint, bigint) {
	require(liquidityAmount > 0, "[POOL] math_logic.gno__Calc01() || liquidityAmount must be > 0")

	pool := GetPool(pToken0, pToken1, pFee)
	_, amount0, amount1 := pool.modifyPosition(
		ModifyPositionParams{
			"_",
			tickLower,
			tickUpper,
			liquidityAmount,
		},
	)

	return amount0, amount1
}

// get sqrtX96 from tick
func getSqrtRatioFromTick(
	tick int32,
) bigint {
	return TickMathGetSqrtRatioAtTick(tick)
}

// get tick from sqrtX96
func getTickFromSqrtRatio(
	sqrtX96 bigint,
) int32 {
	return TickMathGetTickAtSqrtRatio(sqrtX96)
}

func swapAmount(
	pToken0 string,
	pToken1 string,
	pFee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "[POOL] pool.gno__Swap() || amountSpecified can't be zero")

	pool := GetPool(pToken0, pToken1, pFee)

	slot0Start := pool.slot0
	require(slot0Start.unlocked, "[POOL] pool.gno__Swap() || slot0 must be unlocked")

	if zeroForOne {
		require(
			sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(T)__sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > MIN_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MIN_SQRT_RATIO),
		)
	} else {
		require(
			sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO,
			ufmt.Sprintf("[POOL] pool.gno__Swap() || SPL-zeroForOne(F)__sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < MAX_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MAX_SQRT_RATIO),
		)
	}

	pool.slot0.unlocked = false

	cache := SwapCache{
		liquidityStart: pool.liquidity,
		feeProtocol:    0,
	}

	exactInput := amountSpecified > 0

	var state SwapState
	if zeroForOne {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         0,
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal0X128,
			protocolFee:              0,
			liquidity:                cache.liquidityStart,
		}
	} else {
		state = SwapState{
			amountSpecifiedRemaining: amountSpecified,
			amountCalculated:         0,
			sqrtPriceX96:             slot0Start.sqrtPriceX96,
			tick:                     slot0Start.tick,
			feeGrowthGlobalX128:      pool.feeGrowthGlobal1X128,
			protocolFee:              0,
			liquidity:                cache.liquidityStart,
		}
	}

	for state.amountSpecifiedRemaining != 0 && state.amountSpecifiedRemaining != -1 && state.sqrtPriceX96 != sqrtPriceLimitX96 {
		var step StepComputations

		step.sqrtPriceStartX96 = state.sqrtPriceX96

		step.tickNext, step.initialized = pool.tickBitmapNextInitializedTickWithInOneWord(
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

		state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = swapMathComputeSwapStep(
			state.sqrtPriceX96,
			_sqrtRatioTarget,
			state.liquidity,
			state.amountSpecifiedRemaining,
			uint32(pool.fee),
		)

		if exactInput {
			state.amountSpecifiedRemaining -= step.amountIn + step.feeAmount
			state.amountCalculated -= step.amountOut
		} else {
			state.amountSpecifiedRemaining += step.amountOut
			state.amountCalculated += (step.amountIn + step.feeAmount)
		}
	}

	// END LOOP

	var amount0, amount1 bigint
	if zeroForOne == exactInput {
		amount0 = amountSpecified - state.amountSpecifiedRemaining
		amount1 = state.amountCalculated
	} else {
		amount0 = state.amountCalculated
		amount1 = amountSpecified - state.amountSpecifiedRemaining
	}

	pool.slot0.unlocked = true
	return amount0, amount1
}
