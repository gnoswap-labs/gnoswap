package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

type IStaker interface {
	IStakerManager
	IStakerGetter
}

type IStakerManager interface {
	StakeToken(_ int, rlm realm, positionId uint64, referrer string) string
	UnStakeToken(_ int, rlm realm, positionId uint64) string
	CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64)
	CollectEmissionReward(_ int, rlm realm, positionId uint64) (int64, int64)
	CollectExternalIncentiveReward(_ int, rlm realm, positionId uint64, incentiveId string) (int64, int64)

	SetPoolTier(_ int, rlm realm, poolPath string, tier uint64)
	ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64)
	RemovePoolTier(_ int, rlm realm, poolPath string)

	CreateExternalIncentive(
		_ int,
		rlm realm,
		targetPoolPath string,
		rewardToken string,
		rewardAmount int64,
		startTimestamp int64,
		endTimestamp int64,
	)
	EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address)
	CancelExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string)
	CollectExternalIncentivePenalty(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) int64
	AddToken(_ int, rlm realm, tokenPath string)
	RemoveToken(_ int, rlm realm, tokenPath string)

	SetWarmUp(_ int, rlm realm, pct, timeDuration int64)
	SetDepositGnsAmount(_ int, rlm realm, amount int64)
	SetMinimumRewardAmount(_ int, rlm realm, amount int64)
	SetTokenMinimumRewardAmount(_ int, rlm realm, paramsStr string)
	SetUnStakingFee(_ int, rlm realm, fee uint64)
}

type IStakerGetter interface {
	GetPool(poolPath string) (*Pool, error)
	GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree
	GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree
	GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree
	GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree
	GetDeposit(lpTokenId uint64) (*Deposit, error)
	CollectableEmissionReward(positionId uint64) (int64, error)
	CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error)
	GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error)
	GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error)
	GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error)
	GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error)
	GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error)
	GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error)
	GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error)
	GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error)
	IsIncentiveActive(poolPath string, incentiveId string) (bool, error)
	GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error)
	GetDepositGnsAmount() int64
	GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error)
	GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error)
	GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error)
	GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error)
	GetDepositLiquidityAsString(lpTokenId uint64) (string, error)
	GetDepositOwner(lpTokenId uint64) (address, error)
	GetDepositStakeTime(lpTokenId uint64) (int64, error)
	GetDepositTargetPoolPath(lpTokenId uint64) (string, error)
	GetDepositTickLower(lpTokenId uint64) (int32, error)
	GetDepositTickUpper(lpTokenId uint64) (int32, error)
	GetDepositWarmUp(lpTokenId uint64) ([]Warmup, error)
	GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error)
	GetExternalIncentiveByPoolPath(poolPath string) ([]ExternalIncentive, error)
	GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error)
	GetIncentiveCreator(poolPath string, incentiveId string) (address, error)
	GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error)
	GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error)
	GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error)
	GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error)
	GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error)
	GetMinimumRewardAmount() int64
	GetMinimumRewardAmountForToken(tokenPath string) int64
	GetPoolStakedLiquidity(poolPath string) (string, error)
	GetPoolsByTier(tier uint64) ([]string, error)
	GetPoolReward(tier uint64) (int64, error)
	GetPoolTier(poolPath string) uint64
	GetPoolTierCount(tier uint64) uint64
	GetPoolTierRatio(poolPath string) (uint64, error)
	GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool)
	GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error)
	GetUnstakingFee() uint64
	GetPendingProtocolFees() map[string]int64
	HasUnstakedPosition(positionId uint64) bool
	GetUnstakedPositionExitTime(positionId uint64) (int64, error)
	IsStaked(positionId uint64) bool
	GetTotalEmissionSent() int64
	GetAllowedTokens() []string
	GetWarmupTemplate() []Warmup
}

