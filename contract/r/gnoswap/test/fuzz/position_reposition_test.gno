package fuzz

import (
	"math"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	"gno.land/p/nt/ufmt"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/position"
)

// TestFuzzPositionReposition_ValidParams_Stateless tests Reposition with valid parameters
func TestFuzzPositionReposition_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Get the actual liquidity from the position
		liquidity := position.GetPositionLiquidity(tokenId)

		// Clear the position first (Reposition requires position to be fully cleared)
		position.DecreaseLiquidity(
			cross,
			tokenId,
			liquidity.ToString(),
			"0",
			"0",
			2000000000,
			false,
		)

		// Generate params for reposition
		repositionParams := NewValidPositionRepositionParams(ft, tokenId, 3000)
		fuzzResult.AddParams(index, repositionParams)

		// Approve tokens
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/bar", poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/foo", poolAddr, math.MaxInt64)

		// when - reposition
		newTokenId, liquidityStr, tickLower, tickUpper, amount0, amount1 := position.Reposition(
			cross,
			repositionParams.positionId,
			repositionParams.tickLower,
			repositionParams.tickUpper,
			repositionParams.amount0Desired,
			repositionParams.amount1Desired,
			repositionParams.amount0Min,
			repositionParams.amount1Min,
		)

		// then - verify new position created
		if newTokenId == 0 {
			panic("New position tokenId should not be 0")
		}

		if liquidityStr == "0" {
			panic("New position liquidity should not be 0")
		}

		// Verify tick range matches
		if tickLower != repositionParams.tickLower || tickUpper != repositionParams.tickUpper {
			panic("Tick range should match requested range")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}
	})
}

// TestFuzzPositionReposition_RandomizedParams_Stateless tests Reposition with randomized parameters
func TestFuzzPositionReposition_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Get the actual liquidity from the position
		liquidity := position.GetPositionLiquidity(tokenId)

		// Clear the position first (Reposition requires position to be fully cleared)
		position.DecreaseLiquidity(
			cross,
			tokenId,
			liquidity.ToString(),
			"0",
			"0",
			2000000000,
			false,
		)

		// Generate params for reposition
		repositionParams := NewRandomizedPositionRepositionParams(ft, tokenId)
		fuzzResult.AddParams(index, repositionParams)

		// Approve tokens
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/bar", poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/foo", poolAddr, math.MaxInt64)

		// when - reposition (may panic with invalid params)
		position.Reposition(
			cross,
			repositionParams.positionId,
			repositionParams.tickLower,
			repositionParams.tickUpper,
			repositionParams.amount0Desired,
			repositionParams.amount1Desired,
			repositionParams.amount0Min,
			repositionParams.amount1Min,
		)
	})
}

// TestFuzzPositionReposition_ValidParams_Stateful tests Reposition with valid parameters in stateful manner
func TestFuzzPositionReposition_ValidParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Create initial position once
	tokenId := createTestPosition(t, adminAddr, poolAddr)

	// Track all tick ranges this position has been through
	type repositionHistory struct {
		tickLower int32
		tickUpper int32
		liquidity string
	}
	var history []repositionHistory

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Get the current position's liquidity
		liquidity := position.GetPositionLiquidity(tokenId)

		// Clear the position first (Reposition requires position to be fully cleared)
		position.DecreaseLiquidity(
			cross,
			tokenId,
			liquidity.ToString(),
			"0",
			"0",
			2000000000,
			false,
		)

		// Verify position is now empty
		liquidityAfterDecrease := position.GetPositionLiquidity(tokenId)
		if !liquidityAfterDecrease.IsZero() {
			panic(ufmt.Sprintf("Position should be empty after DecreaseLiquidity, but has %s", liquidityAfterDecrease.ToString()))
		}

		// Generate params for reposition
		repositionParams := NewValidPositionRepositionParams(ft, tokenId, 3000)
		fuzzResult.AddParams(index, repositionParams)

		// Approve tokens
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/bar", poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, "gno.land/r/onbloc/foo", poolAddr, math.MaxInt64)

		// when - reposition
		returnedTokenId, liquidityStr, tickLower, tickUpper, amount0, amount1 := position.Reposition(
			cross,
			repositionParams.positionId,
			repositionParams.tickLower,
			repositionParams.tickUpper,
			repositionParams.amount0Desired,
			repositionParams.amount1Desired,
			repositionParams.amount0Min,
			repositionParams.amount1Min,
		)

		// then - verify position was updated
		if returnedTokenId == 0 {
			panic("Returned tokenId should not be 0")
		}

		// Reposition should return the same tokenId (it updates the existing position)
		if returnedTokenId != tokenId {
			panic(ufmt.Sprintf("Reposition should return same tokenId: expected %d, got %d", tokenId, returnedTokenId))
		}

		if liquidityStr == "0" {
			panic("Position liquidity should not be 0 after reposition")
		}

		// Verify tick range matches
		if tickLower != repositionParams.tickLower || tickUpper != repositionParams.tickUpper {
			panic("Tick range should match requested range")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}

		// Track this reposition in history
		history = append(history, repositionHistory{
			tickLower: tickLower,
			tickUpper: tickUpper,
			liquidity: liquidityStr,
		})
	})

	t.Logf("Position #%d was repositioned %d times", tokenId, len(history))
}
