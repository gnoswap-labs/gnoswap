// launchpad protocol fee reward

package main

import (
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/ufmt"

	prbac "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	pf "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"

	"gno.land/r/gnoswap/gov/staker"

	_ "gno.land/r/gnoswap/gov/staker/v1"

	lp "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	admin, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm   = testing.NewUserRealm(stakerAddr)

	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	launchpadAddr, _   = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm   = testing.NewUserRealm(govStakerAddr)

	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = testing.NewUserRealm(projectAddr)

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
	startTime := int64(time.Now().Unix() + 604800) // 7 days

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

	testing.SkipHeights(120960)
	ufmt.Printf("[INFO] skipped 120960 blocks\n")

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

	println("[INFO] protocol fee deposited: bar(1000), qux(2500)")
}

func skipBlocksAndDistribute() {
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks")
}

func formatProtocolFees(fees map[string]int64) string {
	if len(fees) == 0 {
		return "map[]"
	}
	result := "map["
	first := true
	for k, v := range fees {
		if !first {
			result += " "
		}
		result += k + ":" + ufmt.Sprintf("%d", v)
		first = false
	}
	result += "]"
	return result
}

func protocolFeeRewardProjectRecipient() {
	testing.SetRealm(govStakerRealm)
	emissionReward, protocolFees := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(protocolFees))

	testing.SetRealm(projectRealm)
	prevBarBalance := bar.BalanceOf(projectAddr)
	prevQuxBalance := qux.BalanceOf(projectAddr)

	lp.CollectProtocolFee(cross)

	afterBarBalance := bar.BalanceOf(projectAddr)
	afterQuxBalance := qux.BalanceOf(projectAddr)

	println("[INFO] collected protocol fee reward for project recipient")
	ufmt.Printf("[EXPECTED] collected bar amount: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[EXPECTED] collected qux amount: %d\n", afterQuxBalance-prevQuxBalance)
}

// Output:
// [SCENARIO] 1. Create launchpad project and deposit
// [INFO] skipped 120960 blocks
//
// [SCENARIO] 1. Setup protocol fee deposit (bar, qux)
// [INFO] protocol fee deposited: bar(1000), qux(2500)
//
// [SCENARIO] 2. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 3. Check and collect protocol fee reward for project recipient
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:999 gno.land/r/onbloc/qux:2499]
// [INFO] collected protocol fee reward for project recipient
// [EXPECTED] collected bar amount: 999
// [EXPECTED] collected qux amount: 2499
