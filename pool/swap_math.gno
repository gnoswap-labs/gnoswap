package gnoswap

import "gno.land/p/demo/ufmt"

func swapMathComputeSwapStep(
	sqrtRatioCurrentX96 bigint,
	sqrtRatioTargetX96 bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint,
) (bigint, bigint, bigint, bigint) {
	requireUnsigned(sqrtRatioCurrentX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioCurrentX96(%s) >= 0", sqrtRatioCurrentX96))
	requireUnsigned(sqrtRatioTargetX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioTargetX96(%s) >= 0", sqrtRatioTargetX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || liquidity(%s) >= 0", liquidity))
	requireUnsigned(feePips, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || feePips(%s) >= 0", feePips))
	var sqrtRatioNextX96, amountIn, amountOut, feeAmount bigint

	zeroForOne := sqrtRatioCurrentX96 >= sqrtRatioTargetX96
	exactIn := amountRemaining >= 0

	if exactIn {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		requireUnsigned(amountRemainingLessFee, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountRemainingLessFee(%s) >= 0", amountRemainingLessFee))

		if zeroForOne {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%s) >= 0", amountIn))

		if amountRemainingLessFee >= amountIn {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemainingLessFee,
				zeroForOne,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioNextX96(%s) >= 0", sqrtRatioNextX96))
	} else {
		if zeroForOne {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%s) >= 0", amountOut))

		if -amountRemaining >= amountOut {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96,
				liquidity,
				-amountRemaining,
				zeroForOne,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || sqrtRatioNextX96(%s) >= 0", sqrtRatioNextX96))
	}

	max := sqrtRatioTargetX96 == sqrtRatioNextX96

	if zeroForOne {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%s) >= 0__#1", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%s) >= 0__#1", amountOut))
	} else {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountIn(%s) >= 0__#2", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%s) >= 0__#2", amountOut))
	}

	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__swapMathComputeSwapStep() || amountOut(%s) >= 0__#3", amountOut))
	}

	if exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96 {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
	}

	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}
