// PKGPATH: gno.land/r/gnoswap/v1/main

// CollectEmissionReward mints pending GNS emission before settling the claim

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
	"gno.land/r/gnoswap/gov/staker"
	_ "gno.land/r/gnoswap/gov/staker/v1"
)

var (
	admin      = access.MustGetAddress(prbac.ROLE_ADMIN.String())
	adminRealm = testing.NewUserRealm(admin)

	govStakerAddr = access.MustGetAddress(prbac.ROLE_GOV_STAKER.String())

	aliceAddr  = testutils.TestAddress("alice")
	aliceRealm = testing.NewUserRealm(aliceAddr)

	delegateAmount = int64(5_000_000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Start emission and set gov staker share")
	setupEmission(cur)
	println()

	println("[SCENARIO] 2. Alice delegates GNS")
	aliceDelegates(cur)
	println()

	println("[SCENARIO] 3. Skip blocks without minting emission")
	skipBlocksWithoutMint()
	println()

	println("[SCENARIO] 4. Alice collects emission reward only")
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

func aliceDelegates(cur realm) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), aliceAddr, delegateAmount)

	testing.SetRealm(aliceRealm)
	gns.Approve(cross(cur), govStakerAddr, delegateAmount)
	staker.Delegate(cross(cur), aliceAddr, delegateAmount, "")
	ufmt.Printf("[INFO] alice delegated %d GNS\n", delegateAmount)
}

func skipBlocksWithoutMint() {
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks; no emission mint was triggered")
}

func collectEmissionReward(cur realm) {
	accuBefore := emission.GetAccuDistributedToGovStaker()
	staleClaimable, _, _ := staker.GetClaimableRewardByAddress(aliceAddr)
	ufmt.Printf("[INFO] claimable before collect (stale, pre-mint): %d\n", staleClaimable)

	testing.SetRealm(aliceRealm)
	balanceBefore := gns.BalanceOf(aliceAddr)
	staker.CollectEmissionReward(cross(cur))
	collected := gns.BalanceOf(aliceAddr) - balanceBefore

	accuAfter := emission.GetAccuDistributedToGovStaker()
	claimableAfter, _, _ := staker.GetClaimableRewardByAddress(aliceAddr)

	ufmt.Printf("[EXPECTED] gov staker accumulated distribution increased by collect: %t\n", accuAfter > accuBefore)
	ufmt.Printf("[EXPECTED] collected amount: %d\n", collected)
	ufmt.Printf("[EXPECTED] collected includes pending emission: %t\n", collected > staleClaimable)
	ufmt.Printf("[EXPECTED] claimable after collect: %d\n", claimableAfter)
}

func collectEmissionRewardAgain(cur realm) {
	testing.SetRealm(aliceRealm)
	balanceBefore := gns.BalanceOf(aliceAddr)
	staker.CollectEmissionReward(cross(cur))
	collected := gns.BalanceOf(aliceAddr) - balanceBefore

	ufmt.Printf("[EXPECTED] collected amount in same block: %d\n", collected)
}

// Output:
// [SCENARIO] 1. Start emission and set gov staker share
// [INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%
//
// [SCENARIO] 2. Alice delegates GNS
// [INFO] alice delegated 5000000 GNS
//
// [SCENARIO] 3. Skip blocks without minting emission
// [INFO] skipped 10 blocks; no emission mint was triggered
//
// [SCENARIO] 4. Alice collects emission reward only
// [INFO] claimable before collect (stale, pre-mint): 0
// [EXPECTED] gov staker accumulated distribution increased by collect: true
// [EXPECTED] collected amount: 17836756
// [EXPECTED] collected includes pending emission: true
// [EXPECTED] claimable after collect: 0
//
// [SCENARIO] 5. Collect again in the same block
// [EXPECTED] collected amount in same block: 0
