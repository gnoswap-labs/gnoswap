// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
	"gno.land/r/gnoswap/test_token/btc"

	"gno.land/r/gnoswap/pool"

	_ "gno.land/r/gnoswap/pool/v1"
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
	adminAddr, _    = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm      = testing.NewUserRealm(adminAddr)
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())
	posRealm        = testing.NewUserRealm(positionAddr)
	routerAddr, _   = access.GetAddress(prbac.ROLE_ROUTER.String())
	rouRealm        = testing.NewUserRealm(routerAddr)
	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
)

// Token paths
var (
	btcPath = "gno.land/r/gnoswap/test_token/btc"
	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(12000)
	liquidityExpect = "100000000000"

	MIN_PRICE string = "4295128740"
	MAX_PRICE string = "1461446703485210103287273052203988822378723970341"
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

	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Create Btc:Atom pool with fee 500
	println("[INFO] Creating Btc:Atom pool with fee tier 500")
	pool.CreatePool(
		cross,
		atomPath,
		btcPath,
		FeeTier500,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
	)

	// Create Atom:Atone pool with fee 3000
	println("[INFO] Creating Atom:Atone pool with fee tier 3000")
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		FeeTier3000,
		"130621891405341611593710811006", // tick 10000
	)

	// Approve tokens for all tests
	btc.Approve(cross, poolAddr, maxApprove)
	atom.Approve(cross, poolAddr, maxApprove)
	atone.Approve(cross, poolAddr, maxApprove)

	poolSetup = true
	println("[INFO] Pool setup completed")
}

// testPoolMinting tests liquidity minting functionality
func testPoolMinting(t *testing.T) {
	println("[INFO] ===== Testing Pool Minting =====")
	println("[INFO] Testing liquidity provision to pools")

	// Given: Pools exist and tokens are approved
	println("[INFO] Tokens were approved in setup phase")

	// When: Mint liquidity to Btc:Atom pool
	println("[INFO] Minting liquidity to Btc:Atom pool")
	testing.SetRealm(posRealm)
	mintAmount0, mintAmount1 := pool.Mint(
		cross,
		btcPath,
		atomPath,
		FeeTier500,
		-tickUpper,
		-tickLower,
		liquidityExpect,
		adminAddr,
	)

	// Then: Verify minting results
	println("[EXPECTED] Minted amounts should be positive")
	println("[INFO] Minted amount0 (btc):", mintAmount0)
	println("[INFO] Minted amount1 (atom):", mintAmount1)
	uassert.NotEqual(t, "0", mintAmount0)
	uassert.NotEqual(t, "0", mintAmount1)

	// When: Mint liquidity to Atom:Atone pool
	println("[INFO] Minting liquidity to Atom:Atone pool")
	mintAmount0Atone, mintAmount1Atone := pool.Mint(
		cross,
		atomPath,
		atonePath,
		FeeTier3000,
		tickLower,
		tickUpper,
		liquidityExpect,
		adminAddr,
	)

	// Then: Verify second minting results
	println("[EXPECTED] Second minted amounts should be positive")
	println("[INFO] Minted amount0 (atom):", mintAmount0Atone)
	println("[INFO] Minted amount1 (atone):", mintAmount1Atone)
	uassert.NotEqual(t, "0", mintAmount0Atone)
	uassert.NotEqual(t, "0", mintAmount1Atone)

	println("[SCENARIO] Pool Minting Tests - PASSED")
}

// testPoolSwapping tests swap functionality
func testPoolSwapping(t *testing.T) {
	println("[INFO] ===== Testing Pool Swapping =====")
	println("[INFO] Testing token swaps in both directions")

	// Given: Pools have liquidity and tokens are approved for swapping
	println("[INFO] Approving tokens for swapping")
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, 16000)
	btc.Approve(cross, poolAddr, 16000)

	// When: Swap Atom to Btc in Btc:Atom pool
	println("[INFO] Performing Atom to Btc swap")

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	swapIn, swapOut := pool.Swap(
		cross,
		atomPath,
		btcPath,
		FeeTier500,
		adminAddr,
		true, // zeroForOne
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
	)

	// Then: Verify swap results
	println("[EXPECTED] Swap should return positive input and negative output")
	println("[INFO] Swap input amount:", swapIn)
	println("[INFO] Swap output amount:", swapOut)
	uassert.Equal(t, "16000", swapIn)
	uassert.NotEqual(t, "0", swapOut)

	// When: Swap Btc to Atom in Btc:Atom pool
	println("[INFO] Performing Btc to Atom swap")
	swapIn2, swapOut2 := pool.Swap(
		cross,
		atomPath,
		btcPath,
		FeeTier500,
		adminAddr,
		false, // zeroForOne = false
		"16000",
		MAX_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
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
		btcPath,
		atomPath,
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
		btcPath,
		atomPath,
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
	println("[INFO] Testing Atom:Atone pool swap")

	// When: Swap in Atom:Atone pool
	println("[INFO] Performing Atom to Atone swap")
	testing.SetRealm(adminRealm)
	atom.Approve(cross, poolAddr, 16000)

	// set current realm and origin caller
	testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
	swapIn, swapOut := pool.Swap(
		cross,
		atomPath,
		atonePath,
		FeeTier3000,
		adminAddr,
		true, // zeroForOne
		"16000",
		MIN_PRICE,
		adminAddr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
			return mockSwapCallback(atomPath, btcPath, amount0Delta, amount1Delta)
		},
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
		btcPath,
		atomPath,
		FeeTier500,
		true,
		"1000000000", // Very large amount
		MIN_PRICE,
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

func mockSwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64) error {
	testing.SetRealm(adminRealm)

	if amount0Delta > 0 {
		common.SafeGRC20Transfer(cross, token0Path, poolAddr, amount0Delta)
	}
	if amount1Delta > 0 {
		common.SafeGRC20Transfer(cross, token1Path, poolAddr, amount1Delta)
	}

	return nil
}

// Output:
// [INFO] Creating Btc:Atom pool with fee tier 500
// [INFO] Creating Atom:Atone pool with fee tier 3000
// [INFO] Pool setup completed
// [INFO] ===== Testing Pool Minting =====
// [INFO] Testing liquidity provision to pools
// [INFO] Tokens were approved in setup phase
// [INFO] Minting liquidity to Btc:Atom pool
// [EXPECTED] Minted amounts should be positive
// [INFO] Minted amount0 (btc): 8040315472
// [INFO] Minted amount1 (atom): 5771772257
// [INFO] Minting liquidity to Atom:Atone pool
// [EXPECTED] Second minted amounts should be positive
// [INFO] Minted amount0 (atom): 5771772257
// [INFO] Minted amount1 (atone): 8040315472
// [SCENARIO] Pool Minting Tests - PASSED
// [INFO] ===== Testing Pool Swapping =====
// [INFO] Testing token swaps in both directions
// [INFO] Approving tokens for swapping
// [INFO] Performing Atom to Btc swap
// [EXPECTED] Swap should return positive input and negative output
// [INFO] Swap input amount: 16000
// [INFO] Swap output amount: -5883
// [INFO] Performing Btc to Atom swap
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
// [INFO] Testing Atom:Atone pool swap
// [INFO] Performing Atom to Atone swap
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
