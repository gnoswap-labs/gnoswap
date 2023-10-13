package pool

import (
	"std"

	"gno.land/p/demo/ufmt"
)

// get sqrtX96 from tick
func GetSqrtRatioFromTick(
	tick int32,
) bigint {
	return TickMathGetSqrtRatioAtTick(tick)
}

// get tick from sqrtX96
func GetTickFromSqrtRatio(
	sqrtX96 bigint,
) int32 {
	return TickMathGetTickAtSqrtRatio(sqrtX96)
}

func DrySwap(
	pToken0 string,
	pToken1 string,
	pFee uint16,
	recipient std.Address,
	zeroForOne bool,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) (bigint, bigint) {
	require(amountSpecified != 0, "[POOL] math_logic.gno__DrySwap() || amountSpecified can't be zero")

	pool := GetPool(pToken0, pToken1, pFee)
	require(pool.liquidity > 0, ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || pool.liquidity(%d) must be > 0", pool.liquidity))

	slot0Start := pool.slot0

	if zeroForOne {
		require(
			sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO,
			ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || SPL-zeroForOne(T)__sqrtPriceLimitX96(%s) < slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) > MIN_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MIN_SQRT_RATIO),
		)
	} else {
		require(
			sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO,
			ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || SPL-zeroForOne(F)__sqrtPriceLimitX96(%s) > slot0Start.sqrtPriceX96(%s) && sqrtPriceLimitX96(%s) < MAX_SQRT_RATIO(%s)",
				sqrtPriceLimitX96, slot0Start.sqrtPriceX96, sqrtPriceLimitX96, MAX_SQRT_RATIO),
		)
	}

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

		require(step.amountIn != 0 && step.amountOut != 0, ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || step.amountIn(%d) != 0 && step.amountOut(%d) != 0", step.amountIn, step.amountOut))

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

	if zeroForOne {
		require(pool.balances.token0 > amount0, ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || pool.balances.token0(%s) > amount0(%s)", pool.balances.token0, amount0))
	} else {
		require(pool.balances.token1 > amount1, ufmt.Sprintf("[POOL] math_logic.gno__DrySwap() || pool.balances.token1(%s) > amount1(%s)", pool.balances.token1, amount1))
	}

	return amount0, amount1
}
