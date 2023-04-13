package gnoswap


func SwapMathComputeSwapStep(
	sqrtRatioCurrent bigint,
	sqrtRatioTarget bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint,
) (bigint, bigint, bigint, bigint) {
	var sqrtRatioNext, amountIn, amountOut, feeAmount bigint

	zeroForOne := sqrtRatioCurrent >= sqrtRatioTarget
	exactIn := amountRemaining >= 0

	if (exactIn) {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		if (zeroForOne) {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, true)
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, true)
		}
		
		if amountRemainingLessFee >= amountIn {
			sqrtRatioNext = sqrtRatioTarget
		} else {
			sqrtRatioNext = SqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrent,
				liquidity,
				bigint(amountRemainingLessFee),
				zeroForOne,
			)
		}
	} else {
		if (zeroForOne) {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, false)
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, false)
		}
		

		if -amountRemaining >= amountOut {
			sqrtRatioNext = sqrtRatioTarget
		} else {
			sqrtRatioNext = SqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrent,
				liquidity,
				bigint(-amountRemaining),
				zeroForOne,
			)
		}
	}

	max := sqrtRatioTarget == sqrtRatioNext


	if zeroForOne {
		if !(max && exactIn) {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, true)
		} else {
			amountIn = amountIn
		}

		if !(max && !exactIn) {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, false)
		} else {
			amountOut = amountOut
		}
	} else {
		if !(max && exactIn) {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, true)
		} else {
			amountIn = amountIn
		}
		
		if !(max && !exactIn) {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, false)
		} else {
			amountOut = amountOut
		}
	}

	println("zeroForOne", zeroForOne)


	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
	}

	if exactIn && sqrtRatioNext != sqrtRatioTarget {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
	}

	println("feeAmount", feeAmount)
	// panic("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=")
	
	return sqrtRatioNext, amountIn, amountOut, feeAmount
}