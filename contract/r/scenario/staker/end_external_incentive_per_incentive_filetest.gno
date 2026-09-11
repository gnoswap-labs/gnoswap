// PKGPATH: gno.land/r/gnoswap/v1/main

// The uncollected-reward guard is per incentive, not per pool.
//
// A pool can hold several incentives, and an incentive can be underfunded for good - its reward
// amount only ever decreases. A pool-wide guard would let one such incentive lock the refunds of
// every other incentive in the pool, including their GNS deposits.
//
// One position accrues from two incentives and is unstaked without collecting, so both are owed.
// Collecting one must release that one alone.

package main

import (
	"strconv"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath"

	"gno.land/p/demo/tokens/grc721"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
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
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerUserAddr  = testutils.TestAddress("staker")
	stakerUserRealm = testing.NewUserRealm(stakerUserAddr)

	creatorAddr  = testutils.TestAddress("creator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath  = "gno.land/r/onbloc/bar.BAR"
	quxPath  = "gno.land/r/onbloc/qux.QUX"
	gnsPath  = "gno.land/r/gnoswap/gns.GNS"
	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	incentiveDuration int64 = 90 * 24 * 60 * 60
	rewardAmount      int64 = 1_500_000_000

	gnsIncentiveId string
	barIncentiveId string
)

func main(cur realm) {
	println("[SCENARIO] 1. Two incentives on one pool, staked against both")
	setup(cur)

	println()
	println("[SCENARIO] 2. Unstake without collecting: both are owed")
	unstakeWithoutCollecting(cur)

	println()
	println("[SCENARIO] 3. Collect only the BAR incentive")
	collectBarIncentive(cur)

	println()
	println("[SCENARIO] 4. The BAR incentive can end; the GNS one still cannot")
	endBarOnly(cur)

	println()
	println("[SCENARIO] 5. Collecting the GNS incentive releases it too")
	endGnsAfterCollect(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	bar.Transfer(cross(cur), creatorAddr, rewardAmount)
	gns.Transfer(cross(cur), creatorAddr, rewardAmount+200_000_000_000)

	pl.CreatePool(cross(cur), barPath, quxPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(creatorRealm)
	gns.Approve(cross(cur), stakerAddr, maxInt64)
	bar.Approve(cross(cur), stakerAddr, maxInt64)

	createdAt := time.Now().Unix()
	startTime := ((createdAt / 86400) + 2) * 86400
	endTime := startTime + incentiveDuration

	gnsIncentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 1)
	barIncentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 2)

	sr.CreateExternalIncentive(cross(cur), poolPath, gnsPath, rewardAmount, startTime, endTime)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardAmount, startTime, endTime)

	if left := startTime - time.Now().Unix(); left > 0 {
		testing.SkipHeights(left / 5)
	}

	testing.SetRealm(stakerUserRealm)
	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	pn.Mint(
		cross(cur), barPath, quxPath, fee100,
		int32(-100), int32(100), "1000", "1000", "1", "1",
		maxTimeout, stakerUserAddr, "",
	)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross(cur), 1, "")

	println("[INFO] staked position 1 against both incentives")
}

func unstakeWithoutCollecting(cur realm) {
	testing.SkipHeights((incentiveDuration + 24*60*60) / 5)

	testing.SetRealm(stakerUserRealm)
	sr.UnStakeToken(cross(cur), 1)

	testing.SetRealm(creatorRealm)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] ending the BAR incentive is refused")
		sr.EndExternalIncentive(cross(cur), poolPath, barIncentiveId, creatorAddr)
	})
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] ending the GNS incentive is refused")
		sr.EndExternalIncentive(cross(cur), poolPath, gnsIncentiveId, creatorAddr)
	})
}

func collectBarIncentive(cur realm) {
	testing.SetRealm(stakerUserRealm)

	before := bar.BalanceOf(stakerUserAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 1, barIncentiveId)

	ufmt.Printf("[EXPECTED] the BAR reward was paid: %t\n", bar.BalanceOf(stakerUserAddr) > before)
	ufmt.Printf("[EXPECTED] the checkpoint still owes the GNS incentive: %t\n", sr.HasUnstakedPosition(1))
}

func endBarOnly(cur realm) {
	testing.SetRealm(creatorRealm)

	sr.EndExternalIncentive(cross(cur), poolPath, barIncentiveId, creatorAddr)
	println("[EXPECTED] the BAR incentive ended")

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] the GNS incentive is still refused")
		sr.EndExternalIncentive(cross(cur), poolPath, gnsIncentiveId, creatorAddr)
	})
}

func endGnsAfterCollect(cur realm) {
	testing.SetRealm(stakerUserRealm)
	sr.CollectExternalIncentiveReward(cross(cur), 1, gnsIncentiveId)

	testing.SetRealm(creatorRealm)
	sr.EndExternalIncentive(cross(cur), poolPath, gnsIncentiveId, creatorAddr)
	println("[EXPECTED] the GNS incentive ended too")
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Two incentives on one pool, staked against both
// [INFO] staked position 1 against both incentives
//
// [SCENARIO] 2. Unstake without collecting: both are owed
// [EXPECTED] ending the BAR incentive is refused
// [EXPECTED] ending the GNS incentive is refused
//
// [SCENARIO] 3. Collect only the BAR incentive
// [EXPECTED] the BAR reward was paid: true
// [EXPECTED] the checkpoint still owes the GNS incentive: true
//
// [SCENARIO] 4. The BAR incentive can end; the GNS one still cannot
// [EXPECTED] the BAR incentive ended
// [EXPECTED] the GNS incentive is still refused
//
// [SCENARIO] 5. Collecting the GNS incentive releases it too
// [EXPECTED] the GNS incentive ended too
