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

// DrySwap Test - ZeroForOne True with Negative Amount Specified
// Testing DrySwap functionality with zeroForOne=true and amountSpecified=-16000
// Expected behavior: Calculate swap amounts for exact output amount
func main() {
	testDrySwapZeroForOneTrueNegativeAmount(t)
}

// testDrySwapZeroForOneTrueNegativeAmount tests DrySwap with zeroForOne=true and negative amountSpecified
func testDrySwapZeroForOneTrueNegativeAmount(t *testing.T) {
	pool.InitPoolTest(t)

	// Given: Pool exists with minted position
	println("[INFO] Setting up pool and position for DrySwap test")
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

	// When: Perform DrySwap with zeroForOne=true and negative amountSpecified
	amountSpecified := "-16000"
	println("[INFO] Performing DrySwap with zeroForOne=true")
	println("[INFO] Amount specified:", amountSpecified)
	println("[INFO] Note: Negative amount means exact output amount is specified")

	poolIn, poolOut, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		true, // zeroForOne
		amountSpecified,
		consts.MIN_PRICE,
	)

	// Then: Verify DrySwap results
	println("[EXPECTED] Pool input amount should be:", "43513")
	println("[EXPECTED] Pool output amount should be:", "-16000")
	println("[INFO] Actual pool input amount:", poolIn)
	println("[INFO] Actual pool output amount:", poolOut)

	uassert.Equal(t, "43513", poolIn)
	uassert.Equal(t, "-16000", poolOut)

	println("[SCENARIO] 2. DrySwap Test - ZeroForOne True with Negative Amount Specified - PASSED")
}

// Output:
// [INFO] Setting up pool and position for DrySwap test
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/foo
// [INFO] Fee tier: 500
// [INFO] Initial liquidity amount: 100000000000
// [INFO] Tick range: -11000 to -9000
// [INFO] Position minted successfully
// [INFO] Minted amount0: 8040315472
// [INFO] Minted amount1: 2958014650
// [INFO] Performing DrySwap with zeroForOne=true
// [INFO] Amount specified: -16000
// [INFO] Note: Negative amount means exact output amount is specified
// [EXPECTED] Pool input amount should be: 43513
// [EXPECTED] Pool output amount should be: -16000
// [INFO] Actual pool input amount: 43513
// [INFO] Actual pool output amount: -16000
// [SCENARIO] 2. DrySwap Test - ZeroForOne True with Negative Amount Specified - PASSED
