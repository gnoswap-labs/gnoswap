// Tests for collecting the emission reward and a single external incentive reward independently.
//
// The file name sorts after protocol_fee_unstaking_test.gno on purpose: the staker/v1 package tests
// share realm state, and a collect performed here leaves GNS on the staker realm, which the
// insufficient-balance case of TestHandleStakingRewardFee relies on being empty.
package staker

import (
	"chain/runtime"
	"testing"
	"time"

	prabc "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/uassert/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/emission"
	pl "gno.land/r/gnoswap/pool"

	"gno.land/r/gnoswap/gns"
	sr "gno.land/r/gnoswap/staker"
)

// setupSplitCollectDeposit stakes a position in a pool that earns a GNS emission reward and two external
// incentives paying different reward tokens, and lets all of them accrue. It returns the staked position
// id and the incentive ids of the BAR and the BAZ incentive.
func setupSplitCollectDeposit(cur realm, t *testing.T) (uint64, string, string) {
	t.Helper()

	initStakerTest(cur, t)

	poolPath := pl.GetPoolPath(barPath, bazPath, fee3000)
	testing.SetRealm(adminRealm)
	pl.SetPoolCreationFee(cross(cur), 0)
	createDefaultInitialPoolForStakerTest(cur, t)
	emission.SetDistributionStartTime(cross(cur), time.Now().Unix()+1)

	testing.SetRealm(adminRealm)
	CreatePool(cur, barPath, bazPath, fee3000, "79228162514264337593543950336", adminAddr)
	mockInstanceSetPoolTier(cross(cur), poolPath, 1)

	govAddr := access.MustGetAddress(prabc.ROLE_GOVERNANCE.String())
	testing.SetRealm(testing.NewUserRealm(govAddr))
	mockInstanceAddToken(cross(cur), barPath)
	mockInstanceAddToken(cross(cur), bazPath)
	mockInstanceSetUnstakingFee(cross(cur), 0)

	TokenFaucet(cur, t, barPath, addr01)
	TokenFaucet(cur, t, bazPath, addr01)
	TokenFaucet(cur, t, gnsPath, addr01)

	testing.SetRealm(testing.NewUserRealm(addr01))
	TokenApprove(cur, t, barPath, addr01, poolAddr, maxApprove)
	TokenApprove(cur, t, bazPath, addr01, poolAddr, maxApprove)

	positionId, _, _, _ := MintPosition(
		cur,
		t,
		barPath,
		bazPath,
		fee3000,
		-18000,
		18000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		addr01,
		addr01,
	)

	mockNFTMint(cur, addr01, positionId)
	mockNFTApprove(cur, stakerAddr, positionId)
	testing.SetRealm(testing.NewUserRealm(addr01))
	sr.StakeToken(cross(cur), positionId, "")

	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsApprove(cur, t, addr01, stakerAddr, maxApprove)

	startTimestamp := time.Now().AddDate(0, 0, 2).Truncate(24 * time.Hour).Unix()
	CreateExternalIncentiveAsAdmin(
		cur, t,
		poolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)
	CreateExternalIncentiveAsAdmin(
		cur, t,
		poolPath,
		bazPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	// The start time policy puts the incentives a day or more out, so move the chain to their
	// start before anything can accrue. A test block is 5 seconds.
	testing.SkipHeights((startTimestamp - time.Now().Unix()) / 5)

	// Let the emission and both external rewards accrue.
	testing.SkipHeights(3600)

	barIncentiveId := ""
	bazIncentiveId := ""
	getMockInstance().getExternalIncentives().tree.Iterate("", "", func(key string, value any) bool {
		incentive := value.(*sr.ExternalIncentive)
		switch incentive.RewardToken() {
		case barPath:
			barIncentiveId = key
		case bazPath:
			bazIncentiveId = key
		}
		return false
	})

	if barIncentiveId == "" || bazIncentiveId == "" {
		t.Fatal("expected both external incentives to be created")
	}

	return positionId, barIncentiveId, bazIncentiveId
}

// Collecting the emission reward alone must not touch the external incentive side: the external
// rewards stay fully collectable and their per-incentive lastCollectTime is left untouched.
func TestCollectEmissionReward_LeavesExternalRewardCollectable(cur realm, t *testing.T) {
	positionId, barIncentiveId, _ := setupSplitCollectDeposit(cur, t)

	collectableExternal, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	if collectableExternal == 0 {
		t.Fatal("expected an external reward to be collectable before collecting the emission reward")
	}

	resolver, err := getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	externalLastCollectBefore := resolver.ExternalRewardLastCollectTime(barIncentiveId)
	collectedExternalBefore := resolver.CollectedExternalReward(barIncentiveId)

	testing.SetRealm(testing.NewUserRealm(addr01))
	barBefore := TokenBalance(t, barPath, addr01)

	sr.CollectEmissionReward(cross(cur), positionId)

	resolver, err = getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	uassert.Equal(t, barBefore, TokenBalance(t, barPath, addr01))
	uassert.Equal(t, externalLastCollectBefore, resolver.ExternalRewardLastCollectTime(barIncentiveId))
	uassert.Equal(t, collectedExternalBefore, resolver.CollectedExternalReward(barIncentiveId))

	collectableExternalAfter, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, collectableExternal, collectableExternalAfter)

	// The external reward is still deliverable afterwards.
	toUser, _ := sr.CollectExternalIncentiveReward(cross(cur), positionId, barIncentiveId)
	if toUser == 0 {
		t.Fatal("expected the external reward to remain collectable after the emission collect")
	}

	uassert.Equal(t, barBefore+toUser, TokenBalance(t, barPath, addr01))
}

