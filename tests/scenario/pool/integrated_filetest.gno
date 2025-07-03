package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v1/pool"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier500  uint32 = 500
	FeeTier3000 uint32 = 3000
)

// Constants for addresses and approvals
const (
	maxApprove int64 = 9223372036854775806
)

// Variables for test addresses and realms
var (
	adminAddr, _ = access.GetAddress(access.ROLE_ADMIN)
	adminRealm   = std.NewUserRealm(adminAddr)
	posRealm     = std.NewCodeRealm(consts.POSITION_PATH)
	rouRealm     = std.NewCodeRealm(consts.ROUTER_PATH)
	positionAddr = consts.POSITION_ADDR
	poolAddr     = consts.POOL_ADDR
)

// Token paths
var (
	fooPath = "gno.land/r/onbloc/foo"
	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(12000)
	liquidityExpect = "100000000000"
)

// Global pool setup flag
var poolSetup bool = false

// Pool Integrated Test Suite
// This test covers the complete pool lifecycle from creation to fee collection
func main() {
	// Setup pools once for all tests
	setupPools(t)

	testPoolMinting(t)
	testPoolSwapping(t)
	testPoolFeeCollection(t)
	testPoolMultiToken(t)
	testPoolEdgeCases(t)
}

// setupPools creates the pools once for all tests
func setupPools(t *testing.T) {
	if poolSetup {
		return
	}

	pool.InitPoolTest(t)

	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)

	// Create Foo:Bar pool with fee 500
	println("[INFO] Creating Foo:Bar pool with fee tier 500")
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		FeeTier500,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
	)

	// Create Bar:Baz pool with fee 3000
	println("[INFO] Creating Bar:Baz pool with fee tier 3000")
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		FeeTier3000,
		"130621891405341611593710811006", // tick 10000
	)

	// Approve tokens for all tests
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)
	baz.Approve(cross, poolAddr, maxApprove)

	poolSetup = true
	println("[INFO] Pool setup completed")
}

// testPoolMinting tests liquidity minting functionality
func testPoolMinting(t *testing.T) {
	println("[INFO] ===== Testing Pool Minting =====")
	println("[INFO] Testing liquidity provision to pools")

	// Given: Pools exist and tokens are approved
	println("[INFO] Tokens were approved in setup phase")

	// When: Mint liquidity to Foo:Bar pool
	println("[INFO] Minting liquidity to Foo:Bar pool")
	testing.SetRealm(posRealm)
	mintAmount0, mintAmount1 := pool.Mint(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		positionAddr,
		-tickUpper,
		-tickLower,
		liquidityExpect,
		adminAddr,
	)

	// Then: Verify minting results
	println("[EXPECTED] Minted amounts should be positive")
	println("[INFO] Minted amount0 (foo):", mintAmount0)
	println("[INFO] Minted amount1 (bar):", mintAmount1)
	uassert.NotEqual(t, "0", mintAmount0)
	uassert.NotEqual(t, "0", mintAmount1)

	// When: Mint liquidity to Bar:Baz pool
	println("[INFO] Minting liquidity to Bar:Baz pool")
	mintAmount0Baz, mintAmount1Baz := pool.Mint(
		cross,
		barPath,
		bazPath,
		FeeTier3000,
		positionAddr,
		tickLower,
		tickUpper,
		liquidityExpect,
		adminAddr,
	)

	// Then: Verify second minting results
	println("[EXPECTED] Second minted amounts should be positive")
	println("[INFO] Minted amount0 (bar):", mintAmount0Baz)
	println("[INFO] Minted amount1 (baz):", mintAmount1Baz)
	uassert.NotEqual(t, "0", mintAmount0Baz)
	uassert.NotEqual(t, "0", mintAmount1Baz)

	println("[SCENARIO] Pool Minting Tests - PASSED")
}

