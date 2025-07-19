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
	// Combined validation for better performance - single conditional check
	if sqrtRatioCurrentX96 == nil || sqrtRatioTargetX96 == nil || liquidity == nil || amountRemaining == nil {
		panic("SwapMathComputeSwapStep: invalid input")
	}

	// This function is publicly accessible and can be called by external users or contracts.
	// While the pool realm only uses predefined fee values (100, 500, 3000, 10000) which are safely within range,
	// external callers could potentially pass any feePips value. The fee calculation involves subtracting feePips
	// from 1000000 (representing 100%), and if feePips exceeds 1000000, it would cause an underflow,
	// leading to incorrect fee calculations.
	if feePips > denominator {
		panic("SwapMathComputeSwapStep: feePips must be <= 1000000")
	}

	// Pre-compute frequently used values to avoid repeated calculations
	zeroForOne := sqrtRatioCurrentX96.Gte(sqrtRatioTargetX96)
	exactIn := !amountRemaining.IsNeg()
	amountRemainingAbs := amountRemaining.Abs()

	// Optimize fee calculations - use constants where possible
	feePipsUint := u256.NewUint(feePips)
	feeDenom := new(u256.Uint).Sub(u256.NewUint(denominator), feePipsUint)

	// Initialize result variables
	var sqrtRatioNextX96, amountIn, amountOut, feeAmount *u256.Uint

	if exactIn {
		sqrtRatioNextX96, amountIn = handleExactIn(
			zeroForOne,
			sqrtRatioCurrentX96,
			sqrtRatioTargetX96,
			liquidity,
			amountRemainingAbs,
			feeDenom,
		)
	} else {
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

	// Optimize final amountIn/amountOut calculation - remove unnecessary Clone() calls
	// and combine conditions for better branch prediction
	if zeroForOne {
		if !(isMax && exactIn) {
			amountIn = getAmount0DeltaHelper(
				sqrtRatioNextX96,
				sqrtRatioCurrentX96,
				liquidity,
				true,
			)
		}
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

	// Optimized amountOut bounding and fee calculation using pre-computed values
	if !exactIn && amountOut.Gt(amountRemainingAbs) {
		amountOut = amountRemainingAbs
	}

	// Optimized fee calculation with early branch optimization
	if exactIn && !sqrtRatioNextX96.Eq(sqrtRatioTargetX96) {
		// Fast path: fee is leftover when target not reached
		feeAmount = new(u256.Uint).Sub(amountRemainingAbs, amountIn)
	} else {
		// Otherwise compute fee = amountIn * feePips / (1e6 - feePips), rounding up
		feeAmount = u256.MulDivRoundingUp(amountIn, feePipsUint, feeDenom)
	}

	// Initialize zero values for nil results to avoid panic on ToString()
	if amountIn == nil {
		amountIn = u256.Zero()
	}
	if amountOut == nil {
		amountOut = u256.Zero()
	}
	if feeAmount == nil {
		feeAmount = u256.Zero()
	}

	// Final bounds check - optimized with single condition
	if sqrtRatioNextX96.Lt(MIN_SQRT_RATIO) || sqrtRatioNextX96.Gt(MAX_SQRT_RATIO) {
		panic("SwapMathComputeSwapStep: sqrt price out of bounds")
	}
	
	return sqrtRatioNextX96, amountIn, amountOut, feeAmount
}

// handleExactIn handles the EXACT_IN scenario and returns (nextSqrtPrice, provisionalAmountIn).
// Optimized version with reduced memory allocations and faster early returns
func handleExactIn(
	zeroForOne bool,
	sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemainingAbs *u256.Uint,
	feeDenom *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	// Fast path: calculate fee-adjusted amount with single operation
	amountRemainingLessFee := u256.MulDiv(amountRemainingAbs, feeDenom, u256.NewUint(denominator))

	// Early return: when fee consumes all input, no swap occurs
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
	
	// If zero input, then no swap
	if amountIn.IsZero() {
		return sqrtRatioCurrentX96, u256.Zero()
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

	return nextSqrt, amountIn
}

// handleExactOut handles the EXACT_OUT scenario and returns (nextSqrtPrice, provisionalAmountOut).
// Optimized version with reduced function calls and improved branch prediction
func handleExactOut(
	zeroForOne bool,
	sqrtRatioCurrentX96, sqrtRatioTargetX96, liquidity, amountRemainingAbs *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	// Optimized: calculate amountOut based on direction with single conditional
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

	return nextSqrt, amountOut
}
