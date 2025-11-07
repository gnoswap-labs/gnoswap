package fuzz

import (
	"math"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
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

		// Align ticks to spacing
		tickSpacing := pool.GetFeeAmountTickSpacing(3000)
		repositionParams.tickLower = (repositionParams.tickLower / tickSpacing) * tickSpacing
		repositionParams.tickUpper = (repositionParams.tickUpper / tickSpacing) * tickSpacing
		if repositionParams.tickLower >= repositionParams.tickUpper {
			repositionParams.tickUpper = repositionParams.tickLower + tickSpacing
		}

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

		// Align ticks to spacing
		tickSpacing := pool.GetFeeAmountTickSpacing(3000)
		repositionParams.tickLower = (repositionParams.tickLower / tickSpacing) * tickSpacing
		repositionParams.tickUpper = (repositionParams.tickUpper / tickSpacing) * tickSpacing
		if repositionParams.tickLower >= repositionParams.tickUpper {
			repositionParams.tickUpper = repositionParams.tickLower + tickSpacing
		}

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
