// verify symmetric liquidity test - checking if capital efficiency issue is real

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

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"
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
	println("[TEST] Verifying Symmetric Liquidity Behavior")
	println()

	// Setup
	testing.SetRealm(adminRealm)
	pool.SetPoolCreationFee(cross, 0)

	// Create pool
	pool.CreatePool(
		cross,
		barPath,
		bazPath,
		500, // 0.05% fee
		common.TickMathGetSqrtRatioAtTick(0).ToString(),
	)

	// Give Alice tokens
	largeAmount := int64(10_000_000_000_000) // 1e13
	bar.Transfer(cross, aliceAddr, largeAmount)
	baz.Transfer(cross, aliceAddr, largeAmount)

	testing.SetRealm(aliceRealm)
	bar.Approve(cross, poolAddr, largeAmount)
	baz.Approve(cross, poolAddr, largeAmount)
	bar.Approve(cross, positionAddr, largeAmount)
	baz.Approve(cross, positionAddr, largeAmount)

	// Test 1: ASYMMETRIC amounts (reproducing the "issue")
	println("[CASE 1] Asymmetric Amounts (1e12 vs 1e6)")
	_, liq1, amt0_1, amt1_1 := pn.Mint(
		cross,
		barPath, bazPath, 500,
		-10, 10,
		"1000000000000", // 1e12 for token0
		"1000000",       // 1e6 for token1 (limiting factor!)
		"0", "0",
		9999999999,
		aliceAddr, aliceAddr, "",
	)
	ufmt.Printf("  Requested: token0=1e12, token1=1e6\n")
	ufmt.Printf("  Used: token0=%s, token1=%s\n", amt0_1, amt1_1)
	ufmt.Printf("  Liquidity: %s\n", liq1)
	ufmt.Printf("  Result: Limited by smaller token1 amount\n")
	println()

	// Test 2: SYMMETRIC amounts (the real test)
	println("[CASE 2] Symmetric Amounts (1e12 vs 1e12)")
	_, liq2, amt0_2, amt1_2 := pn.Mint(
		cross,
		barPath, bazPath, 500,
		-20, 20,
		"1000000000000", // 1e12 for token0
		"1000000000000", // 1e12 for token1 (SAME!)
		"0", "0",
		9999999999,
		aliceAddr, aliceAddr, "",
	)
	ufmt.Printf("  Requested: token0=1e12, token1=1e12\n")
	ufmt.Printf("  Used: token0=%s, token1=%s\n", amt0_2, amt1_2)
	ufmt.Printf("  Liquidity: %s\n", liq2)
	ufmt.Printf("  Result: Both tokens fully utilized\n")
	println()

	// Test 3: Very narrow range with symmetric amounts
	println("[CASE 3] Ultra-Narrow Range (1 tick) with Symmetric 1e10")
	_, liq3, amt0_3, amt1_3 := pn.Mint(
		cross,
		barPath, bazPath, 500,
		0, 10, // Just 10 ticks!
		"10000000000", // 1e10
		"10000000000", // 1e10
		"0", "0",
		9999999999,
		aliceAddr, aliceAddr, "",
	)
	ufmt.Printf("  Requested: token0=1e10, token1=1e10\n")
	ufmt.Printf("  Used: token0=%s, token1=%s\n", amt0_3, amt1_3)
	ufmt.Printf("  Liquidity: %s\n", liq3)
	println()

	// Test 4: Check actual limits
	println("[CASE 4] Finding Actual Limits")
	ranges := []struct {
		lower, upper int32
		desc         string
	}{
		{-10, 10, "20 ticks"},
		{-50, 50, "100 ticks"},
		{-100, 100, "200 ticks"},
		{-500, 500, "1000 ticks"},
	}

	for _, r := range ranges {
		_, liq, amt0, amt1 := pn.Mint(
			cross,
			barPath, bazPath, 500,
			r.lower, r.upper,
			"1000000000000", // 1e12
			"1000000000000", // 1e12
			"0", "0",
			9999999999,
			aliceAddr, aliceAddr, "",
		)
		ufmt.Printf("  Range %s: Used %s/%s, Liquidity %s\n",
			r.desc, amt0, amt1, liq)
	}
}

// Output:
// [TEST] Verifying Symmetric Liquidity Behavior
//
// [CASE 1] Asymmetric Amounts (1e12 vs 1e6)
//   Requested: token0=1e12, token1=1e6
//   Used: token0=1000000, token1=1000000
//   Liquidity: 2000600039
//   Result: Limited by smaller token1 amount
//
// [CASE 2] Symmetric Amounts (1e12 vs 1e12)
//   Requested: token0=1e12, token1=1e12
//   Used: token0=1000000000000, token1=1000000000000
//   Liquidity: 1000550082495873
//   Result: Both tokens fully utilized
//
// [CASE 3] Ultra-Narrow Range (1 tick) with Symmetric 1e10
//   Requested: token0=1e10, token1=1e10
//   Used: token0=10000000000, token1=0
//   Liquidity: 20006000399979
//
// [CASE 4] Finding Actual Limits
//   Range 20 ticks: Used 1000000000000/1000000000000, Liquidity 2000600039997999
//   Range 100 ticks: Used 1000000000000/1000000000000, Liquidity 400520207989578
//   Range 200 ticks: Used 1000000000000/1000000000000, Liquidity 200510416479002
//   Range 1000 ticks: Used 1000000000000/1000000000000, Liquidity 40504083174144