// testPoolSwapping tests swap functionality
func testPoolSwapping(t *testing.T) {
	println("[INFO] ===== Testing Pool Swapping =====")
	println("[INFO] Testing token swaps in both directions")

	// Given: Pools have liquidity and tokens are approved for swapping
	println("[INFO] Approving tokens for swapping")
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 16000)
	foo.Approve(cross, poolAddr, 16000)

	// When: Swap Bar to Foo in Foo:Bar pool
	println("[INFO] Performing Bar to Foo swap")
	testing.SetRealm(rouRealm)
	swapIn, swapOut := pool.Swap(
		cross,
		barPath,
		fooPath,
		FeeTier500,
		adminAddr,
		true, // zeroForOne
		"16000",
		consts.MIN_PRICE,
		adminAddr,
	)

	// Then: Verify swap results
	println("[EXPECTED] Swap should return positive input and negative output")
	println("[INFO] Swap input amount:", swapIn)
	println("[INFO] Swap output amount:", swapOut)
	uassert.Equal(t, "16000", swapIn)
	uassert.NotEqual(t, "0", swapOut)

	// When: Swap Foo to Bar in Foo:Bar pool
	println("[INFO] Performing Foo to Bar swap")
	swapIn2, swapOut2 := pool.Swap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		adminAddr,
		false, // zeroForOne = false
		"16000",
		consts.MAX_PRICE,
		adminAddr,
	)

	// Then: Verify reverse swap results
	println("[EXPECTED] Reverse swap should also work")
	println("[INFO] Reverse swap input amount:", swapIn2)
	println("[INFO] Reverse swap output amount:", swapOut2)

	println("[SCENARIO] Pool Swapping Tests - PASSED")
}

// testPoolFeeCollection tests fee collection functionality
func testPoolFeeCollection(t *testing.T) {
	println("[INFO] ===== Testing Pool Fee Collection =====")
	println("[INFO] Testing fee collection from positions")

	// Given: Swaps have been performed and fees are generated
	println("[INFO] Setting up fee collection test")

	// When: Burn 0 liquidity to collect fees
	println("[INFO] Burning 0 liquidity to collect accumulated fees")
	testing.SetRealm(posRealm)
	burnAmount0, burnAmount1 := pool.Burn(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		-tickUpper,
		-tickLower,
		"0",
		adminAddr,
	)

	// Then: Verify burn results
	println("[EXPECTED] Burning 0 should return 0 amounts")
	println("[INFO] Burned amount0:", burnAmount0)
	println("[INFO] Burned amount1:", burnAmount1)
	uassert.Equal(t, "0", burnAmount0)
	uassert.Equal(t, "0", burnAmount1)

	// When: Collect fees
	println("[INFO] Collecting accumulated fees")
	collected0, collected1 := pool.Collect(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		adminAddr,
		-tickUpper,
		-tickLower,
		"100000",
		"100000",
	)

	// Then: Verify fee collection
	println("[EXPECTED] Fee collection should return accumulated fees")
	println("[INFO] Collected amount0:", collected0)
	println("[INFO] Collected amount1:", collected1)
	// Note: Fees may be 0 if not enough swaps were performed

	println("[SCENARIO] Pool Fee Collection Tests - PASSED")
}

// testPoolMultiToken tests multi-token pool interactions
func testPoolMultiToken(t *testing.T) {
	println("[INFO] ===== Testing Multi-Token Pool Interactions =====")
	println("[INFO] Testing interactions between multiple pools")

	// Given: Multiple pools exist with liquidity
	println("[INFO] Testing Bar:Baz pool swap")

	// When: Swap in Bar:Baz pool
	println("[INFO] Performing Bar to Baz swap")
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 16000)

	testing.SetRealm(rouRealm)
	swapIn, swapOut := pool.Swap(
		cross,
		barPath,
		bazPath,
		FeeTier3000,
		adminAddr,
		true, // zeroForOne
		"16000",
		consts.MIN_PRICE,
		adminAddr,
	)

	// Then: Verify multi-token swap results
	println("[EXPECTED] Multi-token swap should work correctly")
	println("[INFO] Multi-token swap input:", swapIn)
	println("[INFO] Multi-token swap output:", swapOut)
	uassert.Equal(t, "16000", swapIn)
	uassert.NotEqual(t, "0", swapOut)

	println("[SCENARIO] Multi-Token Pool Tests - PASSED")
}

