// edge case mint burn roundtrip invariant test

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/atone"
)

const INT64_MAX int64 = 9223372036854775807

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	poolAddr, _     = access.GetAddress(prbac.ROLE_POOL.String())
	positionAddr, _ = access.GetAddress(prbac.ROLE_POSITION.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	atonePath = "gno.land/r/gnoswap/test_token/atone"
)

func main() {
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Test Round-Trip in Ultra-Tight Range")
	testRoundTripUltraTight()
	println()

	println("[SCENARIO] 3. Test Round-Trip with Various Amounts")
	testRoundTripVariousAmounts()
	println()

	println("[SCENARIO] 4. Test Round-Trip at Price Boundaries")
	testRoundTripPriceBoundaries()
	println()

	println("[SCENARIO] 5. Test Multiple Round-Trips (Compound Effect)")
	testMultipleRoundTrips()
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Setup test accounts with smaller amounts for shared test environment
	testAmount := int64(10_000_000_000) // 10 billion
	atom.Transfer(cross, aliceAddr, testAmount)
	atone.Transfer(cross, aliceAddr, testAmount)

	testing.SetRealm(aliceRealm)
	atom.Approve(cross, poolAddr, testAmount)
	atone.Approve(cross, poolAddr, testAmount)
	atom.Approve(cross, positionAddr, testAmount)
	atone.Approve(cross, positionAddr, testAmount)

	// Track initial balances
	initialAtomBalance := atom.BalanceOf(aliceAddr)
	initialAtoneBalance := atone.BalanceOf(aliceAddr)

	ufmt.Printf("[INFO] Initial Atom balance: %d\n", initialAtomBalance)
	ufmt.Printf("[INFO] Initial Atone balance: %d\n", initialAtoneBalance)
}

func testRoundTripUltraTight() {
	testing.SetRealm(adminRealm)

	// Create pool with tick spacing 1 (most sensitive)
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	// Record balances before mint
	// atomBefore := atom.BalanceOf(aliceAddr)
	// atoneBefore := atone.BalanceOf(aliceAddr)

	// Mint position with ultra-tight range (1 tick)
	println("[TEST] Mint position with 1-tick range")
	positionId, liquidity, amount0Used, amount1Used := pn.Mint(
		cross,
		atomPath, atonePath, 100,
		0, 1, // 1-tick range
		"1000000000", "1000000000",
		"0", "0",
		9999999999,
		aliceAddr,
		"",
	)

	ufmt.Printf("[MINT] Position %d created\n", positionId)
	ufmt.Printf("[MINT] Liquidity: %s\n", liquidity)
	ufmt.Printf("[MINT] Amount0 used: %s\n", amount0Used)
	ufmt.Printf("[MINT] Amount1 used: %s\n", amount1Used)

	// Immediately burn the entire position
	println("[TEST] Burn entire position")
	_, burnedLiquidity, _, _, amount0Back, amount1Back, _ := pn.DecreaseLiquidity(
		cross,
		positionId,
		liquidity, // burn all liquidity
		"0", "0",
		9999999999,
	)

	ufmt.Printf("[BURN] Liquidity burned: %s\n", burnedLiquidity)
	ufmt.Printf("[BURN] Amount0 returned: %s\n", amount0Back)
	ufmt.Printf("[BURN] Amount1 returned: %s\n", amount1Back)

	// Collect the tokens
	// Note: CollectFee is handled internally by DecreaseLiquidity
	// collected0 := amount0Back
	// collected1 := amount1Back

	// Verify round-trip invariant
	// We should get back approximately what we put in (allowing for tiny rounding)
	amount0UsedU256 := u256.MustFromDecimal(amount0Used)
	amount0BackU256 := u256.MustFromDecimal(amount0Back)
	amount1UsedU256 := u256.MustFromDecimal(amount1Used)
	amount1BackU256 := u256.MustFromDecimal(amount1Back)

	// Calculate differences
	var diff0, diff1 *u256.Uint
	if amount0UsedU256.Gt(amount0BackU256) {
		diff0 = u256.Zero().Sub(amount0UsedU256, amount0BackU256)
	} else {
		diff0 = u256.Zero().Sub(amount0BackU256, amount0UsedU256)
	}

	if amount1UsedU256.Gt(amount1BackU256) {
		diff1 = u256.Zero().Sub(amount1UsedU256, amount1BackU256)
	} else {
		diff1 = u256.Zero().Sub(amount1BackU256, amount1UsedU256)
	}

	// Maximum acceptable loss (0.01% or 1 wei, whichever is larger)
	tolerance0 := u256.Zero().Div(amount0UsedU256, u256.NewUint(10000))
	if tolerance0.IsZero() {
		tolerance0 = u256.NewUint(1)
	}

	tolerance1 := u256.Zero().Div(amount1UsedU256, u256.NewUint(10000))
	if tolerance1.IsZero() {
		tolerance1 = u256.NewUint(1)
	}

	ufmt.Printf("[INVARIANT] Token0 difference: %s (tolerance: %s)\n", diff0.ToString(), tolerance0.ToString())
	ufmt.Printf("[INVARIANT] Token1 difference: %s (tolerance: %s)\n", diff1.ToString(), tolerance1.ToString())

	if diff0.Gt(tolerance0) || diff1.Gt(tolerance1) {
		ufmt.Printf("[WARNING] Round-trip invariant violation detected!\n")
	} else {
		ufmt.Printf("[PASS] Round-trip invariant maintained\n")
	}
}

