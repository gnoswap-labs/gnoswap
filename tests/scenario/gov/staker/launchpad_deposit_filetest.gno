// launchpad deposit scenario

package main

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"
	lp "gno.land/r/gnoswap/v1/launchpad"
)

var t *testing.T

var (
	admin      = consts.ADMIN
	adminRealm = std.NewUserRealm(admin)
	bobAddr    = testutils.TestAddress("bob")
	bobRealm   = std.NewUserRealm(bobAddr)
)

func main() {
	println("[SCENARIO] 1. Launchpad deposit fail cases")
	failCases()
	println()

	println("[SCENARIO] 2. Launchpad deposit success case")
	successCase()
	println()
}

func failCases() {
	projectTier30Id := "gno.land/r/onbloc/obl:130:30"
	// invalid amount (less than minimum)
	ufmt.Printf("[INFO] try deposit less than minimum\n")
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, 100_000)
	testing.SetRealm(bobRealm)
	gns.Approve(cross, consts.LAUNCHPAD_ADDR, 100_000)

	lp.DepositGns(cross, projectTier30Id, 100_000, "")
}

func successCase() {
	depositAmount := int64(1_000_000)
	projectTier30Id := "gno.land/r/onbloc/obl:130:30"
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, bobAddr, depositAmount)
	testing.SetRealm(bobRealm)
	gns.Approve(cross, consts.LAUNCHPAD_ADDR, depositAmount)
	depositId := lp.DepositGns(cross, projectTier30Id, uint64(depositAmount), "")
	ufmt.Printf("[INFO] deposit success: %s\n", depositId)
}
