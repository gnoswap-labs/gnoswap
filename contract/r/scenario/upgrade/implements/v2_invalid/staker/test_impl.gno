// Simplified test implementation for staker contract upgrade testing
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"
	staker "gno.land/r/gnoswap/staker"
	v1 "gno.land/r/gnoswap/staker/v1"
)

func NewV2InvalidStaker(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) staker.IStaker {
	instance := v1.NewStakerV1(store, poolAccessor, emissionAccessor, nftAccessor)

	return &TestStaker{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	staker.RegisterInitializer(cross, func(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) staker.IStaker {
		return NewV2InvalidStaker(store, poolAccessor, emissionAccessor, nftAccessor)
	})
}

// TestStaker is a minimal test implementation that delegates to v1 only when method is activated
type TestStaker struct {
	instance      staker.IStaker
	activeMethods map[string]bool
}

func (t *TestStaker) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestStaker) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IStakerManager interface
func (t *TestStaker) StakeToken(positionId uint64, referrer string) string {
	if !t.isActive("StakeToken") {
		panic("test implementation: StakeToken not supported")
	}
	return t.instance.StakeToken(positionId, referrer)
}

func (t *TestStaker) UnStakeToken(positionId uint64, unwrapResult bool) string {
	if !t.isActive("UnStakeToken") {
		panic("test implementation: UnStakeToken not supported")
	}
	return t.instance.UnStakeToken(positionId, unwrapResult)
}

func (t *TestStaker) MintAndStake(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, referrer string) (uint64, string, string, string, string) {
	if !t.isActive("MintAndStake") {
		panic("test implementation: MintAndStake not supported")
	}
	return t.instance.MintAndStake(token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, referrer)
}

func (t *TestStaker) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	if !t.isActive("CollectReward") {
		panic("test implementation: CollectReward not supported")
	}
	return t.instance.CollectReward(positionId, unwrapResult)
}

func (t *TestStaker) SetPoolTier(poolPath string, tier uint64) {
	if !t.isActive("SetPoolTier") {
		panic("test implementation: SetPoolTier not supported")
	}
	t.instance.SetPoolTier(poolPath, tier)
}

func (t *TestStaker) ChangePoolTier(poolPath string, tier uint64) {
	if !t.isActive("ChangePoolTier") {
		panic("test implementation: ChangePoolTier not supported")
	}
	t.instance.ChangePoolTier(poolPath, tier)
}

func (t *TestStaker) RemovePoolTier(poolPath string) {
	if !t.isActive("RemovePoolTier") {
		panic("test implementation: RemovePoolTier not supported")
	}
	t.instance.RemovePoolTier(poolPath)
}

func (t *TestStaker) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	if !t.isActive("CreateExternalIncentive") {
		panic("test implementation: CreateExternalIncentive not supported")
	}
	t.instance.CreateExternalIncentive(targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp)
}

func (t *TestStaker) EndExternalIncentive(targetPoolPath, incentiveId string) {
	if !t.isActive("EndExternalIncentive") {
		panic("test implementation: EndExternalIncentive not supported")
	}
	t.instance.EndExternalIncentive(targetPoolPath, incentiveId)
}

func (t *TestStaker) AddToken(tokenPath string) {
	if !t.isActive("AddToken") {
		panic("test implementation: AddToken not supported")
	}
	t.instance.AddToken(tokenPath)
}

func (t *TestStaker) RemoveToken(tokenPath string) {
	if !t.isActive("RemoveToken") {
		panic("test implementation: RemoveToken not supported")
	}
	t.instance.RemoveToken(tokenPath)
}

func (t *TestStaker) SetWarmUp(pct, timeDuration int64) {
	if !t.isActive("SetWarmUp") {
		panic("test implementation: SetWarmUp not supported")
	}
	t.instance.SetWarmUp(pct, timeDuration)
}

func (t *TestStaker) SetDepositGnsAmount(amount int64) {
	if !t.isActive("SetDepositGnsAmount") {
		panic("test implementation: SetDepositGnsAmount not supported")
	}
	t.instance.SetDepositGnsAmount(amount)
}

func (t *TestStaker) SetMinimumRewardAmount(amount int64) {
	if !t.isActive("SetMinimumRewardAmount") {
		panic("test implementation: SetMinimumRewardAmount not supported")
	}
	t.instance.SetMinimumRewardAmount(amount)
}

func (t *TestStaker) SetTokenMinimumRewardAmount(paramsStr string) {
	if !t.isActive("SetTokenMinimumRewardAmount") {
		panic("test implementation: SetTokenMinimumRewardAmount not supported")
	}
	t.instance.SetTokenMinimumRewardAmount(paramsStr)
}

func (t *TestStaker) SetUnStakingFee(fee int64) {
	if !t.isActive("SetUnStakingFee") {
		panic("test implementation: SetUnStakingFee not supported")
	}
	t.instance.SetUnStakingFee(fee)
}

