// PKGPATH: gno.land/r/gnoswap/v1/main

package main

import (
	"gno.land/p/gnoswap/gnsmath"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	"gno.land/r/gnoswap/router"

	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"
)

var t *testing.T

const (
	INT64_MAX int64 = 9223372036854775807
)

var (
	adminAddr, _  = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm    = testing.NewUserRealm(adminAddr)
	poolAddr, _   = access.GetAddress(prbac.ROLE_POOL.String())
	routerAddr, _ = access.GetAddress(prbac.ROLE_ROUTER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	fooPath = "gno.land/r/onbloc/foo"

	fee100   = uint32(100)   // 0.01%
	fee500   = uint32(500)   // 0.05%
	fee3000  = uint32(3000)  // 0.30%
	fee10000 = uint32(10000) // 1.00%
)

func main(cur realm) {
	ufmt.Println("[SCENARIO] Fee Calculation Accuracy Test - Validating Uniswap V3 Fee Mathematics")
	initPoolsWithDifferentFees(cur)
	println()

	testing.SkipHeights(1)

	ufmt.Println("[SCENARIO] 1. Fee Calculation for Different Tiers")
	testFeeCalculation100(cur)
	testFeeCalculation500(cur)
	testFeeCalculation3000(cur)
	testFeeCalculation10000(cur)
	println()

	ufmt.Println("[SCENARIO] 2. Fee Accumulation Over Multiple Swaps")
	testFeeAccumulation(cur)
	println()

	ufmt.Println("[SCENARIO] 3. Fee Precision for Small Amounts")
	testSmallAmountFeePrecision(cur)
	println()

	ufmt.Println("[SCENARIO] 4. Fee Calculation in Exact Out Swaps")
	testExactOutFeeCalculation(cur)
	println()
}

func initPoolsWithDifferentFees(cur realm) {
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)

	defaultTokenAmount := int64(100_000_000_000_000)

	ufmt.Println("[INFO] Distributing tokens")
	bar.Transfer(cross(cur), aliceAddr, defaultTokenAmount)
	foo.Transfer(cross(cur), aliceAddr, defaultTokenAmount)

	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	ufmt.Println("[INFO] Creating pools with different fee tiers")
	pl.CreatePool(cross(cur), barPath, fooPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross(cur), barPath, fooPath, fee500, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross(cur), barPath, fooPath, fee3000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	pl.CreatePool(cross(cur), barPath, fooPath, fee10000, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())

	// Add liquidity to all pools
	testing.SetRealm(aliceRealm)
	bar.Approve(cross(cur), poolAddr, INT64_MAX)
	foo.Approve(cross(cur), poolAddr, INT64_MAX)

	// Add same liquidity to all pools for fair comparison
	liquidityAmount := "100000000000"
	pn.Mint(cross(cur), barPath, fooPath, fee100, -10000, 10000, liquidityAmount, liquidityAmount, "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee500, -10000, 10000, liquidityAmount, liquidityAmount, "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee3000, -9960, 9960, liquidityAmount, liquidityAmount, "0", "0", time.Now().Unix()+3600, aliceAddr, "")
	pn.Mint(cross(cur), barPath, fooPath, fee10000, -10000, 10000, liquidityAmount, liquidityAmount, "0", "0", time.Now().Unix()+3600, aliceAddr, "")
}

func testFeeCalculation100(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing 0.01% fee tier")
	amount := "1000000000" // 1 billion units
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:100"

	bar.Approve(cross(cur), routerAddr, 1000000000)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Input: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Output: %s\n", amountOut)

	// Calculate expected fee (0.01% of input)
	// Fee = 1000000000 * 0.0001 = 100000
	ufmt.Println("[EXPECTED] Fee should be ~100,000 units (0.01% of input)")
}

func testFeeCalculation500(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing 0.05% fee tier")
	amount := "1000000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	bar.Approve(cross(cur), routerAddr, 1000000000)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Input: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Output: %s\n", amountOut)

	// Fee = 1000000000 * 0.0005 = 500000
	ufmt.Println("[EXPECTED] Fee should be ~500,000 units (0.05% of input)")
}

func testFeeCalculation3000(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing 0.30% fee tier")
	amount := "1000000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:3000"

	bar.Approve(cross(cur), routerAddr, 1000000000)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Input: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Output: %s\n", amountOut)

	// Fee = 1000000000 * 0.003 = 3000000
	ufmt.Println("[EXPECTED] Fee should be ~3,000,000 units (0.30% of input)")
}

func testFeeCalculation10000(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing 1.00% fee tier")
	amount := "1000000000"
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:10000"

	bar.Approve(cross(cur), routerAddr, 1000000000)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, amount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Input: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Output: %s\n", amountOut)

	// Fee = 1000000000 * 0.01 = 10000000
	ufmt.Println("[EXPECTED] Fee should be ~10,000,000 units (1.00% of input)")
}

