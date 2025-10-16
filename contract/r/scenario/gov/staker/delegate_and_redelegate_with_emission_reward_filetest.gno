// delegate and redelegate with emission reward distribution

package main

import (
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/xgns"
	"gno.land/r/gnoswap/v1/gov/staker"
)

var t *testing.T

var (
	adminAddr, _ = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())

	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = testing.NewUserRealm(dummyAddr)

	reDelegate = testutils.TestAddress("reDelegate")
	minAmount  = int64(1_000_000)
)

func main() {
	println("[SCENARIO] 1. Check initial GNS/xGNS state")
	checkInitialState()
	println()

	println("[SCENARIO] 2. Admin delegates GNS to dummy")
	adminDelegateToDummy()
	println()

	println("[SCENARIO] 3. Admin redelegates from dummy to reDelegate")
	adminRedelegateDummyToReDelegate()
	println()
}

// Check initial GNS/xGNS state
func checkInitialState() {
	// check admin's initial GNS and xGNS balance
	ufmt.Printf("[INFO] admin GNS balance: %d\n", gns.BalanceOf(adminAddr))
	ufmt.Printf("[INFO] admin xGNS balance: %d\n", xgns.BalanceOf(adminAddr))
	ufmt.Printf("[EXPECTED] admin GNS: 100000000000000, xGNS: 0\n")
}

// Admin delegates GNS to dummy
func adminDelegateToDummy() {
	// delegate GNS from admin to dummy
	testing.SetRealm(adminRealm)
	gns.Approve(cross, govStakerAddr, minAmount)
	staker.Delegate(cross, dummyAddr, int64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", minAmount)
	ufmt.Printf("[EXPECTED] dummy delegated amount: %d\n", minAmount)
	ufmt.Printf("[EXPECTED] admin GNS: 99999999000000, xGNS: 1000000\n")
}

// Admin redelegates from dummy to reDelegate
func adminRedelegateDummyToReDelegate() {
	// redelegate from dummy to reDelegate
	testing.SetRealm(adminRealm)
	staker.Redelegate(cross, adminAddr, reDelegate, int64(minAmount))
	ufmt.Printf("[INFO] redelegated %d GNS from dummy to reDelegate\n", minAmount)
	ufmt.Printf("[EXPECTED] dummy delegated amount: 0, reDelegate delegated amount: %d\n", minAmount)
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
// [EXPECTED] admin GNS: 99999999000000, xGNS: 1000000
//
// [SCENARIO] 3. Admin redelegates from dummy to reDelegate
// [INFO] redelegated 1000000 GNS from dummy to reDelegate
// [EXPECTED] dummy delegated amount: 0, reDelegate delegated amount: 1000000
