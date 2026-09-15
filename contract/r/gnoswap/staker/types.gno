package staker

import (
	u256 "gno.land/p/gnoswap/uint256/v1"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

type IStaker interface {
	IStakerManager
	IStakerGetter
}

type IStakerManager interface {
	// StakeToken stakes an LP position NFT, transfers custody to the staker, and
	// starts internal GNS and eligible external reward accounting.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - positionId: LP position NFT identifier whose liquidity will be staked.
	//   - referrer: Optional referral address or identifier supplied for referral tracking.
	//
	// Returns:
	//   - poolPath: Canonical token0:token1:fee path of the pool containing the staked position.
	//
	StakeToken(_ int, rlm realm, positionId uint64, referrer string) string

	// UnStakeToken records the position's exit checkpoint, removes it from active
	// staking, and returns the NFT to its owner.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - positionId: LP position NFT identifier to remove from staking.
	//
	// Returns:
	//   - poolPath: Canonical pool path from the position's active deposit.
	//
	UnStakeToken(_ int, rlm realm, positionId uint64) string

	// CollectReward settles both GNS emission and all currently payable external
	// incentive rewards for a live deposit or an unstaked exit checkpoint.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - positionId: LP position NFT identifier, or an identifier with an exit checkpoint.
	//
	// Returns:
	//   - internalRewardToUser: Decimal string for the GNS amount transferred to the position owner.
	//   - internalRewardPenalty: Decimal string for the GNS warm-up penalty sent to the community pool.
	//   - externalRewards: Map keyed by reward-token path containing gross external reward amounts before the staking fee.
	//   - externalPenalties: Map keyed by reward-token path containing warm-up penalties retained by each incentive.
	//
	CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64)

	// CollectEmissionReward settles only the internal GNS emission for a live
	// deposit or an unstaked exit checkpoint.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - positionId: LP position NFT identifier, or an identifier with an exit checkpoint.
	//
	// Returns:
	//   - rewardToUser: GNS amount transferred to the position owner.
	//   - rewardPenalty: GNS warm-up penalty transferred to the community pool.
	//
	CollectEmissionReward(_ int, rlm realm, positionId uint64) (int64, int64)

	// CollectExternalIncentiveReward settles one external incentive for a live
	// deposit or an unstaked exit checkpoint.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - positionId: LP position NFT identifier, or an identifier with an exit checkpoint.
	//   - incentiveId: External incentive identifier to settle for the position.
	//
	// Returns:
	//   - rewardAmount: Gross reward-token amount calculated for the incentive before the staking fee.
	//   - penaltyAmount: Warm-up penalty amount retained by the incentive rather than sent to the owner.
	//
	CollectExternalIncentiveReward(_ int, rlm realm, positionId uint64, incentiveId string) (int64, int64)

	// SetPoolTier assigns an internal GNS-emission tier to an existing pool.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - poolPath: Canonical pool path whose emission tier is being assigned.
	//   - tier: Pool tier index in [0, AllTierCount); zero removes the pool from the internal emission target.
	//
	SetPoolTier(_ int, rlm realm, poolPath string, tier uint64)

	// ChangePoolTier changes the internal GNS-emission tier of an existing pool.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - poolPath: Canonical pool path whose emission tier is being changed.
	//   - tier: Replacement pool tier index in [0, AllTierCount); zero removes the pool from the internal emission target.
	//
	ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64)

	// RemovePoolTier removes a pool from the internal GNS-emission tier system.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - poolPath: Canonical pool path to remove from tier membership.
	//
	RemovePoolTier(_ int, rlm realm, poolPath string)

	// CreateExternalIncentive funds and registers an external reward program for a
	// target pool over the requested Unix-time interval.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - targetPoolPath: Canonical pool path whose positions may earn the incentive.
	//   - rewardToken: Registered token path used to pay the external reward.
	//   - rewardAmount: Total reward-token amount deposited for the incentive.
	//   - startTimestamp: Inclusive Unix-second timestamp at which rewards begin accruing.
	//   - endTimestamp: Unix-second timestamp at which the reward interval ends.
	//
	CreateExternalIncentive(
		_ int,
		rlm realm,
		targetPoolPath string,
		rewardToken string,
		rewardAmount int64,
		startTimestamp int64,
		endTimestamp int64,
	)

	// EndExternalIncentive finalizes an ended external incentive and refunds its
	// remaining reward tokens and deposited GNS to the requested address.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - targetPoolPath: Canonical pool path containing the incentive.
	//   - incentiveId: Unique external incentive identifier to finalize.
	//   - refundAddress: Address receiving refundable reward tokens and the GNS deposit.
	//
	EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address)

	// CancelExternalIncentive removes an external incentive before it starts and
	// refunds the available funded amounts to its creator.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - targetPoolPath: Canonical pool path containing the incentive.
	//   - incentiveId: Unique external incentive identifier to cancel.
	//
	CancelExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string)

	// CollectExternalIncentivePenalty transfers accumulated warm-up penalties
	// from an ended external incentive to the requested address.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - targetPoolPath: Canonical pool path containing the incentive.
	//   - incentiveId: Ended external incentive identifier whose penalties are collected.
	//   - refundAddress: Address receiving the collected reward-token penalty.
	//
	// Returns:
	//   - penaltyAmount: Amount actually transferred, capped by the staker's available balance and zero when no penalty is accrued.
	//
	CollectExternalIncentivePenalty(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) int64

	// AddToken adds a registered non-default token path to the external-incentive allowlist.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - tokenPath: Registered token contract path to allow for new external incentives.
	//
	AddToken(_ int, rlm realm, tokenPath string)

	// RemoveToken removes a non-default token path from the external-incentive allowlist.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - tokenPath: Allowed token contract path to remove from future incentive creation.
	//
	RemoveToken(_ int, rlm realm, tokenPath string)

	// SetDeniedRewardToken sets or clears the operational deny flag for a reward token.
	// The flag prevents new incentives while leaving already-created incentives collectible.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - tokenPath: Reward-token contract path whose deny flag is being changed.
	//   - denied: true to deny new incentives for the token, or false to remove the denial.
	//
	SetDeniedRewardToken(_ int, rlm realm, tokenPath string, denied bool)

	// SetWarmUp changes the duration associated with one of the fixed warm-up ratios.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - pct: Warm-up completion ratio selector; supported values are 30, 50, 70, and 100.
	//   - timeDuration: Warm-up duration in seconds for the selected ratio; finite tiers are bounded by 365 days.
	//
	SetWarmUp(_ int, rlm realm, pct, timeDuration int64)

	// SetDepositGnsAmount updates the GNS deposit required when creating an external incentive.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - amount: Nonnegative GNS amount required as each external-incentive deposit.
	//
	SetDepositGnsAmount(_ int, rlm realm, amount int64)

	// SetMinimumRewardAmount updates the default minimum reward amount for external incentives.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - amount: Nonnegative reward-token amount used when no token-specific minimum exists.
	//
	SetMinimumRewardAmount(_ int, rlm realm, amount int64)

	// SetTokenMinimumRewardAmount sets or removes a token-specific external-incentive minimum.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - paramsStr: Colon-delimited tokenPath:amount string; amount 0 removes that token's override.
	//
	SetTokenMinimumRewardAmount(_ int, rlm realm, paramsStr string)

	// SetUnStakingFee updates the fee charged against collected staking rewards.
	//
	// Parameters:
	//   - _: Leading integer discriminator for implementation forwarding; proxy methods pass 0.
	//   - rlm: Current realm context forwarded unchanged by the staker proxy (0, cur, ...).
	//   - fee: Unstaking fee rate in basis points, where 10,000 basis points represents 100%.
	//
	SetUnStakingFee(_ int, rlm realm, fee uint64)
}

