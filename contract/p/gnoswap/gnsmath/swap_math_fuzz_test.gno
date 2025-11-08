package gnsmath

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestFuzzSwapMathComputeSwapStep_ValidParams_Stateless tests SwapMathComputeSwapStep with valid parameters
func TestFuzzSwapMathComputeSwapStep_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidSwapMathComputeSwapStepParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtCurrent := u256.MustFromDecimal(params.sqrtRatioCurrentX96)
		sqrtTarget := u256.MustFromDecimal(params.sqrtRatioTargetX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amountRemaining := i256.MustFromDecimal(params.amountRemaining)

		SwapMathComputeSwapStep(sqrtCurrent, sqrtTarget, liquidity, amountRemaining, params.feePips)
	})
}

// TestFuzzSwapMathComputeSwapStep_RandomizedParams_Stateless tests SwapMathComputeSwapStep with randomized parameters
func TestFuzzSwapMathComputeSwapStep_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedSwapMathComputeSwapStepParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtCurrent := u256.MustFromDecimal(params.sqrtRatioCurrentX96)
		sqrtTarget := u256.MustFromDecimal(params.sqrtRatioTargetX96)
		liquidity := u256.MustFromDecimal(params.liquidity)
		amountRemaining := i256.MustFromDecimal(params.amountRemaining)

		SwapMathComputeSwapStep(sqrtCurrent, sqrtTarget, liquidity, amountRemaining, params.feePips)
	})
}
