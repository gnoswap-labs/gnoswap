package pool

import (
	"gno.land/p/demo/ufmt"
)

func swapMathComputeSwapStep(
	sqrtRatioCurrentX96 bigint,
	sqrtRatioTargetX96 bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips uint32,
) (sqrtRatioNextX96, amountIn, amountOut, feeAmount bigint) {
	requireUnsigned(sqrtRatioCurrentX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioCurrentX96(%d) >= 0", sqrtRatioCurrentX96))
	requireUnsigned(sqrtRatioTargetX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioTargetX96(%d) >= 0", sqrtRatioTargetX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || liquidity(%d) >= 0", liquidity))

	isToken1Expensive := sqrtRatioCurrentX96 >= sqrtRatioTargetX96

	// POSTIVIE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := amountRemaining >= 0

	if exactIn {
		amountRemainingLessFee := amountRemaining * bigint(uint64(1000000-feePips)) / 1000000
		requireUnsigned(amountRemainingLessFee, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountRemainingLessFee(%d) >= 0", amountRemainingLessFee))

		if isToken1Expensive {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%d) >= 0", amountIn))

		if amountRemainingLessFee >= amountIn {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemainingLessFee,
				isToken1Expensive,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioNextX96(%d) >= 0", sqrtRatioNextX96))
	} else {
		if isToken1Expensive {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}

		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%d) >= 0", amountOut))

		if absBigint(amountRemaining) >= amountOut {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96,
				liquidity,
				absBigint(-amountRemaining),
				isToken1Expensive,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioNextX96(%d) >= 0", sqrtRatioNextX96))
	}

	max := sqrtRatioTargetX96 == sqrtRatioNextX96

	if isToken1Expensive {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%d) >= 0__#1", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%d) >= 0__#1", amountOut))
	} else {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%d) >= 0__#2", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%d) >= 0__#2", amountOut))
	}

	if !exactIn && amountOut > absBigint(-amountRemaining) {
		amountOut = absBigint(-amountRemaining)
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%d) >= 0__#3", amountOut))
	}

	if exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96 {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * bigint(uint64(feePips)) / bigint(uint64(1000000-feePips))
	}

	if !exactIn && amountOut != 0 {
		amountOut++
	}
	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}

func absBigint(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}
