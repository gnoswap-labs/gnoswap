package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// SwapMathComputeSwapStepStr computes the next sqrt price, amount in, amount out, and fee amount
// Computes the result of swapping some amount in, or amount out, given the parameters of the swap
// The fee, plus the amount in, will never exceed the amount remaining if the swap's `amountSpecified` is positive
//
// input:
// - sqrtRatioCurrentX96: the current sqrt price of the pool
// - sqrtRatioTargetX96: The price that cannot be exceeded, from which the direction of the swap is inferred
// - liquidity: The usable liquidity of the pool
// - amountRemaining: How much input or output amount is remaining to be swapped in/out
// - feePips: The fee taken from the input amount, expressed in hundredths of a bip
//
// output:
// - sqrtRatioNextX96: The price after swapping the amount in/out, not to exceed the price target
// - amountIn: The amount to be swapped in, of either token0 or token1, based on the direction of the swap
// - amountOut: The amount to be received, of either token0 or token1, based on the direction of the swap
// - feeAmount: The amount of input that will be taken as a fee
func SwapMathComputeSwapStepStr(
	sqrtRatioCurrentX96 *u256.Uint,
	sqrtRatioTargetX96 *u256.Uint,
	liquidity *u256.Uint,
	amountRemaining *i256.Int,
	feePips uint64,
) (string, string, string, string) {
	if sqrtRatioCurrentX96 == nil || sqrtRatioTargetX96 == nil || liquidity == nil || amountRemaining == nil {
		panic("SwapMathComputeSwapStepStr: invalid input")
	}

	zeroForOne := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)

	// POSTIVIE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := !(amountRemaining.IsNeg()) // amountRemaining >= 0

	sqrtRatioNextX96 := u256.Zero()
	amountIn := u256.Zero()
	amountOut := u256.Zero()
	feeAmount := u256.Zero()

	if exactIn {
		amountRemainingLessFee := u256.MulDiv(amountRemaining.Abs(), u256.NewUint(1000000-feePips), u256.NewUint(1000000))
		if zeroForOne {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(
				sqrtRatioTargetX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				true)
		} else {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioTargetX96.Clone(),
				liquidity.Clone(),
				true)
		}

		if amountRemainingLessFee.Gte(amountIn) {
			sqrtRatioNextX96 = sqrtRatioTargetX96.Clone()
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromInput(
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				amountRemainingLessFee.Clone(),
				zeroForOne,
			)
		}
	} else {
		if zeroForOne {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(
				sqrtRatioTargetX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				false)
		} else {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioTargetX96.Clone(),
				liquidity.Clone(),
				false)
		}

		if amountRemaining.Abs().Gte(amountOut) {
			sqrtRatioNextX96 = sqrtRatioTargetX96.Clone()
		} else {
			sqrtRatioNextX96 = sqrtPriceMathGetNextSqrtPriceFromOutput(
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				amountRemaining.Abs(),
				zeroForOne,
			)
		}
	}

	isMax := sqrtRatioTargetX96.Eq(sqrtRatioNextX96)

	if zeroForOne {
		if !(isMax && exactIn) {
			amountIn = sqrtPriceMathGetAmount0DeltaHelper(
				sqrtRatioNextX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				true)
		}
		if !(isMax && !exactIn) {
			amountOut = sqrtPriceMathGetAmount1DeltaHelper(
				sqrtRatioNextX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				false)
		}
	} else {
		if !(isMax && exactIn) {
			amountIn = sqrtPriceMathGetAmount1DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioNextX96.Clone(),
				liquidity.Clone(),
				true)
		}
		if !(isMax && !exactIn) {
			amountOut = sqrtPriceMathGetAmount0DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioNextX96.Clone(),
				liquidity.Clone(),
				false)
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
