package staker

import u256 "gno.land/p/gnoswap/uint256"

// IStakerGetter functions

// GetPool returns a copy of the pool for the given path.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - pool: copied pool data, or nil if the pool does not exist
func GetPool(poolPath string) *Pool {
	pool := getImplementation().GetPool(poolPath)
	if pool == nil {
		return nil
	}
	return pool.Clone()
}

// GetIncentive returns a copy of the incentive for the given pool and ID.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: ID of the external incentive
//
// Returns:
//   - incentive: copied incentive data, or nil if the incentive does not exist
func GetIncentive(poolPath string, incentiveId string) *ExternalIncentive {
	incentive := getImplementation().GetIncentive(poolPath, incentiveId)
	if incentive == nil {
		return nil
	}
	return incentive.Clone()
}

// GetDeposit returns a copy of the deposit for the given position ID.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - deposit: copied deposit data, or nil if the deposit does not exist
func GetDeposit(lpTokenId uint64) *Deposit {
	deposit := getImplementation().GetDeposit(lpTokenId)
	if deposit == nil {
		return nil
	}
	return deposit.Clone()
}

// CollectableEmissionReward returns the claimable internal reward amount.
//
// Parameters:
//   - positionId: staked position ID
//
// Returns:
//   - amount: claimable internal GNS emission reward amount
func CollectableEmissionReward(positionId uint64) int64 {
	return getImplementation().CollectableEmissionReward(positionId)
}

// CollectableExternalIncentiveReward returns the claimable external reward amount.
//
// Parameters:
//   - positionId: staked position ID
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: claimable external incentive reward amount
func CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64 {
	return getImplementation().CollectableExternalIncentiveReward(positionId, incentiveId)
}

// GetCreatedHeightOfIncentive returns the block height when an incentive was created.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - height: block height when the incentive was created
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - timestamp: unix timestamp when the incentive was created
func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: total reward amount configured for the incentive
func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: reward amount already distributed from the incentive
func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: reward amount remaining in the incentive
func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

// GetIncentiveAccumulatedPenaltyAmount returns the accumulated warmup penalty amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: accumulated warmup penalty amount for the incentive
func GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveAccumulatedPenaltyAmount(poolPath, incentiveId)
}

// GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: GNS deposit amount locked for the incentive
func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - refunded: true if the incentive has been refunded
func GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	return getImplementation().GetIncentiveRefunded(poolPath, incentiveId)
}

