package staker

type IStakerApi interface {
	ApiGetRewardTokensByPoolPath(targetPoolPath string) string
	ApiGetExternalIncentives() string
	ApiGetExternalIncentiveById(poolPath, incentiveId string) string
	ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string
	ApiGetInternalIncentives() string
	ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string
	ApiGetInternalIncentivesByTiers(targetTier uint64) string
}

type IStakerGetter interface {
	GetPoolIncentiveIdList(poolPath string) []string
	GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64
	GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64
	GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string
	GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64
	GetIncentiveRewardToken(poolPath string, incentiveId string) string
	GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint
	GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string
	GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64
	GetIncentiveRefundee(poolPath string, incentiveId string) address
	GetDepositOwner(lpTokenId uint64) address
	GetDepositStakeTimestamp(lpTokenId uint64) int64
	GetDepositStakeTime(lpTokenId uint64) int64
	GetDepositTargetPoolPath(lpTokenId uint64) string
	GetDepositTickLower(lpTokenId uint64) int32
	GetDepositTickUpper(lpTokenId uint64) int32
	GetDepositLiquidity(lpTokenId uint64) *u256.Uint
	GetDepositLiquidityAsString(lpTokenId uint64) string
	GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64
	GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64
	GetDepositWarmUp(lpTokenId uint64) []Warmup
	GetPoolTier(poolPath string) uint64
	GetPoolTierRatio(poolPath string) uint64
	GetPoolTierCount(tier uint64) uint64
	GetPoolReward(tier uint64) int64
	GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive

	/* protocol_fee_unstaking.gno */
	GetUnstakingFee() int64
}

type IStaker interface {
	/* manage_pool_tier_and_warmup.gno */
	SetPoolTier(poolPath string, tier uint64)
	ChangePoolTier(poolPath string, tier uint64)
	RemovePoolTier(poolPath string)
	SetWarmUp(pct, timeDuration int64)

	/* mint_stake.gno */
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

	/* protocol_fee_unstaking.gno */
	SetUnStakingFee(fee int64)

	/* staler.gno */
	StakeToken(positionId uint64, referrer string) string
	CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64)
	UnStakeToken(positionId uint64, unwrapResult bool) string
}