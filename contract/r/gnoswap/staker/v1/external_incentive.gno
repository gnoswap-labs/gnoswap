package v1

import (
	"chain"
	"chain/runtime"
	"math"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/ufmt"

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
	assertIsValidUserCoinSend(rewardToken, rewardAmount)

	en.MintAndDistributeGns(cross)

	stakerAddr := access.MustGetAddress(prbac.ROLE_STAKER.String())

	// transfer reward token from user to staker
	isRequestUnwrap := false
	if rewardToken == GNOT_DENOM {
		isRequestUnwrap = true
		rewardToken = WUGNOT_PATH
		err := wrapWithTransfer(stakerAddr, rewardAmount)
		if err != nil {
			panic(err)
		}
	} else {
		common.SafeGRC20TransferFrom(cross, rewardToken, caller, stakerAddr, rewardAmount)
	}

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
		isRequestUnwrap,
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
	poolResolver.IncentivesResolver().create(caller, incentive)

	// add incentive to time-based index for lazy discovery during CollectReward
	s.addIncentiveIdByCreationTime(targetPoolPath, incentiveId, currentTime)

	chain.Emit(
		"CreateExternalIncentive",
		"prevAddr", caller.String(),
		"prevRealm", prevRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"rewardToken", rewardToken,
		"rewardAmount", formatInt(rewardAmount),
		"startTimestamp", formatInt(startTimestamp),
		"endTimestamp", formatInt(endTimestamp),
		"depositGnsAmount", formatInt(depositGnsAmount),
		"currentHeight", formatInt(currentHeight),
		"currentTime", formatInt(currentTime),
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
// Only callable by Refundee or Admin.
func (s *stakerV1) EndExternalIncentive(targetPoolPath, incentiveId string) {
	halt.AssertIsNotHaltedStaker()
	halt.AssertIsNotHaltedWithdraw()

	// checks pool registry
	assertIsPoolExists(s, targetPoolPath)

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

	// handle refund based on original token type
	if incentiveResolver.IsRequestUnwrap() {
		// unwrap to GNOT if originally deposited as native GNOT
		transferErr := unwrapWithTransfer(incentiveResolver.Refundee(), refund)
		if transferErr != nil {
			panic(transferErr)
		}
	} else {
		// keep as WUGNOT or other token if originally deposited as wrapped token
		common.SafeGRC20Transfer(cross, incentiveResolver.RewardToken(), incentiveResolver.Refundee(), refund)
	}

	// Transfer GNS deposit back to refundee
	gns.Transfer(cross, incentiveResolver.Refundee(), incentiveResolver.DepositGnsAmount())

	// Mark incentive as refunded and update
	// After this update, attempts to re-claim GNS or rewards that were deposited
	// through the `endExternalIncentive` function will be blocked.
	incentiveResolver.SetRefunded(true)
	incentiveResolver.addDistributedRewardAmount(refund)
	incentivesResolver.update(incentive.Refundee(), incentive)

	previousRealm := runtime.PreviousRealm()
	chain.Emit(
		"EndExternalIncentive",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"incentiveId", incentiveId,
		"targetPoolPath", targetPoolPath,
		"refundee", incentiveResolver.Refundee().String(),
		"refundToken", incentiveResolver.RewardToken(),
		"refundAmount", formatInt(refund),
		"refundGnsAmount", formatInt(incentiveResolver.DepositGnsAmount()),
		"isRequestUnwrap", formatBool(incentiveResolver.IsRequestUnwrap()),
		"externalIncentiveEndBy", previousRealm.Address().String(),
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

	// only refundee or admin can end incentive
	if !access.IsAuthorized(prbac.ROLE_ADMIN.String(), caller) && caller != incentiveResolver.Refundee() {
		adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
		return nil, 0, makeErrorWithDetails(
			errNoPermission,
			ufmt.Sprintf(
				"only refundee(%s) or admin(%s) can end incentive, but called from %s",
				incentiveResolver.Refundee(), adminAddr.String(), caller,
			),
		)
	}

	totalReward := int64(0)

	// calculate total external reward for the incentive
	s.getDeposits().IterateByPoolPath(0, math.MaxUint64, incentiveResolver.TargetPoolPath(), func(positionId uint64, deposit *sr.Deposit) bool {
		depositResolver := NewDepositResolver(deposit)
		lastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveResolver.IncentiveId())

		if lastCollectTime > incentiveResolver.EndTimestamp() {
			return false
		}

		rewardState := resolver.RewardStateOf(deposit)
		calculatedTotalReward := rewardState.calculateCollectableExternalReward(lastCollectTime, currentTime, incentiveResolver.ExternalIncentive)
		totalReward = safeAddInt64(totalReward, calculatedTotalReward)

		return false
	})

	// calculate refund amount is the difference between the incentive reward amount and the total external reward
	refund := safeSubInt64(incentiveResolver.TotalRewardAmount(), totalReward)
	refund = safeSubInt64(refund, incentiveResolver.DistributedRewardAmount())

	return incentiveResolver.ExternalIncentive, refund, nil
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