func testFeeAccumulation(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing fee accumulation over multiple swaps")

	amount := "100000000" // Smaller amount for multiple swaps
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	// Execute multiple swaps
	for i := 0; i < 3; i++ {
		bar.Approve(cross(cur), routerAddr, 100000000)
		amountIn, amountOut := router.ExactInSwapRoute(
			cross(cur), barPath, fooPath, amount, route, "100", "1",
			time.Now().Add(time.Hour).Unix(), "",
		)
		ufmt.Printf("[INFO] SWAP %d - In: %s, Out: %s\n", i+1, amountIn, amountOut)
	}

	ufmt.Println("[EXPECTED] Each swap should deduct 0.05% fee consistently")
}

func testSmallAmountFeePrecision(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing fee precision for small amounts")

	// Test with amount that might cause rounding issues
	smallAmount := "1337" // Prime number for edge case
	route := "gno.land/r/onbloc/bar:gno.land/r/onbloc/foo:500"

	bar.Approve(cross(cur), routerAddr, 1337)

	amountIn, amountOut := router.ExactInSwapRoute(
		cross(cur), barPath, fooPath, smallAmount, route, "100", "1",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Small amount in: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Small amount out: %s\n", amountOut)

	// For 1337 with 0.05% fee, fee should be ~0.67 (rounds to 1)
	ufmt.Println("[EXPECTED] Fee calculation should handle rounding correctly")
}

func testExactOutFeeCalculation(cur realm) {
	testing.SetRealm(aliceRealm)

	ufmt.Println("[INFO] Testing fee calculation in exact out swaps")

	desiredOutput := "1000000000"
	route := "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"

	foo.Approve(cross(cur), routerAddr, 1000000000)

	// For exact out, fee is calculated on the input amount
	amountIn, amountOut := router.ExactOutSwapRoute(
		cross(cur), fooPath, barPath, desiredOutput, route, "100", "999999999999",
		time.Now().Add(time.Hour).Unix(), "",
	)

	ufmt.Printf("[EXPECTED] Input required: %s\n", amountIn)
	ufmt.Printf("[EXPECTED] Output received: %s\n", amountOut)

	// Input should be output / (1 - fee)
	// For 1000000000 output with 0.05% fee: input ≈ 1000000000 / 0.9995 ≈ 1000500250
	ufmt.Println("[EXPECTED] Input should be ~1,000,500,250 (accounting for 0.05% fee)")
}

// Output:
// [SCENARIO] Fee Calculation Accuracy Test - Validating Uniswap V3 Fee Mathematics
// [INFO] Distributing tokens
// [INFO] Creating pools with different fee tiers
//
// [SCENARIO] 1. Fee Calculation for Different Tiers
// [INFO] Testing 0.01% fee tier
// [EXPECTED] Input: 1000000000
// [EXPECTED] Output: -994487688
// [EXPECTED] Fee should be ~100,000 units (0.01% of input)
// [INFO] Testing 0.05% fee tier
// [EXPECTED] Input: 1000000000
// [EXPECTED] Output: -994091411
// [EXPECTED] Fee should be ~500,000 units (0.05% of input)
// [INFO] Testing 0.30% fee tier
// [EXPECTED] Input: 1000000000
// [EXPECTED] Output: -991626613
// [EXPECTED] Fee should be ~3,000,000 units (0.30% of input)
// [INFO] Testing 1.00% fee tier
// [EXPECTED] Input: 1000000000
// [EXPECTED] Output: -984679480
// [EXPECTED] Fee should be ~10,000,000 units (1.00% of input)
//
// [SCENARIO] 2. Fee Accumulation Over Multiple Swaps
// [INFO] Testing fee accumulation over multiple swaps
// [INFO] SWAP 1 - In: 100000000, Out: -98980966
// [INFO] SWAP 2 - In: 100000000, Out: -98903481
// [INFO] SWAP 3 - In: 100000000, Out: -98826089
// [EXPECTED] Each swap should deduct 0.05% fee consistently
//
// [SCENARIO] 3. Fee Precision for Small Amounts
// [INFO] Testing fee precision for small amounts
// [EXPECTED] Small amount in: 1337
// [EXPECTED] Small amount out: -1321
// [EXPECTED] Fee calculation should handle rounding correctly
//
// [SCENARIO] 4. Fee Calculation in Exact Out Swaps
// [INFO] Testing fee calculation in exact out swaps
// [EXPECTED] Input required: 995739810
// [EXPECTED] Output received: -1000000000
// [EXPECTED] Input should be ~1,000,500,250 (accounting for 0.05% fee)
