package v1

import (
	"chain"
	"chain/runtime"
	"math"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	avl "gno.land/p/nt/avl/v0"
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
	targetPoolPath string,
	rewardToken string, // token path should be registered
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	halt.AssertIsNotHaltedStaker()

	prevRealm := runtime.PreviousRealm()
	caller := prevRealm.Address()
	access.AssertIsUser(prevRealm)

	assertIsPoolExists(s, targetPoolPath)

	assertIsGreaterThanMinimumRewardAmount(s, rewardToken, rewardAmount)
	assertIsAllowedForExternalReward(s, targetPoolPath, rewardToken)
	assertIsValidIncentiveStartTime(startTimestamp)
	assertIsValidIncentiveEndTime(endTimestamp)
	assertIsValidIncentiveDuration(safeSubInt64(endTimestamp, startTimestamp))
	// assert that the user has sent the correct amount of native coin
	common.AssertIsNotHandleNativeCoin()

	en.MintAndDistributeGns(cross)

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	// transfer reward token from user to staker
	common.SafeGRC20TransferFrom(cross, rewardToken, caller, stakerAddr, rewardAmount)

	depositGnsAmount := s.store.GetDepositGnsAmount()

	// deposit gns amount
	gns.TransferFrom(cross, caller, stakerAddr, depositGnsAmount)

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
	s.addIncentiveIdByCreationTime(targetPoolPath, incentiveId, currentTime)

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
func (s *stakerV1) EndExternalIncentive(targetPoolPath, incentiveId string, refundAddress address) {
	halt.AssertIsNotHaltedStaker()
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

	caller := runtime.PreviousRealm().Address()

	// Process ending
	incentive, refund, err := s.endExternalIncentive(poolResolver, incentiveResolver, caller, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	// remove incentive from time-based index
	s.removeIncentiveIdByCreationTime(targetPoolPath, incentiveId, incentive.CreatedTimestamp())

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())
	poolLeftExternalRewardAmount := common.BalanceOf(incentiveResolver.RewardToken(), stakerAddr)
	if poolLeftExternalRewardAmount < refund {
		refund = poolLeftExternalRewardAmount
	}

	// Mark incentive as refunded and update
	incentiveResolver.SetRefunded(true)
	incentiveResolver.addDistributedRewardAmount(refund)
	incentivesResolver.update(incentive)

	// refund reward token to refundee
	common.SafeGRC20Transfer(cross, incentiveResolver.RewardToken(), refundAddress, refund)

	// Transfer GNS deposit back to refundee
	gns.Transfer(cross, refundAddress, incentiveResolver.DepositGnsAmount())

	previousRealm := runtime.PreviousRealm()
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

	// Simple time-based refund calculation (no position iteration).
	duration := safeSubInt64(incentiveResolver.EndTimestamp(), incentiveResolver.StartTimestamp())
	totalDistributable := safeMulInt64(incentiveResolver.RewardPerSecond(), duration)
	refund := safeSubInt64(incentiveResolver.TotalRewardAmount(), totalDistributable)
	refund = safeSubInt64(refund, incentiveResolver.DistributedRewardAmount())

	if refund < 0 {
		refund = 0
	}

	return incentiveResolver.ExternalIncentive, refund, nil
}

// CollectExternalIncentivePenalty collects penalty rewards from staked positions
// for a specific ended external incentive. Processes up to maxPositions per call.
// Returns the total penalty collected and the number of positions processed.
// Must be called repeatedly until all positions are processed.
func (s *stakerV1) CollectExternalIncentivePenalty(
	targetPoolPath string,
	incentiveId string,
	maxPositions int,
) (int64, int64) {
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	caller := runtime.PreviousRealm().Address()
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) {
		panic(makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf("only admin can collect penalty, called from %s", caller),
		))
	}

	assertIsPoolExists(s, targetPoolPath)

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
			errCannotEndIncentive,
			ufmt.Sprintf("incentive(%s) must be ended first (call EndExternalIncentive)", incentiveId),
		))
	}

	currentTime := time.Now().Unix()
	totalPenalty := int64(0)
	processedCount := int64(0)

	s.getDeposits().IterateByPoolPath(0, math.MaxUint64, targetPoolPath, func(positionId uint64, deposit *sr.Deposit) bool {
		if int(processedCount) >= maxPositions {
			return true // stop iteration
		}

		depositResolver := NewDepositResolver(deposit)
		lastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)

		// Already collected past the incentive end — no penalty to process
		if lastCollectTime > incentiveResolver.EndTimestamp() {
			return false // continue to next
		}

		rewardState := poolResolver.RewardStateOf(deposit)
		rewards, penalties := rewardState.calculateExternalReward(lastCollectTime, currentTime, incentiveResolver.ExternalIncentive)

		penalty := int64(0)
		for _, p := range penalties {
			penalty = safeAddInt64(penalty, p)
		}

		reward := int64(0)
		for _, r := range rewards {
			reward = safeAddInt64(reward, r)
		}

		totalAmount := safeAddInt64(reward, penalty)
		if totalAmount == 0 {
			return false // continue
		}

		incentive := s.getExternalIncentives().get(incentiveId)
		if incentive == nil {
			return false
		}

		if incentive.RewardAmount() < totalAmount {
			return false // insufficient, skip
		}

		// Deduct reward + penalty from incentive balance
		incentive.SetRewardAmount(safeSubInt64(incentive.RewardAmount(), totalAmount))
		incentiveResolver.addDistributedRewardAmount(reward)
		depositResolver.addCollectedExternalReward(incentiveId, totalAmount)

		err := depositResolver.updateExternalRewardLastCollectTime(incentiveId, currentTime)
		if err != nil {
			panic(err)
		}

		if depositResolver.ExternalRewardLastCollectTime(incentiveId) > incentiveResolver.EndTimestamp() {
			deposit.RemoveExternalIncentiveId(incentiveId)
		}

		s.getExternalIncentives().set(incentiveId, incentive)

		// Transfer reward to position owner
		if reward > 0 {
			toUser, _, err := s.handleStakingRewardFee(incentive.RewardToken(), reward, false)
			if err != nil {
				panic(err.Error())
			}
			if toUser > 0 {
				common.SafeGRC20Transfer(cross, incentive.RewardToken(), deposit.Owner(), toUser)
			}
		}

		totalPenalty = safeAddInt64(totalPenalty, penalty)
		processedCount++

		return false // continue
	})

	// Transfer collected penalties to community pool
	if totalPenalty > 0 {
		communityPoolAddr := access.MustGetAddress(prbac.ROLE_COMMUNITY_POOL.String())
		common.SafeGRC20Transfer(cross, incentiveResolver.RewardToken(), communityPoolAddr, totalPenalty)
	}

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"CollectExternalIncentivePenalty",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"targetPoolPath", targetPoolPath,
		"incentiveId", incentiveId,
		"penaltyAmount", formatAnyInt(totalPenalty),
		"processedPositions", formatAnyInt(processedCount),
	)

	return totalPenalty, processedCount
}

