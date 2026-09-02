// PKGPATH: gno.land/r/gnoswap/v1/main

// Withdrawing a staked position must never depend on the reward payout succeeding.
//
// This drains the staker realm's GNS reserve so that paying the position's internal reward
// would abort, then unstakes. The NFT comes back, the reward stays owed through the
// claimable ledger, and it is paid once the reserve can cover it.

package main

import (
	"testing"
	"time"

	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	en "gno.land/r/gnoswap/emission"

	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminUser    = adminAddr
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	stakerRealm   = testing.NewCodeRealm("gno.land/r/gnoswap/staker")

	poolAddr, _ = access.GetAddress(prabc.ROLE_POOL.String())

	// sink receives the drained reserve so it can be sent back later.
	sink address = "g1v9kxjcm9ta047h6lta047h6lta047h6lzd40gh"

	barPath = "gno.land/r/onbloc/bar.BAR"
	bazPath = "gno.land/r/onbloc/baz.BAZ"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:3000"

	fee3000 uint32 = 3000

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

func main(cur realm) {
	println("[SCENARIO] 1. Stake a position in a tier 1 pool")
	positionId := setup(cur)

	println()
	println("[SCENARIO] 2. Drain the staker reward reserve")
	drained := drainStakerReserve(cur)

	println()
	println("[SCENARIO] 3. Unstake with an empty reserve")
	unstakeWithEmptyReserve(cur, positionId)

	println()
	println("[SCENARIO] 4. Claim once the reserve is restored")
	claimAfterRefund(cur, drained)
}

func setup(cur realm) uint64 {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	en.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	pl.CreatePool(cross(cur), barPath, bazPath, fee3000, "79228162514264337593543950337")
	sr.SetPoolTier(cross(cur), poolPath, 1)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur),
		barPath,
		bazPath,
		fee3000,
		int32(-1020),
		int32(1020),
		"100000",
		"100000",
		"1",
		"1",
		maxTimeout,
		adminUser,
		"",
	)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(cur, positionId))
	sr.StakeToken(cross(cur), positionId, "")

	println("[INFO] position staked, accumulating rewards")
	testing.SkipHeights(100)

	return positionId
}

func drainStakerReserve(cur realm) int64 {
	// Bring emission up to date first so the reserve holds what the position earned, then
	// empty it: any reward transfer from here on would abort.
	testing.SetRealm(adminRealm)
	en.MintAndDistributeGns(cross(cur))

	testing.SetRealm(stakerRealm)
	drained := gns.BalanceOf(stakerAddr)
	gns.Transfer(cross(cur), sink, drained)

	ufmt.Printf("[EXPECTED] staker GNS reserve after draining: %d\n", gns.BalanceOf(stakerAddr))

	return drained
}

func unstakeWithEmptyReserve(cur realm, positionId uint64) {
	testing.SetRealm(adminRealm)

	balanceBefore := gns.BalanceOf(adminUser)

	// Before the split this call collected rewards inline, so an empty reserve aborted it
	// and left the position locked in the staker.
	sr.UnStakeToken(cross(cur), positionId)

	ufmt.Printf("[EXPECTED] position still staked: %t\n", sr.IsStaked(positionId))
	ufmt.Printf("[EXPECTED] NFT returned to owner: %t\n", gnft.MustOwnerOf(positionIdFrom(cur, positionId)) == adminUser)
	ufmt.Printf("[EXPECTED] owner GNS paid during unstake: %d\n", gns.BalanceOf(adminUser)-balanceBefore)
	ufmt.Printf("[EXPECTED] reward settled as claimable: %t\n", sr.GetClaimableReward(adminUser, "gno.land/r/gnoswap/gns.GNS") > 0)
}

func claimAfterRefund(cur realm, drained int64) {
	// Return the drained reserve so the settled reward becomes payable.
	testing.SetRealm(testing.NewUserRealm(sink))
	gns.Transfer(cross(cur), stakerAddr, drained)

	claimable := sr.GetClaimableReward(adminUser, "gno.land/r/gnoswap/gns.GNS")

	testing.SetRealm(adminRealm)
	balanceBefore := gns.BalanceOf(adminUser)
	sr.ClaimRewards(cross(cur))

	ufmt.Printf("[EXPECTED] claimed the settled reward: %t\n", gns.BalanceOf(adminUser)-balanceBefore >= claimable)
	ufmt.Printf("[EXPECTED] claimable left after claiming: %d\n", sr.GetClaimableReward(adminUser, "gno.land/r/gnoswap/gns.GNS"))
}

func positionIdFrom(cur realm, positionId uint64) grc721.TokenID {
	return grc721.TokenID(ufmt.Sprintf("%d", positionId))
}

// Output:
// [SCENARIO] 1. Stake a position in a tier 1 pool
// [INFO] position staked, accumulating rewards
//
// [SCENARIO] 2. Drain the staker reward reserve
// [EXPECTED] staker GNS reserve after draining: 0
//
// [SCENARIO] 3. Unstake with an empty reserve
// [EXPECTED] position still staked: false
// [EXPECTED] NFT returned to owner: true
// [EXPECTED] owner GNS paid during unstake: 0
// [EXPECTED] reward settled as claimable: true
//
// [SCENARIO] 4. Claim once the reserve is restored
// [EXPECTED] claimed the settled reward: true
// [EXPECTED] claimable left after claiming: 0
