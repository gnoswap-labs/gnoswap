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
	"gno.land/r/gnoswap/test_token/atom"
	"gno.land/r/gnoswap/test_token/sol"
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

	atomPath = "gno.land/r/gnoswap/test_token/atom"
	solPath = "gno.land/r/gnoswap/test_token/sol"
)

func fundAndApproveProtocolFeeCallerAtom(amount int64) {
	testing.SetRealm(adminRealm)
	atom.Transfer(cross, stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, amount)
	atom.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

func fundAndApproveProtocolFeeCallerSol(amount int64) {
	testing.SetRealm(adminRealm)
	sol.Transfer(cross, stakerAddr, amount)
	testing.SetRealm(stakerRealm)
	sol.Approve(cross, protocolFeeAddr, amount)
	sol.Approve(cross, protocolFeeV1Realm.Address(), amount)
}

func main() {
	println("[SCENARIO] 1. Create launchpad project and deposit")
	createLaunchpadProject()
	println()

	println("[SCENARIO] 2. Setup protocol fee deposit (atom, sol)")
	setupProtocolFeeDeposit()
	println()

	println("[SCENARIO] 3. Skip blocks and distribute protocol fee")
	skipBlocksAndDistribute()
	println()

	println("[SCENARIO] 4. Check and collect protocol fee reward for project recipient")
	protocolFeeRewardProjectRecipient()
	println()

	println("[SCENARIO] 5. Block withdraw and check claimable reward")
	checkBlockedWithLaunchpadCollectDepositGns()
	println()
}

func createLaunchpadProject() {
	rewardAmount := int64(1_000_000_000)
	startTime := int64(time.Now().Unix() + 604800) // 7 days

	testing.SetRealm(adminRealm)
	atom.Approve(cross, launchpadAddr, rewardAmount)
	lp.CreateProject(
		cross,
		"Atom Launchpad Project",
		atomPath,
		projectAddr,
		int64(rewardAmount),
		atomPath,
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
	depositID := lp.DepositGns(cross, "gno.land/r/gnoswap/test_token/atom:123:30", int64(rewardAmount), "")
	ufmt.Printf("[INFO] deposited launchpad deposit: %s\n", depositID)
}

func setupProtocolFeeDeposit() {
	// mock protocol fee deposit (atom, sol)
	fundAndApproveProtocolFeeCallerAtom(1000)
	fundAndApproveProtocolFeeCallerSol(2500)
	testing.SetRealm(stakerRealm)
	atom.Approve(cross, protocolFeeAddr, 1000)
	sol.Approve(cross, protocolFeeAddr, 2500)
	pf.AddToProtocolFee(cross, atomPath, 1000)
	pf.AddToProtocolFee(cross, solPath, 2500)

	println("[INFO] protocol fee deposited: atom(1000), sol(2500)")
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
	emission.MintAndDistributeGns(cross)
	protocol_fee.DistributeProtocolFee(cross)
	emissionReward, protocolFees, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable reward (project recipient): emissionReward=%d, protocolFees=%s\n", emissionReward, formatProtocolFees(protocolFees))

	testing.SetRealm(projectRealm)
	prevAtomBalance := atom.BalanceOf(projectAddr)
	prevSolBalance := sol.BalanceOf(projectAddr)

	lp.CollectProtocolFee(cross)

	afterAtomBalance := atom.BalanceOf(projectAddr)
	afterSolBalance := sol.BalanceOf(projectAddr)

	println("[INFO] collected protocol fee reward for project recipient")
	ufmt.Printf("[EXPECTED] collected atom amount: %d\n", afterAtomBalance-prevAtomBalance)
	ufmt.Printf("[EXPECTED] collected sol amount: %d\n", afterSolBalance-prevSolBalance)
}

func checkBlockedWithLaunchpadCollectDepositGns() {
	testing.SetRealm(adminRealm)
	uassert.AbortsContains(t, "[GNOSWAP-LAUNCHPAD-011] invalid reward state", func() {
		lp.CollectDepositGns(cross, "1")
	})
	println("[INFO] blocked launchpad collect deposit gns by not yet ended project")
}

// Output:
// [SCENARIO] 1. Create launchpad project and deposit
// [INFO] skipped 120960 blocks
// [INFO] deposited launchpad deposit: 1
//
// [SCENARIO] 2. Setup protocol fee deposit (atom, sol)
// [INFO] protocol fee deposited: atom(1000), sol(2500)
//
// [SCENARIO] 3. Skip blocks and distribute protocol fee
// [INFO] skipped 10 blocks
//
// [SCENARIO] 4. Check and collect protocol fee reward for project recipient
// [INFO] claimable reward (project recipient): emissionReward=0, protocolFees=map[gno.land/r/gnoswap/test_token/atom:999 gno.land/r/gnoswap/test_token/sol:2499]
// [INFO] collected protocol fee reward for project recipient
// [EXPECTED] collected atom amount: 999
// [EXPECTED] collected sol amount: 2499
//
// [SCENARIO] 5. Block withdraw and check claimable reward
// [INFO] blocked launchpad collect deposit gns by not yet ended project