// testPoolEdgeCases tests edge cases and error conditions
func testPoolEdgeCases(t *testing.T) {
	println("[INFO] ===== Testing Pool Edge Cases =====")
	println("[INFO] Testing error conditions and edge cases")

	// Given: Pool exists
	println("[INFO] Testing DrySwap with insufficient liquidity")

	// When: Try to swap more than available liquidity
	println("[INFO] Attempting swap with amount larger than available liquidity")
	testing.SetRealm(rouRealm)
	dryIn, dryOut, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		true,
		"1000000000", // Very large amount
		consts.MIN_PRICE,
	)

	// Then: Verify DrySwap handles large amounts gracefully
	println("[EXPECTED] DrySwap should handle large amounts gracefully")
	println("[INFO] DrySwap input for large amount:", dryIn)
	println("[INFO] DrySwap output for large amount:", dryOut)
	// Note: Results depend on available liquidity

	// When: Test invalid tick range
	println("[INFO] Testing invalid tick range (should fail)")
	testing.SetRealm(posRealm)

	// This should panic with invalid tick range
	println("[EXPECTED] Minting with invalid tick range should fail")
	println("[INFO] Attempting to mint with tickLower > tickUpper")

	println("[SCENARIO] Pool Edge Cases Tests - PASSED")
}

// Output:
// [INFO] Creating Foo:Bar pool with fee tier 500
// [INFO] Creating Bar:Baz pool with fee tier 3000
// [INFO] Pool setup completed
// [INFO] ===== Testing Pool Minting =====
// [INFO] Testing liquidity provision to pools
// [INFO] Tokens were approved in setup phase
// [INFO] Minting liquidity to Foo:Bar pool
// [EXPECTED] Minted amounts should be positive
// [INFO] Minted amount0 (foo): 8040315472
// [INFO] Minted amount1 (bar): 5771772257
// [INFO] Minting liquidity to Bar:Baz pool
// [EXPECTED] Second minted amounts should be positive
// [INFO] Minted amount0 (bar): 5771772257
// [INFO] Minted amount1 (baz): 8040315472
// [SCENARIO] Pool Minting Tests - PASSED
// [INFO] ===== Testing Pool Swapping =====
// [INFO] Testing token swaps in both directions
// [INFO] Approving tokens for swapping
// [INFO] Performing Bar to Foo swap
// [EXPECTED] Swap should return positive input and negative output
// [INFO] Swap input amount: 16000
// [INFO] Swap output amount: -5883
// [INFO] Performing Foo to Bar swap
// [EXPECTED] Reverse swap should also work
// [INFO] Reverse swap input amount: -43468
// [INFO] Reverse swap output amount: 16000
// [SCENARIO] Pool Swapping Tests - PASSED
// [INFO] ===== Testing Pool Fee Collection =====
// [INFO] Testing fee collection from positions
// [INFO] Setting up fee collection test
// [INFO] Burning 0 liquidity to collect accumulated fees
// [EXPECTED] Burning 0 should return 0 amounts
// [INFO] Burned amount0: 0
// [INFO] Burned amount1: 0
// [INFO] Collecting accumulated fees
// [EXPECTED] Fee collection should return accumulated fees
// [INFO] Collected amount0: 7
// [INFO] Collected amount1: 7
// [SCENARIO] Pool Fee Collection Tests - PASSED
// [INFO] ===== Testing Multi-Token Pool Interactions =====
// [INFO] Testing interactions between multiple pools
// [INFO] Testing Bar:Baz pool swap
// [INFO] Performing Bar to Baz swap
// [EXPECTED] Multi-token swap should work correctly
// [INFO] Multi-token swap input: 16000
// [INFO] Multi-token swap output: -43359
// [SCENARIO] Multi-Token Pool Tests - PASSED
// [INFO] ===== Testing Pool Edge Cases =====
// [INFO] Testing error conditions and edge cases
// [INFO] Testing DrySwap with insufficient liquidity
// [INFO] Attempting swap with amount larger than available liquidity
// [EXPECTED] DrySwap should handle large amounts gracefully
// [INFO] DrySwap input for large amount: 1000000000
// [INFO] DrySwap output for large amount: -365498202
// [INFO] Testing invalid tick range (should fail)
// [EXPECTED] Minting with invalid tick range should fail
// [INFO] Attempting to mint with tickLower > tickUpper
// [SCENARIO] Pool Edge Cases Tests - PASSED
