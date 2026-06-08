package v1

import (
	"chain"
	"chain/runtime"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	en "gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	sr "gno.land/r/gnoswap/staker"
)

// CreateExternalIncentive creates an external incentive program for a pool.
//
// Parameters:
//   - targetPoolPath: pool to incentivize
//   - rewardToken: reward token path
//   - rewardAmount: total reward amount
//   - startTimestamp, endTimestamp: incentive period
//
// Only callable by users.
func (s *stakerV1) CreateExternalIncentive(
	_ int,
	rlm realm,
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedStaker()

	prevRealm := rlm.Previous()
	caller := prevRealm.Address()
	access.AssertIsUser(0, prevRealm)

	assertIsPoolExists(s, targetPoolPath)

	assertIsGreaterThanMinimumRewardAmount(s, rewardToken, rewardAmount)
	assertIsAllowedForExternalReward(s, targetPoolPath, rewardToken)
	assertIsValidIncentiveStartTime(startTimestamp)
	assertIsValidIncentiveEndTime(endTimestamp)
	assertIsValidIncentiveDuration(safeSubInt64(endTimestamp, startTimestamp))
	// assert that the user has sent the correct amount of native coin
	common.AssertIsNotHandleNativeCoin()

	en.MintAndDistributeGns(cross(rlm))

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	// transfer reward token from user to staker
	common.SafeGRC20TransferFrom(cross(rlm), rewardToken, caller, stakerAddr, rewardAmount)

	depositGnsAmount := s.store.GetDepositGnsAmount()

	// deposit gns amount
	gns.TransferFrom(cross(rlm), caller, stakerAddr, depositGnsAmount)

	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	incentiveId := s.store.NextIncentiveID(caller, currentTime)
	pool := s.getPools().GetPoolOrNil(targetPoolPath)
	if pool == nil {
		pool = sr.NewPool(targetPoolPath, currentTime)
		s.getPools().set(targetPoolPath, pool)
	}

	incentive := sr.NewExternalIncentive(
		incentiveId,
		targetPoolPath,
		rewardToken,
		rewardAmount,
		startTimestamp,
		endTimestamp,
		caller,
		depositGnsAmount,
		currentHeight,
		currentTime,
	)

	externalIncentives := s.store.GetExternalIncentives()
	if externalIncentives.Has(incentiveId) {
		panic(makeErrorWithDetails(
			errIncentiveAlreadyExists,
			ufmt.Sprintf("incentiveId(%s)", incentiveId),
		))
	}
	// store external incentive information for each incentiveId
	externalIncentives.Set(incentiveId, incentive)

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().create(incentive)

	// add incentive to time-based index for lazy discovery during CollectReward
	s.addIncentiveIdByCreationTime(0, rlm, targetPoolPath, incentiveId, currentTime)

	chain.Emit(
		"CreateExternalIncentive",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", formatAnyInt(rewardAmount),
		"startTimestamp", formatAnyInt(startTimestamp),
		"endTimestamp", formatAnyInt(endTimestamp),
		"depositGnsAmount", formatAnyInt(depositGnsAmount),
		"currentHeight", formatAnyInt(currentHeight),
		"currentTime", formatAnyInt(currentTime),
	)
}

