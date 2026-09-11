package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// IStakerGetter functions

// GetPool returns a copy of the pool for the given path.
func GetPool(poolPath string) (*Pool, error) {
	pool, err := getImplementation().GetPool(poolPath)
	if err != nil {
		return nil, err
	}
	if pool == nil {
		return nil, nil
	}
	return pool.Clone(), nil
}

// GetDeposit returns a copy of the deposit for the given position ID.
func GetDeposit(lpTokenId uint64) (*Deposit, error) {
	deposit, err := getImplementation().GetDeposit(lpTokenId)
	if err != nil {
		return nil, err
	}
	if deposit == nil {
		return nil, nil
	}
	return deposit.Clone(), nil
}

// CollectableEmissionReward returns the claimable internal reward amount.
func CollectableEmissionReward(positionId uint64) (int64, error) {
	return getImplementation().CollectableEmissionReward(positionId)
}

// CollectableExternalIncentiveReward returns the claimable external reward amount.
func CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	return getImplementation().CollectableExternalIncentiveReward(positionId, incentiveId)
}

// GetCreatedHeightOfIncentive returns the block height when an incentive was created.
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

// GetIncentiveAccumulatedPenaltyAmount returns the accumulated warmup penalty amount of an incentive.
func GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveAccumulatedPenaltyAmount(poolPath, incentiveId)
}

// GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.
func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
func GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	return getImplementation().GetIncentiveRefunded(poolPath, incentiveId)
}

// IsIncentiveActive returns whether an incentive is active.
func IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	return getImplementation().IsIncentiveActive(poolPath, incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for a position.
func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

// GetDepositGnsAmount returns the required GNS deposit amount for staking.
func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.
func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

// GetDepositCollectedInternalReward returns the collected internal reward amount of a position.
func GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositCollectedInternalReward(lpTokenId)
}

// GetDepositCollectedExternalReward returns the collected external reward amount of a position.
func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	return getImplementation().GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

// GetDepositLiquidity returns the liquidity amount of a staked position.
func GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	liquidity, err := getImplementation().GetDepositLiquidity(lpTokenId)
	if err != nil {
		return nil, err
	}
	return liquidity.Clone(), nil
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.
func GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositOwner returns the owner of a staked position.
func GetDepositOwner(lpTokenId uint64) (address, error) {
	return getImplementation().GetDepositOwner(lpTokenId)
}

// GetDepositStakeTime returns the staking duration of a position.
func GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositTargetPoolPath returns the pool path of a staked position.
func GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

// GetDepositTickLower returns the lower tick of a staked position.
func GetDepositTickLower(lpTokenId uint64) (int32, error) {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

// GetDepositTickUpper returns the upper tick of a staked position.
func GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

// GetDepositWarmUp returns the warmup records of a staked position.
func GetDepositWarmUp(lpTokenId uint64) ([]Warmup, error) {
	warmups, err := getImplementation().GetDepositWarmUp(lpTokenId)
	if err != nil {
		return nil, err
	}
	return cloneWarmups(warmups), nil
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
func GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	ids, err := getImplementation().GetDepositExternalIncentiveIdList(lpTokenId)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(ids), nil
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func GetExternalIncentiveByPoolPath(poolPath string) ([]ExternalIncentive, error) {
	incentives, err := getImplementation().GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}
	return cloneExternalIncentives(incentives), nil
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

// GetIncentiveCreator returns the creator address of an incentive.
func GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	return getImplementation().GetIncentiveCreator(poolPath, incentiveId)
}

// GetIncentiveRewardAmount returns the total reward amount of an incentive.
func GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}
	return amount.Clone(), nil
}

// GetIncentiveRewardAmountAsString returns the total reward amount of an incentive as string.
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

// GetIncentiveRewardPerSecondX128 returns the reward rate per second of an
// incentive, expressed as a Q128 fixed-point number (i.e. actual rate =
// value / 2^128). Callers needing an integer rate can right-shift the result
// by 128.
func GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetIncentiveRewardPerSecondX128(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}
	return amount.Clone(), nil
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveStartTimestamp(poolPath, incentiveId)
}

