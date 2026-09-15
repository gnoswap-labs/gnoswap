package staker

import (
	u256 "gno.land/p/gnoswap/uint256/v1"
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// IStakerGetter functions

// GetPool returns a copy of the staking state for a pool.
//
// Parameters:
//   - poolPath: pool realm path
//
// Returns:
//   - pool: independent pool copy, or nil when an implementation has no pool value
//   - err: implementation resolution error; the current v1 implementation returns not-found for a missing pool
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

// GetDeposit returns a copy of a staked position's deposit.
//
// Parameters:
//   - lpTokenId: staked position NFT token ID
//
// Returns:
//   - deposit: independent deposit copy, or nil when an implementation has no deposit value
//   - err: implementation resolution error; the current v1 implementation returns not-found for a missing deposit
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

// CollectableEmissionReward returns the gross estimated internal GNS reward for a live staked
// deposit or an exit checkpoint left by UnStakeToken, before staking/protocol fee deduction during
// collection.
//
// Parameters:
//   - positionId: staked position NFT token ID or position with an exit checkpoint
//
// Returns:
//   - amount: Gross estimated internal GNS reward before staking/protocol fee deduction; this
//     read-only value is not the net amount transferred to the owner.
//   - err: Non-nil when positionId is not staked/checked out or reward calculation fails; nil on success.
func CollectableEmissionReward(positionId uint64) (int64, error) {
	return getImplementation().CollectableEmissionReward(positionId)
}

// CollectableExternalIncentiveReward returns the gross estimated external reward for a live staked
// deposit or an exit checkpoint left by UnStakeToken, before staking/protocol fee deduction during
// collection.
//
// Parameters:
//   - positionId: staked position NFT token ID or position with an exit checkpoint
//   - incentiveId: external incentive identifier; an absent entry in the calculated reward map
//     returns zero without error
//
// Returns:
//   - amount: Gross estimated reward in the incentive token's smallest units before
//     staking/protocol fee deduction; zero when incentiveId is absent from the calculated reward map.
//   - err: Non-nil when positionId is not staked/checked out or reward calculation fails; an absent
//     incentiveId is not an error.
func CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	return getImplementation().CollectableExternalIncentiveReward(positionId, incentiveId)
}

// GetCreatedHeightOfIncentive returns an incentive's creation block height.
//
// Parameters:
//   - poolPath: pool realm path
//   - incentiveId: external incentive identifier
//
// Returns:
//   - height: creation block height
//   - err: non-nil when the incentive cannot be resolved
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

// GetIncentiveCreatedTimestamp returns an incentive's creation timestamp.
//
// Parameters:
//   - poolPath: pool realm path
//   - incentiveId: external incentive identifier
//
// Returns:
//   - timestamp: creation Unix timestamp
//   - err: non-nil when the incentive cannot be resolved
func GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

// GetIncentiveTotalRewardAmount returns the total reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Total reward amount configured when the incentive was created, in token units.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

// GetIncentiveDistributedRewardAmount returns the distributed reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Reward amount already delivered to positions or refunded at incentive end, in token units.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

// GetIncentiveRemainingRewardAmount returns the remaining reward amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Mutable reward balance remaining after distributions and refunds, in token units.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

// GetIncentiveAccumulatedPenaltyAmount returns the accumulated warmup penalty amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Warmup penalty accumulated from collections for the incentive, in reward-token units.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveAccumulatedPenaltyAmount(poolPath, incentiveId)
}

// GetIncentiveDepositGnsAmount returns the deposited GNS amount of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: GNS deposit locked by the incentive, in token units.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

// GetIncentiveRefunded returns whether an incentive has been refunded.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - refunded: True when the incentive has been finalized as refunded; false while it remains open.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	return getImplementation().GetIncentiveRefunded(poolPath, incentiveId)
}

// IsIncentiveActive reports whether an unrefunded incentive is active, including both start and end timestamps.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - active: True when the current Unix time is within the incentive window and it has not been refunded.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	return getImplementation().IsIncentiveActive(poolPath, incentiveId)
}

