// PKGPATH: gno.land/r/gnoswap/v1/main

// A checkpoint's claim survives a reward-token balance shortfall instead of being waived.
//
// A staker unstakes without collecting, then the reward token's issuer burns the staker realm's
// balance. The permissionless incentive collect aborts before any bookkeeping, so the claim is
// still owed: the emission source is collected independently, the incentive cannot be refunded
// over the staker's head, and once the balance is restored the very same collect pays the
// staker exactly what was quoted, clears the checkpoint and frees the position to stake again.

package main

import (
	"strconv"
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

	stakerUserAddr  = testutils.TestAddress("absentStaker")
	stakerUserRealm = testing.NewUserRealm(stakerUserAddr)

	creatorAddr  = testutils.TestAddress("incentiveCreator")
	creatorRealm = testing.NewUserRealm(creatorAddr)

	stakerAddr, _ = access.GetAddress(prabc.ROLE_STAKER.String())
	poolAddr, _   = access.GetAddress(prabc.ROLE_POOL.String())

	barPath = "gno.land/r/onbloc/bar.BAR"
	quxPath = "gno.land/r/onbloc/qux.QUX"

	poolPath = "gno.land/r/onbloc/bar.BAR:gno.land/r/onbloc/qux.QUX:100"

	fee100 uint32 = 100

	maxTimeout int64 = 9999999999
	maxInt64   int64 = 9223372036854775807

	incentiveDuration int64 = 90 * 24 * 60 * 60
	rewardAmount      int64 = 1_500_000_000

	incentiveId string
	quoted      int64
	burned      int64
)

func main(cur realm) {
	println("[SCENARIO] 1. Create a BAR incentive and stake against it")
	setup(cur)

	println()
	println("[SCENARIO] 2. The incentive ends and the staker unstakes without collecting")
	unstakeWithoutCollecting(cur)

	println()
	println("[SCENARIO] 3. The issuer burns the staker realm's BAR")
	burnStakerBalance(cur)

	println()
	println("[SCENARIO] 4. The incentive collect aborts and leaves the claim owed")
	incentiveCollectAborts(cur)

	println()
	println("[SCENARIO] 5. The emission source still collects on its own")
	emissionCollects(cur)

	println()
	println("[SCENARIO] 6. The incentive still cannot be refunded")
	refundRejected(cur)

	println()
	println("[SCENARIO] 7. Restoring the balance lets the same collect pay the staker")
	restoreAndCollect(cur)

	println()
	println("[SCENARIO] 8. The refund goes through and the position can be staked again")
	refundAndRestake(cur)
}

func setup(cur realm) {
	testing.SetRealm(adminRealm)

	scenarioutils.EnsureCanonicalDefaultPool(cross(cur))
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)
	sr.SetUnStakingFee(cross(cur), 0)
	pl.SetPoolCreationFee(cross(cur), 0)

	bar.Transfer(cross(cur), stakerUserAddr, 10000)
	qux.Transfer(cross(cur), stakerUserAddr, 10000)
	bar.Transfer(cross(cur), creatorAddr, rewardAmount)
	gns.Transfer(cross(cur), creatorAddr, 100_000_000_000)

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

	ufmt.Printf("[INFO] staked position %d against the incentive\n", positionId)
}

func unstakeWithoutCollecting(cur realm) {
	testing.SkipHeights((incentiveDuration + 24*60*60) / 5)

	testing.SetRealm(stakerUserRealm)
	sr.UnStakeToken(cross(cur), 1)

	var err error
	quoted, err = sr.CollectableExternalIncentiveReward(1, incentiveId)

	ufmt.Printf("[EXPECTED] position left uncollected: %t\n", sr.HasUnstakedPosition(1))
	ufmt.Printf("[EXPECTED] the checkpoint quotes a positive BAR reward: %t\n", err == nil && quoted > 0)
}

func burnStakerBalance(cur realm) {
	testing.SetRealm(adminRealm)

	burned = bar.BalanceOf(stakerAddr)
	bar.Burn(cross(cur), stakerAddr, burned)

	ufmt.Printf("[INFO] staker realm BAR balance is now %d\n", bar.BalanceOf(stakerAddr))
}

