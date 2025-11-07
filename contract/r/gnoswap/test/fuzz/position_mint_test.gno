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

// TestFuzzPositionMint_ValidParams_Stateless tests Mint with valid parameters
func TestFuzzPositionMint_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		mintParams := NewValidPositionMintParams(ft)
		fuzzResult.AddParams(index, mintParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Setup: Create pool if not exists
		poolPath := pool.GetPoolPath(mintParams.token0Path, mintParams.token1Path, mintParams.fee)
		if !pool.ExistsPoolPath(poolPath) {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				mintParams.token0Path,
				mintParams.token1Path,
				mintParams.fee,
				"79228162514264337593543950337",
			)
		}

		// Approve tokens
		common.SafeGRC20Approve(cross, mintParams.token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, mintParams.token1Path, poolAddr, math.MaxInt64)

		// when - mint position
		tokenId, liquidity, amount0, amount1 := position.Mint(
			cross,
			mintParams.token0Path,
			mintParams.token1Path,
			mintParams.fee,
			mintParams.tickLower,
			mintParams.tickUpper,
			mintParams.amount0Desired,
			mintParams.amount1Desired,
			mintParams.amount0Min,
			mintParams.amount1Min,
			mintParams.deadline,
			adminAddr,
			adminAddr,
			"",
		)

		// then - verify position was created
		if tokenId == 0 {
			panic("Position tokenId should not be 0")
		}

		if liquidity == "0" {
			panic("Position liquidity should not be 0")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Position amounts should not be empty")
		}
	})
}

// TestFuzzPositionMint_RandomizedParams_Stateless tests Mint with randomized parameters
func TestFuzzPositionMint_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		mintParams := NewRandomizedPositionMintParams(ft)
		fuzzResult.AddParams(index, mintParams)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Setup: Create pool if not exists
		poolPath := pool.GetPoolPath(mintParams.token0Path, mintParams.token1Path, mintParams.fee)
		if !pool.ExistsPoolPath(poolPath) {
			pool.SetPoolCreationFee(cross, 0)
			pool.CreatePool(
				cross,
				mintParams.token0Path,
				mintParams.token1Path,
				mintParams.fee,
				"79228162514264337593543950337",
			)
		}

		// Approve tokens
		common.SafeGRC20Approve(cross, mintParams.token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, mintParams.token1Path, poolAddr, math.MaxInt64)

		// when - mint position (may panic with invalid params)
		position.Mint(
			cross,
			mintParams.token0Path,
			mintParams.token1Path,
			mintParams.fee,
			mintParams.tickLower,
			mintParams.tickUpper,
			mintParams.amount0Desired,
			mintParams.amount1Desired,
			mintParams.amount0Min,
			mintParams.amount1Min,
			mintParams.deadline,
			adminAddr,
			adminAddr,
			"",
		)
	})
}