// GetDepositExternalRewardLastCollectTimestamp returns the last external reward collection time for
// a position and incentive. For a newly tracked incentive, the value is based on the stake timestamp.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose external reward cursor should be read.
//   - incentiveId: External incentive identifier whose collection cursor should be read.
//
// Returns:
//   - timestamp: Unix timestamp of the last collection cursor; newly tracked incentives use the deposit's stake time.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

// GetDepositGnsAmount returns the GNS deposit required for each external incentive.
//
// Returns:
//   - amount: Configured GNS deposit required per external incentive, in token units.
func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

// GetDepositInternalRewardLastCollectTimestamp returns the last internal reward collection time for a position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose internal reward cursor should be read.
//
// Returns:
//   - timestamp: Unix timestamp of the deposit's last internal reward collection.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

// GetDepositCollectedInternalReward returns the collected internal reward amount of a position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose collected internal reward should be read.
//
// Returns:
//   - amount: Internal GNS reward amount already recorded as collected, in token units.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositCollectedInternalReward(lpTokenId)
}

// GetDepositCollectedExternalReward returns the collected external reward amount of a position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose collected reward should be read.
//   - incentiveId: External incentive identifier whose collected amount should be read.
//
// Returns:
//   - amount: External reward amount already recorded as collected for the incentive, in token units.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	return getImplementation().GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

// GetDepositLiquidity returns the liquidity amount of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose liquidity should be read.
//
// Returns:
//   - liquidity: Independent uint256 copy of the deposit's liquidity amount.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	liquidity, err := getImplementation().GetDepositLiquidity(lpTokenId)
	if err != nil {
		return nil, err
	}
	return liquidity.Clone(), nil
}

// GetDepositLiquidityAsString returns the liquidity amount of a staked position as a decimal string.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose liquidity should be formatted.
//
// Returns:
//   - liquidity: Decimal representation of the deposit's uint256 liquidity amount.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

// GetDepositOwner returns the owner of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose owner should be read.
//
// Returns:
//   - owner: Address recorded as the deposit owner.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositOwner(lpTokenId uint64) (address, error) {
	return getImplementation().GetDepositOwner(lpTokenId)
}

// GetDepositStakeTime returns the Unix timestamp at which a position was staked.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose stake time should be read.
//
// Returns:
//   - stakeTime: Unix timestamp recorded when the deposit entered staking.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

// GetDepositTargetPoolPath returns the pool path of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose target pool should be read.
//
// Returns:
//   - poolPath: Pool path stored on the deposit.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

// GetDepositTickLower returns the lower tick of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose lower boundary should be read.
//
// Returns:
//   - tickLower: Lower price-range tick stored on the deposit.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositTickLower(lpTokenId uint64) (int32, error) {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

// GetDepositTickUpper returns the upper tick of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose upper boundary should be read.
//
// Returns:
//   - tickUpper: Upper price-range tick stored on the deposit.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

// GetDepositWarmUp returns the warmup records of a staked position.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose warmup schedule should be inspected.
//
// Returns:
//   - warmups: Independent copy of the deposit's warmup records.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositWarmUp(lpTokenId uint64) ([]Warmup, error) {
	warmups, err := getImplementation().GetDepositWarmUp(lpTokenId)
	if err != nil {
		return nil, err
	}
	return cloneWarmups(warmups), nil
}

// GetDepositExternalIncentiveIdList returns external incentive IDs tracked by a deposit.
//
// Parameters:
//   - lpTokenId: Position NFT token ID whose deposit should be inspected.
//
// Returns:
//   - incentiveIds: Independent copy of external incentive IDs associated with the deposit.
//   - err: Non-nil when lpTokenId does not resolve to a stored deposit.
func GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	ids, err := getImplementation().GetDepositExternalIncentiveIdList(lpTokenId)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(ids), nil
}

