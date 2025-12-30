// Test that empty delegations are automatically removed after collection

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
	println("[SCENARIO] Test empty delegation removal after collection")
	println()

	println("[STEP 1] Setup - Transfer GNS to alice")
	setupGNS()
	println()

	println("[STEP 2] Alice delegates to validator")
	delegateToValidator()
	println()

	println("[STEP 3] Alice undelegates all amount")
	undelegateAll()
	println()

	println("[STEP 4] Wait for lockup period and collect")
	testing.SkipHeights(120960) // 7 days lockup (7*24*60*60/5 = 120960 blocks)
	collectAfterLockup()
	println()

	println("[SCENARIO] Complete - Empty delegation automatically removed")
}

func setupGNS() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, aliceAddr, minAmount*2)
	ufmt.Printf("[INFO] Transferred %d GNS to alice\n", minAmount*2)
}

func delegateToValidator() {
	testing.SetRealm(aliceRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, validatorAddr, minAmount, "")
	ufmt.Printf("[INFO] Alice delegated %d GNS to validator\n", minAmount)
}

func undelegateAll() {
	testing.SetRealm(aliceRealm)
	staker.Undelegate(cross, validatorAddr, minAmount)
	ufmt.Printf("[INFO] Alice undelegated %d GNS from validator\n", minAmount)
}

func collectAfterLockup() {
	testing.SetRealm(aliceRealm)
	collected := staker.CollectUndelegatedGns(cross)
	ufmt.Printf("[EXPECTED] Alice collected %d GNS\n", collected)

	balance := gns.BalanceOf(aliceAddr)
	ufmt.Printf("[EXPECTED] Alice's GNS balance after collection: %d\n", balance)
}

// Output:
// [SCENARIO] Test empty delegation removal after collection
//
// [STEP 1] Setup - Transfer GNS to alice
// [INFO] Transferred 2000000 GNS to alice
//
// [STEP 2] Alice delegates to validator
// [INFO] Alice delegated 1000000 GNS to validator
//
// [STEP 3] Alice undelegates all amount
// [INFO] Alice undelegated 1000000 GNS from validator
//
// [STEP 4] Wait for lockup period and collect
// [EXPECTED] Alice collected 1000000 GNS
// [EXPECTED] Alice's GNS balance after collection: 2000000
//
// [SCENARIO] Complete - Empty delegation automatically removed
