package pool

import (
	"std"
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
) (bigint, bigint, bool) {

	if amountSpecified == 0 {
		return 0, 0, false
	}

	pool := GetPool(pToken0, pToken1, pFee)
	if !(pool.liquidity > 0) {
		return 0, 0, false
	}

	slot0Start := pool.slot0

	if zeroForOne {
		if !(sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 > MIN_SQRT_RATIO) {
			return 0, 0, false
		}
	} else {
		if !(sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 && sqrtPriceLimitX96 < MAX_SQRT_RATIO) {
			return 0, 0, false
		}
	}

	var cache SwapCache
	if zeroForOne {
		cache = SwapCache{
			liquidityStart: pool.liquidity,
			feeProtocol:    slot0Start.feeProtocol % 16,
		}
	} else {
		cache = SwapCache{
			liquidityStart: pool.liquidity,
			feeProtocol:    slot0Start.feeProtocol >> 4,
		}
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

		var sqrtPriceX96Target bigint
		if zeroForOne {
			if step.sqrtPriceNextX96 < sqrtPriceLimitX96 {
				sqrtPriceX96Target = sqrtPriceLimitX96
			} else {
				sqrtPriceX96Target = step.sqrtPriceNextX96
			}
		} else {
			if step.sqrtPriceNextX96 > sqrtPriceLimitX96 {
				sqrtPriceX96Target = sqrtPriceLimitX96
			} else {
				sqrtPriceX96Target = step.sqrtPriceNextX96
			}
		}

		state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount = swapMathComputeSwapStep(
			state.sqrtPriceX96,
			sqrtPriceX96Target,
			state.liquidity,
			state.amountSpecifiedRemaining,
			uint32(pool.fee),
		)

		if !(step.amountIn != 0 && step.amountOut != 0) {
			// NOT ENOUGH MINTED
			return 0, 0, false
		}

		if exactInput {
			state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount)
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
		if !(pool.balances.token1 > (-1 * amount1)) {
			// NOT ENOUGH BALANCE for token1
			return 0, 0, false
		}

	} else {
		if !(pool.balances.token0 > (-1 * amount0)) {
			// NOT ENOUGH BALANCE for token0
			return 0, 0, false
		}
	}

	return amount0, amount1, true
}
