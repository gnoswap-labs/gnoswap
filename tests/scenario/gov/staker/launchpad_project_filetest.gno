// launchpad project scenario

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"
	lp "gno.land/r/gnoswap/v1/launchpad"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

var (
	admin       = consts.ADMIN
	adminRealm  = std.NewUserRealm(admin)
	aliceAddr   = testutils.TestAddress("alice")
	aliceRealm  = std.NewUserRealm(aliceAddr)
	projectAddr = testutils.TestAddress("projectAddr")
)

func main() {
	println("[SCENARIO] 1. Launchpad project creation fail cases")
	failCases()
	println()

	println("[SCENARIO] 2. Launchpad project creation success case")
	successCase()
	println()
}

func failCases() {
	// not admin
	rewardAmount := int64(1_000_000_000)
	startTime := uint64(time.Now().Unix() + 10)
	ufmt.Printf("[INFO] try create project as not admin\n")
	testing.SetRealm(aliceRealm)
	obl.Approve(cross, consts.LAUNCHPAD_ADDR, rewardAmount)
	uassert.AbortsWithMessage(t, "not admin", func() {
		lp.CreateProject(cross, "OBL Launchpad Project", "gno.land/r/onbloc/obl", projectAddr, uint64(rewardAmount), "gno.land/r/gnoswap/v1/gov/xgns", "1000000", 10, 20, 70, startTime)
	})

	// invalid name (empty)
	testing.SetRealm(adminRealm)
	obl.Approve(cross, consts.LAUNCHPAD_ADDR, rewardAmount)
	uassert.AbortsWithMessage(t, "invalid name (empty)", func() {
		lp.CreateProject(cross, "", "gno.land/r/onbloc/obl", projectAddr, uint64(rewardAmount), "gno.land/r/gnoswap/v1/gov/xgns", "1000000", 10, 20, 70, startTime)
	})
}

func successCase() {
	rewardAmount := int64(1_000_000_000)
	startTime := uint64(time.Now().Unix() + 10)
	testing.SetRealm(adminRealm)
	obl.Approve(cross, consts.LAUNCHPAD_ADDR, rewardAmount)
	projectId := lp.CreateProject(cross, "OBL Launchpad Project", "gno.land/r/onbloc/obl", projectAddr, uint64(rewardAmount), "gno.land/r/gnoswap/v1/gov/xgns", "1000000", 10, 20, 70, startTime)
	ufmt.Printf("[INFO] project created: %s\n", projectId)
}
