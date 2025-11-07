package fuzz

import (
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/position"
)

// TestFuzzPositionDecreaseLiquidity_ValidParams_Stateless tests DecreaseLiquidity with valid parameters
func TestFuzzPositionDecreaseLiquidity_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Use a fixed max liquidity for testing (actual position liquidity may vary)
		maxLiquidity := "100000000"

		// Generate params for decrease liquidity
		decreaseParams := NewValidPositionDecreaseLiquidityParams(ft, tokenId, maxLiquidity)
		fuzzResult.AddParams(index, decreaseParams)

		// when - decrease liquidity
		_, liquidity, amount0, amount1, _, _, _ := position.DecreaseLiquidity(
			cross,
			decreaseParams.positionId,
			decreaseParams.liquidity,
			decreaseParams.amount0Min,
			decreaseParams.amount1Min,
			decreaseParams.deadline,
			decreaseParams.unwrapResult,
		)

		// then - verify liquidity decreased
		if liquidity == "0" && decreaseParams.liquidity != "0" {
			panic("Liquidity should be returned")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}
	})
}

// TestFuzzPositionDecreaseLiquidity_RandomizedParams_Stateless tests DecreaseLiquidity with randomized parameters
func TestFuzzPositionDecreaseLiquidity_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)
		actualLiquidity := position.GetPositionLiquidity(tokenId).ToString()

		// Generate params for decrease liquidity
		decreaseParams := NewRandomizedPositionDecreaseLiquidityParams(ft, tokenId, actualLiquidity)
		fuzzResult.AddParams(index, decreaseParams)

		// when - decrease liquidity (may panic with invalid params)
		position.DecreaseLiquidity(
			cross,
			decreaseParams.positionId,
			decreaseParams.liquidity,
			decreaseParams.amount0Min,
			decreaseParams.amount1Min,
			decreaseParams.deadline,
			decreaseParams.unwrapResult,
		)
	})
}

func TestFuzzPositionDecreaseLiquidity_ValidParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Create pool and initial position once with high liquidity
	tokenId := createTestPosition(t, adminAddr, poolAddr)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		currentLiquidity := position.GetPositionLiquidity(tokenId).ToString()

		decreaseParams := NewValidPositionDecreaseLiquidityParams(ft, tokenId, currentLiquidity)
		fuzzResult.AddParams(index, decreaseParams)

		_, liquidity, amount0, amount1, _, _, _ := position.DecreaseLiquidity(
			cross,
			decreaseParams.positionId,
			decreaseParams.liquidity,
			decreaseParams.amount0Min,
			decreaseParams.amount1Min,
			decreaseParams.deadline,
			decreaseParams.unwrapResult,
		)

		if liquidity == "0" && decreaseParams.liquidity != "0" {
			panic("Liquidity should be returned")
		}

		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}
	})
}

func TestFuzzPositionDecreaseLiquidity_RandomizedParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	tokenId := createTestPosition(t, adminAddr, poolAddr)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		currentLiquidity := position.GetPositionLiquidity(tokenId).ToString()

		// Generate randomized params for decrease liquidity
		decreaseParams := NewRandomizedPositionDecreaseLiquidityParams(ft, tokenId, currentLiquidity)
		fuzzResult.AddParams(index, decreaseParams)

		position.DecreaseLiquidity(
			cross,
			decreaseParams.positionId,
			decreaseParams.liquidity,
			decreaseParams.amount0Min,
			decreaseParams.amount1Min,
			decreaseParams.deadline,
			decreaseParams.unwrapResult,
		)
	})
}
