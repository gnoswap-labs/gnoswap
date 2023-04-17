package gnoswap


func SwapMathComputeSwapStep(
	sqrtRatioCurrent bigint,
	sqrtRatioTarget bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint,
) (bigint, bigint, bigint, bigint) {
	require(sqrtRatioCurrent > 0, "FIX MINUS // SwapMathComputeSwapStep #1")
	require(sqrtRatioTarget > 0, "FIX MINUS // SwapMathComputeSwapStep #2")
	require(liquidity > 0, "FIX MINUS // SwapMathComputeSwapStep #3")
	require(feePips > 0, "FIX MINUS // SwapMathComputeSwapStep #4")
	var sqrtRatioNext, amountIn, amountOut, feeAmount bigint

	zeroForOne := sqrtRatioCurrent >= sqrtRatioTarget
	exactIn := amountRemaining >= 0

	// 1e6 == 10 ^ 6 == 1,000,000 
	if (exactIn) {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		require(amountRemainingLessFee >= 0, "FIX MINUS // SwapMathComputeSwapStep #5")
		
		if (zeroForOne) {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, true)
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, true)
		}
		require(amountIn >= 0, "FIX MINUS // SwapMathComputeSwapStep #6")
		if amountRemainingLessFee >= amountIn {
			sqrtRatioNext = sqrtRatioTarget
		} else {
			sqrtRatioNext = SqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrent,
				liquidity,
				amountRemainingLessFee,
				zeroForOne,
			)
			
			if sqrtRatioNext == 0 { panic ("sqrtRatioNext is 0, WRONG") }
		}
		require(sqrtRatioNext >= 0, "FIX MINUS // SwapMathComputeSwapStep #7")

	} else {
		if (zeroForOne) {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTarget, sqrtRatioCurrent, liquidity, false)
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrent, sqrtRatioTarget, liquidity, false)
		}
		require(amountOut >= 0, "FIX MINUS // SwapMathComputeSwapStep #8")
		
		if -amountRemaining >= amountOut {
			sqrtRatioNext = sqrtRatioTarget
		} else {
			sqrtRatioNext = SqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrent,
				liquidity,
				-amountRemaining,
				zeroForOne,
			)
		}
		require(sqrtRatioNext >= 0, "FIX MINUS // SwapMathComputeSwapStep #9")
	}

	max := sqrtRatioTarget == sqrtRatioNext


	if zeroForOne {
		if (max && exactIn) {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, true)
		}

		if (max && !exactIn) {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNext, sqrtRatioCurrent, liquidity, false)
		}

		require(amountIn >= 0, "FIX MINUS // SwapMathComputeSwapStep #10")
		require(amountOut >= 0, "FIX MINUS // SwapMathComputeSwapStep #11")
	} else {
		if (max && exactIn) {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, true)
		}
		
		if (max && !exactIn) {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrent, sqrtRatioNext, liquidity, false)
		}

		require(amountOut >= 0, "FIX MINUS // SwapMathComputeSwapStep #12")
	}


	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
		require(amountOut >= 0, "FIX MINUS // SwapMathComputeSwapStep #13")
	}

	

	if exactIn && sqrtRatioNext != sqrtRatioTarget {
		feeAmount = amountRemaining - amountIn
		require(feeAmount >= 0, "FIX MINUS // SwapMathComputeSwapStep #14")
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
		require(feeAmount >= 0, "FIX MINUS // SwapMathComputeSwapStep #15")
	}
	
	
	require(sqrtRatioNext >= 0, "FIX MINUS // SwapMathComputeSwapStep #16")
	require(amountIn >= 0, "FIX MINUS // SwapMathComputeSwapStep #17")
	require(amountOut >= 0, "FIX MINUS // SwapMathComputeSwapStep #18")
	require(feeAmount >= 0, "FIX MINUS // SwapMathComputeSwapStep #29")

	return sqrtRatioNext, amountIn, amountOut, feeAmount
}