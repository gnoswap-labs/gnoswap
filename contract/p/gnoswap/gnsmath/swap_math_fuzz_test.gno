package gnsmath

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
)

// TestFuzzSwapMathComputeSwapStep_ValidParams_Stateless tests SwapMathComputeSwapStep with valid parameters
func TestFuzzSwapMathComputeSwapStep_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 500, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidSwapMathComputeSwapStepParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		SwapMathComputeSwapStep(params.sqrtRatioCurrentX96, params.sqrtRatioTargetX96, params.liquidity, params.amountRemaining, params.feePips)
	})
}

// TestFuzzSwapMathComputeSwapStep_RandomizedParams_Stateless tests SwapMathComputeSwapStep with randomized parameters
func TestFuzzSwapMathComputeSwapStep_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 500, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedSwapMathComputeSwapStepParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		SwapMathComputeSwapStep(params.sqrtRatioCurrentX96, params.sqrtRatioTargetX96, params.liquidity, params.amountRemaining, params.feePips)
	})
}