// GetExternalIncentiveByPoolPath returns all external incentives for a pool.
//
// Parameters:
//   - poolPath: Pool path whose external incentives should be listed.
//
// Returns:
//   - incentives: Independent copies of incentives targeting poolPath.
//   - err: Non-nil when stored incentive data cannot be read or cast.
func GetExternalIncentiveByPoolPath(poolPath string) ([]ExternalIncentive, error) {
	incentives, err := getImplementation().GetExternalIncentiveByPoolPath(poolPath)
	if err != nil {
		return nil, err
	}
	return cloneExternalIncentives(incentives), nil
}

// GetIncentiveEndTimestamp returns the end timestamp of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - endTimestamp: Incentive end time as a Unix timestamp.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

// GetIncentiveCreator returns the creator address of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - creator: Address that created and funded the incentive.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	return getImplementation().GetIncentiveCreator(poolPath, incentiveId)
}

// GetIncentiveRewardAmount returns the remaining reward amount of an incentive, after deliveries
// and refunds represented by the current incentive state.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Independent uint256 copy of the incentive's mutable remaining reward amount.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}
	return amount.Clone(), nil
}

// GetIncentiveRewardAmountAsString returns the remaining reward amount of an incentive as string.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - amount: Decimal string for the incentive's remaining reward amount after deliveries and refunds.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

// GetIncentiveRewardPerSecondX128 returns the reward rate per second of an
// incentive, expressed as a Q128 fixed-point number (i.e. actual rate =
// value / 2^128). Callers needing an integer rate can right-shift the result
// by 128.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - rateX128: Clone of the Q128-scaled reward rate; divide by 2^128 to recover the actual token units per second.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	amount, err := getImplementation().GetIncentiveRewardPerSecondX128(poolPath, incentiveId)
	if err != nil {
		return nil, err
	}
	return amount.Clone(), nil
}

// GetIncentiveRewardToken returns the reward token of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - tokenPath: Reward-token path configured for the incentive.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

// GetIncentiveStartTimestamp returns the start timestamp of an incentive.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - startTimestamp: Incentive start time as a Unix timestamp.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	return getImplementation().GetIncentiveStartTimestamp(poolPath, incentiveId)
}

// GetMinimumRewardAmount returns the default minimum reward amount required to create an external
// incentive. A token-specific override may apply.
//
// Returns:
//   - amount: Default minimum external-incentive reward amount in token smallest units.
func GetMinimumRewardAmount() int64 {
	return getImplementation().GetMinimumRewardAmount()
}

// GetMinimumRewardAmountForToken returns the minimum reward amount for a specific token.
//
// Parameters:
//   - tokenPath: Token path whose configured minimum-reward override should be read.
//
// Returns:
//   - amount: Token-specific minimum reward amount when configured, otherwise the default minimum, in token smallest units.
func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return getImplementation().GetMinimumRewardAmountForToken(tokenPath)
}

// GetPoolStakedLiquidity returns the current total staked liquidity of a pool.
//
// Parameters:
//   - poolPath: Pool path whose current staked liquidity should be read.
//
// Returns:
//   - liquidity: Decimal string containing the pool's total staked liquidity at the current time.
//   - err: Non-nil when poolPath does not resolve to a pool.
func GetPoolStakedLiquidity(poolPath string) (string, error) {
	return getImplementation().GetPoolStakedLiquidity(poolPath)
}

// GetPoolsByTier returns the pool list for a tier.
//
// Parameters:
//   - tier: Emission tier identifier whose current pool memberships should be listed.
//
// Returns:
//   - poolPaths: Copy of pool paths currently assigned to tier; tier zero yields an empty list.
//   - err: Non-nil when the stored tier membership contains an invalid value.
func GetPoolsByTier(tier uint64) ([]string, error) {
	pools, err := getImplementation().GetPoolsByTier(tier)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(pools), nil
}

