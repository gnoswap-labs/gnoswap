package staker

import (
	"chain/runtime"
	"time"

	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"

	sr "gno.land/r/gnoswap/staker"
)

// findPoolByPoolPath retrieves the pool by its path, or nil when it does not
// exist. Read-only views use it so a missing pool reads as nil rather than
// aborting the caller's transaction.
func (s *stakerV1) findPoolByPoolPath(poolPath string) *sr.Pool {
	result := s.store.GetPools().Get(poolPath)
	if result == nil {
		return nil
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		return nil
	}

	return pool
}

// getPoolByPoolPath retrieves the pool by its path.
func (s *stakerV1) getPoolByPoolPath(poolPath string) (*sr.Pool, error) {
	result := s.store.GetPools().Get(poolPath)
	if result == nil {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath),
		)
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath),
		)
	}

	return pool, nil
}

// GetPool returns the pool for the given path.
func (s *stakerV1) GetPool(poolPath string) (*sr.Pool, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}
	return pool, nil
}

// getIncentive retrieves an external incentive by ID.
func (s *stakerV1) getIncentive(poolPath string, incentiveId string) (*sr.ExternalIncentive, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}

	incentives := pool.Incentives()
	incentive := incentives.IncentiveTrees().Get(incentiveId)
	if incentive == nil {
		return nil, ufmt.Errorf("incentiveId(%s) incentive does not exist", incentiveId)
	}

	ictv, ok := incentive.(*sr.ExternalIncentive)
	if !ok {
		return nil, ufmt.Errorf("failed to cast incentive to *ExternalIncentive: %T", incentive)
	}
	return ictv, nil
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func (s *stakerV1) GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.StartTimestamp(), nil
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func (s *stakerV1) GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.EndTimestamp(), nil
}

// GetTargetPoolPathByIncentiveId returns the target pool path of an incentive.
func (s *stakerV1) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return incentive.TargetPoolPath(), nil
}

// GetCreatedHeightOfIncentive returns the creation height of an incentive.
func (s *stakerV1) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.CreatedHeight(), nil
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
func (s *stakerV1) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.CreatedTimestamp(), nil
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
func (s *stakerV1) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.TotalRewardAmount(), nil
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
func (s *stakerV1) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.DistributedRewardAmount(), nil
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
func (s *stakerV1) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.RewardAmount(), nil
}

// GetIncentiveAccumulatedPenaltyAmount returns the accumulated warmup penalty amount of an incentive.
func (s *stakerV1) GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.AccumulatedPenaltyAmount(), nil
}

// GetIncentiveDepositGnsAmount returns the deposit GNS amount of an incentive.
func (s *stakerV1) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return 0, err
	}

	return incentive.DepositGnsAmount(), nil
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
func (s *stakerV1) GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return false, err
	}

	return incentive.Refunded(), nil
}

// IsIncentiveActive returns whether an incentive is currently active.
func (s *stakerV1) IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return false, err
	}
	currentTime := time.Now().Unix()

	resolver := NewExternalIncentiveResolver(incentive)
	return resolver.isActive(currentTime) && !resolver.Refunded(), nil
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func (s *stakerV1) GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return incentive.RewardToken(), nil
}

// GetIncentiveRewardAmount returns the reward amount of an incentive.
func (s *stakerV1) GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}

	return u256.NewUintFromInt64(incentive.RewardAmount()), nil
}

// GetIncentiveRewardAmountAsString returns the reward amount of an incentive as string.
func (s *stakerV1) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	rewardAmount, err := s.GetIncentiveRewardAmount(poolPath, incentiveId)
	if err != nil {
		return "", err
	}

	return rewardAmount.ToString(), nil
}

// GetIncentiveRewardPerSecondX128 returns the Q128-scaled reward per second of
// an incentive (i.e. actual rate = value / 2^128). The Q128 form preserves
// sub-second precision that would otherwise be lost to int64 truncation.
func (s *stakerV1) GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}

	return incentive.RewardPerSecondX128(), nil
}

// GetIncentiveCreator returns the creator address of an incentive.
func (s *stakerV1) GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	incentive, err := s.getIncentive(poolPath, incentiveId)
	if err != nil {
		return address(""), err
	}

	return incentive.Creator(), nil
}

