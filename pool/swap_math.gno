package pool

import (
	"gno.land/p/demo/u256"
)

func swapMathComputeSwapStep(
	sqrtRatioCurrentX96 *u256.Uint,
	sqrtRatioTargetX96 *u256.Uint,
	liquidity *u256.Uint,
	amountRemaining *u256.Int,
	feePips uint32,
) (sqrtRatioNextX96, amountIn, amountOut, feeAmount *u256.Uint) {
	isToken1Expensive := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)

	// POSTIVIE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := !amountRemaining.IsNeg()

	if exactIn {
		amountRemainingLessFee := new(u256.Uint).Mul(amountRemaining.Uint(), u256.NewUint(uint64(1000000-feePips)))
		amountRemainingLessFee.Div(amountRemainingLessFee, u256.NewUint(1000000))

		if isToken1Expensive {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
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
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity)
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity)
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

	max := sqrtRatioTargetX96 == sqrtRatioNextX96

	if isToken1Expensive {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioNextX96, sqrtRatioCurrentX96, liquidity)
		}
	} else {
		if max && exactIn {
			amountIn = amountIn
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}

		if max && !exactIn {
			amountOut = amountOut
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioNextX96, liquidity)
		}
	}

	if !exactIn && amountOut.Gt(amountRemaining.Abs()) {
		amountOut = amountRemaining.Abs()
	}

	if exactIn && !sqrtRatioNextX96.Eq(sqrtRatioTargetX96) {
		feeAmount = new(u256.Uint).Sub(amountRemaining.Uint(), amountIn)
	} else {
		feeAmount = new(u256.Uint).Mul(amountIn, u256.NewUint(uint64(feePips)))
		feeAmount.Div(feeAmount, u256.NewUint(uint64(1000000-feePips)))
	}

	if !exactIn && !amountOut.IsZero() {
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
