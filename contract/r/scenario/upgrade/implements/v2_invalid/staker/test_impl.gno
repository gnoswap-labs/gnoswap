// Simplified test implementation for staker contract upgrade testing
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/staker"
)

func init() {
	staker.RegisterInitializer(cross, func(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor) staker.IStaker {
		return &TestStaker{}
	})
}

// TestStaker is a minimal test implementation that panics on all methods
type TestStaker struct{}

// IStakerManager interface
func (t *TestStaker) StakeToken(positionId uint64, referrer string) string {
	panic("test implementation: StakeToken not supported")
}

func (t *TestStaker) UnStakeToken(positionId uint64, unwrapResult bool) string {
	panic("test implementation: UnStakeToken not supported")
}

func (t *TestStaker) MintAndStake(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, referrer string) (uint64, string, string, string, string) {
	panic("test implementation: MintAndStake not supported")
}

func (t *TestStaker) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	panic("test implementation: CollectReward not supported")
}

func (t *TestStaker) SetPoolTier(poolPath string, tier uint64) {
	panic("test implementation: SetPoolTier not supported")
}

func (t *TestStaker) ChangePoolTier(poolPath string, tier uint64) {
	panic("test implementation: ChangePoolTier not supported")
}

func (t *TestStaker) RemovePoolTier(poolPath string) {
	panic("test implementation: RemovePoolTier not supported")
}

func (t *TestStaker) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	panic("test implementation: CreateExternalIncentive not supported")
}

func (t *TestStaker) EndExternalIncentive(targetPoolPath, incentiveId string) {
	panic("test implementation: EndExternalIncentive not supported")
}

func (t *TestStaker) AddToken(tokenPath string) {
	panic("test implementation: AddToken not supported")
}

func (t *TestStaker) RemoveToken(tokenPath string) {
	panic("test implementation: RemoveToken not supported")
}

func (t *TestStaker) SetWarmUp(pct, timeDuration int64) {
	panic("test implementation: SetWarmUp not supported")
}

func (t *TestStaker) SetDepositGnsAmount(amount int64) {
	panic("test implementation: SetDepositGnsAmount not supported")
}

func (t *TestStaker) SetMinimumRewardAmount(amount int64) {
	panic("test implementation: SetMinimumRewardAmount not supported")
}

func (t *TestStaker) SetTokenMinimumRewardAmount(paramsStr string) {
	panic("test implementation: SetTokenMinimumRewardAmount not supported")
}

func (t *TestStaker) SetUnStakingFee(fee int64) {
	panic("test implementation: SetUnStakingFee not supported")
}

// IStakerGetter interface
func (t *TestStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	panic("test implementation: GetCreatedHeightOfIncentive not supported")
}

func (t *TestStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	panic("test implementation: GetDepositExternalRewardLastCollectTimestamp not supported")
}

func (t *TestStaker) GetDepositGnsAmount() int64 {
	panic("test implementation: GetDepositGnsAmount not supported")
}

func (t *TestStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	panic("test implementation: GetDepositInternalRewardLastCollectTimestamp not supported")
}

func (t *TestStaker) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	panic("test implementation: GetDepositLiquidity not supported")
}

func (t *TestStaker) GetDepositLiquidityAsString(lpTokenId uint64) string {
	panic("test implementation: GetDepositLiquidityAsString not supported")
}

func (t *TestStaker) GetDepositStakeTime(lpTokenId uint64) int64 {
	panic("test implementation: GetDepositStakeTime not supported")
}

func (t *TestStaker) GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	panic("test implementation: GetDepositStakeTimestamp not supported")
}

func (t *TestStaker) GetDepositTargetPoolPath(lpTokenId uint64) string {
	panic("test implementation: GetDepositTargetPoolPath not supported")
}

func (t *TestStaker) GetDepositTickLower(lpTokenId uint64) int32 {
	panic("test implementation: GetDepositTickLower not supported")
}

func (t *TestStaker) GetDepositTickUpper(lpTokenId uint64) int32 {
	panic("test implementation: GetDepositTickUpper not supported")
}

func (t *TestStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	panic("test implementation: GetIncentiveEndTimestamp not supported")
}

func (t *TestStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	panic("test implementation: GetIncentiveRewardAmount not supported")
}

func (t *TestStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	panic("test implementation: GetIncentiveRewardAmountAsString not supported")
}

func (t *TestStaker) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	panic("test implementation: GetIncentiveRewardPerSecond not supported")
}

func (t *TestStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	panic("test implementation: GetIncentiveRewardToken not supported")
}

func (t *TestStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	panic("test implementation: GetIncentiveStartTimestamp not supported")
}

func (t *TestStaker) GetMinimumRewardAmount() int64 {
	panic("test implementation: GetMinimumRewardAmount not supported")
}

func (t *TestStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	panic("test implementation: GetMinimumRewardAmountForToken not supported")
}

func (t *TestStaker) GetPoolIncentiveIdList(poolPath string) []string {
	panic("test implementation: GetPoolIncentiveIdList not supported")
}

func (t *TestStaker) GetPoolReward(tier uint64) int64 {
	panic("test implementation: GetPoolReward not supported")
}

func (t *TestStaker) GetPoolTier(poolPath string) uint64 {
	panic("test implementation: GetPoolTier not supported")
}

func (t *TestStaker) GetPoolTierCount(tier uint64) uint64 {
	panic("test implementation: GetPoolTierCount not supported")
}

func (t *TestStaker) GetPoolTierRatio(poolPath string) uint64 {
	panic("test implementation: GetPoolTierRatio not supported")
}

func (t *TestStaker) GetPrintExternalInfo() string {
	panic("test implementation: GetPrintExternalInfo not supported")
}

func (t *TestStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	panic("test implementation: GetSpecificTokenMinimumRewardAmount not supported")
}

func (t *TestStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	panic("test implementation: GetTargetPoolPathByIncentiveId not supported")
}

func (t *TestStaker) GetUnstakingFee() int64 {
	panic("test implementation: GetUnstakingFee not supported")
}

func (t *TestStaker) IsArchivedExternalIncentive(incentiveId string) bool {
	panic("test implementation: IsArchivedExternalIncentive not supported")
}

func (t *TestStaker) IsStaked(positionId uint64) bool {
	panic("test implementation: IsStaked not supported")
}

// IStakerApi interface
func (t *TestStaker) ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	panic("test implementation: ApiGetExternalIncentiveById not supported")
}

func (t *TestStaker) ApiGetExternalIncentives() string {
	panic("test implementation: ApiGetExternalIncentives not supported")
}

func (t *TestStaker) ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	panic("test implementation: ApiGetExternalIncentivesByPoolPath not supported")
}

func (t *TestStaker) ApiGetInternalIncentives() string {
	panic("test implementation: ApiGetInternalIncentives not supported")
}

func (t *TestStaker) ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	panic("test implementation: ApiGetInternalIncentivesByPoolPath not supported")
}

func (t *TestStaker) ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	panic("test implementation: ApiGetInternalIncentivesByTiers not supported")
}

func (t *TestStaker) ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	panic("test implementation: ApiGetRewardsByLpTokenId not supported")
}

func (t *TestStaker) ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	panic("test implementation: ApiGetRewardTokensByPoolPath not supported")
}

func (t *TestStaker) ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	panic("test implementation: ApiGetStakesByLpTokenId not supported")
}
