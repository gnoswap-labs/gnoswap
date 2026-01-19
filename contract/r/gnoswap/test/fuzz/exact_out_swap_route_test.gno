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

// TestFuzzExactOutSwapRoute_ValidParams_Stateless fuzzes the ExactOutSwapRoute function.
func TestFuzzExactOutSwapRoute_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_MIDDLE, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		params := NewValidExactOutSwapRouteParams(ft)

		// initialize randomized environment
		for i := 0; i < 10; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		params.updateAmountInByPreDrySwap()

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactOutSwapRoute(ft, params)
	})
}

// TestFuzzExactOutSwapRoute_RandomizedParams_Stateless fuzzes the ExactOutSwapRoute function.
func TestFuzzExactOutSwapRoute_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_MIDDLE, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the stateless fuzz test
		initStates(t)

		params := NewRandomizedExactOutSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		params.updateAmountInByPreDrySwap()

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactOutSwapRoute(ft, params)
	})
}

// TestFuzzExactOutSwapRoute_RandomizedParams_Stateful fuzzes the ExactOutSwapRoute function.
func TestFuzzExactOutSwapRoute_RandomizedParams_Stateful(t *testing.T) {
	// initialize the states for the stateful fuzz test
	initStates(t)

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS_MIDDLE, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedExactOutSwapRouteParams(ft)

		setupIterations := fuzz.IntRange(1, 10).Draw(ft, "setupIterations").(int)
		for i := 0; i < setupIterations; i++ {
			setupRouterMintPositionByRoutePath(ft, params.routeArr)
		}

		params.updateAmountInByPreDrySwap()

		// add parameters to the fuzz result
		fuzzResult.AddParams(index, params)

		// run the test swap route
		runTestExactOutSwapRoute(ft, params)
	})
}

// runTestExactOutSwapRoute runs the test swap route.
func runTestExactOutSwapRoute(ft *fuzz.T, params *exactOutSwapRouteParams) {
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	// mint test tokens for the input token
	mintedAmount := u256.MustFromDecimal(params.amountIn).Int64()
	if mintedAmount < 0 {
		mintedAmount = 0
	}

	mintTestToken(params.inputToken, mintedAmount)

	// exact out swap route
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	common.SafeGRC20Approve(cross, params.inputToken, routerAddr, math.MaxInt64)

	router.ExactOutSwapRoute(
		cross,
		params.inputToken,
		params.outputToken,
		params.amountOut,
		params.routeArr,
		params.quoteArr,
		params.amountInMax,
		params.deadline,
		params.referrer,
	)
}
