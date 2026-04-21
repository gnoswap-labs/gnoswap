// Scenario: Emergency Mode blocks launchpad growth paths

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	"gno.land/r/onbloc/obl"
)

var t *testing.T

var (
	adminAddr, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm       = testing.NewUserRealm(adminAddr)
	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	userAddr         = testutils.TestAddress("launchpad-user")
)

func main() {
	println("[SCENARIO] 1. Set emergency mode")
	setEmergencyMode()
	println()

	println("[SCENARIO] 2. CreateProject is blocked")
	testCreateProjectBlocked()
	println()

	println("[SCENARIO] 3. DepositGns is blocked")
	testDepositBlocked()
	println()
}

func setEmergencyMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testCreateProjectBlocked() {
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, 10000)
	uassert.AbortsContains(t, "halted: launchpad", func() {
		launchpad.CreateProject(
			cross,
			"Halt Project",
			"gno.land/r/onbloc/obl",
			testutils.TestAddress("recipient"),
			10000,
			"",
			"",
			30,
			30,
			40,
			time.Now().Unix()+604800,
		)
	})
	ufmt.Println("[EXPECTED] create project blocked by launchpad halt")
}

func testDepositBlocked() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 2_000_000)
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, 1_000_000)
	uassert.AbortsContains(t, "halted: launchpad", func() {
		launchpad.DepositGns(cross, "gno.land/r/onbloc/obl:123:30", 1_000_000, "")
	})
	ufmt.Println("[EXPECTED] deposit blocked by launchpad halt")
}

// Output:
// [SCENARIO] 1. Set emergency mode
// [INFO] Launchpad halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 2. CreateProject is blocked
// [EXPECTED] create project blocked by launchpad halt
//
// [SCENARIO] 3. DepositGns is blocked
// [EXPECTED] deposit blocked by launchpad halt
