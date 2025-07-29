// launchpad protocol fee reward

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"

	prbac "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	lp "gno.land/r/gnoswap/v1/launchpad"
	pf "gno.land/r/gnoswap/v1/protocol_fee"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	admin, _     = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm   = std.NewUserRealm(admin)

	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm  = std.NewUserRealm(stakerAddr)

	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr, _  = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = std.NewUserRealm(projectAddr)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func main() {
	println("[SCENARIO] 1. Create launchpad project and deposit")
	createLaunchpadProject()
	println()

	println("[SCENARIO] 1. Setup protocol fee deposit (bar, qux)")
	setupProtocolFeeDeposit()
	println()

	println("[SCENARIO] 2. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 3. Check and collect protocol fee reward for project recipient")
	protocolFeeRewardProjectRecipient()
	println()
}

func createLaunchpadProject() {
	rewardAmount := int64(1_000_000_000)
	startTime := int64(time.Now().Unix() + 3600) // 1 hour

	testing.SetRealm(adminRealm)
	bar.Approve(cross, launchpadAddr, rewardAmount)
	lp.CreateProject(
		cross,
		"Bar Launchpad Project",
		barPath,
		projectAddr,
		int64(rewardAmount),
		barPath,
		"1000000",
		10,
		20,
		70,
		startTime,
	)

	testing.SkipHeights(3600)
	ufmt.Printf("[INFO] skipped 3600 blocks\n")

	testing.SetRealm(adminRealm)
	gns.Approve(cross, launchpadAddr, rewardAmount)
	lp.DepositGns(cross, "gno.land/r/onbloc/bar:123:30", int64(rewardAmount), "")
}

func setupProtocolFeeDeposit() {
	// mock protocol fee deposit (bar, qux)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, protocolFeeAddr, 1000)
	qux.Transfer(cross, protocolFeeAddr, 2500)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)

	ufmt.Printf("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	ufmt.Printf("[INFO] skipped 10 blocks\n")
}

func protocolFeeRewardProjectRecipient() {
	gcr := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): %s\n", gcr)
	testing.SetRealm(projectRealm)

	prevBarBalance := bar.BalanceOf(projectAddr)
	prevQuxBalance := qux.BalanceOf(projectAddr)

	lp.CollectProtocolFee(cross)

	afterBarBalance := bar.BalanceOf(projectAddr)
	afterQuxBalance := qux.BalanceOf(projectAddr)

	ufmt.Printf("[INFO] collected protocol fee reward for project recipient\n")
	ufmt.Printf("[EXPECTED] collected bar amount: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[EXPECTED] collected qux amount: %d\n", afterQuxBalance-prevQuxBalance)
}

// Output:
// [SCENARIO] 1. Create launchpad project and deposit
// [INFO] skipped 3600 blocks
//
// [SCENARIO] 1. Setup protocol fee deposit (bar, qux)
// [INFO] protocol fee deposited: bar(1000), qux(2500)
//
// [SCENARIO] 2. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 3. Check and collect protocol fee reward for project recipient
// [INFO] claimable reward (project recipient): {"height":"3733","now":"1234585940","emissionReward":"0","protocolFees":[{"tokenPath":"gno.land/r/onbloc/bar","amount":"999"},{"tokenPath":"gno.land/r/onbloc/qux","amount":"2499"}]}
// [INFO] collected protocol fee reward for project recipient
// [EXPECTED] collected bar amount: 999
// [EXPECTED] collected qux amount: 2499
