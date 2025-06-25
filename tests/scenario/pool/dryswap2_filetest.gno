package main

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	"gno.land/r/gnoswap/v1/pool"
)

var t *testing.T

// Constants for fee tiers
const (
	FeeTier500 uint32 = 500
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
)

// Test variables
var (
	tickLower       = int32(9000)
	tickUpper       = int32(11000)
	liquidityExpect = "100000000000"
)

// DrySwap vs Actual Swap Comparison Test
// Testing DrySwap prediction accuracy against actual Swap execution
// Expected behavior: DrySwap should accurately predict actual swap amounts
func main() {
	testDrySwapVsActualSwap(t)
}

// testDrySwapVsActualSwap tests DrySwap prediction against actual Swap execution
func testDrySwapVsActualSwap(t *testing.T) {
	pool.InitPoolTest(t)

	// Given: Pool exists with minted position
	println("[INFO] Setting up pool and position for comparison test")
	println("[INFO] Token0:", barPath)
	println("[INFO] Token1:", fooPath)
	println("[INFO] Fee tier:", FeeTier500)
	println("[INFO] Initial liquidity amount:", liquidityExpect)
	println("[INFO] Tick range:", -tickUpper, "to", -tickLower)

	// Create pool
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFeeByAdmin(cross, 0)
	pool.CreatePool(
		cross,
		barPath,
		fooPath,
		FeeTier500,
		common.TickMathGetSqrtRatioAtTick(-10000).ToString(),
	)

	// Approve tokens for minting
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	// Mint position
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

	println("[INFO] Position minted successfully")
	println("[INFO] Minted amount0:", mintAmount0)
	println("[INFO] Minted amount1:", mintAmount1)

	// When: Perform DrySwap to predict swap amounts
	amountSpecified := "16000"
	println("[INFO] Step 1: Performing DrySwap to predict swap amounts")
	println("[INFO] Amount specified:", amountSpecified)

	dryPoolIn, dryPoolOut, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		true, // zeroForOne
		amountSpecified,
		consts.MIN_PRICE,
	)

	println("[INFO] DrySwap prediction completed")
	println("[INFO] Predicted pool input:", dryPoolIn)
	println("[INFO] Predicted pool output:", dryPoolOut)

	// When: Perform actual Swap
	println("[INFO] Step 2: Performing actual Swap")

	// Approve tokens for swapping
	testing.SetRealm(adminRealm)
	bar.Approve(cross, poolAddr, 16000)

	// Execute actual swap
	testing.SetRealm(rouRealm)
	actualPoolIn, actualPoolOut := pool.Swap(
		cross,
		barPath,
		fooPath,
		FeeTier500,
		adminAddr,
		true, // zeroForOne
		amountSpecified,
		consts.MIN_PRICE,
		adminAddr,
	)

	println("[INFO] Actual swap completed")
	println("[INFO] Actual pool input:", actualPoolIn)
	println("[INFO] Actual pool output:", actualPoolOut)

	// Then: Compare DrySwap prediction with actual Swap results
	println("[EXPECTED] DrySwap prediction should match actual swap results")
	println("[INFO] Comparing DrySwap prediction vs actual swap:")
	println("[INFO]   Pool Input - Predicted:", dryPoolIn, "Actual:", actualPoolIn)
	println("[INFO]   Pool Output - Predicted:", dryPoolOut, "Actual:", actualPoolOut)

	uassert.Equal(t, dryPoolIn, actualPoolIn)
	uassert.Equal(t, dryPoolOut, actualPoolOut)

	println("[SCENARIO] 3. DrySwap vs Actual Swap Comparison Test - PASSED")
	println("[INFO] DrySwap accurately predicted the actual swap amounts")
}

// Output:
// [INFO] Setting up pool and position for comparison test
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/foo
// [INFO] Fee tier: 500
// [INFO] Initial liquidity amount: 100000000000
// [INFO] Tick range: -11000 to -9000
// [INFO] Position minted successfully
// [INFO] Minted amount0: 8040315472
// [INFO] Minted amount1: 2958014650
// [INFO] Step 1: Performing DrySwap to predict swap amounts
// [INFO] Amount specified: 16000
// [INFO] DrySwap prediction completed
// [INFO] Predicted pool input: 16000
// [INFO] Predicted pool output: -5883
// [INFO] Step 2: Performing actual Swap
// [INFO] Actual swap completed
// [INFO] Actual pool input: 16000
// [INFO] Actual pool output: -5883
// [EXPECTED] DrySwap prediction should match actual swap results
// [INFO] Comparing DrySwap prediction vs actual swap:
// [INFO]   Pool Input - Predicted: 16000 Actual: 16000
// [INFO]   Pool Output - Predicted: -5883 Actual: -5883
// [SCENARIO] 3. DrySwap vs Actual Swap Comparison Test - PASSED
// [INFO] DrySwap accurately predicted the actual swap amounts
