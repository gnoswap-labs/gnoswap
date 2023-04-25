package gnoswap


func SwapMathComputeSwapStep(
	sqrtRatioCurrentX96 bigint,
	sqrtRatioTargetX96 bigint,
	liquidity bigint,
	amountRemaining bigint,
	feePips bigint,
) (bigint, bigint, bigint, bigint) {
	requireUnsigned(sqrtRatioCurrentX96, "swap_math.gno__SwapMathComputeSwapStep__sqrtRatioCurrentX96")
	requireUnsigned(sqrtRatioTargetX96, "swap_math.gno__SwapMathComputeSwapStep__sqrtRatioTargetX96")
	requireUnsigned(liquidity, "swap_math.gno__SwapMathComputeSwapStep__liquidity")
	requireUnsigned(feePips, "swap_math.gno__SwapMathComputeSwapStep__feePips")
	var sqrtRatioNextX96, amountIn, amountOut, feeAmount bigint

	zeroForOne := sqrtRatioCurrentX96 >= sqrtRatioTargetX96
	exactIn := amountRemaining >= 0

	if (exactIn) {
		amountRemainingLessFee := amountRemaining * (1e6 - feePips) / 1e6
		requireUnsigned(amountRemainingLessFee, "swap_math.gno__SwapMathComputeSwapStep__amountRemainingLessFee")
		
		if (zeroForOne) {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountIn, "swap_math.gno__SwapMathComputeSwapStep__amountIn")
		
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
		requireUnsigned(sqrtRatioNextX96, "swap_math.gno__SwapMathComputeSwapStep__sqrtRatioNextX96")

	} else {
		if (zeroForOne) {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
		}
		requireUnsigned(amountOut, "swap_math.gno__SwapMathComputeSwapStep__amountOut")
		
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
		requireUnsigned(sqrtRatioNextX96, "swap_math.gno__SwapMathComputeSwapStep__sqrtRatioNextX96")
	}

	max := sqrtRatioTargetX96 == sqrtRatioNextX96


	if zeroForOne {
		if (max && exactIn) {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountIn, "swap_math.gno__SwapMathComputeSwapStep__amountIn #1")

		if (max && !exactIn) {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
		requireUnsigned(amountOut, "swap_math.gno__SwapMathComputeSwapStep__amountOut #1")
	} else {
		if (max && exactIn) {
			amountIn = amountIn
		} else {
			amountIn = SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountIn, "swap_math.gno__SwapMathComputeSwapStep__amountIn #2")
		
		if (max && !exactIn) {
			amountOut = amountOut
		} else {
			amountOut = SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
		requireUnsigned(amountOut, "swap_math.gno__SwapMathComputeSwapStep__amountOut #2")
	}

	if !exactIn && amountOut > -amountRemaining {
		amountOut = -amountRemaining
		requireUnsigned(amountOut, "swap_math.gno__SwapMathComputeSwapStep__amountOut #3")
	}

	if exactIn && sqrtRatioNextX96 != sqrtRatioTargetX96 {
		feeAmount = amountRemaining - amountIn
	} else {
		feeAmount = amountIn * feePips / (1e6 - feePips)
	}
	
	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}