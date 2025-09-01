// capital efficiency boundaries test

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(adminAddr)

	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = std.NewUserRealm(aliceAddr)

	barPath = "gno.land/r/onbloc/bar"
	bazPath = "gno.land/r/onbloc/baz"
)

func main() {
	println("[TEST] Capital Efficiency Boundaries Analysis")
	println("==================================================")

	// Setup
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Give Alice plenty of tokens
	largeAmount := int64(1_000_000_000_000_000) // 1e15
	bar.Transfer(cross, aliceAddr, largeAmount)
	baz.Transfer(cross, aliceAddr, largeAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, largeAmount)
	baz.Approve(cross, poolAddr, largeAmount)
	bar.Approve(cross, positionAddr, largeAmount)
	baz.Approve(cross, positionAddr, largeAmount)

	// Test 1: Symmetric large amounts in narrow range
	println("\n[TEST 1] Symmetric Large Amounts in Narrow Range")
	testSymmetricNarrowRange()

	// Test 2: Test different range widths
	println("\n[TEST 2] Capital Deployment vs Range Width")
	testRangeWidthEfficiency()

	// Test 3: Find the actual limits
	println("\n[TEST 3] Finding Actual Deployment Limits")
	testActualLimits()
}

func testSymmetricNarrowRange() {
	testing.SetRealm(adminRealm)

	// Create pool with tight tick spacing
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		100, // 0.01% fee
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	// Test with SYMMETRIC large amounts
	testAmounts := []string{
		"1000000",          // 1e6
		"1000000000",       // 1e9
		"1000000000000",    // 1e12
		"1000000000000000", // 1e15
	}

	for _, amount := range testAmounts {
		// Use very narrow range: just 2 ticks
		_, liquidity, amount0Used, amount1Used := pn.Mint(
			cross,
			barPath, bazPath, 100,
			0, 2, // 2-tick range
			amount, amount, // SYMMETRIC amounts
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		requested := u256.MustFromDecimal(amount)
		used0 := u256.MustFromDecimal(amount0Used)
		used1 := u256.MustFromDecimal(amount1Used)

		// Calculate efficiency as integer percentage
		var efficiency0Pct, efficiency1Pct uint64
		if !requested.IsZero() {
			// Calculate as percentage (multiply by 100 first to avoid truncation)
			efficiency0Pct = used0.Uint64() * 100 / requested.Uint64()
			efficiency1Pct = used1.Uint64() * 100 / requested.Uint64()
		}

		ufmt.Printf("Amount: %s\n", amount)
		ufmt.Printf("  Liquidity: %s\n", liquidity)
		ufmt.Printf("  Token0 - Used: %s (%d%% efficiency)\n", amount0Used, efficiency0Pct)
		ufmt.Printf("  Token1 - Used: %s (%d%% efficiency)\n", amount1Used, efficiency1Pct)
		ufmt.Printf("  Range: 2 ticks (0 to 2)\n\n")
	}
}

func testRangeWidthEfficiency() {
	testing.SetRealm(adminRealm)

	// Create new pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	testAmount := "1000000000000" // 1e12

	// Test different range widths
	ranges := []struct {
		lower int32
		upper int32
		desc  string
	}{
		{-10, 10, "20 ticks (±10)"},
		{-50, 50, "100 ticks (±50)"},
		{-100, 100, "200 ticks (±100)"},
		{-500, 500, "1000 ticks (±500)"},
		{-1000, 1000, "2000 ticks (±1000)"},
		{-5000, 5000, "10000 ticks (±5000)"},
	}

	ufmt.Printf("Testing amount: %s\n\n", testAmount)

	for _, r := range ranges {
		_, liquidity, amount0Used, amount1Used := pn.Mint(
			cross,
			barPath, bazPath, 500,
			r.lower, r.upper,
			testAmount, testAmount,
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		requested := u256.MustFromDecimal(testAmount)
		used0 := u256.MustFromDecimal(amount0Used)

		var efficiencyPct uint64
		if !requested.IsZero() {
			efficiencyPct = used0.Uint64() * 100 / requested.Uint64()
		}

		ufmt.Printf("Range: %s\n", r.desc)
		ufmt.Printf("  Liquidity: %s\n", liquidity)
		ufmt.Printf("  Amount0 used: %s (%d%%)\n", amount0Used, efficiencyPct)
		ufmt.Printf("  Amount1 used: %s\n\n", amount1Used)
	}
}

func testActualLimits() {
	testing.SetRealm(adminRealm)

	// Create new pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	// Test the absolute maximum we can deploy in ultra-narrow range
	println("Finding maximum deployable in 60-tick range (fee tier 3000)...")

	// Try increasing amounts until we hit limits
	testAmounts := []string{
		"1000000000",       // 1e9
		"10000000000",      // 1e10
		"100000000000",     // 1e11
		"1000000000000",    // 1e12
		"10000000000000",   // 1e13
		"100000000000000",  // 1e14
		"1000000000000000", // 1e15
	}

	for _, amount := range testAmounts {
		// Check if Alice has enough balance
		aliceBar := bar.BalanceOf(aliceAddr)
		aliceBaz := baz.BalanceOf(aliceAddr)

		ufmt.Printf("Testing amount: %s\n", amount)
		ufmt.Printf("  Alice balance: bar=%d, baz=%d\n", aliceBar, aliceBaz)

		_, liquidity, amount0Used, amount1Used := pn.Mint(
			cross,
			barPath, bazPath, 3000,
			-60, 60, // Minimum range for fee tier 3000
			amount, amount,
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		ufmt.Printf("  Result: liquidity=%s\n", liquidity)
		ufmt.Printf("  Used: token0=%s, token1=%s\n\n", amount0Used, amount1Used)

		// Check if we're hitting limits
		requested := u256.MustFromDecimal(amount)
		used0 := u256.MustFromDecimal(amount0Used)

		if used0.Lt(requested) {
			ratio := u256.Zero().Mul(used0, u256.NewUint(100))
			ratio = u256.Zero().Div(ratio, requested)
			ufmt.Printf("  ⚠️ LIMITATION DETECTED: Only used %s%% of requested amount\n\n", ratio.ToString())
		}
	}
}

// Output:
// [TEST] Capital Efficiency Boundaries Analysis
// ==================================================
//
// [TEST 1] Symmetric Large Amounts in Narrow Range
// Amount: 1000000
//   Liquidity: 20001999
//   Token0 - Used: 19999 (2.00% efficiency)
//   Token1 - Used: 20001 (2.00% efficiency)
//   Range: 2 ticks (0 to 2)
//
// Amount: 1000000000
//   Liquidity: 20001999999
//   Token0 - Used: 19999999 (2.00% efficiency)
//   Token1 - Used: 20001999 (2.00% efficiency)
//   Range: 2 ticks (0 to 2)
//
// Amount: 1000000000000
//   Liquidity: 20001999999999
//   Token0 - Used: 19999999999 (2.00% efficiency)
//   Token1 - Used: 20001999999 (2.00% efficiency)
//   Range: 2 ticks (0 to 2)
//
// Amount: 1000000000000000
//   Liquidity: 20001999999999999
//   Token0 - Used: 19999999999999 (2.00% efficiency)
//   Token1 - Used: 20001999999999 (2.00% efficiency)
//   Range: 2 ticks (0 to 2)
