package fuzz

import (
	"math"
	"strconv"
	"testing"

	"gno.land/p/gnoswap/fuzz"
	"gno.land/p/gnoswap/fuzzutils"
	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	"gno.land/r/gnoswap/position"

	"gno.land/p/nt/ufmt"
)

// TestFuzzPositionIncreaseLiquidity_ValidParams_Stateless tests IncreaseLiquidity with valid parameters
func TestFuzzPositionIncreaseLiquidity_ValidParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position first
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate params for increase liquidity
		increaseParams := NewValidPositionIncreaseLiquidityParams(ft, tokenId)
		fuzzResult.AddParams(index, increaseParams)

		// Get token paths from position
		token0Path, token1Path := getTokenPathsFromPosition(tokenId)

		// Mint tokens for increase liquidity
		amount0Int64, _ := strconv.ParseInt(increaseParams.amount0Desired, 10, 64)
		amount1Int64, _ := strconv.ParseInt(increaseParams.amount1Desired, 10, 64)
		mintTestToken(token0Path, amount0Int64)
		mintTestToken(token1Path, amount1Int64)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// when - increase liquidity
		_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
			cross,
			increaseParams.positionId,
			increaseParams.amount0Desired,
			increaseParams.amount1Desired,
			increaseParams.amount0Min,
			increaseParams.amount1Min,
			increaseParams.deadline,
		)

		// then - verify liquidity increased
		if liquidity == "0" {
			panic("Liquidity should be increased")
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}
	})
}

// TestFuzzPositionIncreaseLiquidity_RandomizedParams_Stateless tests IncreaseLiquidity with randomized parameters
func TestFuzzPositionIncreaseLiquidity_RandomizedParams_Stateless(t *testing.T) {
	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// given - initialize states
		initStates(t)

		testing.SetRealm(testing.NewUserRealm(adminAddr))

		// Create pool and initial position first
		tokenId := createTestPosition(t, adminAddr, poolAddr)

		// Generate params for increase liquidity
		increaseParams := NewRandomizedPositionIncreaseLiquidityParams(ft, tokenId)
		fuzzResult.AddParams(index, increaseParams)

		// Get token paths from position
		token0Path, token1Path := getTokenPathsFromPosition(tokenId)

		// Mint tokens for increase liquidity
		amount0Int64, _ := strconv.ParseInt(increaseParams.amount0Desired, 10, 64)
		amount1Int64, _ := strconv.ParseInt(increaseParams.amount1Desired, 10, 64)
		mintTestToken(token0Path, amount0Int64)
		mintTestToken(token1Path, amount1Int64)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// when - increase liquidity (may panic with invalid params)
		position.IncreaseLiquidity(
			cross,
			increaseParams.positionId,
			increaseParams.amount0Desired,
			increaseParams.amount1Desired,
			increaseParams.amount0Min,
			increaseParams.amount1Min,
			increaseParams.deadline,
		)
	})
}

func TestFuzzPositionIncreaseLiquidity_ValidParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))

	// Create initial position once with high liquidity
	tokenId := createTestPosition(t, adminAddr, poolAddr)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// Generate params for increase liquidity
		increaseParams := NewValidPositionIncreaseLiquidityParams(ft, tokenId)
		fuzzResult.AddParams(index, increaseParams)

		// Get token paths from position
		token0Path, token1Path := getTokenPathsFromPosition(tokenId)

		// Mint tokens for increase liquidity
		amount0Int64, _ := strconv.ParseInt(increaseParams.amount0Desired, 10, 64)
		amount1Int64, _ := strconv.ParseInt(increaseParams.amount1Desired, 10, 64)
		mintTestToken(token0Path, amount0Int64)
		mintTestToken(token1Path, amount1Int64)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// Get current total liquidity before increase
		prevTotalLiquidity := position.GetPositionLiquidity(tokenId)

		// when - increase liquidity
		_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
			cross,
			increaseParams.positionId,
			increaseParams.amount0Desired,
			increaseParams.amount1Desired,
			increaseParams.amount0Min,
			increaseParams.amount1Min,
			increaseParams.deadline,
		)

		// then - verify liquidity increased
		if liquidity == "0" {
			panic("Liquidity should be increased")
		}

		// Get new total liquidity after increase
		newTotalLiquidity := position.GetPositionLiquidity(tokenId)

		// Verify total liquidity increased
		if newTotalLiquidity.Lte(prevTotalLiquidity) {
			panic(ufmt.Sprintf("Total liquidity should increase: %s <= %s",
				newTotalLiquidity.ToString(), prevTotalLiquidity.ToString()))
		}

		// Verify amounts are non-negative
		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}
	})
}