type IStakerStore interface {
	// DepositGnsAmount
	HasDepositGnsAmountStoreKey() bool
	GetDepositGnsAmount() int64
	SetDepositGnsAmount(_ int, rlm realm, amount int64) error

	// MinimumRewardAmount
	HasMinimumRewardAmountStoreKey() bool
	GetMinimumRewardAmount() int64
	SetMinimumRewardAmount(_ int, rlm realm, amount int64) error

	// Deposits
	HasDepositsStoreKey() bool
	GetDeposits() *bptree.BPTree
	SetDeposits(_ int, rlm realm, deposits *bptree.BPTree) error

	// ExternalIncentives
	HasExternalIncentivesStoreKey() bool
	GetExternalIncentives() *bptree.BPTree
	SetExternalIncentives(_ int, rlm realm, incentives *bptree.BPTree) error

	// TotalEmissionSent
	HasTotalEmissionSentStoreKey() bool
	GetTotalEmissionSent() int64
	SetTotalEmissionSent(_ int, rlm realm, amount int64) error

	// AllowedTokens
	HasAllowedTokensStoreKey() bool
	GetAllowedTokens() []string
	SetAllowedTokens(_ int, rlm realm, tokens []string) error
	AddAllowedToken(_ int, rlm realm, tokenPath string) error
	RemoveAllowedToken(_ int, rlm realm, tokenPath string) error

	// IncentiveCounter
	HasIncentiveCounterStoreKey() bool
	GetIncentiveCounter() *Counter
	SetIncentiveCounter(_ int, rlm realm, counter *Counter) error
	NextIncentiveID(creator address, timestamp int64) string

	// TokenSpecificMinimumRewards
	HasTokenSpecificMinimumRewardsStoreKey() bool
	GetTokenSpecificMinimumRewards() map[string]int64
	SetTokenSpecificMinimumRewards(_ int, rlm realm, rewards map[string]int64) error
	SetTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string, amount int64) error
	RemoveTokenSpecificMinimumRewardItem(_ int, rlm realm, tokenPath string) error

	// UnstakingFee
	HasUnstakingFeeStoreKey() bool
	GetUnstakingFee() uint64
	SetUnstakingFee(_ int, rlm realm, fee uint64) error

	HasPendingProtocolFeesStoreKey() bool
	GetPendingProtocolFees() map[string]int64
	SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error

	// UnstakedPositions
	HasUnstakedPositionsStoreKey() bool
	GetUnstakedPositions() *bptree.BPTree
	SetUnstakedPositions(_ int, rlm realm, positions *bptree.BPTree) error

	// UnsettledIncentiveCounts
	HasUnsettledIncentiveCountsStoreKey() bool
	GetUnsettledIncentiveCounts() map[string]int64
	SetUnsettledIncentiveCounts(_ int, rlm realm, counts map[string]int64) error
	SetUnsettledIncentiveCountItem(_ int, rlm realm, poolPath string, count int64) error
	RemoveUnsettledIncentiveCountItem(_ int, rlm realm, poolPath string) error

	// Pools
	HasPoolsStoreKey() bool
	GetPools() *bptree.BPTree
	SetPools(_ int, rlm realm, pools *bptree.BPTree) error

	// PoolTierMemberships
	HasPoolTierMembershipsStoreKey() bool
	GetPoolTierMemberships() *bptree.BPTree
	SetPoolTierMemberships(_ int, rlm realm, memberships *bptree.BPTree) error

	// PoolTierRatio
	HasPoolTierRatioStoreKey() bool
	GetPoolTierRatio() TierRatio
	SetPoolTierRatio(_ int, rlm realm, ratio TierRatio) error

	// PoolTierCounts
	HasPoolTierCountsStoreKey() bool
	GetPoolTierCounts() [AllTierCount]uint64
	SetPoolTierCounts(_ int, rlm realm, counts [AllTierCount]uint64) error

	// PoolTierLastRewardCacheTimestamp
	HasPoolTierLastRewardCacheTimestampStoreKey() bool
	GetPoolTierLastRewardCacheTimestamp() int64
	SetPoolTierLastRewardCacheTimestamp(_ int, rlm realm, timestamp int64) error

	// PoolTierCurrentEmission
	HasPoolTierCurrentEmissionStoreKey() bool
	GetPoolTierCurrentEmission() int64
	SetPoolTierCurrentEmission(_ int, rlm realm, emission int64) error

	// PoolTierGetEmission
	HasPoolTierGetEmissionStoreKey() bool
	GetPoolTierGetEmission() func() (int64, error)
	SetPoolTierGetEmission(_ int, rlm realm, fn func() (int64, error)) error

	// PoolTierGetHalvingBlocksInRange
	HasPoolTierGetHalvingBlocksInRangeStoreKey() bool
	GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64, error)
	SetPoolTierGetHalvingBlocksInRange(_ int, rlm realm, fn func(start, end int64) ([]int64, []int64, error)) error

	HasWarmupTemplateStoreKey() bool
	GetWarmupTemplate() []Warmup
	SetWarmupTemplate(_ int, rlm realm, warmups []Warmup) error

	// CurrentSwapBatch
	HasCurrentSwapBatchStoreKey() bool
	GetCurrentSwapBatch() *SwapBatchProcessor
	SetCurrentSwapBatch(_ int, rlm realm, batch *SwapBatchProcessor) error
}
