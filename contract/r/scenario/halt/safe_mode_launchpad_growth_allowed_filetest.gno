// Scenario: Safe Mode keeps launchpad growth paths available

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
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

var (
	t *testing.T
	adminAddr, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm       = testing.NewUserRealm(adminAddr)
	launchpadAddr, _ = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	userAddr         = testutils.TestAddress("launchpad-user")
)

func main() {
	println("[SCENARIO] 1. Set safe mode")
	setSafeMode()
	println()

	println("[SCENARIO] 2. CreateProject remains allowed")
	testCreateProjectAllowed()
	println()

	println("[SCENARIO] 3. DepositGns remains allowed")
	testDepositAllowed()
	println()
}

func setSafeMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelSafeMode)
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func testCreateProjectAllowed() {
	testing.SetRealm(adminRealm)
	obl.Approve(cross, launchpadAddr, 10000)
	launchpad.CreateProject(
		cross,
		"Safe Project",
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
	testing.SkipHeights(120960)
	ufmt.Println("[EXPECTED] create project succeeded in safe mode")
}

func testDepositAllowed() {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross, userAddr, 2_000_000)
	testing.SetRealm(testing.NewUserRealm(userAddr))
	gns.Approve(cross, launchpadAddr, 1_000_000)
	depositID := launchpad.DepositGns(cross, "gno.land/r/onbloc/obl:123:30", 1_000_000, "")
	ufmt.Printf("[EXPECTED] deposit succeeded in safe mode: %s\n", depositID)
}

// Output:
// [SCENARIO] 1. Set safe mode
// [INFO] Launchpad halted: false
// [INFO] Withdraw halted: true
//
// [SCENARIO] 2. CreateProject remains allowed
// [EXPECTED] create project succeeded in safe mode
//
// [SCENARIO] 3. DepositGns remains allowed
// [EXPECTED] deposit succeeded in safe mode: 1