func TestFuzzPositionIncreaseLiquidity_RandomizedParams_Stateful(t *testing.T) {
	initStates(t)

	adminAddr, _ := access.GetAddress(prabc.ROLE_ADMIN.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	tokenId := createTestPosition(t, adminAddr, poolAddr)

	fuzzutils.RunFuzzTest(t, 100, func(ft *fuzz.T, fuzzResult *fuzzutils.Result, index int) {
		// Generate params for increase liquidity
		increaseParams := NewRandomizedPositionIncreaseLiquidityParams(ft, tokenId)
		fuzzResult.AddParams(index, increaseParams)

		// Get token paths from position
		token0Path, token1Path := getTokenPathsFromPosition(tokenId)

		// Mint tokens for increase liquidity
		amount0Int64, _ := strconv.ParseInt(increaseParams.amount0Desired, 10, 64)
		amount1Int64, _ := strconv.ParseInt(increaseParams.amount1Desired, 10, 64)
		mintTestToken(token0Path, amount0Int64)
		mintTestToken(token1Path, amount1Int64)

		// Approve tokens
		common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
		common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

		// when - increase liquidity (may panic with invalid params)
		//
		// Get current total liquidity before increase
		prevTotalLiquidity := position.GetPositionLiquidity(tokenId)

		// when - increase liquidity
		_, liquidity, amount0, amount1, _ := position.IncreaseLiquidity(
			cross,
			increaseParams.positionId,
			increaseParams.amount0Desired,
			increaseParams.amount1Desired,
			increaseParams.amount0Min,
			increaseParams.amount1Min,
			increaseParams.deadline,
		)

		if liquidity == "0" {
			panic("Liquidity should be increased")
		}

		if amount0 == "" || amount1 == "" {
			panic("Amounts should not be empty")
		}

		// Get new total liquidity after increase
		newTotalLiquidity := position.GetPositionLiquidity(tokenId)

		// Verify total liquidity increased
		if newTotalLiquidity.Lte(prevTotalLiquidity) {
			panic(ufmt.Sprintf("Total liquidity should increase: %s <= %s",
				newTotalLiquidity.ToString(), prevTotalLiquidity.ToString()))
		}
	})
}

// Helper function to create a test position
func createTestPosition(t *testing.T, adminAddr, poolAddr address) uint64 {
	t.Helper()

	config := getNextPositionTokenConfig()
	token0Path := config.token0Path
	token1Path := config.token1Path
	fee := config.fee

	// Create pool if not exists
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

	// Approve tokens
	common.SafeGRC20Approve(cross, token0Path, poolAddr, math.MaxInt64)
	common.SafeGRC20Approve(cross, token1Path, poolAddr, math.MaxInt64)

	amount0Int64, _ := strconv.ParseInt("10000000", 10, 64)
	amount1Int64, _ := strconv.ParseInt("10000000", 10, 64)
	mintTestToken(token0Path, amount0Int64)
	mintTestToken(token1Path, amount1Int64)

	// Mint initial position
	tokenId, _, _, _ := position.Mint(
		cross,
		token0Path,
		token1Path,
		fee,
		-1800, // tickLower (aligned to spacing 60)
		1800,  // tickUpper
		"10000000",
		"10000000",
		"0",
		"0",
		2000000000,
		adminAddr,
		adminAddr,
		"",
	)

	return tokenId
}

type positionTokenConfig struct {
	token0Path string
	token1Path string
	fee        uint32
}

var (
	positionTokenConfigs       = buildPositionTokenConfigs()
	nextPositionTokenConfigIdx = 0
)

func buildPositionTokenConfigs() []positionTokenConfig {
	tokenPaths := []string{
		barPath,
		bazPath,
		fooPath,
		oblPath,
		quxPath,
	}

	configs := []positionTokenConfig{}
	for i := 0; i < len(tokenPaths); i++ {
		for j := i + 1; j < len(tokenPaths); j++ {
			for _, fee := range defaultFeeTiers {
				configs = append(configs, positionTokenConfig{
					token0Path: tokenPaths[i],
					token1Path: tokenPaths[j],
					fee:        fee,
				})
			}
		}
	}

	return configs
}

func getNextPositionTokenConfig() positionTokenConfig {
	if len(positionTokenConfigs) == 0 {
		panic("position token configs must not be empty")
	}

	config := positionTokenConfigs[nextPositionTokenConfigIdx%len(positionTokenConfigs)]
	nextPositionTokenConfigIdx++
	return config
}