func testRoundTripVariousAmounts() {
	testing.SetRealm(adminRealm)

	// Create new pool
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	// Test with different amount scales
	amounts := []string{
		"1000",       // Small
		"1000000",    // Medium
		"1000000000", // Large
		"1000000000", // Large
	}

	for _, amount := range amounts {
		println(ufmt.Sprintf("[TEST] Round-trip with amount: %s", amount))

		// Mint
		posId, liq, amt0Used, _ := pn.Mint(
			cross,
			atomPath, atonePath, 500,
			-100, 100,
			amount, amount,
			"0", "0",
			9999999999,
			aliceAddr,
			"",
		)

		// Burn
		_, _, _, _, amt0Back, _, _ := pn.DecreaseLiquidity(
			cross,
			posId,
			liq,
			"0", "0",
			9999999999,
		)

		// Verify invariant
		used0 := u256.MustFromDecimal(amt0Used)
		back0 := u256.MustFromDecimal(amt0Back)

		var loss0 *u256.Uint
		if used0.Gt(back0) {
			loss0 = u256.Zero().Sub(used0, back0)
		} else {
			loss0 = u256.Zero()
		}

		ufmt.Printf("[RESULT] Amount: %s, Used: %s, Returned: %s, Loss: %s\n",
			amount, amt0Used, amt0Back, loss0.ToString())
	}
}

func testRoundTripPriceBoundaries() {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	// Test at different price points
	testRanges := []struct {
		tickLower int32
		tickUpper int32
		desc      string
	}{
		{-887220, -887160, "MIN boundary"},
		{887160, 887220, "MAX boundary"},
		{-60, 60, "Around current price"},
		{-1020, 1020, "Wide range"}, // Must be divisible by 60 for fee tier 3000
	}

	for _, tr := range testRanges {
		println(ufmt.Sprintf("[TEST] Round-trip at %s", tr.desc))

		// Mint
		posId, liq, amt0Used, _ := pn.Mint(
			cross,
			atomPath, atonePath, 3000,
			tr.tickLower, tr.tickUpper,
			"1000000", "1000000",
			"0", "0",
			9999999999,
			aliceAddr,
			"",
		)

		// Burn
		_, _, _, _, amt0Back, _, _ := pn.DecreaseLiquidity(
			cross,
			posId,
			liq,
			"0", "0",
			9999999999,
		)

		ufmt.Printf("[RESULT] Range: [%d,%d], In: (%s,%s), Out: (%s,%s)\n",
			tr.tickLower, tr.tickUpper, amt0Used, "(token1)", amt0Back, "(token1)")
	}
}

