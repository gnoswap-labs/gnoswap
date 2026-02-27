package staker

import u256 "gno.land/p/gnoswap/uint256"

// IStakerGetter functions

// GetPool returns a copy of the pool for the given path.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - pool: pool data or nil if not found
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
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - incentive: incentive data or nil if not found
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
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - deposit: deposit data or nil if not found
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
//   - positionId: ID of the staked position
//
// Returns:
//   - reward: claimable internal reward amount
func CollectableEmissionReward(positionId uint64) int64 {
	return getImplementation().CollectableEmissionReward(positionId)
}

// CollectableExternalIncentiveReward returns the claimable external reward amount.
//
// Parameters:
//   - positionId: ID of the staked position
//   - incentiveId: ID of the incentive
//
// Returns:
//   - reward: claimable external reward amount
func CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64 {
	return getImplementation().CollectableExternalIncentiveReward(positionId, incentiveId)
}

// GetCreatedHeightOfIncentive returns the block height when an incentive was created.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - height: block height at creation
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

// GetIncentiveCreatedTimestamp returns the creation timestamp of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - timestamp: creation timestamp
func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: total reward amount
func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: distributed reward amount
func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: remaining reward amount
func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: deposited GNS amount
func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - refunded: true if incentive has been refunded
func GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	return getImplementation().GetIncentiveRefunded(poolPath, incentiveId)
}

