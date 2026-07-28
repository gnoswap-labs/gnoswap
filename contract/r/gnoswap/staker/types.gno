package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
)

type IStaker interface {
	IStakerManager
	IStakerGetter
}

type IStakerManager interface {
	StakeToken(_ int, rlm realm, positionId uint64, referrer string) string
	UnStakeToken(_ int, rlm realm, positionId uint64) string
	CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64)

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
	GetPool(poolPath string) *Pool
	GetPoolRewardCacheCount(poolPath string) uint64
	GetPoolRewardCacheIDs(poolPath string, offset, count int) []int64
	GetPoolRewardCache(poolPath string, timestamp uint64) int64
	GetPoolIncentiveCount(poolPath string) uint64
	GetPoolIncentiveIDs(poolPath string, offset, count int) []string
	GetPoolGlobalRewardRatioAccumulationCount(poolPath string) uint64
	GetPoolGlobalRewardRatioAccumulationIDs(poolPath string, offset, count int) []uint64
	GetPoolGlobalRewardRatioAccumulation(poolPath string, timestamp uint64) string
	GetPoolHistoricalTickCount(poolPath string) uint64
	GetPoolHistoricalTickIDs(poolPath string, offset, count int) []int32
	GetPoolHistoricalTick(poolPath string, tick uint64) int32
	GetIncentive(poolPath string, incentiveId string) *ExternalIncentive
	GetDeposit(lpTokenId uint64) *Deposit
	CollectableEmissionReward(positionId uint64) int64
	CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64
	GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64
	GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64
	GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64
	GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64
	GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64
	GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) int64
	GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64
	GetIncentiveRefunded(poolPath string, incentiveId string) bool
	IsIncentiveActive(poolPath string, incentiveId string) bool
	GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64
	GetDepositGnsAmount() int64
	GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64
	GetDepositCollectedInternalReward(lpTokenId uint64) int64
	GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64
	GetDepositLiquidity(lpTokenId uint64) *u256.Uint
	GetDepositLiquidityAsString(lpTokenId uint64) string
	GetDepositOwner(lpTokenId uint64) address
	GetDepositStakeTime(lpTokenId uint64) int64
	GetDepositTargetPoolPath(lpTokenId uint64) string
	GetDepositTickLower(lpTokenId uint64) int32
	GetDepositTickUpper(lpTokenId uint64) int32
	GetDepositWarmUp(lpTokenId uint64) []Warmup
	GetDepositExternalIncentiveIdList(lpTokenId uint64) []string
	GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive
	GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64
	GetIncentiveCreator(poolPath string, incentiveId string) address
	GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint
	GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string
	GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) *u256.Uint
	GetIncentiveRewardToken(poolPath string, incentiveId string) string
	GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64
	GetMinimumRewardAmount() int64
	GetMinimumRewardAmountForToken(tokenPath string) int64
	GetPoolIncentiveIdList(poolPath string) []string
	GetPoolStakedLiquidity(poolPath string) string
	GetPoolsByTier(tier uint64) []string
	GetPoolReward(tier uint64) int64
	GetPoolTier(poolPath string) uint64
	GetPoolTierCount(tier uint64) uint64
	GetPoolTierRatio(poolPath string) uint64
	GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool)
	GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string
	GetUnstakingFee() uint64
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
	GetPoolTierGetEmission() func() int64
	SetPoolTierGetEmission(_ int, rlm realm, fn func() int64) error

	// PoolTierGetHalvingBlocksInRange
	HasPoolTierGetHalvingBlocksInRangeStoreKey() bool
	GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64)
	SetPoolTierGetHalvingBlocksInRange(_ int, rlm realm, fn func(start, end int64) ([]int64, []int64)) error

	HasWarmupTemplateStoreKey() bool
	GetWarmupTemplate() []Warmup
	SetWarmupTemplate(_ int, rlm realm, warmups []Warmup) error

	// CurrentSwapBatch
	HasCurrentSwapBatchStoreKey() bool
	GetCurrentSwapBatch() *SwapBatchProcessor
	SetCurrentSwapBatch(_ int, rlm realm, batch *SwapBatchProcessor) error

	// ExternalIncentivesByCreationTime
	HasExternalIncentivesByCreationTimeStoreKey() bool
	GetExternalIncentivesByCreationTime() *UintTree
	SetExternalIncentivesByCreationTime(_ int, rlm realm, tree *UintTree) error
}