// addIncentiveIdByCreationTime adds an external incentive to the time-based index.
//
// The index structure is:
//   - creationTime (int64) -> poolPath (string) -> []incentiveIds
func (s *stakerV1) addIncentiveIdByCreationTime(poolPath, incentiveId string, creationTime int64) {
	incentivesByTime := s.getExternalIncentivesByCreationTime()

	currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(creationTime)
	if !exists {
		currentPoolIncentiveIdsValue = avl.NewTree()
	}

	currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected *avl.Tree, got %T", currentPoolIncentiveIdsValue))
	}

	incentiveIdsValue, exists := currentPoolIncentiveIds.Get(poolPath)
	if !exists {
		incentiveIdsValue = []string{}
	}

	incentiveIds, ok := incentiveIdsValue.([]string)
	if !ok {
		panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected []string, got %T", incentiveIdsValue))
	}

	incentiveIds = append(incentiveIds, incentiveId)
	currentPoolIncentiveIds.Set(poolPath, incentiveIds)
	incentivesByTime.Set(creationTime, currentPoolIncentiveIds)

	s.updateExternalIncentivesByCreationTime(incentivesByTime)
}

// removeIncentiveIdByCreationTime removes an incentive from the time-based index.
// This is called when an external incentive is ended via EndExternalIncentive.
//
// The index structure is:
//   - creationTime (int64) -> poolPath (string) -> []incentiveId
func (s *stakerV1) removeIncentiveIdByCreationTime(poolPath, incentiveId string, creationTime int64) {
	incentivesByTime := s.getExternalIncentivesByCreationTime()

	// check if creation time exists
	currentPoolIncentiveIdsValue, exists := incentivesByTime.Get(creationTime)
	if !exists {
		return
	}

	currentPoolIncentiveIds, ok := currentPoolIncentiveIdsValue.(*avl.Tree)
	if !ok {
		panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected *avl.Tree, got %T", currentPoolIncentiveIdsValue))
	}

	// check if pool path exists at this time
	incentiveIdsValue, exists := currentPoolIncentiveIds.Get(poolPath)
	if !exists {
		return
	}

	incentiveIds, ok := incentiveIdsValue.([]string)
	if !ok {
		panic(ufmt.Sprintf("invalid type in incentivesByTime tree: expected []string, got %T", incentiveIdsValue))
	}

	// if only incentive exists for this pool,remove the entire pool entry
	if len(incentiveIds) == 1 && incentiveIds[0] == incentiveId {
		currentPoolIncentiveIds.Remove(poolPath)

		// if no pools remain at this time, remove the time entry
		if currentPoolIncentiveIds.Size() == 0 {
			incentivesByTime.Remove(creationTime)
		} else {
			incentivesByTime.Set(creationTime, currentPoolIncentiveIds)
		}

		s.updateExternalIncentivesByCreationTime(incentivesByTime)

		return
	}

	// remove only the target incentive from slice
	for index, id := range incentiveIds {
		if id == incentiveId {
			incentiveIds = append(incentiveIds[:index], incentiveIds[index+1:]...)
			break
		}
	}

	currentPoolIncentiveIds.Set(poolPath, incentiveIds)
	incentivesByTime.Set(creationTime, currentPoolIncentiveIds)

	s.updateExternalIncentivesByCreationTime(incentivesByTime)
}
