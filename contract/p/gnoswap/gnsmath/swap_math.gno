package gnsmath

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

const denominator = uint64(1_000_000)

// SwapMathComputeSwapStep computes the next sqrt price, amount in, amount out, and fee amount
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
func SwapMathComputeSwapStep(
	sqrtRatioCurrentX96 *u256.Uint,
	sqrtRatioTargetX96 *u256.Uint,
	liquidity *u256.Uint,
	amountRemaining *i256.Int,
	feePips uint64,
) (*u256.Uint, *u256.Uint, *u256.Uint, *u256.Uint) {
	if sqrtRatioCurrentX96 == nil || sqrtRatioTargetX96 == nil ||
		liquidity == nil || amountRemaining == nil {
		panic("SwapMathComputeSwapStep: invalid input")
	}

	// This function is publicly accessible and can be called by external users or contracts.
	// While the pool realm only uses predefined fee values (100, 500, 3000, 10000) which are safely within range,
	// external callers could potentially pass any feePips value. The fee calculation involves subtracting feePips
	// from 1000000 (representing 100%), and if feePips exceeds 1000000, it would cause an underflow,
	// leading to incorrect fee calculations.
	if feePips > denominator {
		panic("SwapMathComputeSwapStep: feePips must be less than or equal to 1000000")
	}

	// zeroForOne determines swap direction based on the relationship of current vs. target
	zeroForOne := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)

	// POSITIVE == EXACT_IN => Estimated AmountOut
	// NEGATIVE == EXACT_OUT => Estimated AmountIn
	exactIn := !amountRemaining.IsNeg()

	amountRemainingAbs := amountRemaining.Abs()
	feeRateInPips := u256.NewUint(feePips)
	withoutFeeRateInPips := u256.NewUint(denominator - feePips)

	sqrtRatioNextX96 := u256.Zero()
	amountIn := u256.Zero()
	amountOut := u256.Zero()
	feeAmount := u256.Zero()

	if exactIn {
		// Handle EXACT_IN scenario as a separate function
		sqrtRatioNextX96, amountIn = handleExactIn(
			zeroForOne,
			sqrtRatioCurrentX96,
			sqrtRatioTargetX96,
			liquidity,
			amountRemainingAbs, // use absolute value here
			withoutFeeRateInPips,
		)
	} else {
		// Handle EXACT_OUT scenario as a separate function
		sqrtRatioNextX96, amountOut = handleExactOut(
			zeroForOne,
			sqrtRatioCurrentX96,
			sqrtRatioTargetX96,
			liquidity,
			amountRemainingAbs,
		)
	}

	// isMax checks if we've hit the boundary price (target)
	isMax := sqrtRatioTargetX96.Eq(sqrtRatioNextX96)

	// Calculate final amountIn, amountOut if needed
	if zeroForOne {
		// If isMax && exactIn, we already have the correct amountIn
		if !(isMax && exactIn) {
			amountIn = getAmount0DeltaHelper(
				sqrtRatioNextX96,
				sqrtRatioCurrentX96,
				liquidity,
				true,
			)
		}
		// If isMax && !exactIn, we already have the correct amountOut
		if !(isMax && !exactIn) {
			amountOut = getAmount1DeltaHelper(
				sqrtRatioNextX96,
				sqrtRatioCurrentX96,
				liquidity,
				false,
			)
		}
	} else {
		if !(isMax && exactIn) {
			amountIn = getAmount1DeltaHelper(
				sqrtRatioCurrentX96,
				sqrtRatioNextX96,
				liquidity,
				true,
			)
		}
		if !(isMax && !exactIn) {
			amountOut = getAmount0DeltaHelper(
				sqrtRatioCurrentX96,
				sqrtRatioNextX96,
				liquidity,
				false,
			)
		}
	}

	// If we're in EXACT_OUT mode but overcalculated 'amountOut'
	if !exactIn && amountOut.Gt(amountRemainingAbs) {
		amountOut = amountRemainingAbs
	}

	// Fee logic
	// If exactIn and we haven't hit the target, the difference is the fee
	// Else, compute fee from feePips
	if exactIn && !sqrtRatioNextX96.Eq(sqrtRatioTargetX96) {
		feeAmount = new(u256.Uint).Sub(amountRemainingAbs, amountIn)
	} else {
		feeAmount = u256.MulDivRoundingUp(
			amountIn,
			feeRateInPips,
			withoutFeeRateInPips,
		)
	}

	// Final sanity check for resulting price
	if sqrtRatioNextX96.Lt(MIN_SQRT_RATIO) || sqrtRatioNextX96.Gt(MAX_SQRT_RATIO) {
		panic(errInvalidPoolSqrtPrice)
	}

	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}

// handleExactIn handles the EXACT_IN scenario and returns (nextSqrtPrice, provisionalAmountIn).
func handleExactIn(
	zeroForOne bool,
	sqrtRatioCurrentX96,
	sqrtRatioTargetX96,
	liquidity,
	amountRemainingAbs,
	withoutFeeRateInPips *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	amountRemainingLessFee := u256.MulDiv(
		amountRemainingAbs,
		withoutFeeRateInPips,
		u256.NewUint(denominator),
	)

	// Special case:
	// When the remaining amount to be swapped becomes 1 during a tick swap,
	// the swap fee becomes less than 0.
	// At this point, check whether the swap is no longer being executed.
	if amountRemainingLessFee.IsZero() {
		return sqrtRatioCurrentX96, u256.Zero()
	}

	var amountIn *u256.Uint
	if zeroForOne {
		amountIn = getAmount0DeltaHelper(
			sqrtRatioTargetX96,
			sqrtRatioCurrentX96,
			liquidity,
			true,
		)
	} else {
		amountIn = getAmount1DeltaHelper(
			sqrtRatioCurrentX96,
			sqrtRatioTargetX96,
			liquidity,
			true,
		)
	}

	if amountRemainingLessFee.Gte(amountIn) {
		return sqrtRatioTargetX96, amountIn
	}

	// We don't reach target price; use partial move
	nextSqrt := getNextSqrtPriceFromInput(
		sqrtRatioCurrentX96,
		liquidity,
		amountRemainingLessFee,
		zeroForOne,
	)

	// Return the partially moved price and calculate amountIn later
	// This avoids double calculation and ensures consistency
	return nextSqrt, amountRemainingLessFee
}

// handleExactOut handles the EXACT_OUT scenario and returns (nextSqrtPrice, provisionalAmountOut).
func handleExactOut(
	zeroForOne bool,
	sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemainingAbs *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	var amountOut *u256.Uint
	if zeroForOne {
		amountOut = getAmount1DeltaHelper(sqrtRatioTargetX96, sqrtRatioCurrentX96, liquidity, false)
	} else {
		amountOut = getAmount0DeltaHelper(sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, false)
	}

	// Fast path: if sufficient liquidity, use target price
	if amountRemainingAbs.Gte(amountOut) {
		return sqrtRatioTargetX96, amountOut
	}

	// Otherwise, partial move: compute next price from residual output amount
	nextSqrt := getNextSqrtPriceFromOutput(
		sqrtRatioCurrentX96,
		liquidity,
		amountRemainingAbs,
		zeroForOne,
	)

	return nextSqrt, amountRemainingAbs
}