// Collecting one external incentive must pay out its reward token while leaving the emission side
// untouched: no GNS moves and the deposit's internal collect cursor does not advance.
func TestCollectExternalIncentiveReward_LeavesEmissionRewardCollectable(cur realm, t *testing.T) {
	positionId, barIncentiveId, _ := setupSplitCollectDeposit(cur, t)

	resolver, err := getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	internalLastCollectBefore := resolver.InternalRewardLastCollectTime()
	collectedInternalBefore := resolver.CollectedInternalReward()

	testing.SetRealm(testing.NewUserRealm(addr01))
	gnsBefore := gns.BalanceOf(addr01)
	barBefore := TokenBalance(t, barPath, addr01)

	toUser, _ := sr.CollectExternalIncentiveReward(cross(cur), positionId, barIncentiveId)
	if toUser == 0 {
		t.Fatal("expected the external reward to be paid out")
	}

	resolver, err = getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	uassert.Equal(t, barBefore+toUser, TokenBalance(t, barPath, addr01))
	uassert.Equal(t, gnsBefore, gns.BalanceOf(addr01))
	uassert.Equal(t, internalLastCollectBefore, resolver.InternalRewardLastCollectTime())
	uassert.Equal(t, collectedInternalBefore, resolver.CollectedInternalReward())

	collectableBar, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(0), collectableBar)
}

// Collecting one external incentive must leave every other incentive of the same deposit untouched.
func TestCollectExternalIncentiveReward_LeavesOtherIncentivesCollectable(cur realm, t *testing.T) {
	positionId, barIncentiveId, bazIncentiveId := setupSplitCollectDeposit(cur, t)

	collectableBaz, err := sr.CollectableExternalIncentiveReward(positionId, bazIncentiveId)
	uassert.NoError(t, err)
	if collectableBaz == 0 {
		t.Fatal("expected the other incentive to be collectable before the single collect")
	}

	resolver, err := getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	bazLastCollectBefore := resolver.ExternalRewardLastCollectTime(bazIncentiveId)

	testing.SetRealm(testing.NewUserRealm(addr01))
	bazBefore := TokenBalance(t, bazPath, addr01)

	sr.CollectExternalIncentiveReward(cross(cur), positionId, barIncentiveId)

	resolver, err = getMockInstance().getDepositResolver(positionId)
	uassert.NoError(t, err)
	uassert.Equal(t, bazBefore, TokenBalance(t, bazPath, addr01))
	uassert.Equal(t, bazLastCollectBefore, resolver.ExternalRewardLastCollectTime(bazIncentiveId))

	collectableBazAfter, err := sr.CollectableExternalIncentiveReward(positionId, bazIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, collectableBaz, collectableBazAfter)

	// The other incentive is still deliverable afterwards.
	toUser, _ := sr.CollectExternalIncentiveReward(cross(cur), positionId, bazIncentiveId)
	if toUser == 0 {
		t.Fatal("expected the other incentive to remain collectable")
	}

	uassert.Equal(t, bazBefore+toUser, TokenBalance(t, bazPath, addr01))
}

