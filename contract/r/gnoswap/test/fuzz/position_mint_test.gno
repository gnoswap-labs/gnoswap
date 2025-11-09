package fuzz

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/ufmt"

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

		fuzzResult.AddParams(index, mintParams)

		amount0Int64, _ := strconv.ParseInt(mintParams.amount0Desired, 10, 64)
		amount1Int64, _ := strconv.ParseInt(mintParams.amount1Desired, 10, 64)
		mintTestToken(mintParams.token0Path, amount0Int64)
		mintTestToken(mintParams.token1Path, amount1Int64)

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
		isCreatePool := fuzz.Bool().Draw(ft, "isCreatePool").(bool)
		if isCreatePool {
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

func TestFuzzPositionMint_ValidParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Create pool once
	token0Path := "gno.land/r/onbloc/bar"
	token1Path := "gno.land/r/onbloc/foo"
	fee := uint32(3000)

	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if !pool.ExistsPoolPath(poolPath) {
		pool.SetPoolCreationFee(cross, 0)
		pool.CreatePool(
			cross,
			token0Path,
			token1Path,
			fee,
			"79228162514264337593543950337",
		)
	}

	// Track minted positions
	var mintedPositions []uint64
	var expectedNextTokenId uint64 = 1

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Use fixed fee to ensure all positions are in the same pool
		mintParams := NewValidPositionMintParams(ft)
		fuzzResult.AddParams(index, mintParams)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// Get pool liquidity before mint
		poolLiquidityBefore := pool.GetLiquidity(poolPath)

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

		// Verify tokenId increases sequentially
		if tokenId != expectedNextTokenId {
			panic(ufmt.Sprintf("Expected tokenId %d, got %d", expectedNextTokenId, tokenId))
		}
		expectedNextTokenId++

		if liquidity == "0" {
			panic("Position liquidity should not be 0")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Position amounts should not be empty")
		}

		// Track this position
		mintedPositions = append(mintedPositions, tokenId)

		// Get pool liquidity after mint
		poolLiquidityAfter := pool.GetLiquidity(poolPath)

		t.Logf("Iteration %d: Minted position #%d with liquidity %s, Pool liquidity: %s -> %s",
			index, tokenId, liquidity, poolLiquidityBefore, poolLiquidityAfter)
	})

	t.Logf("Total positions minted: %d", len(mintedPositions))
}

func TestFuzzPositionMint_RandomizedParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Create pool once
	token0Path := "gno.land/r/onbloc/bar"
	token1Path := "gno.land/r/onbloc/foo"
	fee := uint32(3000)

	poolPath := pool.GetPoolPath(token0Path, token1Path, fee)
	if !pool.ExistsPoolPath(poolPath) {
		pool.SetPoolCreationFee(cross, 0)
		pool.CreatePool(
			cross,
			token0Path,
			token1Path,
			fee,
			"79228162514264337593543950337",
		)
	}

	// Track minted positions
	var mintedPositions []uint64

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Generate randomized params with fixed fee for the pool
		mintParams := NewRandomizedPositionMintParamsWithFee(ft, fee)
		fuzzResult.AddParams(index, mintParams)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// when - mint position (may panic with invalid params)
		tokenId, _, _, _ := position.Mint(
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

		// Track successful mints
		if tokenId != 0 {
			mintedPositions = append(mintedPositions, tokenId)
		}
	})

	t.Logf("Total positions successfully minted: %d", len(mintedPositions))
}