// getDeposit retrieves a deposit by LP token ID.
func (s *stakerV1) getDeposit(lpTokenId uint64) (*sr.Deposit, error) {
	deposits := s.getDeposits()
	if !deposits.Has(lpTokenId) {
		return nil, makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId),
		)
	}

	return deposits.get(lpTokenId), nil
}

// GetDeposit returns the deposit for the given LP token ID.
func (s *stakerV1) GetDeposit(lpTokenId uint64) (*sr.Deposit, error) {
	return s.getDeposit(lpTokenId)
}

// CollectableEmissionReward returns the claimable internal reward amount for a position.
// calculateCollectablePositionReward is read-only, so querying a collectable amount never mutates state.
func (s *stakerV1) CollectableEmissionReward(positionId uint64) (int64, error) {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	if _, err := s.getDeposit(positionId); err != nil {
		return 0, err
	}
	reward := s.calculateCollectablePositionReward(currentHeight, currentTime, positionId)
	return reward.Internal, nil
}

// CollectableExternalIncentiveReward returns the claimable external reward amount for an incentive.
// calculateCollectablePositionReward is read-only, so querying a collectable amount never mutates state.
func (s *stakerV1) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	if _, err := s.getDeposit(positionId); err != nil {
		return 0, err
	}
	reward := s.calculateCollectablePositionReward(currentHeight, currentTime, positionId)
	amount, ok := reward.External[incentiveId]
	if !ok {
		return 0, nil
	}
	return amount, nil
}

// GetDepositOwner returns the owner of a deposit.
func (s *stakerV1) GetDepositOwner(lpTokenId uint64) (address, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return address(""), err
	}

	return deposit.Owner(), nil
}

// GetDepositStakeTime returns the stake time of a deposit.
func (s *stakerV1) GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.StakeTime(), nil
}

// GetDepositTargetPoolPath returns the target pool path of a deposit.
func (s *stakerV1) GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return "", err
	}

	return deposit.TargetPoolPath(), nil
}

// GetDepositTickLower returns the lower tick of a deposit.
func (s *stakerV1) GetDepositTickLower(lpTokenId uint64) (int32, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.TickLower(), nil
}

// GetDepositTickUpper returns the upper tick of a deposit.
func (s *stakerV1) GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.TickUpper(), nil
}

// GetDepositLiquidity returns the liquidity of a deposit.
func (s *stakerV1) GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.Liquidity(), nil
}

// GetDepositLiquidityAsString returns the liquidity of a deposit as string.
func (s *stakerV1) GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	liquidity, err := s.GetDepositLiquidity(lpTokenId)
	if err != nil {
		return "", err
	}

	return liquidity.ToString(), nil
}

// GetDepositInternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.InternalRewardLastCollectTime(), nil
}

// GetDepositCollectedInternalReward returns the collected internal reward amount.
func (s *stakerV1) GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return 0, err
	}

	return deposit.CollectedInternalReward(), nil
}

// GetDepositCollectedExternalReward returns the collected external reward amount for an incentive.
func (s *stakerV1) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	depositResolver, err := s.getDepositResolver(lpTokenId)
	if err != nil {
		return 0, err
	}
	return depositResolver.CollectedExternalReward(incentiveId), nil
}

// GetDepositExternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	depositResolver, err := s.getDepositResolver(lpTokenId)
	if err != nil {
		return 0, err
	}
	return depositResolver.ExternalRewardLastCollectTime(incentiveId), nil
}

// GetDepositWarmUp returns the warm-up records of a deposit.
func (s *stakerV1) GetDepositWarmUp(lpTokenId uint64) ([]sr.Warmup, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.Warmups(), nil
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
func (s *stakerV1) GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	deposit, err := s.getDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}

	return deposit.GetExternalIncentiveIdList(), nil
}

// GetPoolTier returns the tier of a pool.
func (s *stakerV1) GetPoolTier(poolPath string) uint64 {
	return s.getPoolTier().CurrentTier(poolPath)
}

// GetPoolTierRatio returns the current reward ratio for a pool's tier.
func (s *stakerV1) GetPoolTierRatio(poolPath string) (uint64, error) {
	tier := s.GetPoolTier(poolPath)
	ratio, err := s.getPoolTier().tierRatio.Get(tier)
	if err != nil {
		return 0, makeErrorWithDetails(errInvalidPoolTier, err.Error())
	}

	return ratio, nil
}

