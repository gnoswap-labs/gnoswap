package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/pool"
)

// TestFuzzPoolCreate_ValidParams_Stateless tests pool creation with valid parameters
func TestFuzzPoolCreate_ValidParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		initStates(t)

		params := NewValidPoolCreateParams(ft)

		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		pool.SetPoolCreationFee(cross, 0)

		// when
		fuzzResult.AddParams(index, params)

		// then
		pool.CreatePool(
			cross,
			params.token0Path,
			params.token1Path,
			params.fee,
			params.sqrtPriceX96,
		)
	})
}

// TestFuzzPoolCreate_RandomizedParams_Stateless tests pool creation with randomized parameters
func TestFuzzPoolCreate_RandomizedParams_Stateless(t *testing.T) {
	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given
		initStates(t)

		params := NewRandomizedPoolCreateParams(ft)

		adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
		testing.SetRealm(testing.NewUserRealm(adminAddr))
		pool.SetPoolCreationFee(cross, 0)

		// when
		fuzzResult.AddParams(index, params)

		// then
		pool.CreatePool(
			cross,
			params.token0Path,
			params.token1Path,
			params.fee,
			params.sqrtPriceX96,
		)
	})
}

// TestFuzzPoolCreate_RandomizedParams_Stateful tests pool creation with randomized parameters in stateful mode
func TestFuzzPoolCreate_RandomizedParams_Stateful(t *testing.T) {
	// given
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))
	pool.SetPoolCreationFee(cross, 0)

	fuzzutils.RunFuzzTest(t, FUZZ_ITERATIONS, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		params := NewRandomizedPoolCreateParams(ft)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// when
		fuzzResult.AddParams(index, params)

		// then
		pool.CreatePool(
			cross,
			params.token0Path,
			params.token1Path,
			params.fee,
			params.sqrtPriceX96,
		)
	})
}
