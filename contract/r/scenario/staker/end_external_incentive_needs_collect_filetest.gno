// PKGPATH: gno.land/r/gnoswap/v1/main

// An incentive cannot be refunded while an unstaked position still owes an uncollected reward
// from it, and the creator must be able to clear that themselves.
//
// A staker unstakes after the incentive ends and never collects. Their share has not been drawn
// down from the incentive yet, so refunding now would pay it to the creator. The refund is
// refused until the checkpoint is collected - which anyone may do, because it can only ever pay
// the position's owner, so the creator clears it and gets the refund.

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

	// The staker unstakes and never comes back, so nothing that needs their signature can
	// unblock the incentive.
	stakerUserAddr  = testutils.TestAddress("absentStaker")
	stakerUserRealm = testing.NewUserRealm(stakerUserAddr)

	creatorAddr  = testutils.TestAddress("incentiveCreator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"
	gnsPath = "gno.land/r/gnoswap/gns.GNS"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	incentiveDuration int64 = 90 * 24 * 60 * 60
	rewardAmount      int64 = 1_500_000_000

	incentiveId string
)

func main(cur realm) {
	println("[SCENARIO] 1. Create an incentive and stake against it")
	setup(cur)

	println()
	println("[SCENARIO] 2. The incentive ends and the staker unstakes without collecting")
	unstakeWithoutCollecting(cur)

	println()
	println("[SCENARIO] 3. Refunding the incentive is refused")
	refundRejected(cur)

	println()
	println("[SCENARIO] 4. Anyone can collect the position, so the creator does")
	creatorCollects(cur)

	println()
	println("[SCENARIO] 5. The refund goes through")
	refundAndVerify(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	gns.Transfer(cross(cur), creatorAddr, rewardAmount+100_000_000_000)

	pl.CreatePool(cross(cur), barPath, quxPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(creatorRealm)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createdAt := time.Now().Unix()
	startTime := ((createdAt / 86400) + 2) * 86400
	incentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 1)

	sr.CreateExternalIncentive(cross(cur), poolPath, gnsPath, rewardAmount, startTime, startTime+incentiveDuration)

	if left := startTime - time.Now().Unix(); left > 0 {
		testing.SkipHeights(left / 5)
	}

	testing.SetRealm(stakerUserRealm)
	bar.Approve(cross(cur), poolAddr, maxInt64)
	qux.Approve(cross(cur), poolAddr, maxInt64)

	positionId, _, _, _ := pn.Mint(
		cross(cur), barPath, quxPath, fee100,
		int32(-100), int32(100), "1000", "1000", "1", "1",
		maxTimeout, stakerUserAddr, "",
	)

	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(positionId))
	sr.StakeToken(cross(cur), positionId, "")

	ufmt.Printf("[INFO] staked position %d against the incentive\n", positionId)
}

func unstakeWithoutCollecting(cur realm) {
	testing.SkipHeights((incentiveDuration + 24*60*60) / 5)

	testing.SetRealm(stakerUserRealm)
	sr.UnStakeToken(cross(cur), 1)

	ufmt.Printf("[EXPECTED] position left uncollected: %t\n", sr.HasUnstakedPosition(1))
}

func refundRejected(cur realm) {
	testing.SetRealm(creatorRealm)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] refunding while a position is uncollected is refused")
		sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, creatorAddr)
	})
}

// Collecting an unstaked position is permissionless because it can only pay its owner, which is
// what keeps the creator from being stuck behind a staker who has no reason to come back.
func creatorCollects(cur realm) {
	testing.SetRealm(creatorRealm)

	before := gns.BalanceOf(stakerUserAddr)
	sr.CollectReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the checkpoint is cleared: %t\n", !sr.HasUnstakedPosition(1))
	ufmt.Printf("[EXPECTED] the reward went to the staker, not the caller: %t\n",
		gns.BalanceOf(stakerUserAddr) > before)
}

func refundAndVerify(cur realm) {
	testing.SetRealm(creatorRealm)

	sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, creatorAddr)
	println("[EXPECTED] refund succeeded once nothing was left uncollected")
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create an incentive and stake against it
// [INFO] staked position 1 against the incentive
//
// [SCENARIO] 2. The incentive ends and the staker unstakes without collecting
// [EXPECTED] position left uncollected: true
//
// [SCENARIO] 3. Refunding the incentive is refused
// [EXPECTED] refunding while a position is uncollected is refused
//
// [SCENARIO] 4. Anyone can collect the position, so the creator does
// [EXPECTED] the checkpoint is cleared: true
// [EXPECTED] the reward went to the staker, not the caller: true
//
// [SCENARIO] 5. The refund goes through
// [EXPECTED] refund succeeded once nothing was left uncollected