// An incentive that does not belong to the pool the position is staked in must be rejected instead of
// silently collecting nothing.
func TestCollectExternalIncentiveReward_RejectsIncentiveOfAnotherPool(cur realm, t *testing.T) {
	positionId, _, _ := setupSplitCollectDeposit(cur, t)

	otherPoolPath := pl.GetPoolPath(barPath, quxPath, fee3000)
	testing.SetRealm(adminRealm)
	CreatePool(cur, barPath, quxPath, fee3000, "79228162514264337593543950336", adminAddr)

	// The deposit setup already advanced the chain, so the new incentive needs a fresh start time.
	startTimestamp := time.Now().AddDate(0, 0, 2).Truncate(24 * time.Hour).Unix()
	CreateExternalIncentiveAsAdmin(
		cur, t,
		otherPoolPath,
		barPath,
		rewardMinimumAmount,
		startTimestamp,
		startTimestamp+incentiveDuration,
	)

	otherIncentiveId := ""
	getMockInstance().getExternalIncentives().tree.Iterate("", "", func(key string, value any) bool {
		incentive := value.(*sr.ExternalIncentive)
		if incentive.TargetPoolPath() == otherPoolPath {
			otherIncentiveId = key
			return true
		}
		return false
	})

	if otherIncentiveId == "" {
		t.Fatal("expected the other pool's incentive to be created")
	}

	testing.SetRealm(testing.NewUserRealm(addr01))
	uassert.AbortsWithMessage(t, cur,
		makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf(
				"incentiveId(%s) targets pool(%s), but positionId(%d) is staked in pool(%s)",
				otherIncentiveId, otherPoolPath, positionId, pl.GetPoolPath(barPath, bazPath, fee3000),
			),
		).Error(),
		func() {
			sr.CollectExternalIncentiveReward(cross(cur), positionId, otherIncentiveId)
		})
}

// newTestCollectContext mirrors stakerV1.newCollectContext for tests. It exists because
// newCollectContext derives the event fields from rlm.Previous(), which a test cannot reach once
// testing.SetRealm has installed an origin-caller override.
func newTestCollectContext(t *testing.T, s *stakerV1, positionId uint64) *collectContext {
	t.Helper()

	deposit := s.getDeposits().get(positionId)

	pool, ok := s.getPools().Get(deposit.TargetPoolPath())
	if !ok {
		t.Fatal("expected the staked pool to exist")
	}

	currentTime := time.Now().Unix()
	poolResolver := NewPoolResolver(pool)
	globalAccX128, stakedLiquidity := poolResolver.globalRewardRatioAccumulationAt(currentTime)

	lowerTickResolver := NewTickResolver(poolResolver.GetOrNewTick(deposit.TickLower()))
	upperTickResolver := NewTickResolver(poolResolver.GetOrNewTick(deposit.TickUpper()))

	return &collectContext{
		positionId:      positionId,
		deposit:         deposit,
		depositResolver: NewDepositResolver(deposit),

		currentTime: currentTime,
		blockHeight: runtime.ChainHeight(),

		prevAddr:  addr01.String(),
		prevRealm: "",

		stakedLiquidity:     stakedLiquidity,
		globalAccX128:       globalAccX128,
		lowerOutsideAccX128: lowerTickResolver.CurrentOutsideAccumulation(currentTime),
		upperOutsideAccX128: upperTickResolver.CurrentOutsideAccumulation(currentTime),
	}
}

// A warmup ratio below 100% floors the user reward, so a small accrual produces a zero user reward
// together with a non-zero penalty. This is the input state deliverExternalIncentiveReward's zero-reward
// early return has to cope with, so pin it down before asserting what that early return does.
func TestApplyWarmup_SmallRewardFloorsToZeroWithPenalty(cur realm, t *testing.T) {
	positionId, _, _ := setupSplitCollectDeposit(cur, t)

	s := getMockInstance()
	deposit := s.getDeposits().get(positionId)

	pool, ok := s.getPools().Get(deposit.TargetPoolPath())
	if !ok {
		t.Fatal("expected the staked pool to exist")
	}

	// Any warmup that does not pay out the full accrual floors a one-unit reward to zero.
	warmupIndex := -1
	for i, warmup := range deposit.Warmups() {
		if warmup.WarmupRatio < 100 {
			warmupIndex = i
			break
		}
	}

	if warmupIndex == -1 {
		t.Fatal("expected the deposit to have a warmup that withholds part of the reward")
	}

	rewardState := NewPoolResolver(pool).RewardStateOf(deposit)
	rewardState.rewards[warmupIndex] = 1
	rewardState.applyWarmup()

	uassert.Equal(t, int64(0), rewardState.rewards[warmupIndex])
	uassert.Equal(t, int64(1), rewardState.penalties[warmupIndex])
}