type IStakerGetter interface {
	// GetPool returns the registered pool for a canonical pool path.
	//
	// Parameters:
	//   - poolPath: Canonical token0:token1:fee path identifying the pool.
	//
	// Returns:
	//   - pool: Pointer to the registered pool; nil when lookup fails.
	//   - err: Nil on success, or an error when the pool is absent or cannot be decoded.
	//
	GetPool(poolPath string) (*Pool, error)

	// GetPoolRewardCaches exposes a read-only tree of a pool's reward-cache snapshots,
	// keyed by encoded block timestamps.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose reward cache is requested.
	//
	// Returns:
	//   - rewardCaches: Read-only reward-cache tree, or nil when the pool does not exist.
	//
	GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree

	// GetPoolIncentives exposes a read-only tree of a pool's external incentives,
	// keyed by incentive identifier.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose incentives are requested.
	//
	// Returns:
	//   - incentives: Read-only external-incentive tree, or nil when the pool does not exist.
	//
	GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree

	// GetPoolGlobalRewardRatioAccumulations exposes a read-only tree of global
	// reward-ratio snapshots keyed by encoded block timestamps.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose global accumulations are requested.
	//
	// Returns:
	//   - accumulations: Read-only global reward-ratio tree, or nil when the pool does not exist.
	//
	GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree

	// GetPoolHistoricalTicks exposes a read-only tree of historical pool ticks
	// keyed by encoded block timestamps.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose historical ticks are requested.
	//
	// Returns:
	//   - historicalTicks: Read-only historical-tick tree, or nil when the pool does not exist.
	//
	GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree

	// GetDeposit returns the staker deposit associated with an LP position NFT.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier used as the deposit key.
	//
	// Returns:
	//   - deposit: Stored deposit for the position; nil when lookup fails.
	//   - err: Nil on success, or an error when no deposit exists for the identifier.
	//
	GetDeposit(lpTokenId uint64) (*Deposit, error)

	// CollectableEmissionReward calculates the currently claimable internal GNS
	// emission without mutating the position.
	//
	// Parameters:
	//   - positionId: LP position identifier for a live deposit or exit checkpoint.
	//
	// Returns:
	//   - reward: Claimable internal GNS amount at the current chain time and height.
	//   - err: Nil on success, or an error when the position is neither staked nor checkpointed or calculation fails.
	//
	CollectableEmissionReward(positionId uint64) (int64, error)

	// CollectableExternalIncentiveReward calculates the currently claimable amount
	// for one external incentive without mutating the position.
	//
	// Parameters:
	//   - positionId: LP position identifier for a live deposit or exit checkpoint.
	//   - incentiveId: External incentive identifier whose reward is queried.
	//
	// Returns:
	//   - reward: Claimable gross reward-token amount, or zero when that incentive contributes no reward.
	//   - err: Nil on success, or an error when the position or reward calculation is invalid.
	//
	CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error)

	// GetCreatedHeightOfIncentive returns the chain height recorded when an incentive was created.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - createdHeight: Chain height persisted at incentive creation.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveCreatedTimestamp returns the Unix-second creation time of an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - createdTimestamp: Unix-second timestamp recorded at creation.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveTotalRewardAmount returns the amount originally funded for an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - totalRewardAmount: Original reward-token amount funded at creation.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveDistributedRewardAmount returns the reward amount already
	// distributed to positions or refunded when the incentive ended.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - distributedRewardAmount: Cumulative distributed or refunded reward-token amount.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveRemainingRewardAmount returns the current undistributed reward balance.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - remainingRewardAmount: Reward-token amount still held for future distribution or refund.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveAccumulatedPenaltyAmount returns warm-up penalties accumulated
	// from collections for an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - penaltyAmount: Reward-token penalty amount accumulated for later collection.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveDepositGnsAmount returns the GNS deposit locked by an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - depositGnsAmount: GNS amount deposited as the incentive's collateral.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveRefunded reports whether the incentive has been finalized and refunded.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - refunded: True after EndExternalIncentive has marked the incentive refunded; false otherwise.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error)

	// IsIncentiveActive reports whether an unrefunded incentive is within its
	// inclusive start/end Unix-second interval at the current time.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - active: True only when the current time is between the incentive bounds and it is not refunded.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	IsIncentiveActive(poolPath string, incentiveId string) (bool, error)

	// GetDepositExternalRewardLastCollectTimestamp returns the last collection
	// timestamp for one deposit/incentive pair.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier owning the external reward cursor.
	//   - incentiveId: External incentive identifier whose cursor is requested.
	//
	// Returns:
	//   - timestamp: Unix-second cursor, falling back to stake time when the incentive has never been collected.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error)

	// GetDepositGnsAmount returns the configured GNS deposit required per external incentive.
	//
	// Returns:
	//   - amount: Current required GNS deposit in token units.
	//
	GetDepositGnsAmount() int64

	// GetDepositInternalRewardLastCollectTimestamp returns the stored internal
	// reward collection cursor for a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier owning the internal reward cursor.
	//
	// Returns:
	//   - timestamp: Unix-second cursor, which is zero before the first internal collection.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error)

	// GetDepositCollectedInternalReward returns cumulative internal reward recorded for a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose collection total is requested.
	//
	// Returns:
	//   - amount: Cumulative GNS amount recorded as collected for the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error)

	// GetDepositCollectedExternalReward returns the cumulative amount recorded
	// for one deposit/incentive pair.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose collection total is requested.
	//   - incentiveId: External incentive identifier for the collection total.
	//
	// Returns:
	//   - amount: Cumulative gross reward-token amount recorded for that incentive.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error)

	// GetDepositLiquidity returns the full-precision liquidity assigned to a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose liquidity is requested.
	//
	// Returns:
	//   - liquidity: 256-bit liquidity value stored in the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error)

	// GetDepositLiquidityAsString returns the decimal string form of a deposit's liquidity.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose liquidity is requested.
	//
	// Returns:
	//   - liquidity: Decimal representation of the stored 256-bit liquidity.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositLiquidityAsString(lpTokenId uint64) (string, error)

	// GetDepositOwner returns the address recorded as owner of a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose owner is requested.
	//
	// Returns:
	//   - owner: Address recorded when the position was staked.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositOwner(lpTokenId uint64) (address, error)

	// GetDepositStakeTime returns the Unix-second timestamp when a position was staked.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose stake time is requested.
	//
	// Returns:
	//   - stakeTime: Unix-second timestamp stored in the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositStakeTime(lpTokenId uint64) (int64, error)

	// GetDepositTargetPoolPath returns the pool path recorded for a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose target pool is requested.
	//
	// Returns:
	//   - poolPath: Canonical target pool path recorded in the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositTargetPoolPath(lpTokenId uint64) (string, error)

	// GetDepositTickLower returns the lower concentrated-liquidity tick of a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose lower tick is requested.
	//
	// Returns:
	//   - tickLower: Signed lower tick stored in the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositTickLower(lpTokenId uint64) (int32, error)

	// GetDepositTickUpper returns the upper concentrated-liquidity tick of a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose upper tick is requested.
	//
	// Returns:
	//   - tickUpper: Signed upper tick stored in the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositTickUpper(lpTokenId uint64) (int32, error)

	// GetDepositWarmUp returns the warm-up records currently attached to a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose warm-up records are requested.
	//
	// Returns:
	//   - warmups: Warm-up schedule entries stored for the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositWarmUp(lpTokenId uint64) ([]Warmup, error)

	// GetDepositExternalIncentiveIdList returns external incentive identifiers
	// currently tracked by a deposit.
	//
	// Parameters:
	//   - lpTokenId: LP position NFT identifier whose incentive index is requested.
	//
	// Returns:
	//   - incentiveIds: External incentive IDs attached to the deposit.
	//   - err: Nil on success, or an error when the deposit does not exist.
	//
	GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error)

	// GetExternalIncentiveByPoolPath returns all stored external incentives targeting a pool.
	//
	// Parameters:
	//   - poolPath: Canonical pool path used to filter incentive records.
	//
	// Returns:
	//   - incentives: Matching external incentive records, possibly an empty slice.
	//   - err: Nil on success, or an error when a stored record has an invalid type.
	//
	GetExternalIncentiveByPoolPath(poolPath string) ([]ExternalIncentive, error)

	// GetIncentiveEndTimestamp returns the Unix-second end time of an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - endTimestamp: Inclusive Unix-second end bound recorded for the incentive.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error)

	// GetIncentiveCreator returns the address that created and funded an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - creator: Address recorded as the incentive creator.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveCreator(poolPath string, incentiveId string) (address, error)

	// GetIncentiveRewardAmount returns the remaining reward amount as a 256-bit unsigned value.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - rewardAmount: Remaining reward-token amount represented as a uint256 value.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error)

	// GetIncentiveRewardAmountAsString returns the decimal string form of the remaining reward.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - rewardAmount: Decimal representation of the remaining reward-token amount.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error)

	// GetIncentiveRewardPerSecondX128 returns the Q128-scaled reward rate of an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - rewardPerSecondX128: Reward-per-second rate scaled by 2^128 to preserve precision.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error)

	// GetIncentiveRewardToken returns the token path used to pay an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - rewardToken: Registered reward-token contract path.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error)

	// GetIncentiveStartTimestamp returns the Unix-second start time of an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - startTimestamp: Inclusive Unix-second start bound recorded for the incentive.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error)

	// GetMinimumRewardAmount returns the default minimum reward amount for external incentives.
	//
	// Returns:
	//   - amount: Default minimum reward-token amount used when no token-specific override exists.
	//
	GetMinimumRewardAmount() int64

	// GetMinimumRewardAmountForToken returns a token-specific minimum, falling
	// back to the default minimum when no override is configured.
	//
	// Parameters:
	//   - tokenPath: Reward-token contract path whose minimum is requested.
	//
	// Returns:
	//   - amount: Token-specific minimum when configured, otherwise the default minimum.
	//
	GetMinimumRewardAmountForToken(tokenPath string) int64

	// GetPoolStakedLiquidity returns the current total staked liquidity as a decimal string.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose active staked liquidity is requested.
	//
	// Returns:
	//   - liquidity: Decimal string for current staked liquidity, or zero when the pool has no value.
	//   - err: Nil on success, or an error when the pool does not exist.
	//
	GetPoolStakedLiquidity(poolPath string) (string, error)

	// GetPoolsByTier lists pool paths currently assigned to an internal emission tier.
	//
	// Parameters:
	//   - tier: Tier number used to filter pool membership; tier zero returns an empty list.
	//
	// Returns:
	//   - poolPaths: Pool paths assigned to the requested tier.
	//   - err: Nil on success, or an error when stored tier membership cannot be decoded.
	//
	GetPoolsByTier(tier uint64) ([]string, error)

	// GetPoolReward returns the current per-second GNS reward for a tier.
	//
	// Parameters:
	//   - tier: Supported nonzero tier whose reward rate is requested.
	//
	// Returns:
	//   - reward: Current tier reward amount per second.
	//   - err: Nil on success, or an invalid-tier error for zero or unsupported tiers.
	//
	GetPoolReward(tier uint64) (int64, error)

	// GetPoolTier returns the internal emission tier currently assigned to a pool.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose tier is requested.
	//
	// Returns:
	//   - tier: Assigned tier number; zero denotes no internal emission tier.
	//
	GetPoolTier(poolPath string) uint64

	// GetPoolTierCount returns the number of pools assigned to a tier.
	//
	// Parameters:
	//   - tier: Tier number whose membership count is requested; tier zero has count zero.
	//
	// Returns:
	//   - count: Current number of pools in the requested tier.
	//
	GetPoolTierCount(tier uint64) uint64

	// GetPoolTierRatio returns the reward ratio configured for a pool's current tier.
	//
	// Parameters:
	//   - poolPath: Canonical pool path whose current tier ratio is requested.
	//
	// Returns:
	//   - ratio: Current reward ratio for the pool's assigned tier.
	//   - err: Nil on success, or an invalid-tier error when the tier has no ratio.
	//
	GetPoolTierRatio(poolPath string) (uint64, error)

	// GetSpecificTokenMinimumRewardAmount looks up only an explicitly configured
	// token-specific minimum and does not apply the default fallback.
	//
	// Parameters:
	//   - tokenPath: Reward-token contract path whose override is requested.
	//
	// Returns:
	//   - amount: Configured token-specific minimum, or zero when absent.
	//   - found: True when an explicit override exists; false when the default should be used.
	//
	GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool)

	// GetTargetPoolPathByIncentiveId returns the pool path targeted by an incentive.
	//
	// Parameters:
	//   - poolPath: Pool path containing the incentive record.
	//   - incentiveId: External incentive identifier to inspect.
	//
	// Returns:
	//   - targetPoolPath: Pool path recorded as the incentive target.
	//   - err: Nil on success, or an error when the pool or incentive does not exist.
	//
	GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error)

	// GetUnstakingFee returns the current reward fee rate in basis points.
	//
	// Returns:
	//   - fee: Current unstaking fee, where 10,000 basis points represents 100%.
	//
	GetUnstakingFee() uint64

	// GetPendingProtocolFees returns pending protocol-fee amounts keyed by token path.
	//
	// Returns:
	//   - fees: Map from reward-token path to amount awaiting protocol-fee settlement.
	//
	GetPendingProtocolFees() map[string]int64

	// HasUnstakedPosition reports whether an exit checkpoint with uncollected
	// rewards exists for a position.
	//
	// Parameters:
	//   - positionId: LP position identifier whose exit checkpoint is queried.
	//
	// Returns:
	//   - exists: True when an uncollected exit checkpoint is present.
	//
	HasUnstakedPosition(positionId uint64) bool

	// GetUnstakedPositionExitTime returns when an exit checkpoint stopped accruing rewards.
	//
	// Parameters:
	//   - positionId: LP position identifier whose checkpoint is requested.
	//
	// Returns:
	//   - exitTime: Unix-second timestamp at which the position was unstaked.
	//   - err: Nil on success, or an error when no uncollected checkpoint exists.
	//
	GetUnstakedPositionExitTime(positionId uint64) (int64, error)

	// GetUnstakedPositionPendingIncentives returns external incentive IDs still
	// owed by an exit checkpoint.
	//
	// Parameters:
	//   - positionId: LP position identifier whose checkpoint is requested.
	//
	// Returns:
	//   - incentiveIds: External incentive IDs pending collection for the checkpoint.
	//   - err: Nil on success, or an error when no uncollected checkpoint exists.
	//
	GetUnstakedPositionPendingIncentives(positionId uint64) ([]string, error)

	// GetUncollectedIncentiveCount returns the number of exit checkpoints still
	// carrying an uncollected claim for an incentive.
	//
	// Parameters:
	//   - incentiveId: External incentive identifier whose checkpoint count is requested.
	//
	// Returns:
	//   - count: Number of uncollected exit-position claims for the incentive.
	//
	GetUncollectedIncentiveCount(incentiveId string) int64

	// IsStaked reports whether a live deposit exists for a position.
	//
	// Parameters:
	//   - positionId: LP position identifier to query.
	//
	// Returns:
	//   - staked: True when the position is present in active deposits.
	//
	IsStaked(positionId uint64) bool

	// GetTotalEmissionSent returns cumulative GNS emission sent or accounted for.
	//
	// Returns:
	//   - amount: Cumulative internal GNS emission amount recorded by the staker.
	//
	GetTotalEmissionSent() int64

	// GetAllowedTokens returns token paths approved for new external incentives.
	//
	// Returns:
	//   - tokenPaths: Registered external-incentive token paths currently allowed.
	//
	GetAllowedTokens() []string

	// GetDeniedRewardTokens returns token paths denied for new external incentives.
	//
	// Returns:
	//   - tokenPaths: Reward-token paths on the operational deny list.
	//
	GetDeniedRewardTokens() []string

	// GetWarmupTemplate returns the current warm-up schedule used for new deposits.
	//
	// Returns:
	//   - warmups: Ordered warm-up entries defining reward-release ratios and durations.
	//
	GetWarmupTemplate() []Warmup
}

