package gnoswap

import "gno.land/p/demo/ufmt"

func SwapMathComputeSwapStep(
	sqrtRatioCurrentX96 bigint,
	sqrtRatioTargetX96 bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint,
) (bigint, bigint, bigint, bigint) {
	requireUnsigned(sqrtRatioCurrentX96, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || sqrtRatioCurrentX96(%s) must be positive", sqrtRatioCurrentX96))
	requireUnsigned(sqrtRatioTargetX96, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || sqrtRatioTargetX96(%s) must be positive", sqrtRatioTargetX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(feePips, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || feePips(%s) must be positive", feePips))
	var sqrtRatioNextX96, amountIn, amountOut, feeAmount bigint

	zeroForOne := sqrtRatioCurrentX96 >= sqrtRatioTargetX96
	exactIn := amountRemaining >= 0

	if exactIn {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		requireUnsigned(amountRemainingLessFee, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountRemainingLessFee(%s) must be positive", amountRemainingLessFee))

		if zeroForOne {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountIn(%s) must be positive", amountIn))

		if amountRemainingLessFee >= amountIn {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = SqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemainingLessFee,
				zeroForOne,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || sqrtRatioNextX96(%s) must be positive", sqrtRatioNextX96))
	} else {
		if zeroForOne {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountOut(%s) must be positive", amountOut))

		if -amountRemaining >= amountOut {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = SqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96,
				liquidity,
				-amountRemaining,
				zeroForOne,
			)
		}
		requireUnsigned(sqrtRatioNextX96, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || sqrtRatioNextX96(%s) must be positive", sqrtRatioNextX96))
	}

	max := sqrtRatioTargetX96 == sqrtRatioNextX96

	if zeroForOne {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountIn #1(%s) must be positive", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountOut #1(%s) must be positive", amountOut))
	} else {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountIn, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountIn #2(%s) must be positive", amountIn))

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountOut #2(%s) must be positive", amountOut))
	}

	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
		requireUnsigned(amountOut, ufmt.Sprintf("[POOL] swap_math.gno__SwapMathComputeSwapStep() || amountOut #3(%s) must be positive", amountOut))
	}

	if exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96 {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
	}

	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}
