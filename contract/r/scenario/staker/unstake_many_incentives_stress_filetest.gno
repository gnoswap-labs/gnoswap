// PKGPATH: gno.land/r/gnoswap/v1/main

// Stress regression for the exit-checkpoint path: a position sleeps through 8 rounds of
// 3 concurrent incentives (24 total, never collected). Unstake must stay a bounded
// bookkeeping write, each per-source collect must stay bounded, and draining every
// source must clear the checkpoint and release re-staking.

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

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath  = "gno.land/r/onbloc/bar.BAR"
	bazPath  = "gno.land/r/onbloc/baz.BAZ"
	gnsPath  = "gno.land/r/gnoswap/gns.GNS"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/baz.BAZ:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	ninetyDays int64 = 7776000
)

const rounds = 8

func main(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 100)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Approve(cross(cur), poolAddr, maxInt64)
	baz.Approve(cross(cur), poolAddr, maxInt64)
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	baz.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	pl.CreatePool(cross(cur), barPath, bazPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	pn.Mint(cross(cur), barPath, bazPath, fee100, -100, 100, "10000000", "10000000", "0", "0", maxTimeout, adminUser, "")
	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(1)))
	sr.StakeToken(cross(cur), 1, "")

	incentiveIds := []string{}
	for r := 0; r < rounds; r++ {
		createdAt := time.Now().Unix()
		start := ((createdAt / 86400) + 2) * 86400
		for _, tokenPath := range []string{barPath, bazPath, gnsPath} {
			incentiveIds = append(incentiveIds, ufmt.Sprintf("%s:%d:%d", adminAddr, createdAt, len(incentiveIds)+1))
			sr.CreateExternalIncentive(cross(cur), poolPath, tokenPath, 2_000_000_000, start, start+ninetyDays)
		}
		testing.SkipHeights((start + ninetyDays + 86400 - time.Now().Unix()) / 5)
	}

	sr.UnStakeToken(cross(cur), 1)

	pending, err := sr.GetUnstakedPositionPendingIncentives(1)
	if err != nil {
		panic(err)
	}
	println("pending incentives after unstake:", len(pending))
	println("first incentive uncollected count:", sr.GetUncollectedIncentiveCount(incentiveIds[0]))

	reward, penalty := sr.CollectEmissionReward(cross(cur), 1)
	println("emission collected:", reward > 0 || penalty > 0)
	println("checkpoint remains after emission collect:", sr.HasUnstakedPosition(1))

	for _, incentiveId := range incentiveIds {
		sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)
	}

	println("checkpoint remains after draining all sources:", sr.HasUnstakedPosition(1))
	println("first incentive uncollected count:", sr.GetUncollectedIncentiveCount(incentiveIds[0]))

	gnft.Approve(cross(cur), stakerAddr, grc721.TokenID(strconv.Itoa(1)))
	sr.StakeToken(cross(cur), 1, "")
	println("restaked after full collection:", true)
}

// Output:
// pending incentives after unstake: 24
// first incentive uncollected count: 1
// emission collected: true
// checkpoint remains after emission collect: true
// checkpoint remains after draining all sources: false
// first incentive uncollected count: 0
// restaked after full collection: true