// EndExternalIncentive ends an external incentive and refunds remaining rewards.
//
// Finalizes incentive program after end timestamp.
// Returns unallocated rewards and GNS deposit.
// Calculates unclaimable rewards for refund.
//
// Parameters:
//   - targetPoolPath: Pool with the incentive
//   - incentiveId: Unique incentive identifier
//
// Process:
//  1. Validates incentive end time reached
//  2. Calculates remaining and unclaimable rewards
//  3. Refunds rewards to original creator
//  4. Returns 100 GNS deposit
//  5. Removes incentive from active list
//
// Only callable by Creator or Admin.
func (s *stakerV1) EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedWithdraw()

	// checks pool registry
	assertIsPoolExists(s, targetPoolPath)
	assertIsValidAddress(refundAddress)

	// checks if the pool has been incentivized
	pool, exists := s.getPools().Get(targetPoolPath)
	if !exists {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	// Get incentive to check if GNS already refunded
	incentiveResolver, exists := incentivesResolver.GetIncentiveResolver(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end non existent incentive(%s)", incentiveId),
		))
	}

	// Check if incentive has already been refunded
	if incentiveResolver.Refunded() {
		panic(makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("incentive(%s) has already been refunded", incentiveId),
		))
	}

	caller := rlm.Previous().Address()

	// Process ending
	incentive, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, caller, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	poolLeftExternalRewardAmount := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		previousRealm := rlm.Previous()
		chain.Emit(
			"EndExternalIncentiveShortfall",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"incentiveId", incentiveId,
			"targetPoolPath", targetPoolPath,
			"refundee", refundAddress.String(),
			"refundToken", incentiveResolver.RewardToken(),
			"expectedRefundAmount", formatAnyInt(refund),
			"actualRefundAmount", formatAnyInt(poolLeftExternalRewardAmount),
			"creator", incentiveResolver.Creator().String(),
		)
		refund = poolLeftExternalRewardAmount
	}

	// Mark incentive as refunded and update
	// After this update, attempts to re-claim GNS or rewards that were deposited
	// through the `endExternalIncentive` function will be blocked.
	incentiveResolver.SetRefunded(true)
	incentiveResolver.addDistributedRewardAmount(refund)
	incentivesResolver.update(incentive)

	// refund reward token to refundee
	common.SafeGRC20Transfer(cross(rlm), incentiveResolver.RewardToken(), refundAddress, refund)

	// Transfer GNS deposit back to refundee
	gns.Transfer(cross(rlm), refundAddress, incentiveResolver.DepositGnsAmount())

	previousRealm := rlm.Previous()
	chain.Emit(
		"EndExternalIncentive",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"refundee", refundAddress.String(),
		"refundToken", incentiveResolver.RewardToken(),
		"refundAmount", formatAnyInt(refund),
		"refundGnsAmount", formatAnyInt(incentiveResolver.DepositGnsAmount()),
		"externalIncentiveEndBy", previousRealm.Address().String(),
		"creator", incentiveResolver.Creator().String(),
	)
}

// endExternalIncentive processes the end of an external incentive program.
func (s *stakerV1) endExternalIncentive(resolver *PoolResolver, incentiveResolver *ExternalIncentiveResolver, caller address, currentTime int64) (*sr.ExternalIncentive, int64, error) {
	if currentTime < incentiveResolver.EndTimestamp() {
		return nil, 0, makeErrorWithDetails(
			errCannotEndIncentive,
			ufmt.Sprintf("cannot end incentive before endTime(%d), current(%d)", incentiveResolver.EndTimestamp(), currentTime),
		)
	}

	// only creator or admin can end incentive
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentiveResolver.Creator() {
		adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
		return nil, 0, makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf(
				"only creator(%s) or admin(%s) can end incentive, but called from %s",
				incentiveResolver.Creator(), adminAddr.String(), caller,
			),
		)
	}

	// refund = unclaimableReward + remainder + accumulatedPenaltyAmount
	incentivesResolver := resolver.IncentivesResolver()
	unclaimableReward := incentivesResolver.calculateUnclaimableReward(incentiveResolver.IncentiveId())

	duration := safeSubInt64(incentiveResolver.EndTimestamp(), incentiveResolver.StartTimestamp())
	// distributable = floor((rewardPerSecondX128 * duration) / 2^128).
	// With Q128 scaling the truncation per second collapses to at most 1 wei
	// across the entire duration, so `remainder` is effectively zero and the
	// refund accounts only for unclaimable periods.
	distributableU256 := u256.MulDiv(
		incentiveResolver.RewardPerSecondX128(),
		u256.NewUintFromInt64(duration),
		q128,
	)

	distributable := safeConvertToInt64(distributableU256)
	remainder := safeSubInt64(incentiveResolver.TotalRewardAmount(), distributable)

	refund := safeAddInt64(unclaimableReward, remainder)

	maxRefund := safeSubInt64(incentiveResolver.TotalRewardAmount(), incentiveResolver.DistributedRewardAmount())
	if refund > maxRefund {
		refund = maxRefund
	}

	if refund < 0 {
		return nil, 0, makeErrorWithDetails(
			errCalculationError,
			ufmt.Sprintf("refund should never be negative: Got %d", refund),
		)
	}

	return incentiveResolver.ExternalIncentive, refund, nil
}

