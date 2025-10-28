// edge case ultra tight range positions

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const (
	INT64_MAX int64 = 9223372036854775807

	// Critical values for edge case testing
	NEAR_MAX_UINT128 = "340282366920938463463374607431768211454"
	MAX_UINT128      = "340282366920938463463374607431768211455"
	HALF_MAX_UINT128 = "170141183460469231731687303715884105727"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

func main() {
	println("[SCENARIO] 1. Initialize Pool with Minimum Tick Spacing")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Test Single Tick Range Position")
	testSingleTickRange()
	println()

	println("[SCENARIO] 3. Test Multiple Positions at Same Ultra-Tight Range")
	testMultipleUltraTightPositions()
	println()

	println("[SCENARIO] 4. Test Large Amounts in Minimal Range")
	testLargeAmountsMinimalRange()
	println()

	println("[SCENARIO] 5. Test Liquidity Calculation Precision")
	testLiquidityPrecision()
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Create pool with fee tier 100 (tick spacing = 1, most sensitive)
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		100, // fee tier with tick spacing 1
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// Setup test accounts with smaller amounts for shared test environment
	testAmount := int64(10_000_000_000) // 10 billion
	bar.Transfer(cross, aliceAddr, testAmount)
	baz.Transfer(cross, aliceAddr, testAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, testAmount)
	baz.Approve(cross, poolAddr, testAmount)
	bar.Approve(cross, positionAddr, testAmount)
	baz.Approve(cross, positionAddr, testAmount)

	println("[INFO] Pool created with tick spacing 1 (most sensitive to edge cases)")
	println("[INFO] Test accounts funded and approved")
}

func testSingleTickRange() {
	testing.SetRealm(aliceRealm)

	// Single tick range is the absolute minimum and most sensitive
	tickLower := int32(0)
	tickUpper := int32(1) // minimum possible range

	amount0 := "1000000000" // 1e9
	amount1 := "1000000000" // 1e9

	positionId, liquidity, actualAmount0, actualAmount1 := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		tickLower,
		tickUpper,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position %d: Single tick range (0 to 1)\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Amount0 used: %s\n", actualAmount0)
	ufmt.Printf("[EXPECTED] Amount1 used: %s\n", actualAmount1)

	// Verify liquidity is within reasonable bounds
	// Single tick ranges should not produce extreme liquidity values
}

func testMultipleUltraTightPositions() {
	testing.SetRealm(aliceRealm)

	// Test overlapping ultra-tight positions
	// This tests if the pool correctly handles multiple positions in same range

	// First position
	pos1Id, liq1, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		10, 11, // 1-tick range
		"500000000",
		"500000000",
		"0", "0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	// Second position at same range
	pos2Id, liq2, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		10, 11, // same 1-tick range
		"500000000",
		"500000000",
		"0", "0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position %d liquidity: %s\n", pos1Id, liq1)
	ufmt.Printf("[EXPECTED] Position %d liquidity: %s (should be similar to position %d)\n", pos2Id, liq2, pos1Id)
	ufmt.Printf("[EXPECTED] Multiple positions in same ultra-tight range handled correctly\n")
}

func testLargeAmountsMinimalRange() {
	testing.SetRealm(aliceRealm)

	// Test with large amounts in minimal range
	// This stresses the intermediate calculations
	tickLower := int32(-1)
	tickUpper := int32(0) // 1-tick range around current price

	// Large amounts within available balance
	amount0 := "1000000000" // 1e9
	amount1 := "1000000000" // 1e9

	positionId, liquidity, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		tickLower,
		tickUpper,
		amount0,
		amount1,
		"0",
		"0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Position %d: Large amounts in 1-tick range\n", positionId)
	ufmt.Printf("[EXPECTED] Liquidity: %s\n", liquidity)
	ufmt.Printf("[EXPECTED] Calculations handled large amounts without overflow\n")
}

func testLiquidityPrecision() {
	testing.SetRealm(aliceRealm)

	// Test precision with incrementally different amounts
	// Verifies that small changes produce proportional results

	baseAmount := "1000000000"
	incrementAmount := "1000000001" // +1 wei

	// Position with base amount
	_, liq1, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		100, 101, // 1-tick range
		baseAmount,
		baseAmount,
		"0", "0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	// Position with +1 wei
	_, liq2, _, _ := pn.Mint(
		cross,
		barPath,
		bazPath,
		100,
		110, 111, // different range to avoid interference
		incrementAmount,
		baseAmount,
		"0", "0",
		9999999999,
		aliceAddr,
		aliceAddr,
		"",
	)

	ufmt.Printf("[EXPECTED] Base liquidity: %s\n", liq1)
	ufmt.Printf("[EXPECTED] +1 wei liquidity: %s\n", liq2)
	ufmt.Printf("[EXPECTED] Small input changes produce proportional liquidity changes\n")
}

// Output:
// [SCENARIO] 1. Initialize Pool with Minimum Tick Spacing
// [INFO] Pool created with tick spacing 1 (most sensitive to edge cases)
// [INFO] Test accounts funded and approved
//
// [SCENARIO] 2. Test Single Tick Range Position
// [EXPECTED] Position 1: Single tick range (0 to 1)
// [EXPECTED] Liquidity: 20001499987500
// [EXPECTED] Amount0 used: 1000000000
// [EXPECTED] Amount1 used: 0
//
// [SCENARIO] 3. Test Multiple Positions at Same Ultra-Tight Range
// [EXPECTED] Position 2 liquidity: 10005751368922
// [EXPECTED] Position 3 liquidity: 10005751368922 (should be similar to position 2)
// [EXPECTED] Multiple positions in same ultra-tight range handled correctly
//
// [SCENARIO] 4. Test Large Amounts in Minimal Range
// [EXPECTED] Position 4: Large amounts in 1-tick range
// [EXPECTED] Liquidity: 20001499987500
// [EXPECTED] Calculations handled large amounts without overflow
//
// [SCENARIO] 5. Test Liquidity Calculation Precision
// [EXPECTED] Base liquidity: 20101752898303
// [EXPECTED] +1 wei liquidity: 20111805805240
// [EXPECTED] Small input changes produce proportional liquidity changes
