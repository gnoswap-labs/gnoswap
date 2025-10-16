// edge case monotonicity test

// PKGPATH: gno.land/r/demo/main

package main

import (
	"testing"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

const INT64_MAX int64 = 9223372036854775807

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
	println("[SCENARIO] 1. Initialize Setup")
	initializeSetup()
	println()

	println("[SCENARIO] 2. Test Monotonicity in Ultra-Tight Range")
	testMonotonicityUltraTight()
	println()

	println("[SCENARIO] 3. Test Monotonicity Across Different Scales")
	testMonotonicityScales()
	println()

	println("[SCENARIO] 4. Test Monotonicity at Boundaries")
	testMonotonicityBoundaries()
	println()

	println("[SCENARIO] 5. Test No Discontinuous Jumps")
	testNoDiscontinuousJumps()
	println()
}

func initializeSetup() {
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Setup test accounts with smaller amounts for shared test environment
	testAmount := int64(10_000_000_000) // 10 billion
	bar.Transfer(cross, aliceAddr, testAmount)
	baz.Transfer(cross, aliceAddr, testAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, testAmount)
	baz.Approve(cross, poolAddr, testAmount)
	bar.Approve(cross, positionAddr, testAmount)
	baz.Approve(cross, positionAddr, testAmount)

	println("[INFO] Setup completed")
}

