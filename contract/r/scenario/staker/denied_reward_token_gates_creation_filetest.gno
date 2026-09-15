// PKGPATH: gno.land/r/gnoswap/v1/main

// The reward-token deny switch stops new incentives only.
//
// A pool-pair token qualifies as a reward token for its own pool without the allowlist, so the
// deny switch is the only lever against a pair token whose issuer turned hostile. Denying it
// refuses new incentives in that token, leaves an already-created incentive collectible - here
// through an exit checkpoint - cannot touch the default protocol tokens, and is reversible.

package main

import (
	"strconv"
	"strings"
	"testing"
	"time"

	"gno.land/p/gnoswap/gnsmath/v1"
	"gno.land/r/gnoswap/scenarioutils"

	"gno.land/p/nt/grc721/v0"
	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gnft"
	"gno.land/r/gnoswap/gns"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"
	sr "gno.land/r/gnoswap/staker"

	prabc "gno.land/p/gnoswap/rbac/v1"
	_ "gno.land/r/gnoswap/rbac/v1"

	_ "gno.land/r/gnoswap/pool/v1"
	_ "gno.land/r/gnoswap/position/v1"
	_ "gno.land/r/gnoswap/staker/v1"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/qux"
)

var (
	adminAddr, _ = access.GetAddress(prabc.ROLE_ADMIN.String())
	adminRealm   = testing.NewUserRealm(adminAddr)

	stakerUserAddr  = testutils.TestAddress("deniedStaker")
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
	nextStart   int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Create a BAR incentive, stake against it, and unstake without collecting")
	setup(cur)

	println()
	println("[SCENARIO] 2. Deny BAR as a reward token")
	denyBar(cur)

	println()
	println("[SCENARIO] 3. A new BAR incentive is refused through the pair-token path")
	creationRefused(cur)

	println()
	println("[SCENARIO] 4. The existing BAR incentive still collects through the checkpoint")
	checkpointStillCollects(cur)

	println()
	println("[SCENARIO] 5. Default protocol tokens cannot be denied")
	defaultTokenProtected(cur)

	println()
	println("[SCENARIO] 6. Clearing the flag lets a new BAR incentive through")
	undenyAndCreate(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	bar.Transfer(cross(cur), creatorAddr, rewardAmount*2)
	gns.Transfer(cross(cur), creatorAddr, 200_000_000_000)

	pl.CreatePool(cross(cur), barPath, quxPath, fee100, gnsmath.TickMathGetSqrtRatioAtTick(0).ToString())
	sr.SetPoolTier(cross(cur), poolPath, 1)

	testing.SetRealm(creatorRealm)
	bar.Approve(cross(cur), stakerAddr, maxInt64)
	gns.Approve(cross(cur), stakerAddr, maxInt64)

	createdAt := time.Now().Unix()
	startTime := ((createdAt / 86400) + 2) * 86400
	incentiveId = ufmt.Sprintf("%s:%d:%d", creatorAddr, createdAt, 1)

	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardAmount, startTime, startTime+incentiveDuration)

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

	// Past the incentive end, so the pool is free for a new BAR incentive later.
	testing.SkipHeights((incentiveDuration + 24*60*60) / 5)
	sr.UnStakeToken(cross(cur), positionId)

	ufmt.Printf("[INFO] position %d unstaked with the BAR incentive uncollected: %t\n", positionId, sr.HasUnstakedPosition(positionId))
}

func denyBar(cur realm) {
	testing.SetRealm(adminRealm)
	sr.SetDeniedRewardToken(cross(cur), barPath, true)

	ufmt.Printf("[EXPECTED] denied reward tokens: [%s]\n", strings.Join(sr.GetDeniedRewardTokens(), ","))
}

func creationRefused(cur realm) {
	testing.SetRealm(creatorRealm)

	nextStart = ((time.Now().Unix() / 86400) + 2) * 86400

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-025]", func() {
		println("[EXPECTED] creating a BAR incentive is refused while BAR is denied")
		sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardAmount, nextStart, nextStart+incentiveDuration)
	})
}

func checkpointStillCollects(cur realm) {
	testing.SetRealm(stakerUserRealm)

	before := bar.BalanceOf(stakerUserAddr)
	sr.CollectReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the BAR reward was still paid: %t\n", bar.BalanceOf(stakerUserAddr) > before)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))
}

func defaultTokenProtected(cur realm) {
	testing.SetRealm(adminRealm)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-026]", func() {
		println("[EXPECTED] denying GNS is refused")
		sr.SetDeniedRewardToken(cross(cur), gnsPath, true)
	})
}

func undenyAndCreate(cur realm) {
	testing.SetRealm(adminRealm)
	sr.SetDeniedRewardToken(cross(cur), barPath, false)

	testing.SetRealm(creatorRealm)
	sr.CreateExternalIncentive(cross(cur), poolPath, barPath, rewardAmount, nextStart, nextStart+incentiveDuration)

	ufmt.Printf("[EXPECTED] denied reward tokens: [%s]\n", strings.Join(sr.GetDeniedRewardTokens(), ","))
	incentives, _ := sr.GetExternalIncentiveByPoolPath(poolPath)
	ufmt.Printf("[EXPECTED] incentives on the pool after re-creation: %d\n", len(incentives))
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create a BAR incentive, stake against it, and unstake without collecting
// [INFO] position 1 unstaked with the BAR incentive uncollected: true
//
// [SCENARIO] 2. Deny BAR as a reward token
// [EXPECTED] denied reward tokens: [gno.land/r/onbloc/bar.BAR]
//
// [SCENARIO] 3. A new BAR incentive is refused through the pair-token path
// [EXPECTED] creating a BAR incentive is refused while BAR is denied
//
// [SCENARIO] 4. The existing BAR incentive still collects through the checkpoint
// [EXPECTED] the BAR reward was still paid: true
// [EXPECTED] the checkpoint is gone: true
//
// [SCENARIO] 5. Default protocol tokens cannot be denied
// [EXPECTED] denying GNS is refused
//
// [SCENARIO] 6. Clearing the flag lets a new BAR incentive through
// [EXPECTED] denied reward tokens: []
// [EXPECTED] incentives on the pool after re-creation: 2
