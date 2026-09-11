// PKGPATH: gno.land/r/gnoswap/v1/main

// A checkpoint must deliver a penalty even when the user reward rounds to zero.
//
// The warmup ratio floors the user reward, so a small enough accrual yields no user reward and
// a positive penalty. While the position is staked that is left to accrue until a collect can
// deliver a non-zero amount. An unstaked position has stopped accruing, so the same window is
// final: the penalty has to be delivered now, or it is dropped with the checkpoint.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/demo/tokens/grc721"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"

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

	stakerAddr, _    = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _      = access.GetAddress(prabc.ROLE_POOL.String())
	communityAddr, _ = access.GetAddress(prabc.ROLE_COMMUNITY_POOL.String())

	barPath  = "gno.land/r/onbloc/bar.BAR"
	bazPath  = "gno.land/r/onbloc/baz.BAZ"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807
)

// Position ids in mint order.
const (
	bulkId uint64 = 1 // holds effectively all of the pool's staked liquidity
	dustId uint64 = 2 // small enough that its user reward floors to zero
)

func main(cur realm) {
	println("[SCENARIO] 1. Stake a dust position beside a much larger one")
	setup(cur)

	println()
	println("[SCENARIO] 2. Unstake the dust position and collect it")
	collectDust(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)

	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	mint(cur, "100000000000")
	stake(cur, bulkId)

	mint(cur, "20000")
	stake(cur, dustId)

	testing.SkipHeights(1)
}

func collectDust(cur realm) {
	testing.SetRealm(adminRealm)

	sr.UnStakeToken(cross(cur), dustId)

	// The community pool is also an emission target, so bring emission up to date before
	// measuring; otherwise the collect's own distribution lands in the same delta.
	emission.MintAndDistributeGns(cross(cur))

	ownerBefore := gns.BalanceOf(adminUser)
	communityBefore := gns.BalanceOf(communityAddr)
	sr.CollectReward(cross(cur), dustId)

	ufmt.Printf("[EXPECTED] the user reward floored to zero: %t\n", gns.BalanceOf(adminUser) == ownerBefore)
	ufmt.Printf("[EXPECTED] the penalty was still delivered: %t\n", gns.BalanceOf(communityAddr) > communityBefore)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(dustId))
}

func mint(cur realm, amount string) {
	pn.Mint(cross(cur), barPath, bazPath, fee100, -100, 100, amount, amount, "0", "0", maxTimeout, adminUser, "")
}

func stake(cur realm, positionId uint64) {
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(int(positionId))))
	sr.StakeToken(cross(cur), positionId, "")
}

// Output:
// [SCENARIO] 1. Stake a dust position beside a much larger one
//
// [SCENARIO] 2. Unstake the dust position and collect it
// [EXPECTED] the user reward floored to zero: true
// [EXPECTED] the penalty was still delivered: true
// [EXPECTED] the checkpoint is gone: true
