// delegate and redelegate with emission reward distribution

package main

import (
	"testing"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var t *testing.T

var (
	adminAddr  = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(adminAddr)

	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	dummyAddr       = testutils.TestAddress("dummy")
	reDelegateAddr  = testutils.TestAddress("reDelegate")
	thirdDelegatee  = testutils.TestAddress("thirdDelegatee")
	minAmount       = int64(1_000_000)
)

func main() {
	println("[SCENARIO] 1. Check initial GNS/xGNS state")
	checkInitialState()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummy")
	adminDelegateToDummy()
	println()

	println("[SCENARIO] 3. Admin redelegates from dummy to reDelegate")
	adminRedelegate(dummyAddr, reDelegateAddr)
	println()

	println("[SCENARIO] 4. Admin redelegates from reDelegate to thirdDelegatee")
	adminRedelegate(reDelegateAddr, thirdDelegatee)
	println()

	println("[SCENARIO] 5. Admin redelegates from thirdDelegatee back to dummy")
	adminRedelegate(thirdDelegatee, dummyAddr)
	println()
}

// Check initial GNS/xGNS state
func checkInitialState() {
	// check admin's initial GNS and xGNS balance
	ufmt.Printf("[INFO] admin GNS balance: %d\n", gns.BalanceOf(adminAddr))
	ufmt.Printf("[INFO] admin xGNS balance: %d\n", xgns.BalanceOf(adminAddr))
	println("[EXPECTED] admin GNS: 100000000000000, xGNS: 0")
}

// Admin delegates GNS to dummy
func adminDelegateToDummy() {
	// delegate GNS from admin to dummy
	testing.SetRealm(adminRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, dummyAddr, int64(minAmount), "")
	totalLockedAmount := staker.GetTotalLockedAmount()
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", minAmount)
	ufmt.Printf("[EXPECTED] dummy delegated amount: %d\n", minAmount)
	ufmt.Printf("[EXPECTED] total locked amount after delegate: %d\n", totalLockedAmount)
	println("[EXPECTED] admin GNS: 99999999000000, xGNS: 1000000")
}

// Admin redelegates from one delegatee to another.
func adminRedelegate(from, to address) {
	testing.SetRealm(adminRealm)
	staker.Redelegate(cross, from, to, int64(minAmount))
	totalLockedAmount := staker.GetTotalLockedAmount()
	ufmt.Printf("[INFO] redelegated %d GNS from %s to %s\n", minAmount, from.String(), to.String())
	ufmt.Printf("[EXPECTED] total locked amount after redelegate from %s to %s: %d\n", from.String(), to.String(), totalLockedAmount)
}

// Output:
// [SCENARIO] 1. Check initial GNS/xGNS state
// [INFO] admin GNS balance: 100000000000000
// [INFO] admin xGNS balance: 0
// [EXPECTED] admin GNS: 100000000000000, xGNS: 0
//
// [SCENARIO] 2. Admin delegates GNS to dummy
// [INFO] delegated 1000000 GNS from admin to dummy
// [EXPECTED] dummy delegated amount: 1000000
// [EXPECTED] total locked amount after delegate: 1000000
// [EXPECTED] admin GNS: 99999999000000, xGNS: 1000000
//
// [SCENARIO] 3. Admin redelegates from dummy to reDelegate
// [INFO] redelegated 1000000 GNS from g1v36k6mteta047h6lta047h6lta047h6lz7gmv8 to g1wfj5getvv4nkzar9ta047h6lta047h6lycyuqt
// [EXPECTED] total locked amount after redelegate from g1v36k6mteta047h6lta047h6lta047h6lz7gmv8 to g1wfj5getvv4nkzar9ta047h6lta047h6lycyuqt: 1000000
//
// [SCENARIO] 4. Admin redelegates from reDelegate to thirdDelegatee
// [INFO] redelegated 1000000 GNS from g1wfj5getvv4nkzar9ta047h6lta047h6lycyuqt to g1w35xjunyg3jkcet8v96x2e2lta047h6llvhxz3
// [EXPECTED] total locked amount after redelegate from g1wfj5getvv4nkzar9ta047h6lta047h6lycyuqt to g1w35xjunyg3jkcet8v96x2e2lta047h6llvhxz3: 1000000
//
// [SCENARIO] 5. Admin redelegates from thirdDelegatee back to dummy
// [INFO] redelegated 1000000 GNS from g1w35xjunyg3jkcet8v96x2e2lta047h6llvhxz3 to g1v36k6mteta047h6lta047h6lta047h6lz7gmv8
// [EXPECTED] total locked amount after redelegate from g1w35xjunyg3jkcet8v96x2e2lta047h6llvhxz3 to g1v36k6mteta047h6lta047h6lta047h6lz7gmv8: 1000000
