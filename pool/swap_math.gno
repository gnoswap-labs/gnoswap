package gnoswap

func SwapMathComputeSwapStep(
	sqrtRatioCurrent bigdec,
	sqrtRatioTarget bigdec,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint
) (bigdec, bigint, bigint,  bigint) {

	var bool zeroForOne = sqrtRatioCurrent >= sqrtRatioTarget
	var bool exactIn = amountRemaining >= 0

	if (exactIn) {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		if (zeroForOne) {
			amountIn := SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, true)
		} else {
			amountIn := SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, true)
		}

		if amountRemainingLessFee >= amountIn {
			sqrtPriceNext := sqrtRatioTarget
		} else {
			sqrtRatioNext := SqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrent,
				liquidity,
				amountRemainingLessFee,
				zeroForOne,
			)
		}
	} else {
		if (zeroForOne) {
			amountOut := SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, false)
		} else {
			amountOut := SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, false)
		}
		if (-amountRemaining) >= amountOut {
			sqrtRatioNext = sqrtRatioTarget
		} else {
			sqrtRatioNext = SqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrent,
				liquidity,
				-amountRemaining,
				zeroForOne,
			)
		}
	}

	max := sqrtRatioTarget == sqrtRatioNext

	if zeroForOne {
		if !(max && exactIn) {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, true)
		}

		if (!max && !exactIn) {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, false)
		}
	} else {
		if !(max && exactIn) {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, true)
		}

		if (!max && !exactIn) {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, false)
		}
	}

	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
	}

	if exactIn && sqrtRatioNext != sqrtRatioTarget {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
	}

	return sqrtRatioNext96, amountIn, amountOut, feeAmount
}