type IStakerStore interface {
	// HasDepositGnsAmountStoreKey reports whether the configured GNS-deposit key exists.
	//
	// Returns:
	//   - exists: True when the depositGnsAmount key is present in persistent storage.
	//
	HasDepositGnsAmountStoreKey() bool

	// GetDepositGnsAmount returns the stored GNS deposit required per external incentive.
	//
	// Returns:
	//   - amount: Persisted GNS amount in token units; storage read or type failures panic.
	//
	GetDepositGnsAmount() int64

	// SetDepositGnsAmount persists the GNS deposit required per external incentive.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - amount: GNS amount in token units to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetDepositGnsAmount(_ int, rlm realm, amount int64) error

	// HasMinimumRewardAmountStoreKey reports whether the default minimum-reward key exists.
	//
	// Returns:
	//   - exists: True when the minimumRewardAmount key is present in persistent storage.
	//
	HasMinimumRewardAmountStoreKey() bool

	// GetMinimumRewardAmount returns the default minimum external-incentive reward.
	//
	// Returns:
	//   - amount: Persisted default reward-token minimum; storage read or type failures panic.
	//
	GetMinimumRewardAmount() int64

	// SetMinimumRewardAmount persists the default minimum external-incentive reward.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - amount: Default minimum reward-token amount in token units.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetMinimumRewardAmount(_ int, rlm realm, amount int64) error

	// HasDepositsStoreKey reports whether the active-deposits tree key exists.
	//
	// Returns:
	//   - exists: True when the deposits key is present in persistent storage.
	//
	HasDepositsStoreKey() bool

	// GetDeposits returns the persisted active position-deposit tree.
	//
	// Returns:
	//   - deposits: B+tree mapping LP position IDs to deposits; storage read or type failures panic.
	//
	GetDeposits() *bptree.BPTree

	// SetDeposits persists the active position-deposit tree.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - deposits: B+tree containing active position deposits to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error

	// HasExternalIncentivesStoreKey reports whether the external-incentives tree key exists.
	//
	// Returns:
	//   - exists: True when the externalIncentives key is present in persistent storage.
	//
	HasExternalIncentivesStoreKey() bool

	// GetExternalIncentives returns the persisted external-incentive tree.
	//
	// Returns:
	//   - incentives: B+tree mapping incentive IDs to incentive records; storage read or type failures panic.
	//
	GetExternalIncentives() *bptree.BPTree

	// SetExternalIncentives persists the external-incentive tree.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - incentives: B+tree containing external-incentive records to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetExternalIncentives(_ int, rlm realm, incentives *bptree.BPTree) error

	// HasTotalEmissionSentStoreKey reports whether the cumulative-emission key exists.
	//
	// Returns:
	//   - exists: True when the totalEmissionSent key is present in persistent storage.
	//
	HasTotalEmissionSentStoreKey() bool

	// GetTotalEmissionSent returns the persisted cumulative GNS emission amount.
	//
	// Returns:
	//   - amount: Cumulative internal emission in GNS token units; storage read or type failures panic.
	//
	GetTotalEmissionSent() int64

	// SetTotalEmissionSent persists the cumulative GNS emission amount.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - amount: Cumulative GNS amount to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetTotalEmissionSent(_ int, rlm realm, amount int64) error

	// HasAllowedTokensStoreKey reports whether the external-incentive allowlist key exists.
	//
	// Returns:
	//   - exists: True when the allowedTokens key is present in persistent storage.
	//
	HasAllowedTokensStoreKey() bool

	// GetAllowedTokens returns a copy of token paths allowed for new incentives.
	//
	// Returns:
	//   - tokenPaths: Store-owned allowlist copied into a caller-safe slice.
	//
	GetAllowedTokens() []string

	// SetAllowedTokens replaces the external-incentive allowlist.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokens: Token contract paths to persist as the new allowlist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetAllowedTokens(_ int, rlm realm, tokens []string) error

	// AddAllowedToken adds a token path to the allowlist when it is not already present.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Token contract path to add to the allowlist.
	//
	// Returns:
	//   - err: Nil when added or already present, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	AddAllowedToken(_ int, rlm realm, tokenPath string) error

	// RemoveAllowedToken removes a token path from the allowlist when present.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Token contract path to remove from the allowlist.
	//
	// Returns:
	//   - err: Nil when removed or absent, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	RemoveAllowedToken(_ int, rlm realm, tokenPath string) error

	// HasDeniedRewardTokensStoreKey reports whether the external reward deny-list key exists.
	//
	// Returns:
	//   - exists: True when the deniedRewardTokens key is present in persistent storage.
	//
	HasDeniedRewardTokensStoreKey() bool

	// GetDeniedRewardTokens returns a copy of token paths denied for new incentives.
	//
	// Returns:
	//   - tokenPaths: Store-owned deny list copied for callers; an uninitialized key yields an empty slice.
	//
	GetDeniedRewardTokens() []string

	// AddDeniedRewardToken adds a token path to the deny list when absent.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Reward-token contract path to deny for new incentives.
	//
	// Returns:
	//   - err: Nil when added or already present, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	AddDeniedRewardToken(_ int, rlm realm, tokenPath string) error

	// RemoveDeniedRewardToken removes a token path from the deny list when present.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Reward-token contract path to allow again for new incentives.
	//
	// Returns:
	//   - err: Nil when removed or absent, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	RemoveDeniedRewardToken(_ int, rlm realm, tokenPath string) error

	// HasIncentiveCounterStoreKey reports whether the incentive-counter key exists.
	//
	// Returns:
	//   - exists: True when the incentiveCounter key is present in persistent storage.
	//
	HasIncentiveCounterStoreKey() bool

	// GetIncentiveCounter returns the persisted counter used to allocate incentive IDs.
	//
	// Returns:
	//   - counter: Incentive-ID counter object; storage read or type failures panic.
	//
	GetIncentiveCounter() *Counter

	// SetIncentiveCounter persists the incentive-ID counter.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - counter: Counter object whose next value will be used for incentive IDs.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetIncentiveCounter(_ int, rlm realm, counter *Counter) error

	// NextIncentiveID consumes the next counter value and formats a unique incentive ID.
	//
	// Parameters:
	//   - creator: Address that is creating and funding the incentive.
	//   - timestamp: Unix-second creation timestamp embedded in the identifier.
	//
	// Returns:
	//   - incentiveId: Identifier combining creator, timestamp, and the incremented counter index.
	//
	NextIncentiveID(creator address, timestamp int64) string

	// HasTokenSpecificMinimumRewardsStoreKey reports whether token-specific minimums exist.
	//
	// Returns:
	//   - exists: True when the tokenSpecificMinimumRewards key is present in persistent storage.
	//
	HasTokenSpecificMinimumRewardsStoreKey() bool

	// GetTokenSpecificMinimumRewards returns configured token-specific reward minimums.
	//
	// Returns:
	//   - rewards: Map from token contract path to minimum reward amount; storage read or type failures panic.
	//
	GetTokenSpecificMinimumRewards() map[string]int64

	// SetTokenSpecificMinimumRewards replaces all token-specific minimums.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - rewards: Token-path-to-minimum-amount mapping to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetTokenSpecificMinimumRewards(_ int, rlm realm, rewards map[string]int64) error

	// SetTokenSpecificMinimumRewardItem sets one token's minimum reward entry.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Token contract path whose override is being set.
	//   - amount: Token-specific minimum reward amount in token units.
	//
	// Returns:
	//   - err: Nil when the item is stored, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	SetTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string, amount int64) error

	// RemoveTokenSpecificMinimumRewardItem removes one token's minimum reward entry.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - tokenPath: Token contract path whose override is being removed.
	//
	// Returns:
	//   - err: Nil after rebuilding the mapping without the item, ErrSpoofedRealm for a non-current realm, or the KV-store write error.
	//
	RemoveTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string) error

	// HasUnstakingFeeStoreKey reports whether the unstaking-fee key exists.
	//
	// Returns:
	//   - exists: True when the unstakingFee key is present in persistent storage.
	//
	HasUnstakingFeeStoreKey() bool

	// GetUnstakingFee returns the stored reward fee rate in basis points.
	//
	// Returns:
	//   - fee: Persisted fee rate, where 10,000 basis points represents 100%.
	//
	GetUnstakingFee() uint64

	// SetUnstakingFee persists the reward fee rate.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - fee: Fee rate in basis points.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetUnstakingFee(_ int, rlm realm, fee uint64) error

	// HasPendingProtocolFeesStoreKey reports whether pending protocol fees exist.
	//
	// Returns:
	//   - exists: True when the pendingProtocolFees key is present in persistent storage.
	//
	HasPendingProtocolFeesStoreKey() bool

	// GetPendingProtocolFees returns pending protocol-fee amounts by token path.
	//
	// Returns:
	//   - fees: Token-path-to-amount map awaiting settlement; storage read or type failures panic.
	//
	GetPendingProtocolFees() map[string]int64

	// SetPendingProtocolFees replaces all pending protocol-fee amounts.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - fees: Token-path-to-amount map copied into realm-owned persistent storage.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm or write-permission error when unauthorized, or the KV-store write error.
	//
	SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error

	// GetPendingProtocolFee returns the pending amount for one token path.
	//
	// Parameters:
	//   - tokenPath: Token contract path whose pending amount is requested.
	//
	// Returns:
	//   - amount: Pending amount for the token, or zero when no entry exists.
	//
	GetPendingProtocolFee(tokenPath string) int64

	// SetPendingProtocolFee updates one token's pending protocol-fee amount.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; it must also be authorized for code-realm writes.
	//   - tokenPath: Token contract path whose pending amount is updated.
	//   - amount: Pending protocol-fee amount to record for the token.
	//
	// Returns:
	//   - err: Nil when updated, ErrSpoofedRealm or write-permission error when unauthorized, or the KV-store write error.
	//
	SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error

	// RemovePendingProtocolFee deletes one token's pending protocol-fee entry.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; it must also be authorized for code-realm writes.
	//   - tokenPath: Token contract path whose pending entry is deleted.
	//
	// Returns:
	//   - err: Nil when removed, ErrSpoofedRealm or write-permission error when unauthorized, or the KV-store write error.
	//
	RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error

	// HasUnstakedPositionsStoreKey reports whether the exit-checkpoint tree key exists.
	//
	// Returns:
	//   - exists: True when the unstakedPositions key is present in persistent storage.
	//
	HasUnstakedPositionsStoreKey() bool

	// GetUnstakedPositions returns the persisted exit-checkpoint tree.
	//
	// Returns:
	//   - positions: B+tree mapping position IDs to unstaked checkpoints; storage read or type failures panic.
	//
	GetUnstakedPositions() *bptree.BPTree

	// SetUnstakedPositions persists the exit-checkpoint tree.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - positions: B+tree containing unstaked position checkpoints to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetUnstakedPositions(_ int, rlm realm, positions *bptree.BPTree) error

	// HasUncollectedIncentiveCountsStoreKey reports whether the incentive-count tree key exists.
	//
	// Returns:
	//   - exists: True when the uncollectedIncentiveCounts key is present in persistent storage.
	//
	HasUncollectedIncentiveCountsStoreKey() bool

	// GetUncollectedIncentiveCounts returns the persisted count tree for exit claims.
	//
	// Returns:
	//   - counts: B+tree mapping incentive IDs to uncollected checkpoint counts; storage read or type failures panic.
	//
	GetUncollectedIncentiveCounts() *bptree.BPTree

	// SetUncollectedIncentiveCounts persists the exit-claim count tree.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - counts: B+tree containing uncollected incentive counts to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetUncollectedIncentiveCounts(_ int, rlm realm, counts *bptree.BPTree) error
	// HasPoolsStoreKey reports whether the pool registry tree key exists.
	//
	// Returns:
	//   - exists: True when the pools key is present in persistent storage.
	//
	HasPoolsStoreKey() bool

	// GetPools returns the persisted pool registry tree.
	//
	// Returns:
	//   - pools: B+tree mapping canonical pool paths to pool records; storage read or type failures panic.
	//
	GetPools() *bptree.BPTree

	// SetPools persists the pool registry tree.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - pools: B+tree containing pool records to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPools(_ int, rlm realm, pools *bptree.BPTree) error

	// HasPoolTierMembershipsStoreKey reports whether pool-to-tier membership data exists.
	//
	// Returns:
	//   - exists: True when the poolTierMemberships key is present in persistent storage.
	//
	HasPoolTierMembershipsStoreKey() bool

	// GetPoolTierMemberships returns the persisted pool-to-tier membership tree.
	//
	// Returns:
	//   - memberships: B+tree mapping pool paths to tier numbers; storage read or type failures panic.
	//
	GetPoolTierMemberships() *bptree.BPTree

	// SetPoolTierMemberships persists pool-to-tier membership data.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - memberships: B+tree mapping pool paths to tier numbers.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierMemberships(_ int, rlm realm, memberships *bptree.BPTree) error

	// HasPoolTierRatioStoreKey reports whether tier reward-ratio data exists.
	//
	// Returns:
	//   - exists: True when the poolTierRatio key is present in persistent storage.
	//
	HasPoolTierRatioStoreKey() bool

	// GetPoolTierRatio returns the persisted tier-to-ratio configuration.
	//
	// Returns:
	//   - ratio: TierRatio configuration used to calculate pool emission shares; storage read or type failures panic.
	//
	GetPoolTierRatio() TierRatio

	// SetPoolTierRatio persists tier reward-ratio configuration.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - ratio: TierRatio configuration to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierRatio(_ int, rlm realm, ratio TierRatio) error

	// HasPoolTierCountsStoreKey reports whether tier membership counts exist.
	//
	// Returns:
	//   - exists: True when the poolTierCounts key is present in persistent storage.
	//
	HasPoolTierCountsStoreKey() bool

	// GetPoolTierCounts returns the fixed-size array of pool counts by tier.
	//
	// Returns:
	//   - counts: Per-tier pool membership counts indexed by AllTierCount; storage read or type failures panic.
	//
	GetPoolTierCounts() [AllTierCount]uint64

	// SetPoolTierCounts persists per-tier pool membership counts.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - counts: Fixed-size per-tier pool membership counts to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierCounts(_ int, rlm realm, counts [AllTierCount]uint64) error

	// HasPoolTierLastRewardCacheTimestampStoreKey reports whether the reward-cache timestamp exists.
	//
	// Returns:
	//   - exists: True when the poolTierLastRewardCacheTimestamp key is present in persistent storage.
	//
	HasPoolTierLastRewardCacheTimestampStoreKey() bool

	// GetPoolTierLastRewardCacheTimestamp returns the last tier reward-cache timestamp.
	//
	// Returns:
	//   - timestamp: Unix-second timestamp persisted after tier reward caching; read/type failures panic.
	//
	GetPoolTierLastRewardCacheTimestamp() int64

	// SetPoolTierLastRewardCacheTimestamp persists the tier reward-cache timestamp.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - timestamp: Unix-second timestamp to persist as the last cache boundary.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierLastRewardCacheTimestamp(_ int, rlm realm, timestamp int64) error

	// HasPoolTierCurrentEmissionStoreKey reports whether the current tier-emission key exists.
	//
	// Returns:
	//   - exists: True when the poolTierCurrentEmission key is present in persistent storage.
	//
	HasPoolTierCurrentEmissionStoreKey() bool

	// GetPoolTierCurrentEmission returns the current GNS emission rate cached for tiers.
	//
	// Returns:
	//   - emission: Current per-second emission amount; storage read or type failures panic.
	//
	GetPoolTierCurrentEmission() int64

	// SetPoolTierCurrentEmission persists the current tier-emission rate.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - emission: Current per-second GNS emission amount to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierCurrentEmission(_ int, rlm realm, emission int64) error

	// HasPoolTierGetEmissionStoreKey reports whether the emission-rate callback exists.
	//
	// Returns:
	//   - exists: True when the poolTierGetEmission key is present in persistent storage.
	//
	HasPoolTierGetEmissionStoreKey() bool

	// GetPoolTierGetEmission returns the callback used to query current emission.
	//
	// Returns:
	//   - getEmission: Callback returning the current emission amount and an error; storage read or type failures panic.
	//
	GetPoolTierGetEmission() func() (int64, error)

	// SetPoolTierGetEmission persists the callback used to query current emission.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - fn: Callback that returns the current per-second emission amount, or an error when unavailable.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierGetEmission(_ int, rlm realm, fn func() (int64, error)) error

	// HasPoolTierGetHalvingBlocksInRangeStoreKey reports whether the halving-range callback exists.
	//
	// Returns:
	//   - exists: True when the poolTierGetHalvingBlocksInRange key is present in persistent storage.
	//
	HasPoolTierGetHalvingBlocksInRangeStoreKey() bool

	// GetPoolTierGetHalvingBlocksInRange returns the callback used to query
	// halving timestamps and matching emission amounts for a time range.
	//
	// Returns:
	//   - getHalvingBlocksInRange: Callback taking [start,end) timestamps and returning ascending halving timestamps, corresponding emissions, and an error; storage read or type failures panic.
	//
	GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64, error)

	// SetPoolTierGetHalvingBlocksInRange persists the halving-range callback.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - fn: Callback taking a [start,end) timestamp interval and returning matching halving timestamps, emission amounts, and an error.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetPoolTierGetHalvingBlocksInRange(_ int, rlm realm, fn func(start, end int64) ([]int64, []int64, error)) error

	// HasWarmupTemplateStoreKey reports whether the warm-up template key exists.
	//
	// Returns:
	//   - exists: True when the warmupTemplate key is present in persistent storage.
	//
	HasWarmupTemplateStoreKey() bool

	// GetWarmupTemplate returns a copy of the warm-up schedule for new deposits.
	//
	// Returns:
	//   - warmups: Caller-safe copy of ordered warm-up ratio and duration entries.
	//
	GetWarmupTemplate() []Warmup

	// SetWarmupTemplate replaces the warm-up schedule for new deposits.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - warmups: Ordered warm-up ratio and duration entries to persist.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetWarmupTemplate(_ int, rlm realm, warmups []Warmup) error

	// HasCurrentSwapBatchStoreKey reports whether the current swap-batch key exists.
	//
	// Returns:
	//   - exists: True when the currentSwapBatch key is present in persistent storage.
	//
	HasCurrentSwapBatchStoreKey() bool

	// GetCurrentSwapBatch returns the persisted swap-batch processor state.
	//
	// Returns:
	//   - batch: Current SwapBatchProcessor pointer; storage read or type failures panic.
	//
	GetCurrentSwapBatch() *SwapBatchProcessor

	// SetCurrentSwapBatch persists the current swap-batch processor state.
	//
	// Parameters:
	//   - _: Leading integer discriminator for internal store forwarding; callers pass 0.
	//   - rlm: Propagated current realm context; a non-current realm is rejected before writing.
	//   - batch: SwapBatchProcessor state to persist for the current batch.
	//
	// Returns:
	//   - err: Nil when stored, ErrSpoofedRealm for a non-current realm, or the underlying KV-store write error.
	//
	SetCurrentSwapBatch(_ int, rlm realm, batch *SwapBatchProcessor) error
}
