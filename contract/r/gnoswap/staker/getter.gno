package staker

import u256 "gno.land/p/gnoswap/uint256"

// IStakerGetter functions

// GetCreatedHeightOfIncentive returns the block height when an incentive was created.
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
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

// GetDepositLiquidity returns the liquidity amount of a staked position.
func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getImplementation().GetDepositLiquidity(lpTokenId)
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.
func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositStakeTime returns the staking duration of a position.
func GetDepositStakeTime(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositStakeTimestamp returns the staking timestamp of a position.
func GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTimestamp(lpTokenId)
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

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
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

// IsArchivedExternalIncentive returns whether an external incentive is archived.
func IsArchivedExternalIncentive(incentiveId string) bool {
	return getImplementation().IsArchivedExternalIncentive(incentiveId)
}

// IsStaked returns whether a position is staked.
func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// IStakerApi functions

// ApiGetExternalIncentiveById returns external incentive data as JSON.
func ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	return getImplementation().ApiGetExternalIncentiveById(poolPath, incentiveId)
}

// ApiGetExternalIncentives returns all external incentives as JSON.
func ApiGetExternalIncentives() string {
	return getImplementation().ApiGetExternalIncentives()
}

// ApiGetExternalIncentivesByPoolPath returns external incentives for a pool as JSON.
func ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetExternalIncentivesByPoolPath(targetPoolPath)
}

// ApiGetInternalIncentives returns all internal incentives as JSON.
func ApiGetInternalIncentives() string {
	return getImplementation().ApiGetInternalIncentives()
}

// ApiGetInternalIncentivesByPoolPath returns internal incentives for a pool as JSON.
func ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetInternalIncentivesByPoolPath(targetPoolPath)
}

// ApiGetInternalIncentivesByTiers returns internal incentives for a tier as JSON.
func ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	return getImplementation().ApiGetInternalIncentivesByTiers(targetTier)
}

// ApiGetRewardsByLpTokenId returns rewards for a staked position as JSON.
func ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	return getImplementation().ApiGetRewardsByLpTokenId(targetLpTokenId)
}

// ApiGetRewardTokensByPoolPath returns reward tokens for a pool as JSON.
func ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetRewardTokensByPoolPath(targetPoolPath)
}

// ApiGetStakesByLpTokenId returns staking information for a position as JSON.
func ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	return getImplementation().ApiGetStakesByLpTokenId(targetLpTokenId)
}