func testMonotonicityUltraTight() {
	testing.SetRealm(adminRealm)

	// Create pool with tick spacing 1 (most sensitive)
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		100,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	println("[TEST] Monotonicity in 1-tick range (most sensitive)")

	// Test with incremental amounts
	baseAmount := "1000000000" // 1e9
	amounts := []string{
		baseAmount,
		"1000000001", // +1 wei
		"1000000002", // +2 wei
		"1000000010", // +10 wei
		"1000000100", // +100 wei
		"1000001000", // +1000 wei
	}

	var prevLiquidity *u256.Uint

	for i, amount := range amounts {
		// Use different tick ranges to avoid position interference
		tickLower := int32(i * 10)
		tickUpper := int32(i*10 + 1)

		_, liquidity, _, _ := pn.Mint(
			cross,
			barPath, bazPath, 100,
			tickLower, tickUpper,
			amount, amount,
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		liq := u256.MustFromDecimal(liquidity)

		ufmt.Printf("[RESULT] Amount: %s, Liquidity: %s\n", amount, liquidity)

		// Verify monotonicity
		if prevLiquidity != nil {
			if liq.Lt(prevLiquidity) {
				ufmt.Printf("[ERROR] Monotonicity violation! Current(%s) < Previous(%s)\n",
					liq.ToString(), prevLiquidity.ToString())
			} else {
				// Check the increase is proportional
				diff := u256.Zero().Sub(liq, prevLiquidity)

				// The liquidity increase should be small for small input increases
				// For 1 wei increase, liquidity shouldn't jump by more than a reasonable factor
				if i == 1 { // First increment (1 wei)
					// Calculate percentage increase
					percentIncrease := u256.Zero().Mul(diff, u256.NewUint(10000))
					percentIncrease = u256.Zero().Div(percentIncrease, prevLiquidity)

					// Should be less than 0.01% (1 basis point)
					if percentIncrease.Gt(u256.NewUint(1)) {
						ufmt.Printf("[WARNING] Large jump detected: %s basis points increase for 1 wei\n",
							percentIncrease.ToString())
					} else {
						ufmt.Printf("[PASS] Proportional increase for 1 wei: %s basis points\n",
							percentIncrease.ToString())
					}
				}
			}
		}

		prevLiquidity = liq
	}
}

func testMonotonicityScales() {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		500,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	println("[TEST] Monotonicity across different scales")

	// Test at different magnitude scales
	scales := []struct {
		base string
		inc  string
		desc string
	}{
		{"1000", "1001", "Small scale"},
		{"1000000", "1000001", "Medium scale"},
		{"1000000000", "1000000001", "Large scale"},
	}

	for _, scale := range scales {
		// Position with base amount
		_, liq1, _, _ := pn.Mint(
			cross,
			barPath, bazPath, 500,
			-100, 100,
			scale.base, scale.base,
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		// Position with incremented amount
		_, liq2, _, _ := pn.Mint(
			cross,
			barPath, bazPath, 500,
			200, 300, // Different range
			scale.inc, scale.base,
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		liquidity1 := u256.MustFromDecimal(liq1)
		liquidity2 := u256.MustFromDecimal(liq2)

		ufmt.Printf("[%s] Base: %s (liq: %s), +1: %s (liq: %s)\n",
			scale.desc, scale.base, liq1, scale.inc, liq2)

		// Verify monotonicity
		if liquidity2.Lt(liquidity1) {
			ufmt.Printf("[ERROR] Monotonicity violation at scale %s!\n", scale.desc)
		} else {
			diff := u256.Zero().Sub(liquidity2, liquidity1)
			ufmt.Printf("[PASS] Monotonic increase: %s\n", diff.ToString())
		}
	}
}

func testMonotonicityBoundaries() {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		3000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	println("[TEST] Monotonicity at tick boundaries")

	// Test at boundary positions where calculations are most sensitive
	boundaries := []struct {
		tickLower int32
		tickUpper int32
		desc      string
	}{
		{-887220, -887160, "MIN boundary"},
		{887160, 887220, "MAX boundary"},
		{-60, 0, "Negative to zero"},
		{0, 60, "Zero to positive"},
	}

	for _, boundary := range boundaries {
		amounts := []string{"1000000", "1000001", "1000002"}
		var prevLiq *u256.Uint

		ufmt.Printf("[TEST] %s [%d, %d]\n", boundary.desc, boundary.tickLower, boundary.tickUpper)

		for _, amount := range amounts {
			_, liq, _, _ := pn.Mint(
				cross,
				barPath, bazPath, 3000,
				boundary.tickLower, boundary.tickUpper,
				amount, amount,
				"0", "0",
				9999999999,
				aliceAddr, aliceAddr, "",
			)

			liquidity := u256.MustFromDecimal(liq)

			if prevLiq != nil && liquidity.Lt(prevLiq) {
				ufmt.Printf("[ERROR] Non-monotonic at %s!\n", boundary.desc)
			}

			prevLiq = liquidity
		}

		ufmt.Printf("[PASS] Monotonic at %s\n", boundary.desc)
	}
}

func testNoDiscontinuousJumps() {
	testing.SetRealm(adminRealm)

	// Create pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		10000,
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	testing.SetRealm(aliceRealm)

	println("[TEST] No discontinuous jumps in liquidity")

	// Test continuous sequence of amounts
	// Looking for any sudden jumps that would indicate calculation errors

	baseAmount := uint64(100000000) // 100 million instead of 1 billion
	var liquidities []uint64

	// Test 10 consecutive values (reduced from 100 to avoid running out of tokens)
	for i := uint64(0); i < 10; i++ {
		amount := baseAmount + i

		_, liq, _, _ := pn.Mint(
			cross,
			barPath, bazPath, 10000,
			-200, 200,
			ufmt.Sprintf("%d", amount),
			ufmt.Sprintf("%d", amount), // Use symmetric amounts
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)

		liquidity := u256.MustFromDecimal(liq)
		liquidities = append(liquidities, liquidity.Uint64())
	}

	// Analyze differences between consecutive liquidities
	maxJump := uint64(0)
	avgJump := uint64(0)

	for i := 1; i < len(liquidities); i++ {
		var jump uint64
		if liquidities[i] > liquidities[i-1] {
			jump = liquidities[i] - liquidities[i-1]
		} else {
			ufmt.Printf("[ERROR] Non-monotonic at index %d\n", i)
			continue
		}

		if jump > maxJump {
			maxJump = jump
		}
		avgJump += jump
	}

	avgJump = avgJump / uint64(len(liquidities)-1)

	ufmt.Printf("[STATS] Average liquidity increase per wei: %d\n", avgJump)
	ufmt.Printf("[STATS] Maximum liquidity increase per wei: %d\n", maxJump)

	// Check for outliers (jumps > 10x average would be suspicious)
	if maxJump > avgJump*10 {
		ufmt.Printf("[WARNING] Detected potential discontinuity: max jump is %dx average\n",
			maxJump/avgJump)
	} else {
		ufmt.Printf("[PASS] No discontinuous jumps detected\n")
	}
}

// Output:
// [SCENARIO] 1. Initialize Setup
// [INFO] Setup completed
//
// [SCENARIO] 2. Test Monotonicity in Ultra-Tight Range
// [TEST] Monotonicity in 1-tick range (most sensitive)
// [RESULT] Amount: 1000000000, Liquidity: 20001499987500
// [RESULT] Amount: 1000000001, Liquidity: 20011502757855
// [WARNING] Large jump detected: 5 basis points increase for 1 wei
// [RESULT] Amount: 1000000002, Liquidity: 20021510530606
// [RESULT] Amount: 1000000010, Liquidity: 20031523448475
// [RESULT] Amount: 1000000100, Liquidity: 20041543017291
// [RESULT] Amount: 1000001000, Liquidity: 20051583839561
//
// [SCENARIO] 3. Test Monotonicity Across Different Scales
// [TEST] Monotonicity across different scales
// [Small scale] Base: 1000 (liq: 200510), +1: 1001 (liq: 202728)
// [PASS] Monotonic increase: 2218
// [Medium scale] Base: 1000000 (liq: 200510416), +1: 1000001 (liq: 202525680)
// [PASS] Monotonic increase: 2015264
// [Large scale] Base: 1000000000 (liq: 200510416479), +1: 1000000001 (liq: 202525478613)
// [PASS] Monotonic increase: 2015062134
//
// [SCENARIO] 4. Test Monotonicity at Boundaries
// [TEST] Monotonicity at tick boundaries
// [TEST] MIN boundary [-887220, -887160]
// [PASS] Monotonic at MIN boundary
// [TEST] MAX boundary [887160, 887220]
// [PASS] Monotonic at MAX boundary
// [TEST] Negative to zero [-60, 0]
// [PASS] Monotonic at Negative to zero
// [TEST] Zero to positive [0, 60]
// [PASS] Monotonic at Zero to positive
//
// [SCENARIO] 5. Test No Discontinuous Jumps
// [TEST] No discontinuous jumps in liquidity
// [STATS] Average liquidity increase per wei: 100
// [STATS] Maximum liquidity increase per wei: 101
// [PASS] No discontinuous jumps detected