// GetPoolTierCount returns the number of pools in a tier.
func (s *stakerV1) GetPoolTierCount(tier uint64) uint64 {
	if tier == 0 {
		return 0
	}
	return uint64(s.getPoolTier().CurrentCount(tier))
}

// GetPoolReward returns the current reward amount for a tier.
func (s *stakerV1) GetPoolReward(tier uint64) (int64, error) {
	if tier == 0 || tier >= AllTierCount {
		return 0, makeErrorWithDetails(
			errInvalidPoolTier,
			ufmt.Sprintf("tier(%d) must be between 1 and %d", tier, AllTierCount-1),
		)
	}
	return s.getPoolTier().CurrentReward(tier), nil
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
func (s *stakerV1) GetPoolStakedLiquidity(poolPath string) (string, error) {
	pool, err := s.getPoolByPoolPath(poolPath)
	if err != nil {
		return "", err
	}
	liquidity := NewPoolResolver(pool).CurrentStakedLiquidity(time.Now().Unix())
	if liquidity == nil {
		return u256.Zero().ToString(), nil
	}

	return liquidity.ToString(), nil
}

// GetPoolsByTier returns the list of pools in a tier.
func (s *stakerV1) GetPoolsByTier(tier uint64) ([]string, error) {
	if tier == 0 {
		return []string{}, nil
	}

	pools := make([]string, 0)
	var iterErr error
	s.getPoolTier().membership.Iterate("", "", func(poolPath string, value any) bool {
		currentTier, ok := value.(uint64)
		if !ok {
			iterErr = ufmt.Errorf("failed to cast tier to uint64")
			return true
		}
		if currentTier == tier {
			pools = append(pools, poolPath)
		}
		return false
	})
	if iterErr != nil {
		return nil, iterErr
	}

	return pools, nil
}

// GetTotalEmissionSent returns the total GNS emission sent.
func (s *stakerV1) GetTotalEmissionSent() int64 {
	return s.store.GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive token list.
func (s *stakerV1) GetAllowedTokens() []string {
	return s.store.GetAllowedTokens()
}

// GetWarmupTemplate returns the current warmup template.
func (s *stakerV1) GetWarmupTemplate() []sr.Warmup {
	return s.store.GetWarmupTemplate()
}

// IsStaked returns whether a position is staked.
func (s *stakerV1) IsStaked(positionId uint64) bool {
	return s.getDeposits().Has(positionId)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func (s *stakerV1) GetExternalIncentiveByPoolPath(poolPath string) ([]sr.ExternalIncentive, error) {
	incentives := make([]sr.ExternalIncentive, 0)
	var iterErr error

	s.store.GetExternalIncentives().Iterate("", "", func(_ string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			iterErr = ufmt.Errorf("failed to cast value to *ExternalIncentive")
			return true
		}
		if incentive.TargetPoolPath() == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})
	if iterErr != nil {
		return nil, iterErr
	}

	return incentives, nil
}

// GetPoolRewardCaches returns a read-only view of a pool's reward cache, keyed
// by the encoded block timestamp. nil is returned when the pool does not exist.
func (s *stakerV1) GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.RewardCache().ReadOnly(rewardCacheEntry)
}

// GetPoolIncentives returns a read-only view of a pool's external incentives,
// keyed by incentive ID. nil is returned when the pool does not exist.
func (s *stakerV1) GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return rotree.Wrap(pool.Incentives().IncentiveTrees(), cloneExternalIncentiveEntry)
}

// GetPoolGlobalRewardRatioAccumulations returns a read-only view of a pool's
// global reward ratio accumulation, keyed by the encoded block timestamp.
// nil is returned when the pool does not exist.
func (s *stakerV1) GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.GlobalRewardRatioAccumulation().ReadOnly(accumulationEntry)
}

// GetPoolHistoricalTicks returns a read-only view of a pool's historical ticks,
// keyed by the encoded block timestamp with the int32 tick as the value.
// nil is returned when the pool does not exist.
func (s *stakerV1) GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	pool := s.findPoolByPoolPath(poolPath)
	if pool == nil {
		return nil
	}

	return pool.HistoricalTick().ReadOnly(historicalTickEntry)
}