func testMultipleRoundTrips() {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.CreatePool(
		cross,
		atomPath,
		atonePath,
		10000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	println("[TEST] Multiple consecutive round-trips (checking compound effects)")

	initialAtom := atom.BalanceOf(aliceAddr)
	initialAtone := atone.BalanceOf(aliceAddr)

	// Perform 5 round-trips
	for i := 1; i <= 5; i++ {
		// Mint
		posId, liq, _, _ := pn.Mint(
			cross,
			atomPath, atonePath, 10000,
			-200, 200,
			"1000000", "1000000",
			"0", "0",
			9999999999,
			aliceAddr,
			"",
		)

		// Burn
		pn.DecreaseLiquidity(
			cross,
			posId,
			liq,
			"0", "0",
			9999999999,
		)

		currentAtom := atom.BalanceOf(aliceAddr)
		currentAtone := atone.BalanceOf(aliceAddr)

		ufmt.Printf("[ROUND %d] Atom balance: %d, Atone balance: %d\n",
			i, currentAtom, currentAtone)
	}

	finalAtom := atom.BalanceOf(aliceAddr)
	finalAtone := atone.BalanceOf(aliceAddr)

	// Check cumulative effect
	totalLossAtom := initialAtom - finalAtom
	totalLossAtone := initialAtone - finalAtone

	ufmt.Printf("[FINAL] Total Atom loss after 5 round-trips: %d\n", totalLossAtom)
	ufmt.Printf("[FINAL] Total Atone loss after 5 round-trips: %d\n", totalLossAtone)

	// Loss should be minimal (< 0.1% total)
	maxAcceptableLoss := int64(5000) // 5 * 1000000 * 0.001
	if totalLossAtom > maxAcceptableLoss || totalLossAtone > maxAcceptableLoss {
		ufmt.Printf("[WARNING] Excessive loss detected in multiple round-trips!\n")
	} else {
		ufmt.Printf("[PASS] Multiple round-trips maintain value preservation\n")
	}
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] Initial Atom balance: 10000000000
// [INFO] Initial Atone balance: 10000000000
//
// [SCENARIO] 2. Test Round-Trip in Ultra-Tight Range
// [TEST] Mint position with 1-tick range
// [MINT] Position 1 created
// [MINT] Liquidity: 20001499987500
// [MINT] Amount0 used: 1000000000
// [MINT] Amount1 used: 0
// [TEST] Burn entire position
// [BURN] Liquidity burned: 20001499987500
// [BURN] Amount0 returned: 999999999
// [BURN] Amount1 returned: 0
// [INVARIANT] Token0 difference: 1 (tolerance: 100000)
// [INVARIANT] Token1 difference: 0 (tolerance: 1)
// [PASS] Round-trip invariant maintained
//
// [SCENARIO] 3. Test Round-Trip with Various Amounts
// [TEST] Round-trip with amount: 1000
// [RESULT] Amount: 1000, Used: 1000, Returned: 999, Loss: 1
// [TEST] Round-trip with amount: 1000000
// [RESULT] Amount: 1000000, Used: 1000000, Returned: 999999, Loss: 1
// [TEST] Round-trip with amount: 1000000000
// [RESULT] Amount: 1000000000, Used: 1000000000, Returned: 999999999, Loss: 1
// [TEST] Round-trip with amount: 1000000000
// [RESULT] Amount: 1000000000, Used: 1000000000, Returned: 999999999, Loss: 1
//
// [SCENARIO] 4. Test Round-Trip at Price Boundaries
// [TEST] Round-trip at MIN boundary
// [RESULT] Range: [-887220,-887160], In: (0,(token1)), Out: (0,(token1))
// [TEST] Round-trip at MAX boundary
// [RESULT] Range: [887160,887220], In: (1000000,(token1)), Out: (999999,(token1))
// [TEST] Round-trip at Around current price
// [RESULT] Range: [-60,60], In: (1000000,(token1)), Out: (999999,(token1))
// [TEST] Round-trip at Wide range
// [RESULT] Range: [-1020,1020], In: (1000000,(token1)), Out: (999999,(token1))
//
// [SCENARIO] 5. Test Multiple Round-Trips (Compound Effect)
// [TEST] Multiple consecutive round-trips (checking compound effects)
// [ROUND 1] Atom balance: 9999999991, Atone balance: 9999999992
// [ROUND 2] Atom balance: 9999999990, Atone balance: 9999999991
// [ROUND 3] Atom balance: 9999999989, Atone balance: 9999999990
// [ROUND 4] Atom balance: 9999999988, Atone balance: 9999999989
// [ROUND 5] Atom balance: 9999999987, Atone balance: 9999999988
// [FINAL] Total Atom loss after 5 round-trips: 5
// [FINAL] Total Atone loss after 5 round-trips: 5
// [PASS] Multiple round-trips maintain value preservation
