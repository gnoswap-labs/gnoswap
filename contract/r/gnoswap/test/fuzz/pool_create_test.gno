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
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		poolParams := NewValidPoolCreateParams(ft)
		fuzzResult.AddParams(index, poolParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Set pool creation fee to 0 for testing
		pool.SetPoolCreationFee(cross, 0)

		// when - create pool
		pool.CreatePool(
			cross,
			poolParams.token0Path,
			poolParams.token1Path,
			poolParams.fee,
			poolParams.sqrtPriceX96,
		)
	})
}

// TestFuzzPoolCreate_RandomizedParams_Stateless tests pool creation with randomized parameters
func TestFuzzPoolCreate_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		poolParams := NewRandomizedPoolCreateParams(ft)
		fuzzResult.AddParams(index, poolParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Set pool creation fee to 0 for testing
		pool.SetPoolCreationFee(cross, 0)

		// when - create pool
		pool.CreatePool(
			cross,
			poolParams.token0Path,
			poolParams.token1Path,
			poolParams.fee,
			poolParams.sqrtPriceX96,
		)
	})
}

// TestFuzzPoolCreate_ValidParams_Stateful tests pool creation with valid parameters in stateful mode
func TestFuzzPoolCreate_ValidParams_Stateful(t *testing.T) {
	// given - initialize states once
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Set pool creation fee to 0 for testing
	pool.SetPoolCreationFee(cross, 0)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		poolParams := NewValidPoolCreateParams(ft)

		fuzzResult.AddParams(index, poolParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		pool.CreatePool(
			cross,
			poolParams.token0Path,
			poolParams.token1Path,
			poolParams.fee,
			poolParams.sqrtPriceX96,
		)
	})
}

// TestFuzzPoolCreate_RandomizedParams_Stateful tests pool creation with randomized parameters in stateful mode
func TestFuzzPoolCreate_RandomizedParams_Stateful(t *testing.T) {
	// given - initialize states once
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Set pool creation fee to 0 for testing
	pool.SetPoolCreationFee(cross, 0)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		poolParams := NewRandomizedPoolCreateParams(ft)
		fuzzResult.AddParams(index, poolParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// when - create pool (may panic if duplicate or invalid params)
		pool.CreatePool(
			cross,
			poolParams.token0Path,
			poolParams.token1Path,
			poolParams.fee,
			poolParams.sqrtPriceX96,
		)
	})
}
