package v1

import (
	"chain/runtime"
	"time"

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

// GetPool returns the pool for the given path.
func (s *stakerV1) GetPool(poolPath string) *sr.Pool {
	return s.getPoolByPoolPath(poolPath)
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

// GetIncentive returns the incentive for the given pool and ID.
func (s *stakerV1) GetIncentive(poolPath string, incentiveId string) *sr.ExternalIncentive {
	return s.getIncentive(poolPath, incentiveId)
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

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
func (s *stakerV1) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.CreatedTimestamp()
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
func (s *stakerV1) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.TotalRewardAmount()
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
func (s *stakerV1) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.DistributedRewardAmount()
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
func (s *stakerV1) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.RewardAmount()
}

// GetIncentiveDepositGnsAmount returns the deposit GNS amount of an incentive.
func (s *stakerV1) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.DepositGnsAmount()
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
func (s *stakerV1) GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	incentive := s.getIncentive(poolPath, incentiveId)

	return incentive.Refunded()
}

// IsIncentiveActive returns whether an incentive is currently active.
func (s *stakerV1) IsIncentiveActive(poolPath string, incentiveId string) bool {
	incentive := s.getIncentive(poolPath, incentiveId)
	currentTime := time.Now().Unix()

	resolver := NewExternalIncentiveResolver(incentive)
	return resolver.isActive(currentTime) && !resolver.Refunded()
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

// GetDeposit returns the deposit for the given LP token ID.
func (s *stakerV1) GetDeposit(lpTokenId uint64) *sr.Deposit {
	return s.getDeposit(lpTokenId)
}

// CollectableEmissionReward returns the claimable internal reward amount for a position.
func (s *stakerV1) CollectableEmissionReward(positionId uint64) int64 {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	reward := s.calcPositionReward(currentHeight, currentTime, positionId)
	return reward.Internal
}

// CollectableExternalIncentiveReward returns the claimable external reward amount for an incentive.
func (s *stakerV1) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64 {
	currentTime := time.Now().Unix()
	currentHeight := runtime.ChainHeight()
	reward := s.calcPositionReward(currentHeight, currentTime, positionId)
	amount, ok := reward.External[incentiveId]
	if !ok {
		return 0
	}
	return amount
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

// GetDepositStakeTimestamp returns the staking timestamp of a deposit.
func (s *stakerV1) GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.StakeTime()
}

// GetDepositCollectedInternalReward returns the collected internal reward amount.
func (s *stakerV1) GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	deposit := s.getDeposit(lpTokenId)

	return deposit.CollectedInternalReward()
}

// GetDepositCollectedExternalReward returns the collected external reward amount for an incentive.
func (s *stakerV1) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return s.getDepositResolver(lpTokenId).CollectedExternalReward(incentiveId)
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

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
func (s *stakerV1) GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	deposit := s.getDeposit(lpTokenId)

	return deposit.GetExternalIncentiveIdList()
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

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
func (s *stakerV1) GetPoolStakedLiquidity(poolPath string) string {
	pool := s.getPoolByPoolPath(poolPath)
	liquidity := NewPoolResolver(pool).CurrentStakedLiquidity(time.Now().Unix())
	if liquidity == nil {
		return u256.Zero().ToString()
	}

	return liquidity.ToString()
}

// GetPoolsByTier returns the list of pools in a tier.
func (s *stakerV1) GetPoolsByTier(tier uint64) []string {
	if tier == 0 {
		return []string{}
	}

	pools := make([]string, 0)
	s.getPoolTier().membership.Iterate("", "", func(poolPath string, value any) bool {
		currentTier, ok := value.(uint64)
		if !ok {
			panic("failed to cast tier to uint64")
		}
		if currentTier == tier {
			pools = append(pools, poolPath)
		}
		return false
	})

	return pools
}

// GetTotalEmissionSent returns the total GNS emission sent.
func (s *stakerV1) GetTotalEmissionSent() int64 {
	return s.store.GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive token list.
func (s *stakerV1) GetAllowedTokens() []string {
	tokens := s.store.GetAllowedTokens()
	result := make([]string, len(tokens))
	copy(result, tokens)
	return result
}

// GetWarmupTemplate returns the current warmup template.
func (s *stakerV1) GetWarmupTemplate() []sr.Warmup {
	warmups := s.store.GetWarmupTemplate()
	result := make([]sr.Warmup, len(warmups))
	copy(result, warmups)
	return result
}

// GetTotalStakedPositionCount returns the total staked position count.
func (s *stakerV1) GetTotalStakedPositionCount() uint64 {
	total := uint64(0)
	s.getStakers().tree.Iterate("", "", func(_ string, value any) bool {
		depositTree := retrieveDepositTree(value)
		total += uint64(depositTree.Size())
		return false
	})
	return total
}

// GetStakedPositionsByUser returns staked position IDs for a user with pagination.
func (s *stakerV1) GetStakedPositionsByUser(owner address, offset, count int) []uint64 {
	if count <= 0 {
		return []uint64{}
	}
	if offset < 0 {
		offset = 0
	}

	depositTreeI, ok := s.getStakers().tree.Get(owner.String())
	if !ok {
		return []uint64{}
	}

	depositTree := retrieveDepositTree(depositTreeI)
	positions := make([]uint64, 0, count)
	depositTree.IterateByOffset(offset, count, func(depositId string, _ any) bool {
		positions = append(positions, sr.DecodeUint(depositId))
		return false
	})

	return positions
}

// IsStaked returns whether a position is staked.
func (s *stakerV1) IsStaked(positionId uint64) bool {
	return s.getDeposits().Has(positionId)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func (s *stakerV1) GetExternalIncentiveByPoolPath(poolPath string) []sr.ExternalIncentive {
	incentives := make([]sr.ExternalIncentive, 0)

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
