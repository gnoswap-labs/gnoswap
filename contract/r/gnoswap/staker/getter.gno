package staker

import u256 "gno.land/p/gnoswap/uint256"

// IStakerGetter functions
func GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return getImplementation().GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

func GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return getImplementation().GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

func GetDepositGnsAmount() int64 {
	return getImplementation().GetDepositGnsAmount()
}

func GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

func GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return getImplementation().GetDepositLiquidity(lpTokenId)
}

func GetDepositLiquidityAsString(lpTokenId uint64) string {
	return getImplementation().GetDepositLiquidityAsString(lpTokenId)
}

func GetDepositStakeTime(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTime(lpTokenId)
}

func GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	return getImplementation().GetDepositStakeTimestamp(lpTokenId)
}

func GetDepositTargetPoolPath(lpTokenId uint64) string {
	return getImplementation().GetDepositTargetPoolPath(lpTokenId)
}

func GetDepositTickLower(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickLower(lpTokenId)
}

func GetDepositTickUpper(lpTokenId uint64) int32 {
	return getImplementation().GetDepositTickUpper(lpTokenId)
}

func GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveEndTimestamp(poolPath, incentiveId)
}

func GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return getImplementation().GetIncentiveRewardAmount(poolPath, incentiveId)
}

func GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

func GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

func GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return getImplementation().GetIncentiveRewardToken(poolPath, incentiveId)
}

func GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	return getImplementation().GetIncentiveStartTimestamp(poolPath, incentiveId)
}

func GetMinimumRewardAmount() int64 {
	return getImplementation().GetMinimumRewardAmount()
}

func GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return getImplementation().GetMinimumRewardAmountForToken(tokenPath)
}

func GetPoolIncentiveIdList(poolPath string) []string {
	return getImplementation().GetPoolIncentiveIdList(poolPath)
}

func GetPoolReward(tier uint64) int64 {
	return getImplementation().GetPoolReward(tier)
}

func GetPoolTier(poolPath string) uint64 {
	return getImplementation().GetPoolTier(poolPath)
}

func GetPoolTierCount(tier uint64) uint64 {
	return getImplementation().GetPoolTierCount(tier)
}

func GetPoolTierRatio(poolPath string) uint64 {
	return getImplementation().GetPoolTierRatio(poolPath)
}

func GetPrintExternalInfo() string {
	return getImplementation().GetPrintExternalInfo()
}

func GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return getImplementation().GetSpecificTokenMinimumRewardAmount(tokenPath)
}

func GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return getImplementation().GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

func GetUnstakingFee() int64 {
	return getImplementation().GetUnstakingFee()
}

func IsArchivedExternalIncentive(incentiveId string) bool {
	return getImplementation().IsArchivedExternalIncentive(incentiveId)
}

func IsStaked(positionId uint64) bool {
	return getImplementation().IsStaked(positionId)
}

// IStakerApi functions
func ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	return getImplementation().ApiGetExternalIncentiveById(poolPath, incentiveId)
}

func ApiGetExternalIncentives() string {
	return getImplementation().ApiGetExternalIncentives()
}

func ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetExternalIncentivesByPoolPath(targetPoolPath)
}

func ApiGetInternalIncentives() string {
	return getImplementation().ApiGetInternalIncentives()
}

func ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetInternalIncentivesByPoolPath(targetPoolPath)
}

func ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	return getImplementation().ApiGetInternalIncentivesByTiers(targetTier)
}

func ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	return getImplementation().ApiGetRewardsByLpTokenId(targetLpTokenId)
}

func ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	return getImplementation().ApiGetRewardTokensByPoolPath(targetPoolPath)
}

func ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	return getImplementation().ApiGetStakesByLpTokenId(targetLpTokenId)
}