// Regression test for the zero-reward early return of deliverExternalIncentiveReward.
//
// When the warmup floors the user reward to zero while leaving a penalty, the whole delivery is skipped:
// the penalty is NOT booked on the incentive and the per-incentive lastCollectTime is NOT advanced. That
// is deliberate rather than a dropped penalty - the untouched accrual is recalculated over the wider
// window of the next collect, which is asserted here by collecting for real afterwards.
func TestDeliverExternalIncentiveReward_ZeroRewardWithPenaltyIsDeferred(cur realm, t *testing.T) {
	positionId, barIncentiveId, _ := setupSplitCollectDeposit(cur, t)

	s := getMockInstance()
	incentiveResolver := NewExternalIncentiveResolver(s.getExternalIncentives().get(barIncentiveId))

	rewardAmountBefore := incentiveResolver.RewardAmount()
	distributedBefore := incentiveResolver.DistributedRewardAmount()
	penaltyBefore := incentiveResolver.AccumulatedPenaltyAmount()

	depositResolver, err := s.getDepositResolver(positionId)
	uassert.NoError(t, err)
	lastCollectBefore := depositResolver.ExternalRewardLastCollectTime(barIncentiveId)
	collectedBefore := depositResolver.CollectedExternalReward(barIncentiveId)

	collectableBefore, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	if collectableBefore == 0 {
		t.Fatal("expected an external reward to be collectable before the skipped delivery")
	}

	testing.SetRealm(testing.NewUserRealm(addr01))
	barBefore := TokenBalance(t, barPath, addr01)

	ctx := newTestCollectContext(t, s, positionId)
	rewardToken, rewardAmount, rewardPenalty := s.deliverExternalIncentiveReward(0, cur, ctx, barIncentiveId, 0, 1000)

	// A skipped incentive is reported by an empty reward token and zero amounts.
	uassert.Equal(t, "", rewardToken)
	uassert.Equal(t, int64(0), rewardAmount)
	uassert.Equal(t, int64(0), rewardPenalty)

	// Neither the incentive nor the deposit was touched, so nothing was consumed by the skipped call.
	incentiveResolver = NewExternalIncentiveResolver(s.getExternalIncentives().get(barIncentiveId))
	uassert.Equal(t, rewardAmountBefore, incentiveResolver.RewardAmount())
	uassert.Equal(t, distributedBefore, incentiveResolver.DistributedRewardAmount())
	uassert.Equal(t, penaltyBefore, incentiveResolver.AccumulatedPenaltyAmount())

	depositResolver, err = s.getDepositResolver(positionId)
	uassert.NoError(t, err)
	uassert.Equal(t, lastCollectBefore, depositResolver.ExternalRewardLastCollectTime(barIncentiveId))
	uassert.Equal(t, collectedBefore, depositResolver.CollectedExternalReward(barIncentiveId))
	uassert.Equal(t, barBefore, TokenBalance(t, barPath, addr01))

	collectableAfter, err := sr.CollectableExternalIncentiveReward(positionId, barIncentiveId)
	uassert.NoError(t, err)
	uassert.Equal(t, collectableBefore, collectableAfter)

	// The deferred accrual is still deliverable: the reward and the penalty are recalculated from the
	// untouched lastCollectTime and booked by the next collect.
	testing.SetRealm(testing.NewUserRealm(addr01))
	toUser, penalty := sr.CollectExternalIncentiveReward(cross(cur), positionId, barIncentiveId)
	if toUser == 0 {
		t.Fatal("expected the deferred external reward to remain collectable")
	}

	uassert.Equal(t, barBefore+toUser, TokenBalance(t, barPath, addr01))

	incentiveResolver = NewExternalIncentiveResolver(s.getExternalIncentives().get(barIncentiveId))
	uassert.Equal(t, distributedBefore+toUser, incentiveResolver.DistributedRewardAmount())
	uassert.Equal(t, penaltyBefore+penalty, incentiveResolver.AccumulatedPenaltyAmount())
	uassert.Equal(t, rewardAmountBefore-toUser-penalty, incentiveResolver.RewardAmount())
}