// Any caller may try, and none may waive the claim: the collect aborts before touching state.
func incentiveCollectAborts(cur realm) {
	testing.SetRealm(creatorRealm)

	ledgerBefore, _ := sr.GetIncentiveRemainingRewardAmount(poolPath, incentiveId)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-027]", func() {
		println("[EXPECTED] collecting the incentive aborts while the balance is short")
		sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)
	})

	ledgerAfter, _ := sr.GetIncentiveRemainingRewardAmount(poolPath, incentiveId)

	ufmt.Printf("[EXPECTED] the checkpoint still owes the incentive: %t\n", sr.HasUnstakedPosition(1))
	ufmt.Printf("[EXPECTED] the incentive was not debited: %t\n", ledgerBefore == ledgerAfter)
	ufmt.Printf("[EXPECTED] the uncollected count is untouched: %d\n", sr.GetUncollectedIncentiveCount(incentiveId))
}

func emissionCollects(cur realm) {
	testing.SetRealm(creatorRealm)

	before := gns.BalanceOf(stakerUserAddr)
	sr.CollectEmissionReward(cross(cur), 1)

	ufmt.Printf("[EXPECTED] the emission reward was paid to the staker: %t\n", gns.BalanceOf(stakerUserAddr) > before)
	ufmt.Printf("[EXPECTED] the checkpoint still owes the incentive: %t\n", sr.HasUnstakedPosition(1))
}

func refundRejected(cur realm) {
	testing.SetRealm(creatorRealm)

	var t *testing.T
	uassert.AbortsContains(t, cur, "[GNOSWAP-STAKER-024]", func() {
		println("[EXPECTED] refunding while the claim is owed is refused")
		sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, creatorAddr)
	})
}

func restoreAndCollect(cur realm) {
	testing.SetRealm(adminRealm)
	bar.Mint(cross(cur), stakerAddr, burned)

	testing.SetRealm(creatorRealm)
	before := bar.BalanceOf(stakerUserAddr)
	sr.CollectExternalIncentiveReward(cross(cur), 1, incentiveId)

	ufmt.Printf("[EXPECTED] the staker received exactly the quoted amount: %t\n", bar.BalanceOf(stakerUserAddr)-before == quoted)
	ufmt.Printf("[EXPECTED] the checkpoint is gone: %t\n", !sr.HasUnstakedPosition(1))
	ufmt.Printf("[EXPECTED] the uncollected count is cleared: %d\n", sr.GetUncollectedIncentiveCount(incentiveId))
}

func refundAndRestake(cur realm) {
	testing.SetRealm(creatorRealm)
	sr.EndExternalIncentive(cross(cur), poolPath, incentiveId, creatorAddr)
	println("[EXPECTED] refund succeeded once the claim was paid")

	testing.SetRealm(stakerUserRealm)
	gnft.Approve(cross(cur), stakerAddr, positionIdFrom(1))
	sr.StakeToken(cross(cur), 1, "")

	ufmt.Printf("[EXPECTED] position is staked again: %t\n", sr.IsStaked(1))
}

func positionIdFrom(positionId uint64) grc721.TokenID {
	return grc721.TokenID(strconv.Itoa(int(positionId)))
}

// Output:
// [SCENARIO] 1. Create a BAR incentive and stake against it
// [INFO] staked position 1 against the incentive
//
// [SCENARIO] 2. The incentive ends and the staker unstakes without collecting
// [EXPECTED] position left uncollected: true
// [EXPECTED] the checkpoint quotes a positive BAR reward: true
//
// [SCENARIO] 3. The issuer burns the staker realm's BAR
// [INFO] staker realm BAR balance is now 0
//
// [SCENARIO] 4. The incentive collect aborts and leaves the claim owed
// [EXPECTED] collecting the incentive aborts while the balance is short
// [EXPECTED] the checkpoint still owes the incentive: true
// [EXPECTED] the incentive was not debited: true
// [EXPECTED] the uncollected count is untouched: 1
//
// [SCENARIO] 5. The emission source still collects on its own
// [EXPECTED] the emission reward was paid to the staker: true
// [EXPECTED] the checkpoint still owes the incentive: true
//
// [SCENARIO] 6. The incentive still cannot be refunded
// [EXPECTED] refunding while the claim is owed is refused
//
// [SCENARIO] 7. Restoring the balance lets the same collect pay the staker
// [EXPECTED] the staker received exactly the quoted amount: true
// [EXPECTED] the checkpoint is gone: true
// [EXPECTED] the uncollected count is cleared: 0
//
// [SCENARIO] 8. The refund goes through and the position can be staked again
// [EXPECTED] refund succeeded once the claim was paid
// [EXPECTED] position is staked again: true