// CollectExternalIncentivePenalty collects accumulated warmup penalties
// for a specific ended external incentive.
// Penalties are accumulated during CollectReward and stored in the incentive.
// This function transfers the accumulated penalty to the specified refund address.
// Returns the penalty amount collected.
//
// Only callable by the incentive creator or admin.
func (s *stakerV1) CollectExternalIncentivePenalty(
	_ int,
	rlm realm,
	targetPoolPath string,
	incentiveId string,
	refundAddress address,
) int64 {
	if !rlm.IsCurrent() {
		panic(errSpoofedRealm)
	}

	halt.AssertIsNotHaltedWithdraw()

	assertIsPoolExists(s, targetPoolPath)
	assertIsValidAddress(refundAddress)

	pool, exists := s.getPools().Get(targetPoolPath)
	if !exists {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("targetPoolPath(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentivesResolver := poolResolver.IncentivesResolver()

	incentiveResolver, exists := incentivesResolver.GetIncentiveResolver(incentiveId)
	if !exists {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentive(%s) not found", incentiveId),
		))
	}

	if !incentiveResolver.Refunded() {
		panic(makeErrorWithDetails(
			errIsNotEndedIncentive,
			ufmt.Sprintf("incentive(%s) must be ended first (call EndExternalIncentive)", incentiveId),
		))
	}

	caller := rlm.Previous().Address()
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentiveResolver.Creator() {
		adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("only creator(%s) or admin(%s) can collect penalty, but called from %s", incentiveResolver.Creator(), adminAddr.String(), caller),
		))
	}

	penaltyAmount := incentiveResolver.AccumulatedPenaltyAmount()
	if penaltyAmount == 0 {
		return 0
	}

	// Cap by actual staker balance
	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	balance := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
	if balance < penaltyAmount {
		previousRealm := rlm.Previous()
		chain.Emit(
			"CollectExternalIncentivePenaltyShortfall",
			"prevAddr", previousRealm.Address().String(),
			"prevRealm", previousRealm.PkgPath(),
			"targetPoolPath", targetPoolPath,
			"incentiveId", incentiveId,
			"refundAddress", refundAddress.String(),
			"refundToken", incentiveResolver.RewardToken(),
			"expectedPenaltyAmount", formatAnyInt(penaltyAmount),
			"actualPenaltyAmount", formatAnyInt(balance),
			"creator", incentiveResolver.Creator().String(),
		)
		penaltyAmount = balance
	}

	// Reset accumulated penalty
	incentiveResolver.SetAccumulatedPenaltyAmount(safeSubInt64(incentiveResolver.AccumulatedPenaltyAmount(), penaltyAmount))
	incentivesResolver.update(incentiveResolver.ExternalIncentive)

	// Transfer penalty to refund address
	common.SafeGRC20Transfer(cross(rlm), incentiveResolver.RewardToken(), refundAddress, penaltyAmount)

	previousRealm := rlm.Previous()
	chain.Emit(
		"CollectExternalIncentivePenalty",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"targetPoolPath", targetPoolPath,
		"incentiveId", incentiveId,
		"refundAddress", refundAddress.String(),
		"penaltyAmount", formatAnyInt(penaltyAmount),
	)

	return penaltyAmount
}

// addIncentiveIdByCreationTime adds an external incentive to the time-based index.
//
// The index structure is:
//   - creationTime (int64) -> poolPath (string) -> []incentiveIds
func (s *stakerV1) addIncentiveIdByCreationTime(_ int, rlm realm, poolPath, incentiveId string, creationTime int64) {
	incentivesByTime := s.getExternalIncentivesByCreationTime()

	// Rebuild the nested poolPath -> []incentiveId tree into a freshly allocated
	// bptree on every call instead of mutating the one fetched out of the
	// persisted UintTree. A persisted nested tree is owned by /r/gnoswap/staker
	// and a direct bptree.Set on it from a different calling realm trips the
	// readonly-taint gate (the bptree Set runs in the caller's realm, not the
	// tree's owning realm). Allocating a fresh tree here makes it owned by the
	// executing realm, so its leaf writes are always permitted; re-Setting all
	// existing entries preserves the stored shape.
	freshPoolIncentiveIds := sr.NewBPTreeN(16)
	found := false

	if currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(creationTime); exists {
		currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*bptree.BPTree)
		if !ok {
			panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected *bptree.BPTree, got %T", currentPoolIncentiveIdsValue))
		}

		currentPoolIncentiveIds.Iterate("", "", func(key string, value any) bool {
			incentiveIds, ok := value.([]string)
			if !ok {
				panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected []string, got %T", value))
			}

			copied := make([]string, len(incentiveIds))
			copy(copied, incentiveIds)
			if key == poolPath {
				copied = append(copied, incentiveId)
				found = true
			}
			freshPoolIncentiveIds.Set(key, copied)
			return false
		})
	}

	if !found {
		freshPoolIncentiveIds.Set(poolPath, []string{incentiveId})
	}

	incentivesByTime.Set(creationTime, freshPoolIncentiveIds)

	s.updateExternalIncentivesByCreationTime(0, rlm, incentivesByTime)
}
