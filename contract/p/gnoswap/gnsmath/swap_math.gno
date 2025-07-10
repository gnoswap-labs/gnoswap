package gnsmath

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
	// Validate mandatory inputs
	if sqrtRatioCurrentX96 == nil || sqrtRatioTargetX96 == nil ||
		liquidity == nil || amountRemaining == nil {
		panic("SwapMathComputeSwapStepStr: invalid input")
	}

	// This function is publicly accessible and can be called by external users or contracts.
	// While the pool realm only uses predefined fee values (100, 500, 3000, 10000) which are safely within range,
	// external callers could potentially pass any feePips value. The fee calculation involves subtracting feePips
	// from 1000000 (representing 100%), and if feePips exceeds 1000000, it would cause an underflow,
	// leading to incorrect fee calculations.
	if feePips > 1_000_000 {
		panic("SwapMathComputeSwapStepStr: feePips must be <= 1000000")
	}

	// Determine swap direction: true => token0 → token1 (zeroForOne)
	zeroForOne := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)
	// exactIn: positive amountRemaining means EXACT_IN
	exactIn := !amountRemaining.IsNeg()

	feePipsUint := u256.NewUint(feePips)
	oneMillion := u256.NewUint(1_000_000)
	feeDenom := new(u256.Uint).Sub(oneMillion, feePipsUint)

	sqrtRatioNextX96 := u256.Zero()
	amountIn := u256.Zero()
	amountOut := u256.Zero()
	feeAmount := u256.Zero()

	if exactIn {
		sqrtRatioNextX96, amountIn = handleExactIn(
			zeroForOne,
			sqrtRatioCurrentX96.Clone(),
			sqrtRatioTargetX96.Clone(),
			liquidity.Clone(),
			amountRemaining.Abs(),
			feeDenom,
		)
	} else {
		sqrtRatioNextX96, amountOut = handleExactOut(
			zeroForOne,
			sqrtRatioCurrentX96.Clone(),
			sqrtRatioTargetX96.Clone(),
			liquidity.Clone(),
			amountRemaining.Abs(),
		)
	}

	// isMax checks if we've hit the boundary price (target)
	isMax := sqrtRatioTargetX96.Eq(sqrtRatioNextX96)

	// Compute final amountIn / amountOut if not already correct
	if zeroForOne {
		if !(isMax && exactIn) {
			amountIn = getAmount0DeltaHelper(
				sqrtRatioNextX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				true,
			)
		}
		if !(isMax && !exactIn) {
			amountOut = getAmount1DeltaHelper(
				sqrtRatioNextX96.Clone(),
				sqrtRatioCurrentX96.Clone(),
				liquidity.Clone(),
				false,
			)
		}
	} else {
		if !(isMax && exactIn) {
			amountIn = getAmount1DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioNextX96.Clone(),
				liquidity.Clone(),
				true,
			)
		}
		if !(isMax && !exactIn) {
			amountOut = getAmount0DeltaHelper(
				sqrtRatioCurrentX96.Clone(),
				sqrtRatioNextX96.Clone(),
				liquidity.Clone(),
				false,
			)
		}
	}

	// Bound amountOut in EXACT_OUT mode
	if !exactIn && amountOut.Gt(amountRemaining.Abs()) {
		amountOut = amountRemaining.Abs()
	}

	// Fee calculation
	if exactIn && !sqrtRatioNextX96.Eq(sqrtRatioTargetX96) {
		// If we didn't reach target in EXACT_IN, fee is leftover
		feeAmount = new(u256.Uint).Sub(amountRemaining.Abs(), amountIn)
	} else {
		// Otherwise compute fee = amountIn * feePips / (1e6 - feePips), rounding up
		feeAmount = u256.MulDivRoundingUp(amountIn, feePipsUint, feeDenom)
	}

	// Final sanity check for resulting price
	if sqrtRatioNextX96.Lt(MIN_SQRT_RATIO) || sqrtRatioNextX96.Gt(MAX_SQRT_RATIO) {
		panic("SwapMathComputeSwapStepStr: sqrt price out of bounds")
	}

	return sqrtRatioNextX96.ToString(), amountIn.ToString(), amountOut.ToString(), feeAmount.ToString()
}

// handleExactIn handles the EXACT_IN scenario and returns (nextSqrtPrice, provisionalAmountIn).
// - zeroForOne: swap direction
// - amountRemainingAbs: absolute amount to swap in
// - feeDenom: precomputed (1e6 - feePips) for fee calculation
func handleExactIn(
	zeroForOne bool,
	sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemainingAbs *u256.Uint,
	feeDenom *u256.Uint,
) (*u256.Uint, *u256.Uint) {

	// amountRemainingLessFee = amountRemainingAbs * (1e6 - feePips) / 1e6
	amountRemainingLessFee := u256.MulDiv(
		amountRemainingAbs,
		feeDenom,
		u256.NewUint(1_000_000),
	)

	// Special case:
	// When fee alone consumes all input (e.g., amount=1 with high fee)
	// no actual swap occurs, price remains unchanged
	if amountRemainingLessFee.IsZero() {
		return sqrtRatioCurrentX96, u256.Zero()
	}

	// Estimate the full move amountIn
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

	// If we can afford the full move, jump to target
	if amountRemainingLessFee.Gte(amountIn) {
		return sqrtRatioTargetX96, amountIn
	}

	// Otherwise, partial move: compute next price from residual input
	nextSqrt := getNextSqrtPriceFromInput(
		sqrtRatioCurrentX96,
		liquidity,
		amountRemainingLessFee,
		zeroForOne,
	)

	// No price change -> no amountIn
	if nextSqrt.Eq(sqrtRatioCurrentX96) {
		return sqrtRatioCurrentX96, u256.Zero()
	}
	return nextSqrt, amountIn
}

// handleExactOut handles the EXACT_OUT scenario and returns (nextSqrtPrice, provisionalAmountOut).
// - amountRemainingAbs: absolute amount to swap out
func handleExactOut(
	zeroForOne bool,
	sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemainingAbs *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	// Estimate the full move amountOut
	var amountOut *u256.Uint
	if zeroForOne {
		amountOut = getAmount1DeltaHelper(
			sqrtRatioTargetX96,
			sqrtRatioCurrentX96,
			liquidity,
			false,
		)
	} else {
		amountOut = getAmount0DeltaHelper(
			sqrtRatioCurrentX96,
			sqrtRatioTargetX96,
			liquidity,
			false,
		)
	}

	// If we can supply the full amountOut, jump to target
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

	// No price change -> no amountOut
	if nextSqrt.Eq(sqrtRatioCurrentX96) {
		return sqrtRatioCurrentX96, u256.Zero()
	}

	return nextSqrt, amountOut
}
