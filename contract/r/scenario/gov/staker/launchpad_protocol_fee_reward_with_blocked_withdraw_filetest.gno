// PKGPATH: gno.land/r/gnoswap/v1/main

// launchpad protocol fee reward

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/protocol_fee"
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
	t *testing.T

	admin, _   = access.GetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	stakerAddr, _ = access.GetAddress(prbac.ROLE_STAKER.String())
	stakerRealm   = testing.NewUserRealm(stakerAddr)

	protocolFeeAddr, _ = access.GetAddress(prbac.ROLE_PROTOCOL_FEE.String())
	protocolFeeV1Realm = testing.NewCodeRealm("gno.land/r/gnoswap/protocol_fee/v1")
	launchpadAddr, _   = access.GetAddress(prbac.ROLE_LAUNCHPAD.String())

	govStakerAddr, _ = access.GetAddress(prbac.ROLE_GOV_STAKER.String())
	govStakerRealm   = testing.NewUserRealm(govStakerAddr)

	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = testing.NewUserRealm(projectAddr)

	barPath = "gno.land/r/onbloc/bar"
	quxPath = "gno.land/r/onbloc/qux"
)

func fundAndApproveProtocolFeeCallerBar(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	bar.Transfer(cross(cur), stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, amount)
	bar.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
}

func fundAndApproveProtocolFeeCallerQux(cur realm, amount int64) {
	testing.SetRealm(adminRealm)
	qux.Transfer(cross(cur), stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	qux.Approve(cross(cur), protocolFeeAddr, amount)
	qux.Approve(cross(cur), protocolFeeV1Realm.Address(), amount)
}

func main(cur realm) {
	println("[SCENARIO] 1. Create launchpad project and deposit")
	createLaunchpadProject(cur)
	println()

	println("[SCENARIO] 2. Setup protocol fee deposit (bar, qux)")
	setupProtocolFeeDeposit(cur)
	println()

	println("[SCENARIO] 3. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute(cur)
	println()

	println("[SCENARIO] 4. Check and collect protocol fee reward for project recipient")
	protocolFeeRewardProjectRecipient(cur)
	println()

	println("[SCENARIO] 5. Block withdraw and check claimable reward")
	checkBlockedWithLaunchpadCollectDepositGns(cur)
	println()
}

func createLaunchpadProject(cur realm) {
	rewardAmount := int64(1_000_000_000)
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), launchpadAddr, rewardAmount)
	lp.CreateProject(
		cross(cur),
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
	gns.Approve(cross(cur), launchpadAddr, rewardAmount)
	depositID := lp.DepositGns(cross(cur), "gno.land/r/onbloc/bar:123:30", int64(rewardAmount), "")
	ufmt.Printf("[INFO] deposited launchpad deposit: %s\n", depositID)
}

func setupProtocolFeeDeposit(cur realm) {
	// mock protocol fee deposit (bar, qux)
	fundAndApproveProtocolFeeCallerBar(cur, 1000)
	fundAndApproveProtocolFeeCallerQux(cur, 2500)
	testing.SetRealm(stakerRealm)
	bar.Approve(cross(cur), protocolFeeAddr, 1000)
	qux.Approve(cross(cur), protocolFeeAddr, 2500)
	pf.AddToProtocolFee(cross(cur), barPath, 1000)
	pf.AddToProtocolFee(cross(cur), quxPath, 2500)

	println("[INFO] protocol fee deposited: bar(1000), qux(2500)")
}

func skipBlocksAndDistribute(cur realm) {
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks")
}

func formatProtocolFees(cur realm, fees map[string]int64) string {
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

func protocolFeeRewardProjectRecipient(cur realm) {
	testing.SetRealm(govStakerRealm)
	emission.MintAndDistributeGns(cross(cur))
	protocol_fee.DistributeProtocolFee(cross(cur))
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(cur, protocolFees))

	testing.SetRealm(projectRealm)
	prevBarBalance := bar.BalanceOf(projectAddr)
	prevQuxBalance := qux.BalanceOf(projectAddr)

	lp.CollectProtocolFee(cross(cur))

	afterBarBalance := bar.BalanceOf(projectAddr)
	afterQuxBalance := qux.BalanceOf(projectAddr)

	println("[INFO] collected protocol fee reward for project recipient")
	ufmt.Printf("[EXPECTED] collected bar amount: %d\n", afterBarBalance-prevBarBalance)
	ufmt.Printf("[EXPECTED] collected qux amount: %d\n", afterQuxBalance-prevQuxBalance)
}

func checkBlockedWithLaunchpadCollectDepositGns(cur realm) {
	testing.SetRealm(adminRealm)
	uassert.AbortsContains(t, cur, "[GNOSWAP-LAUNCHPAD-011] invalid reward state", func() {
		lp.CollectDepositGns(cross(cur), "1")
	})
	println("[INFO] blocked launchpad collect deposit gns by not yet ended project")
}

// Output:
// [SCENARIO] 1. Create launchpad project and deposit
// [INFO] skipped 120960 blocks
// [INFO] deposited launchpad deposit: 1
//
// [SCENARIO] 2. Setup protocol fee deposit (bar, qux)
// [INFO] protocol fee deposited: bar(1000), qux(2500)
//
// [SCENARIO] 3. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 4. Check and collect protocol fee reward for project recipient
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/onbloc/bar:999 gno.land/r/onbloc/qux:2499]
// [INFO] collected protocol fee reward for project recipient
// [EXPECTED] collected bar amount: 999
// [EXPECTED] collected qux amount: 2499
//
// [SCENARIO] 5. Block withdraw and check claimable reward
// [INFO] blocked launchpad collect deposit gns by not yet ended project
