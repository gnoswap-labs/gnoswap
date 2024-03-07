package pool

import (
	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
)

func swapMathComputeSwapStep(
	sqrtRatioCurrentX96 *u256.Uint, // uint160
	sqrtRatioTargetX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountRemaining *i256.Int, // int256
	feePips uint64,
) (sqrtRatioNextX96, amountIn, amountOut, feeAmount *u256.Uint) {
	isToken1Expensive := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)

	// POSTIVIE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := !(amountRemaining.IsNeg()) // amountRemaining >= 0

	// println()
	// println("exactIn", exactIn)                     // f
	// println("isToken1Expensive", isToken1Expensive) // t

	if exactIn {
		amountRemainingLessFee := u256.Zero()

		// amountRemainingLessFee := amountRemaining * bigint(uint64(1000000-feePips)) / 1000000
		_amountRemaining := amountRemaining.Abs()
		amountRemainingLessFee = amountRemainingLessFee.Mul(_amountRemaining, u256.NewUint(1000000-feePips))
		amountRemainingLessFee = amountRemainingLessFee.Div(amountRemainingLessFee, u256.NewUint(1000000))
		if isToken1Expensive {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, true)
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, true)
		}

		if amountRemainingLessFee.Gte(amountIn) {
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemainingLessFee,
				isToken1Expensive,
			)
		}
	} else {
		if isToken1Expensive {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false)
		}

		if amountRemaining.Abs().Gte(amountOut) {
			// println(3)
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			// println(4)
			// println("sqrtRatioCurrentX96:", sqrtRatioCurrentX96.ToString())
			// println("liquidity:", liquidity.ToString())
			// println("amountRemaining.Abs():", amountRemaining.Abs().ToString())
			// println("isToken1Expensive:", isToken1Expensive)
			// println("<< SQRT")
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemaining.Abs(),
				isToken1Expensive,
			)
			// println("sqrtRatioNextX96:", sqrtRatioNextX96.ToString())
			// panic("F")
		}
	}

	max := sqrtRatioTargetX96.Eq(sqrtRatioNextX96)

	if isToken1Expensive {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, true)
		}

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity, false)
		}
	} else {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, true)
		}

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity, false)
		}
	}

	if !exactIn && amountOut.Gt(amountRemaining.Abs()) {
		amountOut = amountRemaining.Abs()
	}

	if exactIn && !(sqrtRatioNextX96.Eq(sqrtRatioTargetX96)) {
		feeAmount = new(u256.Uint).Sub(amountRemaining.Abs(), amountIn)
	} else {
		feeAmount = new(u256.Uint).Mul(amountIn, u256.NewUint(feePips))
		feeAmount = feeAmount.Div(feeAmount, u256.NewUint(1000000-feePips))
	}

	if !exactIn && !(amountOut.IsZero()) {
		amountOut = amountOut.Add(amountOut, u256.NewUint(1))
	}
	// println()
	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}
