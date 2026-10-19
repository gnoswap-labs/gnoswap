// PKGPATH: gno.land/r/gnoswap/v1/main

// CollectEmissionRewardFromLaunchPad mints pending GNS emission before settling the claim

package main

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	prbac "gno.land/p/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/access/v1"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/scenarioutils"

	_ "gno.land/r/gnoswap/common/v1"
	_ "gno.land/r/gnoswap/protocol_fee/v1"
	_ "gno.land/r/gnoswap/rbac/v1"

	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"

	lp "gno.land/r/gnoswap/launchpad"
	_ "gno.land/r/gnoswap/launchpad/v1"

	"gno.land/r/onbloc/bar"
)

var (
	admin      = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	launchpadAddr = access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())

	projectAddr  = testutils.TestAddress("projectAddr")
	projectRealm = testing.NewUserRealm(projectAddr)

	barPath = "gno.land/r/onbloc/bar.BAR"
)

func main(cur realm) {
	println("[SCENARIO] 1. Start emission and set gov staker share")
	setupEmission(cur)
	println()

	println("[SCENARIO] 2. Create launchpad project and deposit GNS")
	createProjectAndDeposit(cur)
	println()

	println("[SCENARIO] 3. Skip blocks without minting emission")
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks; no emission mint was triggered")
	println()

	println("[SCENARIO] 4. Project recipient collects emission reward via launchpad")
	collectEmissionReward(cur)
	println()

	println("[SCENARIO] 5. Collect again in the same block")
	collectEmissionRewardAgain(cur)
}

func setupEmission(cur realm) {
	testing.SetRealm(adminRealm)
	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	emission.ChangeDistributionPct(
		cross(cur),
		7000, // liquidityStakerPct
		2000, // devOpsPct
		500,  // communityPoolPct
		500,  // govStakerPct
	)
	println("[INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%")
}

func createProjectAndDeposit(cur realm) {
	rewardAmount := int64(1_000_000_000)
	startTime := time.Now().Unix() + 604800 // 7 days

	testing.SetRealm(adminRealm)
	bar.Approve(cross(cur), launchpadAddr, rewardAmount)
	lp.CreateProject(
		cross(cur),
		"Bar Launchpad Project",
		barPath,
		projectAddr,
		rewardAmount,
		barPath,
		"1000000",
		10,
		20,
		70,
		startTime,
	)

	testing.SkipHeights(120960)
	ufmt.Printf("[INFO] skipped 120960 blocks\n")

	depositAmount := int64(1_000_000)
	testing.SetRealm(adminRealm)
	gns.Approve(cross(cur), launchpadAddr, depositAmount)
	lp.DepositGns(cross(cur), "gno.land/r/onbloc/bar.BAR:123:30", depositAmount, "")
	ufmt.Printf("[INFO] deposited %d GNS to launchpad project\n", depositAmount)
}

func collectEmissionReward(cur realm) {
	accuBefore := emission.GetAccuDistributedToGovStaker()
	staleClaimable, _, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)
	ufmt.Printf("[INFO] claimable before collect (stale, pre-mint): %d\n", staleClaimable)

	testing.SetRealm(projectRealm)
	balanceBefore := gns.BalanceOf(projectAddr)
	lp.CollectEmissionReward(cross(cur))
	collected := gns.BalanceOf(projectAddr) - balanceBefore

	accuAfter := emission.GetAccuDistributedToGovStaker()
	claimableAfter, _, _ := staker.GetClaimableRewardByLaunchpad(projectAddr)

	ufmt.Printf("[EXPECTED] gov staker accumulated distribution increased by collect: %t\n", accuAfter > accuBefore)
	ufmt.Printf("[EXPECTED] collected amount: %d\n", collected)
	ufmt.Printf("[EXPECTED] collected includes pending emission: %t\n", collected > staleClaimable)
	ufmt.Printf("[EXPECTED] claimable after collect: %d\n", claimableAfter)
}

func collectEmissionRewardAgain(cur realm) {
	testing.SetRealm(projectRealm)
	balanceBefore := gns.BalanceOf(projectAddr)
	lp.CollectEmissionReward(cross(cur))
	collected := gns.BalanceOf(projectAddr) - balanceBefore

	ufmt.Printf("[EXPECTED] collected amount in same block: %d\n", collected)
}

// Output:
// [SCENARIO] 1. Start emission and set gov staker share
// [INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%
//
// [SCENARIO] 2. Create launchpad project and deposit GNS
// [INFO] skipped 120960 blocks
// [INFO] deposited 1000000 GNS to launchpad project
//
// [SCENARIO] 3. Skip blocks without minting emission
// [INFO] skipped 10 blocks; no emission mint was triggered
//
// [SCENARIO] 4. Project recipient collects emission reward via launchpad
// [INFO] claimable before collect (stale, pre-mint): 0
// [EXPECTED] gov staker accumulated distribution increased by collect: true
// [EXPECTED] collected amount: 17836756
// [EXPECTED] collected includes pending emission: true
// [EXPECTED] claimable after collect: 0
//
// [SCENARIO] 5. Collect again in the same block
// [EXPECTED] collected amount in same block: 0
