// PKGPATH: gno.land/r/gnoswap/v1/main

// CollectReward mints pending GNS emission before settling the claim

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

	aliceAddr = testutils.TestAddress("alice")
	bobAddr   = testutils.TestAddress("bob")

	aliceAmount = int64(1_000_000)
	bobAmount   = int64(3_000_000)
)

func main(cur realm) {
	println("[SCENARIO] 1. Start emission and set gov staker share")
	setupEmission(cur)
	println()

	println("[SCENARIO] 2. Alice and Bob delegate GNS")
	delegate(cur, aliceAddr, aliceAmount)
	delegate(cur, bobAddr, bobAmount)
	println()

	println("[SCENARIO] 3. Skip blocks without minting emission")
	testing.SkipHeights(10)
	println("[INFO] skipped 10 blocks; no emission mint was triggered")
	println()

	println("[SCENARIO] 4. Alice collects all rewards")
	collectReward(cur, "alice", aliceAddr)
	println()

	println("[SCENARIO] 5. Bob collects all rewards in the same block")
	collectReward(cur, "bob", bobAddr)
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

func delegate(cur realm, addr address, amount int64) {
	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), addr, amount)

	testing.SetRealm(testing.NewUserRealm(addr))
	gns.Approve(cross(cur), govStakerAddr, amount)
	staker.Delegate(cross(cur), addr, amount, "")
	ufmt.Printf("[INFO] %s delegated %d GNS\n", addr.String(), amount)
}

func collectReward(cur realm, name string, addr address) {
	accuBefore := emission.GetAccuDistributedToGovStaker()
	staleClaimable, _, _ := staker.GetClaimableRewardByAddress(addr)
	ufmt.Printf("[INFO] %s claimable before collect: %d\n", name, staleClaimable)

	testing.SetRealm(testing.NewUserRealm(addr))
	balanceBefore := gns.BalanceOf(addr)
	staker.CollectReward(cross(cur))
	collected := gns.BalanceOf(addr) - balanceBefore

	accuAfter := emission.GetAccuDistributedToGovStaker()
	claimableAfter, _, _ := staker.GetClaimableRewardByAddress(addr)

	ufmt.Printf("[EXPECTED] %s collect increased gov staker accumulated distribution: %t\n", name, accuAfter > accuBefore)
	ufmt.Printf("[EXPECTED] %s collected amount: %d\n", name, collected)
	ufmt.Printf("[EXPECTED] %s claimable after collect: %d\n", name, claimableAfter)
}

// Output:
// [SCENARIO] 1. Start emission and set gov staker share
// [INFO] emission distribution ratio changed: staker 70%, devops 20%, community 5%, govstaker 5%
//
// [SCENARIO] 2. Alice and Bob delegate GNS
// [INFO] g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh delegated 1000000 GNS
// [INFO] g1vfhkyh6lta047h6lta047h6lta047h6l03vdhu delegated 3000000 GNS
//
// [SCENARIO] 3. Skip blocks without minting emission
// [INFO] skipped 10 blocks; no emission mint was triggered
//
// [SCENARIO] 4. Alice collects all rewards
// [INFO] alice claimable before collect: 0
// [EXPECTED] alice collect increased gov staker accumulated distribution: true
// [EXPECTED] alice collected amount: 4459189
// [EXPECTED] alice claimable after collect: 0
//
// [SCENARIO] 5. Bob collects all rewards in the same block
// [INFO] bob claimable before collect: 13377567
// [EXPECTED] bob collect increased gov staker accumulated distribution: false
// [EXPECTED] bob collected amount: 13377567
// [EXPECTED] bob claimable after collect: 0
