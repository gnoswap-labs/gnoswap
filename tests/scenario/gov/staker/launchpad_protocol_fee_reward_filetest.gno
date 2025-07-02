// launchpad protocol fee reward

package main

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/ufmt"
	"gno.land/p/gnoswap/consts"

	"gno.land/r/gnoswap/v1/gns"
	"gno.land/r/gnoswap/v1/gov/staker"
	lp "gno.land/r/gnoswap/v1/launchpad"
	pf "gno.land/r/gnoswap/v1/protocol_fee"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	admin        = consts.ADMIN
	adminRealm   = std.NewUserRealm(admin)
	bobAddr      = testutils.TestAddress("bob")
	bobRealm     = std.NewUserRealm(bobAddr)
	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = std.NewUserRealm(projectAddr)
	stakerRealm  = std.NewUserRealm(consts.STAKER_ADDR)

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

	println("[SCENARIO] 3. Check and collect protocol fee reward for bob")
	protocolFeeRewardBob()
	println()

	println("[SCENARIO] 4. Check and collect protocol fee reward for project recipient")
	protocolFeeRewardProjectRecipient()
	println()
}

func createLaunchpadProject() {
	rewardAmount := int64(1_000_000_000)
	startTime := uint64(time.Now().Unix() + 10)

	testing.SetRealm(adminRealm)
	bar.Approve(cross, consts.LAUNCHPAD_ADDR, rewardAmount)
	lp.CreateProject(
		cross,
		"Bar Launchpad Project",
		barPath,
		projectAddr,
		uint64(rewardAmount),
		barPath,
		"1000000",
		10,
		20,
		70,
		startTime,
	)

	testing.SkipHeights(10)
	ufmt.Printf("[INFO] skipped 10 blocks\n")

	testing.SetRealm(adminRealm)
	gns.Approve(cross, consts.LAUNCHPAD_ADDR, rewardAmount)
	lp.DepositGns(cross, "gno.land/r/onbloc/bar:123:30", uint64(rewardAmount), "")
}

func setupProtocolFeeDeposit() {
	// mock protocol fee deposit (bar, qux)
	testing.SetRealm(adminRealm)
	bar.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 1000)
	qux.Transfer(cross, consts.PROTOCOL_FEE_ADDR, 2500)

	testing.SetRealm(stakerRealm)
	pf.AddToProtocolFee(cross, barPath, 1000)
	pf.AddToProtocolFee(cross, quxPath, 2500)

	ufmt.Printf("[INFO] protocol fee deposited: bar(1000), qux(2500)\n")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	ufmt.Printf("[INFO] skipped 10 blocks\n")
}

func protocolFeeRewardBob() {
	gcr := staker.GetClaimableRewardByAddress(bobAddr)
	ufmt.Printf("[INFO] claimable reward (bob): %s\n", gcr)
	testing.SetRealm(bobRealm)
	staker.CollectReward(cross)
	ufmt.Printf("[INFO] collected protocol fee reward for bob\n")
}

func protocolFeeRewardProjectRecipient() {
	gcr := staker.GetClaimableRewardByAddress(projectAddr)
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
// [INFO] skipped 10 blocks
//
// [SCENARIO] 1. Setup protocol fee deposit (bar, qux)
// [INFO] protocol fee deposited: bar(1000), qux(2500)
//
// [SCENARIO] 2. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 3. Check and collect protocol fee reward for bob
// [INFO] claimable reward (bob):
// [INFO] collected protocol fee reward for bob
//
// [SCENARIO] 4. Check and collect protocol fee reward for project recipient
// [INFO] claimable reward (project recipient): {"height":"143","now":"1234567990","emissionReward":"0","protocolFees":[{"tokenPath":"gno.land/r/onbloc/bar","amount":"999"},{"tokenPath":"gno.land/r/onbloc/qux","amount":"2499"}]}
// [INFO] collected protocol fee reward for project recipient
// [EXPECTED] collected bar amount: 999
// [EXPECTED] collected qux amount: 2499