// GetPoolReward returns the reward amount for a tier.
//
// Parameters:
//   - tier: Emission tier identifier for which to retrieve the per-pool reward.
//
// Returns:
//   - reward: Current per-pool GNS reward rate for tier, in token units per second.
//   - err: Non-nil when tier is outside the valid range 1 through AllTierCount-1.
func GetPoolReward(tier uint64) (int64, error) {
	return getImplementation().GetPoolReward(tier)
}

// GetPoolTier returns the tier of a pool.
//
// Parameters:
//   - poolPath: Pool path whose current emission tier should be read.
//
// Returns:
//   - tier: Current emission tier identifier; zero when the pool has no tier assignment.
func GetPoolTier(poolPath string) uint64 {
	return getImplementation().GetPoolTier(poolPath)
}

// GetPoolTierCount returns the number of pools in a tier.
//
// Parameters:
//   - tier: Emission tier identifier to count; tier zero has no pools.
//
// Returns:
//   - count: Number of pools currently assigned to tier, or zero for tier zero.
func GetPoolTierCount(tier uint64) uint64 {
	return getImplementation().GetPoolTierCount(tier)
}

// GetPoolTierRatio returns the reward ratio of a pool.
//
// Parameters:
//   - poolPath: Pool path whose current emission tier ratio should be read.
//
// Returns:
//   - ratio: Stored reward-share ratio for the pool's current tier.
//   - err: Non-nil when the pool's tier is invalid and has no configured ratio.
func GetPoolTierRatio(poolPath string) (uint64, error) {
	return getImplementation().GetPoolTierRatio(poolPath)
}

// GetSpecificTokenMinimumRewardAmount returns the explicitly set minimum reward amount for a token.
//
// Parameters:
//   - tokenPath: Token path whose explicit minimum-reward override should be read.
//
// Returns:
//   - amount: Explicit minimum reward amount in token smallest units, or 0 when no override is configured.
//   - found: True when tokenPath has an explicit override; false when the default would be used.
func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

// GetTargetPoolPathByIncentiveId returns the pool path for an incentive ID.
//
// Parameters:
//   - poolPath: Pool path containing the incentive record.
//   - incentiveId: External incentive identifier to resolve.
//
// Returns:
//   - targetPoolPath: Pool path stored on the resolved incentive.
//   - err: Non-nil when poolPath or incentiveId cannot be resolved.
func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

// GetUnstakingFee returns the current unstaking fee rate in basis points (0-1,000; 100 = 1%).
//
// Returns:
//   - feeRate: Current staking-reward fee rate in basis points.
func GetUnstakingFee() uint64 {
	return getImplementation().GetUnstakingFee()
}

// HasUnstakedPosition returns whether a position was unstaked with rewards left to collect.
//
// Parameters:
//   - positionId: Position NFT token ID to check in the unstaked-position tree.
//
// Returns:
//   - unstaked: True when positionId has an exit checkpoint awaiting collection; false otherwise.
func HasUnstakedPosition(positionId uint64) bool {
	return getImplementation().HasUnstakedPosition(positionId)
}

// GetUnstakedPositionExitTime returns the timestamp at which an unstaked position stopped accruing rewards.
//
// Parameters:
//   - positionId: Position NFT token ID identifying the unstaked exit checkpoint.
//
// Returns:
//   - exitTime: Unix timestamp pinned as the end of the position's reward-accrual window.
//   - err: Non-nil when positionId has no unstaked checkpoint with uncollected rewards.
func GetUnstakedPositionExitTime(positionId uint64) (int64, error) {
	return getImplementation().GetUnstakedPositionExitTime(positionId)
}

// GetUnstakedPositionPendingIncentives returns the incentives an unstaked position has yet to collect.
//
// Parameters:
//   - positionId: Position NFT token ID identifying the unstaked exit checkpoint.
//
// Returns:
//   - incentiveIds: Copy of external incentive IDs still pending for the exit checkpoint.
//   - err: Non-nil when positionId has no unstaked checkpoint with uncollected rewards.
func GetUnstakedPositionPendingIncentives(positionId uint64) ([]string, error) {
	incentiveIds, err := getImplementation().GetUnstakedPositionPendingIncentives(positionId)
	if err != nil {
		return nil, err
	}
	return cloneStringSlice(incentiveIds), nil
}

