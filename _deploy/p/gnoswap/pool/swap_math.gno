package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func SwapMathComputeSwapStepStr(
	sqrtRatioCurrentX96 *u256.Uint, // uint160
	sqrtRatioTargetX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountRemaining *i256.Int, // int256
	feePips uint64,
) (string, string, string, string) { // (sqrtRatioNextX96, amountIn, amountOut, feeAmount *u256.Uint)
	isToken1Expensive := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)

	// POSTIVIE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := !(amountRemaining.IsNeg()) // amountRemaining >= 0

	sqrtRatioNextX96 := u256.Zero()
	amountIn := u256.Zero()
	amountOut := u256.Zero()
	feeAmount := u256.Zero()

	if exactIn {
		amountRemainingLessFee := u256.MulDiv(amountRemaining.Abs(), u256.NewUint(1000000-feePips), u256.NewUint(1000000))

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
			sqrtRatioNextX96 = sqrtRatioTargetX96
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96,
				liquidity,
				amountRemaining.Abs(),
				isToken1Expensive,
			)
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
		feeAmount = u256.MulDivRoundingUp(amountIn, u256.NewUint(feePips), new(u256.Uint).Sub(u256.NewUint(1000000), u256.NewUint(feePips)))
	}

	return sqrtRatioNextX96.ToString(), amountIn.ToString(), amountOut.ToString(), feeAmount.ToString()
}