// GetMinimumRewardAmount returns the minimum reward amount to distribute.
func GetMinimumRewardAmount() int64 {
	return getImplementation().GetMinimumRewardAmount()
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return getImplementation().GetMinimumRewardAmountForToken(tokenPath)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
func GetPoolStakedLiquidity(poolPath string) (string, error) {
	return getImplementation().GetPoolStakedLiquidity(poolPath)
}

// GetPoolsByTier returns the pool list for a tier.
func GetPoolsByTier(tier uint64) ([]string, error) {
	pools, err := getImplementation().GetPoolsByTier(tier)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(pools), nil
}

// GetPoolReward returns the reward amount for a tier.
func GetPoolReward(tier uint64) (int64, error) {
	return getImplementation().GetPoolReward(tier)
}

// GetPoolTier returns the tier of a pool.
func GetPoolTier(poolPath string) uint64 {
	return getImplementation().GetPoolTier(poolPath)
}

// GetPoolTierCount returns the number of pools in a tier.
func GetPoolTierCount(tier uint64) uint64 {
	return getImplementation().GetPoolTierCount(tier)
}

// GetPoolTierRatio returns the reward ratio of a pool.
func GetPoolTierRatio(poolPath string) (uint64, error) {
	return getImplementation().GetPoolTierRatio(poolPath)
}

// GetSpecificTokenMinimumRewardAmount returns the minimum reward amount for a specific token.
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

// GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

// GetUnstakingFee returns the unstaking fee percentage.
func GetUnstakingFee() uint64 {
	return getImplementation().GetUnstakingFee()
}

// HasUnstakedPosition returns whether a position was unstaked with rewards left to collect.
func HasUnstakedPosition(positionId uint64) bool {
	return getImplementation().HasUnstakedPosition(positionId)
}

// GetUnstakedPositionExitTime returns the timestamp at which an unstaked position stopped accruing rewards.
func GetUnstakedPositionExitTime(positionId uint64) (int64, error) {
	return getImplementation().GetUnstakedPositionExitTime(positionId)
}

// GetUnstakedPositionPendingIncentives returns the incentives an unstaked position has yet to collect.
func GetUnstakedPositionPendingIncentives(positionId uint64) ([]string, error) {
	incentiveIds, err := getImplementation().GetUnstakedPositionPendingIncentives(positionId)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(incentiveIds), nil
}

// GetUncollectedIncentiveCount returns how many unstaked positions still owe a reward from the incentive.
func GetUncollectedIncentiveCount(incentiveId string) int64 {
	return getImplementation().GetUncollectedIncentiveCount(incentiveId)
}

// IsStaked returns whether a position is staked.
func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// GetTotalEmissionSent returns the total GNS emission sent.
func GetTotalEmissionSent() int64 {
	return getImplementation().GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive tokens.
func GetAllowedTokens() []string {
	return cloneStringSlice(getImplementation().GetAllowedTokens())
}

// GetWarmupTemplate returns the current warmup template.
func GetWarmupTemplate() []Warmup {
	return cloneWarmups(getImplementation().GetWarmupTemplate())
}

// GetPoolRewardCaches returns a read-only view of a pool's reward cache, keyed
// by the encoded block timestamp. Callers paginate it themselves through
// IterateByOffset and decode keys with DecodeInt64.
func GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolRewardCaches(poolPath)
}

// GetPoolIncentives returns a read-only view of a pool's external incentives,
// keyed by incentive ID. Reading an entry yields a clone, so the view cannot
// mutate realm state.
func GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolIncentives(poolPath)
}

// GetPoolGlobalRewardRatioAccumulations returns a read-only view of a pool's
// global reward ratio accumulation, keyed by the encoded block timestamp.
// Decode keys with DecodeInt64.
func GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolGlobalRewardRatioAccumulations(poolPath)
}

// GetPoolHistoricalTicks returns a read-only view of a pool's historical ticks,
// keyed by the encoded block timestamp with the int32 tick as the value.
// Decode keys with DecodeInt64.
func GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolHistoricalTicks(poolPath)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
func GetPendingProtocolFees() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetPendingProtocolFees())
}
