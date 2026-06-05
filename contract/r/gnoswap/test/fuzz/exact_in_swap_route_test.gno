package fuzz

import (
	"math"
	"testing"

	prabc "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/router"
)

// TestFuzzExactInSwapRoute_ValidParams_Stateless fuzzes the ExactInSwapRoute function.
func TestFuzzExactInSwapRoute_ValidParams_Stateless(cur realm, t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(cur, t)

		params := NewValidExactInSwapRouteParams(ft)

		// initialize randomized environment
		for i := 0; i < 10; i++ {
			setupRouterMintPositionByRoutePath(cur, ft, params.routeArr)
		}

		params.updateDrySwapResult(cur)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactInSwapRoute(cur, ft, params)
	})
}

// TestFuzzExactInSwapRoute_RandomizedParams_Stateless fuzzes the ExactInSwapRoute function.
func TestFuzzExactInSwapRoute_RandomizedParams_Stateless(cur realm, t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(cur, t)

		params := NewRandomizedExactInSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(cur, ft, params.routeArr)
		}

		params.updateDrySwapResult(cur)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactInSwapRoute(cur, ft, params)
	})
}

// TestFuzzExactInSwapRoute_RandomizedParams_Stateful fuzzes the ExactInSwapRoute function.
func TestFuzzExactInSwapRoute_RandomizedParams_Stateful(cur realm, t *testing.T) {
	// initialize the states for the stateful fuzz test
	initStates(cur, t)

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedExactInSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(cur, ft, params.routeArr)
		}

		params.updateDrySwapResult(cur)

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactInSwapRoute(cur, ft, params)
	})
}

// runTestExactInSwapRoute runs the test swap route.
func runTestExactInSwapRoute(cur realm, ft *fuzz.T, params *exactInSwapRouteParams) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	// mint test tokens for the input token
	mintedAmount := u256.MustFromDecimal(params.amountIn).Int64()
	if mintedAmount < 0 {
		mintedAmount = 0
	}

	mintTestToken(cur, params.inputToken, mintedAmount)

	// exact in swap route
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	common.SafeGRC20Approve(cross(cur), params.inputToken, routerAddr, math.MaxInt64)

	router.ExactInSwapRoute(
		cross(cur),
		params.inputToken,
		params.outputToken,
		params.amountIn,
		params.routeArr,
		params.quoteArr,
		params.amountOutMin,
		params.deadline,
		params.referrer,
	)
}
