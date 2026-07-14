// PKGPATH: gno.land/r/gnoswap/v1/main

// Test partial collection with multiple undelegations at different times

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

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

func main(cur realm) {
	println("[SCENARIO] Test partial collection with multiple undelegations")
	println()

	println("[STEP 1] Setup - Transfer GNS to alice")
	setupGNS(cur)
	println()

	println("[STEP 2] Alice delegates to validator")
	delegateToValidator(cur)
	println()

	println("[STEP 3] Alice undelegates 3M GNS (first)")
	undelegateFirst(cur)
	println()

	println("[STEP 4] Wait 1 hour and undelegate 3M GNS (second)")
	testing.SkipHeights(720) // 1 hour = 3600 seconds / 5 = 720 blocks
	undelegateSecond(cur)
	println()

	println("[STEP 5] Wait 1 hour and undelegate 4M GNS (third)")
	testing.SkipHeights(720) // 1 hour = 720 blocks
	undelegateThird(cur)
	println()

	println("[STEP 6] Wait 7 days from first undelegate and collect")
	testing.SkipHeights(119520) // 7 days from first undelegate (120960 - 1440 = 119520)
	collectFirst(cur)
	println()

	println("[STEP 7] Wait 1 hour and collect second batch")
	testing.SkipHeights(720) // 7 days from second undelegate
	collectSecond(cur)
	println()

	println("[STEP 8] Wait 1 hour and collect third batch")
	testing.SkipHeights(720) // 7 days from third undelegate
	collectThird(cur)
	println()

	println("[SCENARIO] Complete - Partial collection verified")
}

func setupGNS(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, minAmount*12)
	ufmt.Printf("[INFO] Transferred %d GNS to alice\n", minAmount*12)
}

func delegateToValidator(cur realm) {
	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, minAmount*10)
	staker.Delegate(cross(cur), validatorAddr, minAmount*10, "")
	ufmt.Printf("[INFO] Alice delegated %d GNS to validator\n", minAmount*10)
}

func undelegateFirst(cur realm) {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross(cur), validatorAddr, minAmount*3)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (first batch)\n", minAmount*3)
}

func undelegateSecond(cur realm) {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross(cur), validatorAddr, minAmount*3)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (second batch)\n", minAmount*3)
}

func undelegateThird(cur realm) {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross(cur), validatorAddr, minAmount*4)
	ufmt.Printf("[INFO] Alice undelegated %d GNS (third batch)\n", minAmount*4)
}

func collectFirst(cur realm) {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross(cur))
	ufmt.Printf("[EXPECTED] Alice collected %d GNS (first batch only)\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance: %d\n", balance)
}

func collectSecond(cur realm) {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross(cur))
	ufmt.Printf("[EXPECTED] Alice collected %d GNS (second batch)\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance: %d\n", balance)
}

func collectThird(cur realm) {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross(cur))
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
// [STEP 6] Wait 7 days from first undelegate and collect
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
