package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
)

const FUZZ_ITERATIONS = 10

// TestFuzzTickMathGetSqrtRatioAtTick_ValidParams_Stateless tests TickMathGetSqrtRatioAtTick with valid parameters
func TestFuzzTickMathGetSqrtRatioAtTick_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidTickMathGetSqrtRatioAtTickParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		common.TickMathGetSqrtRatioAtTick(params.tick)
	})
}

// TestFuzzTickMathGetSqrtRatioAtTick_RandomizedParams_Stateless tests TickMathGetSqrtRatioAtTick with randomized parameters
func TestFuzzTickMathGetSqrtRatioAtTick_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedTickMathGetSqrtRatioAtTickParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		common.TickMathGetSqrtRatioAtTick(params.tick)
	})
}

// TestFuzzTickMathGetTickAtSqrtRatio_ValidParams_Stateless tests TickMathGetTickAtSqrtRatio with valid parameters
func TestFuzzTickMathGetTickAtSqrtRatio_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewValidTickMathGetTickAtSqrtRatioParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.sqrtPriceX96)
		common.TickMathGetTickAtSqrtRatio(sqrtPrice)
	})
}

// TestFuzzTickMathGetTickAtSqrtRatio_RandomizedParams_Stateless tests TickMathGetTickAtSqrtRatio with randomized parameters
func TestFuzzTickMathGetTickAtSqrtRatio_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		params := NewRandomizedTickMathGetTickAtSqrtRatioParams(ft)

		// when
		fuzzResult.AddParams(index, params)

		// then
		sqrtPrice := u256.MustFromDecimal(params.sqrtPriceX96)
		common.TickMathGetTickAtSqrtRatio(sqrtPrice)
	})
}