// IsIncentiveActive returns whether an incentive is active.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - active: true if incentive is active
func IsIncentiveActive(poolPath string, incentiveId string) bool {
	return getImplementation().IsIncentiveActive(poolPath, incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for a position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//   - incentiveId: ID of the incentive
//
// Returns:
//   - timestamp: last collection timestamp
func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

// GetDepositGnsAmount returns the required GNS deposit amount for staking.
//
// Returns:
//   - amount: required GNS deposit amount
func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - timestamp: last collection timestamp
func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

// GetDepositCollectedInternalReward returns the collected internal reward amount of a position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - amount: collected internal reward amount
func GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	return getImplementation().GetDepositCollectedInternalReward(lpTokenId)
}

// GetDepositCollectedExternalReward returns the collected external reward amount of a position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: collected external reward amount
func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

// GetDepositLiquidity returns the liquidity amount of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - liquidity: liquidity amount
func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getImplementation().GetDepositLiquidity(lpTokenId)
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as string.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - liquidity: liquidity amount as string
func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositOwner returns the owner of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - owner: owner address
func GetDepositOwner(lpTokenId uint64) address {
	return getImplementation().GetDepositOwner(lpTokenId)
}

// GetDepositStakeTime returns the staking duration of a position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - stakeTime: staking timestamp
func GetDepositStakeTime(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositTargetPoolPath returns the pool path of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - poolPath: target pool path
func GetDepositTargetPoolPath(lpTokenId uint64) string {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

// GetDepositTickLower returns the lower tick of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - tickLower: lower tick boundary
func GetDepositTickLower(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

// GetDepositTickUpper returns the upper tick of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - tickUpper: upper tick boundary
func GetDepositTickUpper(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

// GetDepositWarmUp returns the warmup records of a staked position.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - warmups: warmup period records
func GetDepositWarmUp(lpTokenId uint64) []Warmup {
	return getImplementation().GetDepositWarmUp(lpTokenId)
}

// GetDepositExternalIncentiveIdList returns external incentive IDs for a deposit.
//
// Parameters:
//   - lpTokenId: ID of the LP token position
//
// Returns:
//   - incentiveIds: list of external incentive IDs
func GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	return getImplementation().GetDepositExternalIncentiveIdList(lpTokenId)
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - incentives: list of external incentives
func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	return getImplementation().GetExternalIncentiveByPoolPath(poolPath)
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - timestamp: end timestamp
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

// GetIncentiveRefundee returns the refundee address of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - refundee: refundee address
func GetIncentiveRefundee(poolPath string, incentiveId string) address {
	return getImplementation().GetIncentiveRefundee(poolPath, incentiveId)
}

// GetIncentiveRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: total reward amount
func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRewardAmountAsString returns the total reward amount of an incentive as string.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - amount: total reward amount as string
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

// GetIncentiveRewardPerSecond returns the reward rate per second of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - rate: reward per second
func GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

// GetIncentiveRewardToken returns the reward token of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - tokenPath: reward token path
func GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - timestamp: start timestamp
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveStartTimestamp(poolPath, incentiveId)
}

// GetMinimumRewardAmount returns the minimum reward amount to distribute.
//
// Returns:
//   - amount: minimum reward amount
func GetMinimumRewardAmount() int64 {
	return getImplementation().GetMinimumRewardAmount()
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: minimum reward amount for the token
func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return getImplementation().GetMinimumRewardAmountForToken(tokenPath)
}

// GetPoolIncentiveIdList returns all incentive IDs for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - incentiveIds: list of incentive IDs
func GetPoolIncentiveIdList(poolPath string) []string {
	return getImplementation().GetPoolIncentiveIdList(poolPath)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - liquidity: total staked liquidity as string
func GetPoolStakedLiquidity(poolPath string) string {
	return getImplementation().GetPoolStakedLiquidity(poolPath)
}

// GetPoolsByTier returns the pool list for a tier.
//
// Parameters:
//   - tier: tier level
//
// Returns:
//   - pools: list of pool paths
func GetPoolsByTier(tier uint64) []string {
	return getImplementation().GetPoolsByTier(tier)
}

// GetPoolReward returns the reward amount for a tier.
//
// Parameters:
//   - tier: tier level
//
// Returns:
//   - reward: reward amount for the tier
func GetPoolReward(tier uint64) int64 {
	return getImplementation().GetPoolReward(tier)
}

// GetPoolTier returns the tier of a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - tier: tier level
func GetPoolTier(poolPath string) uint64 {
	return getImplementation().GetPoolTier(poolPath)
}

// GetPoolTierCount returns the number of pools in a tier.
//
// Parameters:
//   - tier: tier level
//
// Returns:
//   - count: number of pools
func GetPoolTierCount(tier uint64) uint64 {
	return getImplementation().GetPoolTierCount(tier)
}

// GetPoolTierRatio returns the reward ratio of a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - ratio: reward ratio
func GetPoolTierRatio(poolPath string) uint64 {
	return getImplementation().GetPoolTierRatio(poolPath)
}

// GetSpecificTokenMinimumRewardAmount returns the minimum reward amount for a specific token.
//
// Parameters:
//   - tokenPath: path of the token
//
// Returns:
//   - amount: minimum reward amount
//   - exists: true if token has specific minimum
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

// GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.
//
// Parameters:
//   - poolPath: path of the pool
//   - incentiveId: ID of the incentive
//
// Returns:
//   - targetPoolPath: target pool path
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

// GetUnstakingFee returns the unstaking fee percentage.
//
// Returns:
//   - fee: unstaking fee percentage
func GetUnstakingFee() int64 {
	return getImplementation().GetUnstakingFee()
}

// IsStaked returns whether a position is staked.
//
// Parameters:
//   - positionId: ID of the position
//
// Returns:
//   - staked: true if position is staked
func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// GetTotalEmissionSent returns the total GNS emission sent.
//
// Returns:
//   - amount: total GNS emission sent
func GetTotalEmissionSent() int64 {
	return getImplementation().GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive tokens.
//
// Returns:
//   - tokens: list of allowed token paths
func GetAllowedTokens() []string {
	return getImplementation().GetAllowedTokens()
}

// GetWarmupTemplate returns the current warmup template.
//
// Returns:
//   - warmups: warmup template records
func GetWarmupTemplate() []Warmup {
	return getImplementation().GetWarmupTemplate()
}

// GetTotalStakedUserCount returns the total number of staked users.
//
// Returns:
//   - count: total number of users with staked positions
func GetTotalStakedUserCount() uint64 {
	return getImplementation().GetTotalStakedUserCount()
}

// GetTotalStakedUserPositionCount returns the staked position count for a user.
//
// Parameters:
//   - user: user address
//
// Returns:
//   - count: number of staked positions
func GetTotalStakedUserPositionCount(user address) uint64 {
	return getImplementation().GetTotalStakedUserPositionCount(user)
}

// GetStakedPositionsByUser returns staked position IDs for a user with pagination.
//
// Parameters:
//   - owner: owner address
//   - offset: starting index
//   - count: number of positions to return
//
// Returns:
//   - positionIds: list of staked position IDs
func GetStakedPositionsByUser(owner address, offset, count int) []uint64 {
	return getImplementation().GetStakedPositionsByUser(owner, offset, count)
}

// GetPoolRewardCacheCount returns the number of reward cache entries for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - count: number of reward cache entries
func GetPoolRewardCacheCount(poolPath string) uint64 {
	return getImplementation().GetPoolRewardCacheCount(poolPath)
}

// GetPoolRewardCacheIDs returns a paginated list of reward cache timestamps for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - offset: starting index
//   - count: number of entries to return
//
// Returns:
//   - timestamps: list of reward cache timestamps
func GetPoolRewardCacheIDs(poolPath string, offset, count int) []int64 {
	return getImplementation().GetPoolRewardCacheIDs(poolPath, offset, count)
}

// GetPoolRewardCache returns the reward cache value at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - timestamp: cache timestamp
//
// Returns:
//   - reward: cached reward value
func GetPoolRewardCache(poolPath string, timestamp uint64) int64 {
	return getImplementation().GetPoolRewardCache(poolPath, timestamp)
}

// GetPoolIncentiveCount returns the number of incentives for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - count: number of incentives
func GetPoolIncentiveCount(poolPath string) uint64 {
	return getImplementation().GetPoolIncentiveCount(poolPath)
}

// GetPoolIncentiveIDs returns a paginated list of incentive IDs for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - offset: starting index
//   - count: number of IDs to return
//
// Returns:
//   - incentiveIds: list of incentive IDs
func GetPoolIncentiveIDs(poolPath string, offset, count int) []string {
	return getImplementation().GetPoolIncentiveIDs(poolPath, offset, count)
}

// GetPoolGlobalRewardRatioAccumulationCount returns the number of global reward ratio accumulation entries for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - count: number of accumulation entries
func GetPoolGlobalRewardRatioAccumulationCount(poolPath string) uint64 {
	return getImplementation().GetPoolGlobalRewardRatioAccumulationCount(poolPath)
}

// GetPoolGlobalRewardRatioAccumulationIDs returns a paginated list of timestamps for global reward ratio accumulation entries.
//
// Parameters:
//   - poolPath: path of the pool
//   - offset: starting index
//   - count: number of entries to return
//
// Returns:
//   - timestamps: list of accumulation timestamps
func GetPoolGlobalRewardRatioAccumulationIDs(poolPath string, offset, count int) []uint64 {
	return getImplementation().GetPoolGlobalRewardRatioAccumulationIDs(poolPath, offset, count)
}

// GetPoolGlobalRewardRatioAccumulation returns the global reward ratio accumulation at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - timestamp: accumulation timestamp
//
// Returns:
//   - ratio: global reward ratio accumulation
func GetPoolGlobalRewardRatioAccumulation(poolPath string, timestamp uint64) *u256.Uint {
	return getImplementation().GetPoolGlobalRewardRatioAccumulation(poolPath, timestamp)
}

// GetPoolHistoricalTickCount returns the number of historical tick entries for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//
// Returns:
//   - count: number of historical tick entries
func GetPoolHistoricalTickCount(poolPath string) uint64 {
	return getImplementation().GetPoolHistoricalTickCount(poolPath)
}

// GetPoolHistoricalTickIDs returns a paginated list of historical tick values for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - offset: starting index
//   - count: number of entries to return
//
// Returns:
//   - ticks: list of historical tick values
func GetPoolHistoricalTickIDs(poolPath string, offset, count int) []int32 {
	return getImplementation().GetPoolHistoricalTickIDs(poolPath, offset, count)
}

// GetPoolHistoricalTick returns the historical tick at a specific timestamp for a pool.
//
// Parameters:
//   - poolPath: path of the pool
//   - tick: tick index
//
// Returns:
//   - tick: historical tick value
func GetPoolHistoricalTick(poolPath string, tick uint64) int32 {
	return getImplementation().GetPoolHistoricalTick(poolPath, tick)
}