// IStakerGetter interface
func (t *TestStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	if !t.isActive("GetCreatedHeightOfIncentive") {
		panic("test implementation: GetCreatedHeightOfIncentive not supported")
	}
	return t.instance.GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

func (t *TestStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	if !t.isActive("GetDepositExternalRewardLastCollectTimestamp") {
		panic("test implementation: GetDepositExternalRewardLastCollectTimestamp not supported")
	}
	return t.instance.GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

func (t *TestStaker) GetDepositGnsAmount() int64 {
	if !t.isActive("GetDepositGnsAmount") {
		panic("test implementation: GetDepositGnsAmount not supported")
	}
	return t.instance.GetDepositGnsAmount()
}

func (t *TestStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	if !t.isActive("GetDepositInternalRewardLastCollectTimestamp") {
		panic("test implementation: GetDepositInternalRewardLastCollectTimestamp not supported")
	}
	return t.instance.GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

func (t *TestStaker) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	if !t.isActive("GetDepositLiquidity") {
		panic("test implementation: GetDepositLiquidity not supported")
	}
	return t.instance.GetDepositLiquidity(lpTokenId)
}

func (t *TestStaker) GetDepositLiquidityAsString(lpTokenId uint64) string {
	if !t.isActive("GetDepositLiquidityAsString") {
		panic("test implementation: GetDepositLiquidityAsString not supported")
	}
	return t.instance.GetDepositLiquidityAsString(lpTokenId)
}

func (t *TestStaker) GetDepositOwner(lpTokenId uint64) address {
	if !t.isActive("GetDepositOwner") {
		panic("test implementation: GetDepositOwner not supported")
	}
	return t.instance.GetDepositOwner(lpTokenId)
}

func (t *TestStaker) GetDepositStakeTime(lpTokenId uint64) int64 {
	if !t.isActive("GetDepositStakeTime") {
		panic("test implementation: GetDepositStakeTime not supported")
	}
	return t.instance.GetDepositStakeTime(lpTokenId)
}

func (t *TestStaker) GetDepositTargetPoolPath(lpTokenId uint64) string {
	if !t.isActive("GetDepositTargetPoolPath") {
		panic("test implementation: GetDepositTargetPoolPath not supported")
	}
	return t.instance.GetDepositTargetPoolPath(lpTokenId)
}

func (t *TestStaker) GetDepositTickLower(lpTokenId uint64) int32 {
	if !t.isActive("GetDepositTickLower") {
		panic("test implementation: GetDepositTickLower not supported")
	}
	return t.instance.GetDepositTickLower(lpTokenId)
}

func (t *TestStaker) GetDepositTickUpper(lpTokenId uint64) int32 {
	if !t.isActive("GetDepositTickUpper") {
		panic("test implementation: GetDepositTickUpper not supported")
	}
	return t.instance.GetDepositTickUpper(lpTokenId)
}

func (t *TestStaker) GetDepositWarmUp(lpTokenId uint64) []staker.Warmup {
	if !t.isActive("GetDepositWarmUp") {
		panic("test implementation: GetDepositWarmUp not supported")
	}
	return t.instance.GetDepositWarmUp(lpTokenId)
}

func (t *TestStaker) GetExternalIncentiveByPoolPath(poolPath string) []staker.ExternalIncentive {
	if !t.isActive("GetExternalIncentiveByPoolPath") {
		panic("test implementation: GetExternalIncentiveByPoolPath not supported")
	}
	return t.instance.GetExternalIncentiveByPoolPath(poolPath)
}

func (t *TestStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	if !t.isActive("GetIncentiveEndTimestamp") {
		panic("test implementation: GetIncentiveEndTimestamp not supported")
	}
	return t.instance.GetIncentiveEndTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRefundee(poolPath string, incentiveId string) address {
	if !t.isActive("GetIncentiveRefundee") {
		panic("test implementation: GetIncentiveRefundee not supported")
	}
	return t.instance.GetIncentiveRefundee(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	if !t.isActive("GetIncentiveRewardAmount") {
		panic("test implementation: GetIncentiveRewardAmount not supported")
	}
	return t.instance.GetIncentiveRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	if !t.isActive("GetIncentiveRewardAmountAsString") {
		panic("test implementation: GetIncentiveRewardAmountAsString not supported")
	}
	return t.instance.GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	if !t.isActive("GetIncentiveRewardPerSecond") {
		panic("test implementation: GetIncentiveRewardPerSecond not supported")
	}
	return t.instance.GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	if !t.isActive("GetIncentiveRewardToken") {
		panic("test implementation: GetIncentiveRewardToken not supported")
	}
	return t.instance.GetIncentiveRewardToken(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	if !t.isActive("GetIncentiveStartTimestamp") {
		panic("test implementation: GetIncentiveStartTimestamp not supported")
	}
	return t.instance.GetIncentiveStartTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetMinimumRewardAmount() int64 {
	if !t.isActive("GetMinimumRewardAmount") {
		panic("test implementation: GetMinimumRewardAmount not supported")
	}
	return t.instance.GetMinimumRewardAmount()
}

func (t *TestStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	if !t.isActive("GetMinimumRewardAmountForToken") {
		panic("test implementation: GetMinimumRewardAmountForToken not supported")
	}
	return t.instance.GetMinimumRewardAmountForToken(tokenPath)
}

func (t *TestStaker) GetPoolIncentiveIdList(poolPath string) []string {
	if !t.isActive("GetPoolIncentiveIdList") {
		panic("test implementation: GetPoolIncentiveIdList not supported")
	}
	return t.instance.GetPoolIncentiveIdList(poolPath)
}

func (t *TestStaker) GetPoolReward(tier uint64) int64 {
	if !t.isActive("GetPoolReward") {
		panic("test implementation: GetPoolReward not supported")
	}
	return t.instance.GetPoolReward(tier)
}

func (t *TestStaker) GetPoolTier(poolPath string) uint64 {
	if !t.isActive("GetPoolTier") {
		panic("test implementation: GetPoolTier not supported")
	}
	return t.instance.GetPoolTier(poolPath)
}

func (t *TestStaker) GetPoolTierCount(tier uint64) uint64 {
	if !t.isActive("GetPoolTierCount") {
		panic("test implementation: GetPoolTierCount not supported")
	}
	return t.instance.GetPoolTierCount(tier)
}

func (t *TestStaker) GetPoolTierRatio(poolPath string) uint64 {
	if !t.isActive("GetPoolTierRatio") {
		panic("test implementation: GetPoolTierRatio not supported")
	}
	return t.instance.GetPoolTierRatio(poolPath)
}

func (t *TestStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	if !t.isActive("GetSpecificTokenMinimumRewardAmount") {
		panic("test implementation: GetSpecificTokenMinimumRewardAmount not supported")
	}
	return t.instance.GetSpecificTokenMinimumRewardAmount(tokenPath)
}

func (t *TestStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	if !t.isActive("GetTargetPoolPathByIncentiveId") {
		panic("test implementation: GetTargetPoolPathByIncentiveId not supported")
	}
	return t.instance.GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

func (t *TestStaker) GetUnstakingFee() int64 {
	if !t.isActive("GetUnstakingFee") {
		panic("test implementation: GetUnstakingFee not supported")
	}
	return t.instance.GetUnstakingFee()
}

func (t *TestStaker) IsStaked(positionId uint64) bool {
	if !t.isActive("IsStaked") {
		panic("test implementation: IsStaked not supported")
	}
	return t.instance.IsStaked(positionId)
}

// IStakerApi interface
func (t *TestStaker) ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	if !t.isActive("ApiGetExternalIncentiveById") {
		panic("test implementation: ApiGetExternalIncentiveById not supported")
	}
	return t.instance.ApiGetExternalIncentiveById(poolPath, incentiveId)
}

func (t *TestStaker) ApiGetExternalIncentives() string {
	if !t.isActive("ApiGetExternalIncentives") {
		panic("test implementation: ApiGetExternalIncentives not supported")
	}
	return t.instance.ApiGetExternalIncentives()
}

func (t *TestStaker) ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	if !t.isActive("ApiGetExternalIncentivesByPoolPath") {
		panic("test implementation: ApiGetExternalIncentivesByPoolPath not supported")
	}
	return t.instance.ApiGetExternalIncentivesByPoolPath(targetPoolPath)
}

func (t *TestStaker) ApiGetInternalIncentives() string {
	if !t.isActive("ApiGetInternalIncentives") {
		panic("test implementation: ApiGetInternalIncentives not supported")
	}
	return t.instance.ApiGetInternalIncentives()
}

func (t *TestStaker) ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	if !t.isActive("ApiGetInternalIncentivesByPoolPath") {
		panic("test implementation: ApiGetInternalIncentivesByPoolPath not supported")
	}
	return t.instance.ApiGetInternalIncentivesByPoolPath(targetPoolPath)
}

func (t *TestStaker) ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	if !t.isActive("ApiGetInternalIncentivesByTiers") {
		panic("test implementation: ApiGetInternalIncentivesByTiers not supported")
	}
	return t.instance.ApiGetInternalIncentivesByTiers(targetTier)
}

func (t *TestStaker) ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	if !t.isActive("ApiGetRewardsByLpTokenId") {
		panic("test implementation: ApiGetRewardsByLpTokenId not supported")
	}
	return t.instance.ApiGetRewardsByLpTokenId(targetLpTokenId)
}

func (t *TestStaker) ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	if !t.isActive("ApiGetRewardTokensByPoolPath") {
		panic("test implementation: ApiGetRewardTokensByPoolPath not supported")
	}
	return t.instance.ApiGetRewardTokensByPoolPath(targetPoolPath)
}

func (t *TestStaker) ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	if !t.isActive("ApiGetStakesByLpTokenId") {
		panic("test implementation: ApiGetStakesByLpTokenId not supported")
	}
	return t.instance.ApiGetStakesByLpTokenId(targetLpTokenId)
}
