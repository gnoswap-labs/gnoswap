// delegate and redelegate with emission reward distribution

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	"gno.land/r/gnoswap/v1/gov/xgns"
)

var t *testing.T

var (
	admin      = consts.ADMIN
	adminRealm = std.NewUserRealm(admin)
	dummyAddr  = testutils.TestAddress("dummy")
	dummyRealm = std.NewUserRealm(dummyAddr)
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
	ufmt.Printf("[INFO] admin GNS balance: %d\n", gns.BalanceOf(admin))
	ufmt.Printf("[INFO] admin xGNS balance: %d\n", xgns.BalanceOf(admin))
	ufmt.Printf("[EXPECTED] admin GNS: 100000000000000, xGNS: 0\n")
}

// Admin delegates GNS to dummy
func adminDelegateToDummy() {
	// delegate GNS from admin to dummy
	testing.SetRealm(adminRealm)
	gns.Approve(cross, consts.GOV_STAKER_ADDR, minAmount)
	staker.Delegate(cross, dummyAddr, uint64(minAmount), "")
	ufmt.Printf("[INFO] delegated %d GNS from admin to dummy\n", minAmount)
	ufmt.Printf("[EXPECTED] dummy delegated amount: %d\n", minAmount)
	ufmt.Printf("[EXPECTED] admin GNS: 99999999000000, xGNS: 1000000\n")
}

// Admin redelegates from dummy to reDelegate
func adminRedelegateDummyToReDelegate() {
	// redelegate from dummy to reDelegate
	testing.SetRealm(adminRealm)
	staker.Redelegate(cross, dummyAddr, reDelegate, uint64(minAmount))
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
