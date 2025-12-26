// Test partial collection with multiple undelegations at different times

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	admin, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	validatorAddr = testutils.TestAddress("validator1")

	minAmount = int64(1_000_000)
)

func main() {
	println("[SCENARIO] Test partial collection with multiple undelegations")
	println()

	println("[STEP 1] Setup - Transfer GNS to alice")
	setupGNS()
	println()

	println("[STEP 2] Alice delegates to validator")
	delegateToValidator()
	println()

	println("[STEP 3] Alice undelegates 3M GNS (first)")
	undelegateFirst()
	println()

	println("[STEP 4] Wait 1 hour and undelegate 3M GNS (second)")
	testing.SkipHeights(720) // 1 hour = 3600 seconds / 5 = 720 blocks
	undelegateSecond()
	println()

	println("[STEP 5] Wait 1 hour and undelegate 4M GNS (third)")
	testing.SkipHeights(720) // 1 hour = 720 blocks
	undelegateThird()
	println()

	println("[STEP 6] Wait 1 day from first undelegate and collect")
	testing.SkipHeights(15840) // Skip 15840 blocks to reach 1 day from first undelegate (17280 - 1440 = 15840)
	collectFirst()
	println()

	println("[STEP 7] Wait 1 hour and collect second batch")
	testing.SkipHeights(720) // Skip 720 more blocks to reach 1 day from second undelegate
	collectSecond()
	println()

	println("[STEP 8] Wait 1 hour and collect third batch")
	testing.SkipHeights(720) // Skip 720 more blocks to reach 1 day from third undelegate
	collectThird()
	println()

	println("[SCENARIO] Complete - Partial collection verified")
}

func setupGNS() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, aliceAddr, minAmount*12)
	ufmt.Printf("[INFO] Transferred %d GNS to alice\n", minAmount*12)
}

func delegateToValidator() {
	testing.SetRealm(aliceRealm)
	gns.Approve(cross, govStakerAddr, minAmount*10)
	staker.Delegate(cross, validatorAddr, minAmount*10, "")
	ufmt.Printf("[INFO] Alice delegated %d GNS to validator\n", minAmount*10)
}

func undelegateFirst() {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross, validatorAddr, minAmount*3)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (first batch)\n", minAmount*3)
}

func undelegateSecond() {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross, validatorAddr, minAmount*3)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (second batch)\n", minAmount*3)
}

func undelegateThird() {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross, validatorAddr, minAmount*4)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (third batch)\n", minAmount*4)
}

func collectFirst() {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross)
	ufmt.Printf("[EXPECTED] Alice collected %d GNS (first batch only)\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance: %d\n", balance)
}

func collectSecond() {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross)
	ufmt.Printf("[EXPECTED] Alice collected %d GNS (second batch)\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance: %d\n", balance)
}

func collectThird() {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross)
	ufmt.Printf("[EXPECTED] Alice collected %d GNS (third batch)\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance: %d\n", balance)
}

// Output:
// [SCENARIO] Test partial collection with multiple undelegations
//
// [STEP 1] Setup - Transfer GNS to alice
// [INFO] Transferred 12000000 GNS to alice
//
// [STEP 2] Alice delegates to validator
// [INFO] Alice delegated 10000000 GNS to validator
//
// [STEP 3] Alice undelegates 3M GNS (first)
// [INFO] Alice undelegated 3000000 GNS (first batch)
//
// [STEP 4] Wait 1 hour and undelegate 3M GNS (second)
// [INFO] Alice undelegated 3000000 GNS (second batch)
//
// [STEP 5] Wait 1 hour and undelegate 4M GNS (third)
// [INFO] Alice undelegated 4000000 GNS (third batch)
//
// [STEP 6] Wait 1 day from first undelegate and collect
// [EXPECTED] Alice collected 3000000 GNS (first batch only)
// [EXPECTED] Alice's GNS balance: 5000000
//
// [STEP 7] Wait 1 hour and collect second batch
// [EXPECTED] Alice collected 3000000 GNS (second batch)
// [EXPECTED] Alice's GNS balance: 8000000
//
// [STEP 8] Wait 1 hour and collect third batch
// [EXPECTED] Alice collected 4000000 GNS (third batch)
// [EXPECTED] Alice's GNS balance: 12000000
//
// [SCENARIO] Complete - Partial collection verified
