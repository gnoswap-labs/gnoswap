package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
)

// TestFuzzTickMathGetSqrtRatioAtTick_ValidParams tests TickMathGetSqrtRatioAtTick with valid parameters
func TestFuzzTickMathGetSqrtRatioAtTick_ValidParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewValidTickMathGetSqrtRatioAtTickParams(ft)
		fuzzResult.AddParams(index, params)

		// when
		result := common.TickMathGetSqrtRatioAtTick(params.tick)

		// then - verify result is within expected range
		minSqrtRatio := u256.MustFromDecimal(MIN_SQRT_RATIO)
		maxSqrtRatio := u256.MustFromDecimal(MAX_SQRT_RATIO)

		if result == nil {
			panic("TickMathGetSqrtRatioAtTick returned nil for valid tick")
		}

		if result.Lt(minSqrtRatio) || result.Gt(maxSqrtRatio) {
			panic(ufmt.Sprintf("TickMathGetSqrtRatioAtTick returned out of range value: %s", result.ToString()))
		}

		// Verify roundtrip consistency: tick -> sqrt -> tick should give tick or tick-1
		// Skip roundtrip for max tick as it may produce maxSqrtRatio which is invalid input for GetTickAtSqrtRatio
		if params.tick < MAX_TICK {
			reverseToTick := common.TickMathGetTickAtSqrtRatio(result)
			if reverseToTick != params.tick && reverseToTick != params.tick-1 {
				panic(ufmt.Sprintf("Roundtrip failed: tick %d -> sqrt %s -> tick %d", params.tick, result.ToString(), reverseToTick))
			}
		}
	})
}

// TestFuzzTickMathGetSqrtRatioAtTick_RandomizedParams tests TickMathGetSqrtRatioAtTick with randomized parameters (includes invalid)
func TestFuzzTickMathGetSqrtRatioAtTick_RandomizedParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedTickMathGetSqrtRatioAtTickParams(ft)
		fuzzResult.AddParams(index, params)

		_ = common.TickMathGetSqrtRatioAtTick(params.tick)
	})
}

// TestFuzzTickMathGetTickAtSqrtRatio_ValidParams tests TickMathGetTickAtSqrtRatio with valid parameters
func TestFuzzTickMathGetTickAtSqrtRatio_ValidParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewValidTickMathGetTickAtSqrtRatioParams(ft)
		fuzzResult.AddParams(index, params)

		// when
		sqrtPrice := u256.MustFromDecimal(params.sqrtPriceX96)
		result := common.TickMathGetTickAtSqrtRatio(sqrtPrice)

		// then - verify result is within expected tick range
		if result < MIN_TICK || result > MAX_TICK {
			panic(ufmt.Sprintf("TickMathGetTickAtSqrtRatio returned out of range tick: %d", result))
		}

		// Verify monotonicity: larger sqrt price should give larger or equal tick
		// and getSqrtRatioAtTick(result) should be <= input
		resultSqrt := common.TickMathGetSqrtRatioAtTick(result)
		if resultSqrt.Gt(sqrtPrice) {
			panic(ufmt.Sprintf("Monotonicity violated: getSqrtRatioAtTick(%d) = %s > input %s", result, resultSqrt.ToString(), sqrtPrice.ToString()))
		}

		// Verify upper bound: getSqrtRatioAtTick(result+1) should be > input (unless at max tick)
		if result < MAX_TICK {
			nextResultSqrt := common.TickMathGetSqrtRatioAtTick(result + 1)
			if nextResultSqrt.Lte(sqrtPrice) {
				panic(ufmt.Sprintf("Upper bound violated: getSqrtRatioAtTick(%d) = %s <= input %s", result+1, nextResultSqrt.ToString(), sqrtPrice.ToString()))
			}
		}
	})
}

// TestFuzzTickMathGetTickAtSqrtRatio_RandomizedParams tests TickMathGetTickAtSqrtRatio with randomized parameters (includes invalid)
func TestFuzzTickMathGetTickAtSqrtRatio_RandomizedParams(t *testing.T) {
	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedTickMathGetTickAtSqrtRatioParams(ft)
		fuzzResult.AddParams(index, params)

		// when
		sqrtPrice := u256.MustFromDecimal(params.sqrtPriceX96)

		_ = common.TickMathGetTickAtSqrtRatio(sqrtPrice)
	})
}