// GetUncollectedIncentiveCount returns how many unstaked positions still owe a reward from the incentive.
//
// Parameters:
//   - incentiveId: External incentive identifier whose outstanding exit positions should be counted.
//
// Returns:
//   - count: Number of unstaked positions with an uncollected reward for incentiveId.
func GetUncollectedIncentiveCount(incentiveId string) int64 {
	return getImplementation().GetUncollectedIncentiveCount(incentiveId)
}

// IsStaked returns whether a position is staked.
//
// Parameters:
//   - positionId: Position NFT token ID to check in the active deposit tree.
//
// Returns:
//   - staked: True when positionId has an active deposit; false for an unstaked or unknown position.
func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// GetTotalEmissionSent returns the total GNS emission sent.
//
// Returns:
//   - amount: Cumulative GNS emission amount sent by the staker, in token units.
func GetTotalEmissionSent() int64 {
	return getImplementation().GetTotalEmissionSent()
}

// GetAllowedTokens returns the allowed external incentive tokens.
//
// Returns:
//   - tokenPaths: Copy of token paths permitted for external incentives.
func GetAllowedTokens() []string {
	return cloneStringSlice(getImplementation().GetAllowedTokens())
}

// GetDeniedRewardTokens returns the denied external incentive reward tokens.
//
// Returns:
//   - tokenPaths: Copy of token paths excluded from external incentive rewards.
func GetDeniedRewardTokens() []string {
	return cloneStringSlice(getImplementation().GetDeniedRewardTokens())
}

// GetWarmupTemplate returns the current warmup template.
//
// Returns:
//   - warmups: Copy of the configured warmup schedule used for newly staked positions.
func GetWarmupTemplate() []Warmup {
	return cloneWarmups(getImplementation().GetWarmupTemplate())
}

// GetPoolRewardCaches returns a read-only view of a pool's reward cache, keyed
// by the encoded block timestamp. Callers paginate it themselves through
// IterateByOffset and decode keys with DecodeInt64.
//
// Parameters:
//   - poolPath: Pool path whose reward-cache checkpoints should be read.
//
// Returns:
//   - caches: Read-only tree of timestamp keys to cached reward values, or nil when poolPath has no pool.
func GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolRewardCaches(poolPath)
}

// GetPoolIncentives returns a read-only view of a pool's external incentives,
// keyed by incentive ID. Reading an entry yields a clone, so the view cannot
// mutate realm state.
//
// Parameters:
//   - poolPath: Pool path whose external-incentive records should be read.
//
// Returns:
//   - incentives: Read-only tree keyed by incentive ID with cloned entries, or nil when poolPath has no pool.
func GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolIncentives(poolPath)
}

// GetPoolGlobalRewardRatioAccumulations returns a read-only view of a pool's
// global reward ratio accumulation, keyed by the encoded block timestamp.
//
// Parameters:
//   - poolPath: Pool path whose global reward-ratio checkpoints should be read.
//
// Returns:
//   - accumulations: Read-only tree of timestamp keys to stored accumulation values, or nil when poolPath has no pool.
func GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolGlobalRewardRatioAccumulations(poolPath)
}

// GetPoolHistoricalTicks returns a read-only view of a pool's historical ticks,
// keyed by the encoded block timestamp with the int32 tick as the value.
//
// Parameters:
//   - poolPath: Pool path whose historical tick checkpoints should be read.
//
// Returns:
//   - ticks: Read-only tree of timestamp keys to int32 ticks, or nil when poolPath has no pool.
func GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolHistoricalTicks(poolPath)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
//
// Returns:
//   - fees: Copy of pending protocol-fee amounts keyed by token path, in the corresponding token units.
func GetPendingProtocolFees() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetPendingProtocolFees())
}
