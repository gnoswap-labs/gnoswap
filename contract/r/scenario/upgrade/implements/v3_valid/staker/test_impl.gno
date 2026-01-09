// Simplified test implementation for staker contract upgrade testing
package v3_valid

import (
	u256 "gno.land/p/gnoswap/uint256"
	staker "gno.land/r/gnoswap/staker"
	v1 "gno.land/r/gnoswap/staker/v1"
)

func NewV3ValidStaker(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) staker.IStaker {
	return &TestStaker{
		instance: v1.NewStakerV1(store, poolAccessor, emissionAccessor, nftAccessor),
	}
}

func init() {
	staker.RegisterInitializer(cross, func(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) staker.IStaker {
		return NewV3ValidStaker(store, poolAccessor, emissionAccessor, nftAccessor)
	})
}

// TestStaker is a minimal test implementation that panics on all methods
type TestStaker struct {
	instance staker.IStaker
}

// IStakerManager interface
func (t *TestStaker) StakeToken(positionId uint64, referrer string) string {
	return t.instance.StakeToken(positionId, referrer)
}

func (t *TestStaker) UnStakeToken(positionId uint64, unwrapResult bool) string {
	return t.instance.UnStakeToken(positionId, unwrapResult)
}

func (t *TestStaker) MintAndStake(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, referrer string) (uint64, string, string, string, string) {
	return t.instance.MintAndStake(token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, referrer)
}

func (t *TestStaker) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	return t.instance.CollectReward(positionId, unwrapResult)
}

func (t *TestStaker) SetPoolTier(poolPath string, tier uint64) {
	t.instance.SetPoolTier(poolPath, tier)
}

func (t *TestStaker) ChangePoolTier(poolPath string, tier uint64) {
	t.instance.ChangePoolTier(poolPath, tier)
}

func (t *TestStaker) RemovePoolTier(poolPath string) {
	t.instance.RemovePoolTier(poolPath)
}

func (t *TestStaker) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	t.instance.CreateExternalIncentive(targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp)
}

func (t *TestStaker) EndExternalIncentive(targetPoolPath, incentiveId string) {
	t.instance.EndExternalIncentive(targetPoolPath, incentiveId)
}

func (t *TestStaker) AddToken(tokenPath string) {
	t.instance.AddToken(tokenPath)
}

func (t *TestStaker) RemoveToken(tokenPath string) {
	t.instance.RemoveToken(tokenPath)
}

func (t *TestStaker) SetWarmUp(pct, timeDuration int64) {
	t.instance.SetWarmUp(pct, timeDuration)
}

func (t *TestStaker) SetDepositGnsAmount(amount int64) {
	t.instance.SetDepositGnsAmount(amount)
}

func (t *TestStaker) SetMinimumRewardAmount(amount int64) {
	t.instance.SetMinimumRewardAmount(amount)
}

func (t *TestStaker) SetTokenMinimumRewardAmount(paramsStr string) {
	t.instance.SetTokenMinimumRewardAmount(paramsStr)
}

func (t *TestStaker) SetUnStakingFee(fee int64) {
	t.instance.SetUnStakingFee(fee)
}

// IStakerGetter interface
func (t *TestStaker) GetPool(poolPath string) *staker.Pool {
	return t.instance.GetPool(poolPath)
}

func (t *TestStaker) GetIncentive(poolPath string, incentiveId string) *staker.ExternalIncentive {
	return t.instance.GetIncentive(poolPath, incentiveId)
}

func (t *TestStaker) GetDeposit(lpTokenId uint64) *staker.Deposit {
	return t.instance.GetDeposit(lpTokenId)
}

func (t *TestStaker) CollectableEmissionReward(positionId uint64) int64 {
	return t.instance.CollectableEmissionReward(positionId)
}

func (t *TestStaker) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64 {
	return t.instance.CollectableExternalIncentiveReward(positionId, incentiveId)
}

func (t *TestStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return t.instance.GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	return t.instance.GetIncentiveRefunded(poolPath, incentiveId)
}

func (t *TestStaker) IsIncentiveActive(poolPath string, incentiveId string) bool {
	return t.instance.IsIncentiveActive(poolPath, incentiveId)
}

func (t *TestStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return t.instance.GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

func (t *TestStaker) GetDepositGnsAmount() int64 {
	return t.instance.GetDepositGnsAmount()
}

func (t *TestStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return t.instance.GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

func (t *TestStaker) GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	return t.instance.GetDepositCollectedInternalReward(lpTokenId)
}

func (t *TestStaker) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	return t.instance.GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

func (t *TestStaker) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return t.instance.GetDepositLiquidity(lpTokenId)
}

