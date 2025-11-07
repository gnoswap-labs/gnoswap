package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
)

// TestFuzzStakeToken_ValidParams_Stateless fuzzes the StakeToken function.
func TestFuzzStakeToken_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		params := NewRandomizedExactInSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestExactInSwapRoute(ft, params)
	})
}

// TestFuzzStakeToken_RandomizedParams_Stateless fuzzes the StakeToken function.
func TestFuzzStakeToken_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		params := NewRandomizedExactInSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestExactInSwapRoute(ft, params)
	})
}

// TestFuzzExactInSwapRoute_RandomizedParams_Stateful fuzzes the ExactInSwapRoute function.
func TestFuzzStakeToken_RandomizedParams_Stateful(t *testing.T) {
	// initialize the states for the stateful fuzz test
	initStates(t)

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedExactInSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		runTestExactInSwapRoute(ft, params)
	})
}
