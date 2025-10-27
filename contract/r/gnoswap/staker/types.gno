package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
)

type IStaker interface {
	IStakerManager
	IStakerGetter
	IStakerApi
}

type IStakerManager interface {
	StakeToken(positionId uint64, referrer string) string
	UnStakeToken(positionId uint64, unwrapResult bool) string
	MintAndStake(
		token0 string,
		token1 string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		amount0Desired string,
		amount1Desired string,
		amount0Min string,
		amount1Min string,
		deadline int64,
		referrer string,
	) (uint64, string, string, string, string)
	CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64)

	SetPoolTier(poolPath string, tier uint64)
	ChangePoolTier(poolPath string, tier uint64)
	RemovePoolTier(poolPath string)

	CreateExternalIncentive(
		targetPoolPath string,
		rewardToken string,
		rewardAmount int64,
		startTimestamp int64,
		endTimestamp int64,
	)
	EndExternalIncentive(targetPoolPath, incentiveId string)
	AddToken(tokenPath string)
	RemoveToken(tokenPath string)

	SetWarmUp(pct, timeDuration int64)
	SetDepositGnsAmount(amount int64)
	SetMinimumRewardAmount(amount int64)
	SetTokenMinimumRewardAmount(paramsStr string)
	SetUnStakingFee(fee int64)
}

type IStakerGetter interface {
	GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64
	GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64
	GetDepositGnsAmount() int64
	GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64
	GetDepositLiquidity(lpTokenId uint64) *u256.Uint
	GetDepositLiquidityAsString(lpTokenId uint64) string
	GetDepositStakeTime(lpTokenId uint64) int64
	GetDepositStakeTimestamp(lpTokenId uint64) int64
	GetDepositTargetPoolPath(lpTokenId uint64) string
	GetDepositTickLower(lpTokenId uint64) int32
	GetDepositTickUpper(lpTokenId uint64) int32
	GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64
	GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint
	GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string
	GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64
	GetIncentiveRewardToken(poolPath string, incentiveId string) string
	GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64
	GetMinimumRewardAmount() int64
	GetMinimumRewardAmountForToken(tokenPath string) int64
	GetPoolIncentiveIdList(poolPath string) []string
	GetPoolReward(tier uint64) int64
	GetPoolTier(poolPath string) uint64
	GetPoolTierCount(tier uint64) uint64
	GetPoolTierRatio(poolPath string) uint64
	GetPrintExternalInfo() string
	GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool)
	GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string
	GetUnstakingFee() int64
	IsArchivedExternalIncentive(incentiveId string) bool
	IsStaked(positionId uint64) bool
}

type IStakerApi interface {
	ApiGetExternalIncentiveById(poolPath, incentiveId string) string
	ApiGetExternalIncentives() string
	ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string
	ApiGetInternalIncentives() string
	ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string
	ApiGetInternalIncentivesByTiers(targetTier uint64) string
	ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string
	ApiGetRewardTokensByPoolPath(targetPoolPath string) string
	ApiGetStakesByLpTokenId(targetLpTokenId uint64) string
}

type IStakerStore interface {
	// DepositGnsAmount
	HasDepositGnsAmountStoreKey() bool
	GetDepositGnsAmount() int64
	SetDepositGnsAmount(amount int64) error

	// MinimumRewardAmount
	HasMinimumRewardAmountStoreKey() bool
	GetMinimumRewardAmount() int64
	SetMinimumRewardAmount(amount int64) error

	// Deposits
	HasDepositsStoreKey() bool
	GetDeposits() *avl.Tree
	SetDeposits(deposits *avl.Tree) error

	// ExternalIncentives
	HasExternalIncentivesStoreKey() bool
	GetExternalIncentives() *avl.Tree
	SetExternalIncentives(incentives *avl.Tree) error

	// Stakers
	HasStakersStoreKey() bool
	GetStakers() *avl.Tree
	SetStakers(stakers *avl.Tree) error

	// TotalEmissionSent
	HasTotalEmissionSentStoreKey() bool
	GetTotalEmissionSent() int64
	SetTotalEmissionSent(amount int64) error

	// AllowedTokens
	HasAllowedTokensStoreKey() bool
	GetAllowedTokens() []string
	SetAllowedTokens(tokens []string) error

	// IncentiveCounter
	HasIncentiveCounterStoreKey() bool
	GetIncentiveCounter() *Counter
	SetIncentiveCounter(counter *Counter) error
	NextIncentiveID(creator address, timestamp int64) string

	// TokenSpecificMinimumRewards
	HasTokenSpecificMinimumRewardsStoreKey() bool
	GetTokenSpecificMinimumRewards() *avl.Tree
	SetTokenSpecificMinimumRewards(rewards *avl.Tree) error

	// UnstakingFee
	HasUnstakingFeeStoreKey() bool
	GetUnstakingFee() int64
	SetUnstakingFee(fee int64) error

	// Pools
	HasPoolsStoreKey() bool
	GetPools() *avl.Tree
	SetPools(pools *avl.Tree) error

	// PoolTierMemberships
	HasPoolTierMembershipsStoreKey() bool
	GetPoolTierMemberships() *avl.Tree
	SetPoolTierMemberships(memberships *avl.Tree) error

	// PoolTierRatio
	HasPoolTierRatioStoreKey() bool
	GetPoolTierRatio() TierRatio
	SetPoolTierRatio(ratio TierRatio) error

	// PoolTierCounts
	HasPoolTierCountsStoreKey() bool
	GetPoolTierCounts() [AllTierCount]uint64
	SetPoolTierCounts(counts [AllTierCount]uint64) error

	// PoolTierLastRewardCacheTimestamp
	HasPoolTierLastRewardCacheTimestampStoreKey() bool
	GetPoolTierLastRewardCacheTimestamp() int64
	SetPoolTierLastRewardCacheTimestamp(timestamp int64) error

	// PoolTierLastRewardCacheHeight
	HasPoolTierLastRewardCacheHeightStoreKey() bool
	GetPoolTierLastRewardCacheHeight() int64
	SetPoolTierLastRewardCacheHeight(height int64) error

	// PoolTierCurrentEmission
	HasPoolTierCurrentEmissionStoreKey() bool
	GetPoolTierCurrentEmission() int64
	SetPoolTierCurrentEmission(emission int64) error

	// PoolTierGetEmission
	HasPoolTierGetEmissionStoreKey() bool
	GetPoolTierGetEmission() func() int64
	SetPoolTierGetEmission(fn func() int64) error

	// PoolTierGetHalvingBlocksInRange
	HasPoolTierGetHalvingBlocksInRangeStoreKey() bool
	GetPoolTierGetHalvingBlocksInRange() func(start, end int64) ([]int64, []int64)
	SetPoolTierGetHalvingBlocksInRange(fn func(start, end int64) ([]int64, []int64)) error

	HasWarmupTemplateStoreKey() bool
	GetWarmupTemplate() []Warmup
	SetWarmupTemplate(warmups []Warmup) error
}
