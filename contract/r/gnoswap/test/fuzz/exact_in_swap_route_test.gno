package fuzz

import (
	"math"
	"testing"
	"time"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/router"
)

// TestFuzzExactInSwapRoute_ValidParams_Stateless fuzzes the ExactInSwapRoute function.
func TestFuzzExactInSwapRoute_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the fuzz test
		initStates(t)

		params := NewValidExactInSwapRouteParams(ft)
		fuzzResult.AddParams(index, params)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		exists := pool.ExistsPoolPath(pool.GetPoolPath(params.inputToken, params.outputToken, uint32(3000)))
		if !exists {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				params.inputToken,
				params.outputToken,
				uint32(3000),
				"79228162514264337593543950337",
			)
		}

		common.SafeGRC20Approve(cross, params.inputToken, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, params.outputToken, poolAddr, math.MaxInt64)

		position.Mint(
			cross,
			params.inputToken,
			params.outputToken,
			3000,
			-1080,
			960,
			"100000000",
			"100000000",
			"0",
			"0",
			time.Now().Add(time.Hour).Unix(),
			adminAddr,
			adminAddr,
			"",
		)

		common.SafeGRC20Approve(cross, params.inputToken, routerAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, params.outputToken, routerAddr, math.MaxInt64)

		router.ExactInSwapRoute(
			cross,
			params.inputToken,
			params.outputToken,
			params.amountIn,
			params.routeArr,
			params.quoteArr,
			params.amountOutMin,
			params.deadline,
			params.referrer,
		)
	})
}

// TestFuzzExactInSwapRoute_RandomizedParams_Stateless fuzzes the ExactInSwapRoute function.
func TestFuzzExactInSwapRoute_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// initialize the states for the fuzz test
		initStates(t)

		params := NewRandomizedExactInSwapRouteParams(ft)
		fuzzResult.AddParams(index, params)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		exists := pool.ExistsPoolPath(pool.GetPoolPath(params.inputToken, params.outputToken, uint32(3000)))
		if !exists {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				params.inputToken,
				params.outputToken,
				uint32(3000),
				"79228162514264337593543950337",
			)
		}

		common.SafeGRC20Approve(cross, params.inputToken, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, params.outputToken, poolAddr, math.MaxInt64)

		position.Mint(
			cross,
			params.inputToken,
			params.outputToken,
			3000,
			-1080,
			960,
			"100000000",
			"100000000",
			"0",
			"0",
			time.Now().Add(time.Hour).Unix(),
			adminAddr,
			adminAddr,
			"",
		)

		common.SafeGRC20Approve(cross, params.inputToken, routerAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, params.outputToken, routerAddr, math.MaxInt64)

		router.ExactInSwapRoute(
			cross,
			params.inputToken,
			params.outputToken,
			params.amountIn,
			params.routeArr,
			params.quoteArr,
			params.amountOutMin,
			params.deadline,
			params.referrer,
		)
	})
}
