// Scenario: Emergency Mode keeps launchpad settlement paths available

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	_ "gno.land/r/gnoswap/gov/staker/v1"
	"gno.land/r/gnoswap/halt"
	launchpad "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"
	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	"gno.land/r/onbloc/bar"
)

var (
	adminAddr, _       = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm         = testing.NewUserRealm(adminAddr)
	launchpadAddr, _   = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())
	stakerAddr, _      = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm        = testing.NewUserRealm(stakerAddr)
	govStakerAddr, _   = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm     = testing.NewUserRealm(govStakerAddr)
	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	projectAddr        = testutils.TestAddress("project-owner")
	projectRealm       = testing.NewUserRealm(projectAddr)
)

func main() {
	println("[SCENARIO] 1. Create project and deposit")
	createProjectAndDeposit()
	println()

	println("[SCENARIO] 2. Add and distribute protocol fee")
	setupProtocolFee()
	println()

	println("[SCENARIO] 3. Set emergency mode")
	setEmergencyMode()
	println()

	println("[SCENARIO] 4. Launchpad CollectProtocolFee remains allowed")
	collectProtocolFee()
	println()
}

func createProjectAndDeposit() {
	rewardAmount := int64(1000000000)
	startTime := int64(time.Now().Unix() + 604800)
	testing.SetRealm(adminRealm)
	bar.Approve(cross, launchpadAddr, rewardAmount)
	launchpad.CreateProject(cross, "Bar Project", "gno.land/r/onbloc/bar", projectAddr, rewardAmount, "gno.land/r/onbloc/bar", "1000000", 10, 20, 70, startTime)
	testing.SkipHeights(120960)
	gns.Approve(cross, launchpadAddr, rewardAmount)
	launchpad.DepositGns(cross, "gno.land/r/onbloc/bar:123:30", rewardAmount, "")
	ufmt.Println("[INFO] project created and deposit completed")
}

func setupProtocolFee() {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, stakerAddr, 1000)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross, protocolFeeAddr, 1000)
	pf.AddToProtocolFee(cross, "gno.land/r/onbloc/bar", 1000)
	testing.SkipHeights(10)
	testing.SetRealm(govStakerRealm)
	emission.MintAndDistributeGns(cross)
	pf.DistributeProtocolFee(cross)
	ufmt.Println("[INFO] protocol fee distributed")
}

func setEmergencyMode() {
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelEmergency)
	ufmt.Printf("[INFO] Launchpad halted: %t\n", halt.IsHaltedLaunchpad())
	ufmt.Printf("[INFO] Withdraw halted: %t\n", halt.IsHaltedWithdraw())
}

func collectProtocolFee() {
	testing.SetRealm(projectRealm)
	launchpad.CollectProtocolFee(cross)
	ufmt.Printf("[EXPECTED] project BAR balance after collect: %d\n", bar.BalanceOf(projectAddr))
}

// Output:
// [SCENARIO] 1. Create project and deposit
// [INFO] project created and deposit completed
//
// [SCENARIO] 2. Add and distribute protocol fee
// [INFO] protocol fee distributed
//
// [SCENARIO] 3. Set emergency mode
// [INFO] Launchpad halted: true
// [INFO] Withdraw halted: false
//
// [SCENARIO] 4. Launchpad CollectProtocolFee remains allowed
// [EXPECTED] project BAR balance after collect: 999
