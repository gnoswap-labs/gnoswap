package v1

import (
	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	sr "gno.land/r/gnoswap/staker"
)

// getPoolByPoolPath retrieves the pool by its path.
func (s *stakerV1) getPoolByPoolPath(poolPath string) *sr.Pool {
	result, ok := s.store.GetPools().Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	pool, ok := result.(*sr.Pool)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	return pool
}

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
func (s *stakerV1) GetPoolIncentiveIdList(poolPath string) []string {
	pool := s.getPoolByPoolPath(poolPath)

	incentives := pool.Incentives()

	ids := []string{}
	incentives.IncentiveTrees().Iterate("", "", func(key string, value any) bool {
		ids = append(ids, key)
		return false
	})

	return ids
}

// getIncentive retrieves an external incentive by ID.
func (s *stakerV1) getIncentive(poolPath string, incentiveId string) *sr.ExternalIncentive {
	pool := s.getPoolByPoolPath(poolPath)

	incentives := pool.Incentives()
	incentive, exist := incentives.IncentiveTrees().Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	ictv, ok := incentive.(*sr.ExternalIncentive)
	if !ok {
		panic(ufmt.Sprintf("failed to cast incentive to *ExternalIncentive: %T", incentive))
	}
	return ictv
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func (s *stakerV1) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.StartTimestamp()
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func (s *stakerV1) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.EndTimestamp()
}

// GetTargetPoolPathByIncentiveId returns the target pool path of an incentive.
func (s *stakerV1) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.TargetPoolPath()
}

// GetCreatedHeightOfIncentive returns the creation height of an incentive.
func (s *stakerV1) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.CreatedHeight()
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func (s *stakerV1) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardToken()
}

// GetIncentiveRewardAmount returns the reward amount of an incentive.
func (s *stakerV1) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	incentive := s.getIncentive(poolPath, incentiveId)

	return u256.NewUintFromInt64(incentive.RewardAmount())
}

// GetIncentiveRewardAmountAsString returns the reward amount of an incentive as string.
func (s *stakerV1) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	rewardAmount := s.GetIncentiveRewardAmount(poolPath, incentiveId)

	return rewardAmount.ToString()
}

// GetIncentiveRewardPerSecond returns the reward per second of an incentive.
func (s *stakerV1) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardPerSecond()
}

// GetIncentiveRefundee returns the refundee address of an incentive.
func (s *stakerV1) GetIncentiveRefundee(poolPath string, incentiveId string) address {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.Refundee()
}

// getDeposit retrieves a deposit by LP token ID.
func (s *stakerV1) getDeposit(lpTokenId uint64) *sr.Deposit {
	deposit := s.getDeposits().get(lpTokenId)
	if deposit == nil {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId)),
		)
	}

	return deposit
}

// GetDepositOwner returns the owner of a deposit.
func (s *stakerV1) GetDepositOwner(lpTokenId uint64) address {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Owner()
}

// GetDepositStakeTime returns the stake time of a deposit.
func (s *stakerV1) GetDepositStakeTime(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.StakeTime()
}

// GetDepositTargetPoolPath returns the target pool path of a deposit.
func (s *stakerV1) GetDepositTargetPoolPath(lpTokenId uint64) string {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TargetPoolPath()
}

// GetDepositTickLower returns the lower tick of a deposit.
func (s *stakerV1) GetDepositTickLower(lpTokenId uint64) int32 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TickLower()
}

// GetDepositTickUpper returns the upper tick of a deposit.
func (s *stakerV1) GetDepositTickUpper(lpTokenId uint64) int32 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.TickUpper()
}

// GetDepositLiquidity returns the liquidity of a deposit.
func (s *stakerV1) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Liquidity().Clone()
}

// GetDepositLiquidityAsString returns the liquidity of a deposit as string.
func (s *stakerV1) GetDepositLiquidityAsString(lpTokenId uint64) string {
	liquidity := s.GetDepositLiquidity(lpTokenId)

	return liquidity.ToString()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.InternalRewardLastCollectTime()
}

// GetDepositExternalRewardLastCollectTimestamp returns the last collect timestamp of a deposit.
func (s *stakerV1) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return s.getDepositResolver(lpTokenId).ExternalRewardLastCollectTime(incentiveId)
}

// GetDepositWarmUp returns the warm-up records of a deposit.
func (s *stakerV1) GetDepositWarmUp(lpTokenId uint64) []sr.Warmup {
	deposit := s.getDeposit(lpTokenId)

	return deposit.Warmups()
}

// GetPoolTier returns the tier of a pool.
func (s *stakerV1) GetPoolTier(poolPath string) uint64 {
	return s.getPoolTier().CurrentTier(poolPath)
}

// GetPoolTierRatio returns the current reward ratio for a pool's tier.
func (s *stakerV1) GetPoolTierRatio(poolPath string) uint64 {
	tier := s.GetPoolTier(poolPath)
	ratio, err := s.getPoolTier().tierRatio.Get(tier)
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPoolTier, err.Error()))
	}

	return ratio
}

// GetPoolTierCount returns the number of pools in a tier.
func (s *stakerV1) GetPoolTierCount(tier uint64) uint64 {
	if tier == 0 {
		return 0
	}
	return uint64(s.getPoolTier().CurrentCount(tier))
}

// GetPoolReward returns the current reward amount for a tier.
func (s *stakerV1) GetPoolReward(tier uint64) int64 {
	return s.getPoolTier().CurrentReward(tier)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func (s *stakerV1) GetExternalIncentiveByPoolPath(poolPath string) []sr.ExternalIncentive {
	incentives := []sr.ExternalIncentive{}
	s.store.GetExternalIncentives().Iterate("", "", func(_ string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}
		if incentive.TargetPoolPath() == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})

	return incentives
}