// IsIncentiveActive returns whether an incentive is active.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - active: true if the incentive is active
func IsIncentiveActive(poolPath string, incentiveId string) bool {
	return getImplementation().IsIncentiveActive(poolPath, incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for a position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//   - incentiveId: external incentive ID
//
// Returns:
//   - timestamp: unix timestamp of the last external reward collection
func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

// GetDepositGnsAmount returns the required GNS deposit amount for creating an external incentive.
//
// Returns:
//   - amount: required GNS deposit amount for creating an external incentive
func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - timestamp: unix timestamp of the last internal reward collection
func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

// GetDepositCollectedInternalReward returns the collected internal reward amount of a position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - amount: internal reward amount already collected by the position
func GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	return getImplementation().GetDepositCollectedInternalReward(lpTokenId)
}

// GetDepositCollectedExternalReward returns the collected external reward amount of a position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: external reward amount already collected by the position
func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

// GetDepositLiquidity returns the liquidity amount of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - liquidity: copied liquidity amount of the staked position
func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getImplementation().GetDepositLiquidity(lpTokenId).Clone()
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - liquidity: liquidity amount of the staked position as a string
func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositOwner returns the owner of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - owner: owner address of the staked position
func GetDepositOwner(lpTokenId uint64) address {
	return getImplementation().GetDepositOwner(lpTokenId)
}

// GetDepositStakeTime returns the stake start timestamp of a position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - stakeTime: stake start timestamp recorded for the position
func GetDepositStakeTime(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositTargetPoolPath returns the pool path of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - poolPath: target pool path of the staked position
func GetDepositTargetPoolPath(lpTokenId uint64) string {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

// GetDepositTickLower returns the lower tick of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - tickLower: lower tick boundary of the staked position
func GetDepositTickLower(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

// GetDepositTickUpper returns the upper tick of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - tickUpper: upper tick boundary of the staked position
func GetDepositTickUpper(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

// GetDepositWarmUp returns the warmup records of a staked position.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - warmups: copied warmup records of the staked position
func GetDepositWarmUp(lpTokenId uint64) []Warmup {
	return cloneWarmups(getImplementation().GetDepositWarmUp(lpTokenId))
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
//
// Parameters:
//   - lpTokenId: staked LP position ID
//
// Returns:
//   - incentiveIds: external incentive IDs associated with the deposit
func GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	return cloneStringSlice(getImplementation().GetDepositExternalIncentiveIdList(lpTokenId))
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - incentives: copied external incentives for the pool
func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	return cloneExternalIncentives(getImplementation().GetExternalIncentiveByPoolPath(poolPath))
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - timestamp: incentive end timestamp
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

// GetIncentiveCreator returns the creator address of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - creator: creator address of the incentive
func GetIncentiveCreator(poolPath string, incentiveId string) address {
	return getImplementation().GetIncentiveCreator(poolPath, incentiveId)
}

// GetIncentiveRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: copied total reward amount of the incentive
func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId).Clone()
}

// GetIncentiveRewardAmountAsString returns the total reward amount of an incentive as string.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: total reward amount of the incentive as a string
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

// GetIncentiveRewardPerSecond returns the reward rate per second of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - amount: reward amount emitted per second
func GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

// GetIncentiveRewardToken returns the reward token of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - tokenPath: reward token path of the incentive
func GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
//
// Parameters:
//   - poolPath: pool path associated with the incentive
//   - incentiveId: external incentive ID
//
// Returns:
//   - timestamp: incentive start timestamp
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveStartTimestamp(poolPath, incentiveId)
}

// GetMinimumRewardAmount returns the minimum reward amount to distribute.
//
// Returns:
//   - amount: global minimum reward amount to distribute
func GetMinimumRewardAmount() int64 {
	return getImplementation().GetMinimumRewardAmount()
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
//
// Parameters:
//   - tokenPath: reward token path
//
// Returns:
//   - amount: minimum reward amount for the token
func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return getImplementation().GetMinimumRewardAmountForToken(tokenPath)
}

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - incentiveIds: incentive IDs associated with the pool
func GetPoolIncentiveIdList(poolPath string) []string {
	return cloneStringSlice(getImplementation().GetPoolIncentiveIdList(poolPath))
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - liquidity: current total staked liquidity of the pool
func GetPoolStakedLiquidity(poolPath string) string {
	return getImplementation().GetPoolStakedLiquidity(poolPath)
}

// GetPoolsByTier returns the pool list for a tier.
//
// Parameters:
//   - tier: reward tier to query
//
// Returns:
//   - poolPaths: pool paths assigned to the tier
func GetPoolsByTier(tier uint64) []string {
	return cloneStringSlice(getImplementation().GetPoolsByTier(tier))
}

// GetPoolReward returns the reward amount for a tier.
//
// Parameters:
//   - tier: reward tier to query
//
// Returns:
//   - amount: reward amount allocated to the tier
func GetPoolReward(tier uint64) int64 {
	return getImplementation().GetPoolReward(tier)
}

// GetPoolTier returns the tier of a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - tier: reward tier assigned to the pool
func GetPoolTier(poolPath string) uint64 {
	return getImplementation().GetPoolTier(poolPath)
}

// GetPoolTierCount returns the number of pools in a tier.
//
// Parameters:
//   - tier: reward tier to query
//
// Returns:
//   - count: number of pools assigned to the tier
func GetPoolTierCount(tier uint64) uint64 {
	return getImplementation().GetPoolTierCount(tier)
}

// GetPoolTierRatio returns the reward ratio of a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - ratio: reward ratio for the pool tier
func GetPoolTierRatio(poolPath string) uint64 {
	return getImplementation().GetPoolTierRatio(poolPath)
}

// GetSpecificTokenMinimumRewardAmount returns the minimum reward amount for a specific token.
//
// Parameters:
//   - tokenPath: reward token path
//
// Returns:
//   - amount: minimum reward amount for the token
//   - exists: true if a token-specific minimum is configured
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

// GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.
//
// Parameters:
//   - poolPath: pool path namespace to query
//   - incentiveId: external incentive ID
//
// Returns:
//   - targetPoolPath: pool path targeted by the incentive
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

// GetUnstakingFee returns the unstaking fee percentage.
//
// Returns:
//   - fee: unstaking fee in basis points
func GetUnstakingFee() uint64 {
	return getImplementation().GetUnstakingFee()
}

// IsStaked returns whether a position is staked.
//
// Parameters:
//   - positionId: LP position ID
//
// Returns:
//   - staked: true if the position is currently staked
func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// GetTotalEmissionSent returns the total GNS emission sent.
//
// Returns:
//   - amount: total GNS emission amount sent through the staker
func GetTotalEmissionSent() int64 {
	return getImplementation().GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive tokens.
//
// Returns:
//   - tokenPaths: allowed external incentive token paths
func GetAllowedTokens() []string {
	return cloneStringSlice(getImplementation().GetAllowedTokens())
}

// GetWarmupTemplate returns the current warmup template.
//
// Returns:
//   - warmups: copied current warmup template
func GetWarmupTemplate() []Warmup {
	return cloneWarmups(getImplementation().GetWarmupTemplate())
}

// GetPoolRewardCacheCount returns the number of reward cache entries for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - count: number of reward cache entries for the pool
func GetPoolRewardCacheCount(poolPath string) uint64 {
	return getImplementation().GetPoolRewardCacheCount(poolPath)
}

// GetPoolRewardCacheIDs returns a paginated list of reward cache timestamps for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - offset: starting offset
//   - count: maximum number of IDs to return
//
// Returns:
//   - timestamps: paginated reward cache timestamps
func GetPoolRewardCacheIDs(poolPath string, offset, count int) []int64 {
	return cloneInt64Slice(getImplementation().GetPoolRewardCacheIDs(poolPath, offset, count))
}

// GetPoolRewardCache returns the reward cache value at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - timestamp: reward cache timestamp
//
// Returns:
//   - amount: reward cache value at the timestamp
func GetPoolRewardCache(poolPath string, timestamp uint64) int64 {
	return getImplementation().GetPoolRewardCache(poolPath, timestamp)
}

// GetPoolIncentiveCount returns the number of incentives for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - count: number of incentives for the pool
func GetPoolIncentiveCount(poolPath string) uint64 {
	return getImplementation().GetPoolIncentiveCount(poolPath)
}

// GetPoolIncentiveIDs returns a paginated list of incentive IDs for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - offset: starting offset
//   - count: maximum number of IDs to return
//
// Returns:
//   - incentiveIds: paginated incentive IDs for the pool
func GetPoolIncentiveIDs(poolPath string, offset, count int) []string {
	return cloneStringSlice(getImplementation().GetPoolIncentiveIDs(poolPath, offset, count))
}

// GetPoolGlobalRewardRatioAccumulationCount returns the number of global reward ratio accumulation entries for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - count: number of global reward ratio accumulation entries
func GetPoolGlobalRewardRatioAccumulationCount(poolPath string) uint64 {
	return getImplementation().GetPoolGlobalRewardRatioAccumulationCount(poolPath)
}

// GetPoolGlobalRewardRatioAccumulationIDs returns a paginated list of timestamps for global reward ratio accumulation entries.
//
// Parameters:
//   - poolPath: pool path to query
//   - offset: starting offset
//   - count: maximum number of IDs to return
//
// Returns:
//   - timestamps: paginated global reward ratio accumulation timestamps
func GetPoolGlobalRewardRatioAccumulationIDs(poolPath string, offset, count int) []uint64 {
	return cloneUint64Slice(getImplementation().GetPoolGlobalRewardRatioAccumulationIDs(poolPath, offset, count))
}

// GetPoolGlobalRewardRatioAccumulation returns the global reward ratio accumulation at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - timestamp: global reward ratio accumulation timestamp
//
// Returns:
//   - accumulation: global reward ratio accumulation at the timestamp
func GetPoolGlobalRewardRatioAccumulation(poolPath string, timestamp uint64) string {
	return getImplementation().GetPoolGlobalRewardRatioAccumulation(poolPath, timestamp)
}

// GetPoolHistoricalTickCount returns the number of historical tick entries for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//
// Returns:
//   - count: number of historical tick entries for the pool
func GetPoolHistoricalTickCount(poolPath string) uint64 {
	return getImplementation().GetPoolHistoricalTickCount(poolPath)
}

// GetPoolHistoricalTickIDs returns a paginated list of historical tick values for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - offset: starting offset
//   - count: maximum number of IDs to return
//
// Returns:
//   - ticks: paginated historical tick values for the pool
func GetPoolHistoricalTickIDs(poolPath string, offset, count int) []int32 {
	return cloneInt32Slice(getImplementation().GetPoolHistoricalTickIDs(poolPath, offset, count))
}

// GetPoolHistoricalTick returns the historical tick at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: pool path to query
//   - tick: timestamp key for the historical tick entry
//
// Returns:
//   - historicalTick: historical tick value for the timestamp
func GetPoolHistoricalTick(poolPath string, tick uint64) int32 {
	return getImplementation().GetPoolHistoricalTick(poolPath, tick)
}
