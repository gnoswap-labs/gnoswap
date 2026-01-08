package staker

import u256 "gno.land/p/gnoswap/uint256"

// IStakerGetter functions

// GetCreatedHeightOfIncentive returns the block height when an incentive was created.
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.
func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
func GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	return getImplementation().GetIncentiveRefunded(poolPath, incentiveId)
}

// IsIncentiveActive returns whether an incentive is active.
func IsIncentiveActive(poolPath string, incentiveId string) bool {
	return getImplementation().IsIncentiveActive(poolPath, incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for a position.
func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

// GetDepositGnsAmount returns the required GNS deposit amount for staking.
func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.
func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

// GetDepositStakeTimestamp returns the staking timestamp of a position.
func GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTimestamp(lpTokenId)
}

// GetDepositCollectedInternalReward returns the collected internal reward amount of a position.
func GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	return getImplementation().GetDepositCollectedInternalReward(lpTokenId)
}

// GetDepositCollectedExternalReward returns the collected external reward amount of a position.
func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

// GetDepositLiquidity returns the liquidity amount of a staked position.
func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getImplementation().GetDepositLiquidity(lpTokenId)
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.
func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositOwner returns the owner of a staked position.
func GetDepositOwner(lpTokenId uint64) address {
	return getImplementation().GetDepositOwner(lpTokenId)
}

// GetDepositStakeTime returns the staking duration of a position.
func GetDepositStakeTime(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositTargetPoolPath returns the pool path of a staked position.
func GetDepositTargetPoolPath(lpTokenId uint64) string {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

// GetDepositTickLower returns the lower tick of a staked position.
func GetDepositTickLower(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

// GetDepositTickUpper returns the upper tick of a staked position.
func GetDepositTickUpper(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

// GetDepositWarmUp returns the warmup records of a staked position.
func GetDepositWarmUp(lpTokenId uint64) []Warmup {
	return getImplementation().GetDepositWarmUp(lpTokenId)
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
func GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	return getImplementation().GetDepositExternalIncentiveIdList(lpTokenId)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	return getImplementation().GetExternalIncentiveByPoolPath(poolPath)
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

// GetIncentiveRefundee returns the refundee address of an incentive.
func GetIncentiveRefundee(poolPath string, incentiveId string) address {
	return getImplementation().GetIncentiveRefundee(poolPath, incentiveId)
}

// GetIncentiveRewardAmount returns the total reward amount of an incentive.
func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRewardAmountAsString returns the total reward amount of an incentive as string.
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

// GetIncentiveRewardPerSecond returns the reward rate per second of an incentive.
func GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

// GetIncentiveRewardToken returns the reward token of an incentive.
func GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
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

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
func GetPoolIncentiveIdList(poolPath string) []string {
	return getImplementation().GetPoolIncentiveIdList(poolPath)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
func GetPoolStakedLiquidity(poolPath string) string {
	return getImplementation().GetPoolStakedLiquidity(poolPath)
}

// GetPoolsByTier returns the pool list for a tier.
func GetPoolsByTier(tier uint64) []string {
	return getImplementation().GetPoolsByTier(tier)
}

// GetPoolReward returns the reward amount for a tier.
func GetPoolReward(tier uint64) int64 {
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
func GetPoolTierRatio(poolPath string) uint64 {
	return getImplementation().GetPoolTierRatio(poolPath)
}

// GetSpecificTokenMinimumRewardAmount returns the minimum reward amount for a specific token.
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

// GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

// GetUnstakingFee returns the unstaking fee percentage.
func GetUnstakingFee() int64 {
	return getImplementation().GetUnstakingFee()
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
	return getImplementation().GetAllowedTokens()
}

// GetWarmupTemplate returns the current warmup template.
func GetWarmupTemplate() []Warmup {
	return getImplementation().GetWarmupTemplate()
}

// GetTotalStakedPositionCount returns the total staked position count.
func GetTotalStakedPositionCount() uint64 {
	return getImplementation().GetTotalStakedPositionCount()
}

// GetStakedPositionsByOwner returns staked position IDs for an owner.
func GetStakedPositionsByOwner(owner address) []uint64 {
	return getImplementation().GetStakedPositionsByOwner(owner)
}
