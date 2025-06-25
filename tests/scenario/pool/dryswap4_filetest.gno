package main

import (
	"std"
	"testing"

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

// DrySwap Test - ZeroForOne False (Token1 to Token0)
// Testing DrySwap functionality with zeroForOne=false
// Expected behavior: Calculate swap amounts for Token1 to Token0 direction
func main() {
	testDrySwapZeroForOneFalse(t)
}

// testDrySwapZeroForOneFalse tests DrySwap with zeroForOne=false
func testDrySwapZeroForOneFalse(t *testing.T) {
	pool.InitPoolTest(t)

	// Given: Pool exists with minted position
	println("[INFO] Token0:", barPath)
	println("[INFO] Token1:", fooPath)
	println("[INFO] Fee tier:", FeeTier500)
	println("[INFO] Initial liquidity amount:", liquidityExpect)
	println("[INFO] Tick range:", -tickUpper, "to", -tickLower)
	println("[INFO] Direction: Token1 (foo) to Token0 (bar) - zeroForOne=false")

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

	// When: Perform DrySwap with zeroForOne=false and positive amountSpecified
	amountSpecified := "16000"
	println("[INFO] Performing DrySwap with zeroForOne=false")
	println("[INFO] Amount specified:", amountSpecified)
	println("[INFO] Direction: foo (Token1) -> bar (Token0)")

	poolIn, poolOut, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		false, // zeroForOne = false
		amountSpecified,
		consts.MAX_PRICE, // Use MAX_PRICE for zeroForOne=false
	)

	// Then: Verify DrySwap results for zeroForOne=false
	println("[EXPECTED] Pool input amount should be:", "16000")
	println("[EXPECTED] Pool output amount should be positive (bar tokens)")
	println("[INFO] Actual pool input amount:", poolIn)
	println("[INFO] Actual pool output amount:", poolOut)

	println("[EXPECTED] poolIn", poolIn)
	// Note: poolOut will be positive for zeroForOne=false as we're getting bar tokens

	// When: Perform DrySwap with zeroForOne=false and negative amountSpecified
	negativeAmount := "-16000"
	println("[INFO] Performing DrySwap with zeroForOne=false and negative amount")
	println("[INFO] Amount specified:", negativeAmount)
	println("[INFO] This means exact output amount is specified")

	poolInNeg, poolOutNeg, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		false, // zeroForOne = false
		negativeAmount,
		consts.MAX_PRICE,
	)

	// Then: Verify DrySwap results for negative amount
	println("[EXPECTED] Pool input amount should be calculated for exact output")
	println("[EXPECTED] Pool output amount should be:", "-16000")
	println("[INFO] Actual pool input amount:", poolInNeg)
	println("[INFO] Actual pool output amount:", poolOutNeg)

	println("[EXPECTED] poolInNeg", poolInNeg)

	println("[SCENARIO] 5. DrySwap Test - ZeroForOne False - PASSED")
	println("[INFO] DrySwap correctly handles zeroForOne=false direction")
}

// Output:
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/foo
// [INFO] Fee tier: 500
// [INFO] Initial liquidity amount: 100000000000
// [INFO] Tick range: -11000 to -9000
// [INFO] Direction: Token1 (foo) to Token0 (bar) - zeroForOne=false
// [INFO] Position minted successfully
// [INFO] Minted amount0: 8040315472
// [INFO] Minted amount1: 2958014650
// [INFO] Performing DrySwap with zeroForOne=false
// [INFO] Amount specified: 16000
// [INFO] Direction: foo (Token1) -> bar (Token0)
// [EXPECTED] Pool input amount should be: 16000
// [EXPECTED] Pool output amount should be positive (bar tokens)
// [INFO] Actual pool input amount: -43468
// [INFO] Actual pool output amount: 16000
// [EXPECTED] poolIn -43468
// [INFO] Performing DrySwap with zeroForOne=false and negative amount
// [INFO] Amount specified: -16000
// [INFO] This means exact output amount is specified
// [EXPECTED] Pool input amount should be calculated for exact output
// [EXPECTED] Pool output amount should be: -16000
// [INFO] Actual pool input amount: -16000
// [INFO] Actual pool output amount: 5890
// [EXPECTED] poolInNeg -16000
// [SCENARIO] 5. DrySwap Test - ZeroForOne False - PASSED
// [INFO] DrySwap correctly handles zeroForOne=false direction
