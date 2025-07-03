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

// DrySwap Failure Cases Test
// Testing DrySwap behavior when conditions are not met
// Expected behavior: DrySwap should fail gracefully when liquidity is insufficient
func main() {
	testDrySwapFailureCases(t)
}

// testDrySwapFailureCases tests DrySwap behavior in failure scenarios
func testDrySwapFailureCases(t *testing.T) {
	pool.InitPoolTest(t)

	// Given: Pool exists but no liquidity is provided
	println("[INFO] Token0:", barPath)
	println("[INFO] Token1:", fooPath)
	println("[INFO] Fee tier:", FeeTier500)
	println("[INFO] Note: No liquidity will be minted to test failure case")

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

	println("[INFO] Pool created successfully without any liquidity")

	// When: Attempt DrySwap without liquidity
	amountSpecified := "16000"
	println("[INFO] Attempting DrySwap without liquidity")
	println("[INFO] Amount specified:", amountSpecified)
	println("[INFO] Expected: DrySwap should fail due to insufficient liquidity")

	// DrySwap should fail when no liquidity exists
	dryPoolIn, dryPoolOut, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		true, // zeroForOne
		amountSpecified,
		consts.MIN_PRICE,
	)

	// Then: Verify DrySwap failure behavior
	println("[EXPECTED] DrySwap should return zero amounts when no liquidity exists")
	println("[INFO] DrySwap result - Pool input:", dryPoolIn)
	println("[INFO] DrySwap result - Pool output:", dryPoolOut)

	// When: Add some liquidity and test again
	println("[INFO] Adding minimal liquidity to test partial failure")

	// Approve tokens for minting
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	// Mint small position
	testing.SetRealm(posRealm)
	mintAmount0, mintAmount1 := pool.Mint(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		positionAddr,
		-tickUpper,
		-tickLower,
		"1000", // Small liquidity amount
		adminAddr,
	)

	println("[INFO] Small position minted")
	println("[INFO] Minted amount0:", mintAmount0)
	println("[INFO] Minted amount1:", mintAmount1)

	// When: Attempt DrySwap with insufficient liquidity for large amount
	largeAmount := "1000000"
	println("[INFO] Attempting DrySwap with amount larger than available liquidity")
	println("[INFO] Amount specified:", largeAmount)
	println("[INFO] Available liquidity is much smaller than requested amount")

	dryPoolInLarge, dryPoolOutLarge, _ := pool.DrySwap(
		cross,
		fooPath,
		barPath,
		FeeTier500,
		true, // zeroForOne
		largeAmount,
		consts.MIN_PRICE,
	)

	// Then: Verify DrySwap behavior with insufficient liquidity
	println("[EXPECTED] DrySwap should return reduced amounts when liquidity is insufficient")
	println("[INFO] DrySwap result for large amount:")
	println("[INFO]   Pool input:", dryPoolInLarge)
	println("[INFO]   Pool output:", dryPoolOutLarge)
	println("[INFO] Note: Amounts should be limited by available liquidity")

	println("[SCENARIO] 4. DrySwap Failure Cases Test - PASSED")
	println("[INFO] DrySwap correctly handles insufficient liquidity scenarios")
}

// Output:
// [INFO] Token0: gno.land/r/onbloc/bar
// [INFO] Token1: gno.land/r/onbloc/foo
// [INFO] Fee tier: 500
// [INFO] Note: No liquidity will be minted to test failure case
// [INFO] Pool created successfully without any liquidity
// [INFO] Attempting DrySwap without liquidity
// [INFO] Amount specified: 16000
// [INFO] Expected: DrySwap should fail due to insufficient liquidity
// [EXPECTED] DrySwap should return zero amounts when no liquidity exists
// [INFO] DrySwap result - Pool input: 0
// [INFO] DrySwap result - Pool output: 0
// [INFO] Adding minimal liquidity to test partial failure
// [INFO] Small position minted
// [INFO] Minted amount0: 81
// [INFO] Minted amount1: 30
// [INFO] Attempting DrySwap with amount larger than available liquidity
// [INFO] Amount specified: 1000000
// [INFO] Available liquidity is much smaller than requested amount
// [EXPECTED] DrySwap should return reduced amounts when liquidity is insufficient
// [INFO] DrySwap result for large amount:
// [INFO]   Pool input: 87
// [INFO]   Pool output: -29
// [INFO] Note: Amounts should be limited by available liquidity
// [SCENARIO] 4. DrySwap Failure Cases Test - PASSED
// [INFO] DrySwap correctly handles insufficient liquidity scenarios