func (t *TestStaker) GetDepositLiquidityAsString(lpTokenId uint64) string {
	return t.instance.GetDepositLiquidityAsString(lpTokenId)
}

func (t *TestStaker) GetDepositOwner(lpTokenId uint64) address {
	return t.instance.GetDepositOwner(lpTokenId)
}

func (t *TestStaker) GetDepositStakeTime(lpTokenId uint64) int64 {
	return t.instance.GetDepositStakeTime(lpTokenId)
}

func (t *TestStaker) GetDepositTargetPoolPath(lpTokenId uint64) string {
	return t.instance.GetDepositTargetPoolPath(lpTokenId)
}

func (t *TestStaker) GetDepositTickLower(lpTokenId uint64) int32 {
	return t.instance.GetDepositTickLower(lpTokenId)
}

func (t *TestStaker) GetDepositTickUpper(lpTokenId uint64) int32 {
	return t.instance.GetDepositTickUpper(lpTokenId)
}

func (t *TestStaker) GetDepositWarmUp(lpTokenId uint64) []staker.Warmup {
	return t.instance.GetDepositWarmUp(lpTokenId)
}

func (t *TestStaker) GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	return t.instance.GetDepositExternalIncentiveIdList(lpTokenId)
}

func (t *TestStaker) GetExternalIncentiveByPoolPath(poolPath string) []staker.ExternalIncentive {
	return t.instance.GetExternalIncentiveByPoolPath(poolPath)
}

func (t *TestStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveEndTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRefundee(poolPath string, incentiveId string) address {
	return t.instance.GetIncentiveRefundee(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return t.instance.GetIncentiveRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return t.instance.GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveRewardPerSecond(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return t.instance.GetIncentiveRewardToken(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	return t.instance.GetIncentiveStartTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetMinimumRewardAmount() int64 {
	return t.instance.GetMinimumRewardAmount()
}

func (t *TestStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return t.instance.GetMinimumRewardAmountForToken(tokenPath)
}

func (t *TestStaker) GetPoolIncentiveIdList(poolPath string) []string {
	return t.instance.GetPoolIncentiveIdList(poolPath)
}

func (t *TestStaker) GetPoolStakedLiquidity(poolPath string) string {
	return t.instance.GetPoolStakedLiquidity(poolPath)
}

func (t *TestStaker) GetPoolsByTier(tier uint64) []string {
	return t.instance.GetPoolsByTier(tier)
}

func (t *TestStaker) GetPoolReward(tier uint64) int64 {
	return t.instance.GetPoolReward(tier)
}

func (t *TestStaker) GetPoolTier(poolPath string) uint64 {
	return t.instance.GetPoolTier(poolPath)
}

func (t *TestStaker) GetPoolTierCount(tier uint64) uint64 {
	return t.instance.GetPoolTierCount(tier)
}

func (t *TestStaker) GetPoolTierRatio(poolPath string) uint64 {
	return t.instance.GetPoolTierRatio(poolPath)
}

func (t *TestStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return t.instance.GetSpecificTokenMinimumRewardAmount(tokenPath)
}

func (t *TestStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return t.instance.GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

func (t *TestStaker) GetUnstakingFee() int64 {
	return t.instance.GetUnstakingFee()
}

func (t *TestStaker) IsStaked(positionId uint64) bool {
	return t.instance.IsStaked(positionId)
}

func (t *TestStaker) GetTotalEmissionSent() int64 {
	return t.instance.GetTotalEmissionSent()
}

func (t *TestStaker) GetAllowedTokens() []string {
	return t.instance.GetAllowedTokens()
}

func (t *TestStaker) GetWarmupTemplate() []staker.Warmup {
	return t.instance.GetWarmupTemplate()
}

func (t *TestStaker) GetTotalStakedUserCount() uint64 {
	return t.instance.GetTotalStakedUserCount()
}

func (t *TestStaker) GetTotalStakedUserPositionCount(user address) uint64 {
	return t.instance.GetTotalStakedUserPositionCount(user)
}

func (t *TestStaker) GetStakedPositionsByUser(owner address, offset, count int) []uint64 {
	return t.instance.GetStakedPositionsByUser(owner, offset, count)
}
