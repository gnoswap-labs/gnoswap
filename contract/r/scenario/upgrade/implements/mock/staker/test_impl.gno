// Simplified test implementation for staker contract upgrade testing
package mock

import (
	u256 "gno.land/p/gnoswap/uint256"
	staker "gno.land/r/gnoswap/staker"
	v1 "gno.land/r/gnoswap/staker/v1"
)

func NewMockStaker(store staker.IStakerStore, poolAccessor staker.PoolAccessor, emissionAccessor staker.EmissionAccessor, nftAccessor staker.NFTAccessor) *TestStaker {
	instance := v1.NewStakerV1(store, poolAccessor, emissionAccessor, nftAccessor)

	return &TestStaker{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
	}
}

// TestStaker is a minimal test implementation that panics on all methods
type TestStaker struct {
	instance staker.IStaker
	mockFns  map[string]func(args ...any) any
}

func (t *TestStaker) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestStaker) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IStakerManager interface
func (t *TestStaker) StakeToken(positionId uint64, referrer string) string {
	return t.ExecuteFn(
		"StakeToken",
		func(args ...any) any { return t.instance.StakeToken(args[0].(uint64), args[1].(string)) },
		positionId, referrer,
	).(string)
}

func (t *TestStaker) UnStakeToken(positionId uint64, unwrapResult bool) string {
	return t.ExecuteFn(
		"UnStakeToken",
		func(args ...any) any { return t.instance.UnStakeToken(args[0].(uint64), args[1].(bool)) },
		positionId, unwrapResult,
	).(string)
}

func (t *TestStaker) MintAndStake(token0 string, token1 string, fee uint32, tickLower int32, tickUpper int32, amount0Desired string, amount1Desired string, amount0Min string, amount1Min string, deadline int64, referrer string) (uint64, string, string, string, string) {
	result := t.ExecuteFn(
		"MintAndStake",
		func(args ...any) any {
			r1, r2, r3, r4, r5 := t.instance.MintAndStake(args[0].(string), args[1].(string), args[2].(uint32), args[3].(int32), args[4].(int32), args[5].(string), args[6].(string), args[7].(string), args[8].(string), args[9].(int64), args[10].(string))
			return []any{r1, r2, r3, r4, r5}
		},
		token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, referrer,
	).([]any)
	return result[0].(uint64), result[1].(string), result[2].(string), result[3].(string), result[4].(string)
}

func (t *TestStaker) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	result := t.ExecuteFn(
		"CollectReward",
		func(args ...any) any {
			r1, r2, r3, r4 := t.instance.CollectReward(args[0].(uint64), args[1].(bool))
			return []any{r1, r2, r3, r4}
		},
		positionId, unwrapResult,
	).([]any)
	return result[0].(string), result[1].(string), result[2].(map[string]int64), result[3].(map[string]int64)
}

func (t *TestStaker) SetPoolTier(poolPath string, tier uint64) {
	t.ExecuteFn(
		"SetPoolTier",
		func(args ...any) any { t.instance.SetPoolTier(args[0].(string), args[1].(uint64)); return nil },
		poolPath, tier,
	)
}

func (t *TestStaker) ChangePoolTier(poolPath string, tier uint64) {
	t.ExecuteFn(
		"ChangePoolTier",
		func(args ...any) any { t.instance.ChangePoolTier(args[0].(string), args[1].(uint64)); return nil },
		poolPath, tier,
	)
}

func (t *TestStaker) RemovePoolTier(poolPath string) {
	t.ExecuteFn(
		"RemovePoolTier",
		func(args ...any) any { t.instance.RemovePoolTier(args[0].(string)); return nil },
		poolPath,
	)
}

func (t *TestStaker) CreateExternalIncentive(targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	t.ExecuteFn(
		"CreateExternalIncentive",
		func(args ...any) any {
			t.instance.CreateExternalIncentive(args[0].(string), args[1].(string), args[2].(int64), args[3].(int64), args[4].(int64))
			return nil
		},
		targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp,
	)
}

func (t *TestStaker) EndExternalIncentive(targetPoolPath, incentiveId string) {
	t.ExecuteFn(
		"EndExternalIncentive",
		func(args ...any) any { t.instance.EndExternalIncentive(args[0].(string), args[1].(string)); return nil },
		targetPoolPath, incentiveId,
	)
}

func (t *TestStaker) AddToken(tokenPath string) {
	t.ExecuteFn(
		"AddToken",
		func(args ...any) any { t.instance.AddToken(args[0].(string)); return nil },
		tokenPath,
	)
}

func (t *TestStaker) RemoveToken(tokenPath string) {
	t.ExecuteFn(
		"RemoveToken",
		func(args ...any) any { t.instance.RemoveToken(args[0].(string)); return nil },
		tokenPath,
	)
}

func (t *TestStaker) SetWarmUp(pct, timeDuration int64) {
	t.ExecuteFn(
		"SetWarmUp",
		func(args ...any) any { t.instance.SetWarmUp(args[0].(int64), args[1].(int64)); return nil },
		pct, timeDuration,
	)
}

func (t *TestStaker) SetDepositGnsAmount(amount int64) {
	t.ExecuteFn(
		"SetDepositGnsAmount",
		func(args ...any) any { t.instance.SetDepositGnsAmount(args[0].(int64)); return nil },
		amount,
	)
}

func (t *TestStaker) SetMinimumRewardAmount(amount int64) {
	t.ExecuteFn(
		"SetMinimumRewardAmount",
		func(args ...any) any { t.instance.SetMinimumRewardAmount(args[0].(int64)); return nil },
		amount,
	)
}

func (t *TestStaker) SetTokenMinimumRewardAmount(paramsStr string) {
	t.ExecuteFn(
		"SetTokenMinimumRewardAmount",
		func(args ...any) any { t.instance.SetTokenMinimumRewardAmount(args[0].(string)); return nil },
		paramsStr,
	)
}

func (t *TestStaker) SetUnStakingFee(fee int64) {
	t.ExecuteFn(
		"SetUnStakingFee",
		func(args ...any) any { t.instance.SetUnStakingFee(args[0].(int64)); return nil },
		fee,
	)
}

// IStakerGetter interface
func (t *TestStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	return t.ExecuteFn(
		"GetCreatedHeightOfIncentive",
		func(args ...any) any {
			return t.instance.GetCreatedHeightOfIncentive(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(int64)
}

func (t *TestStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	return t.ExecuteFn(
		"GetDepositExternalRewardLastCollectTimestamp",
		func(args ...any) any {
			return t.instance.GetDepositExternalRewardLastCollectTimestamp(args[0].(uint64), args[1].(string))
		},
		lpTokenId, incentiveId,
	).(int64)
}

func (t *TestStaker) GetDepositGnsAmount() int64 {
	return t.ExecuteFn(
		"GetDepositGnsAmount",
		func(args ...any) any { return t.instance.GetDepositGnsAmount() },
	).(int64)
}

func (t *TestStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	return t.ExecuteFn(
		"GetDepositInternalRewardLastCollectTimestamp",
		func(args ...any) any {
			return t.instance.GetDepositInternalRewardLastCollectTimestamp(args[0].(uint64))
		},
		lpTokenId,
	).(int64)
}

func (t *TestStaker) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	return t.ExecuteFn(
		"GetDepositLiquidity",
		func(args ...any) any { return t.instance.GetDepositLiquidity(args[0].(uint64)) },
		lpTokenId,
	).(*u256.Uint)
}

func (t *TestStaker) GetDepositLiquidityAsString(lpTokenId uint64) string {
	return t.ExecuteFn(
		"GetDepositLiquidityAsString",
		func(args ...any) any { return t.instance.GetDepositLiquidityAsString(args[0].(uint64)) },
		lpTokenId,
	).(string)
}

func (t *TestStaker) GetDepositStakeTime(lpTokenId uint64) int64 {
	return t.ExecuteFn(
		"GetDepositStakeTime",
		func(args ...any) any { return t.instance.GetDepositStakeTime(args[0].(uint64)) },
		lpTokenId,
	).(int64)
}

func (t *TestStaker) GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	return t.ExecuteFn(
		"GetDepositStakeTimestamp",
		func(args ...any) any { return t.instance.GetDepositStakeTimestamp(args[0].(uint64)) },
		lpTokenId,
	).(int64)
}

func (t *TestStaker) GetDepositTargetPoolPath(lpTokenId uint64) string {
	return t.ExecuteFn(
		"GetDepositTargetPoolPath",
		func(args ...any) any { return t.instance.GetDepositTargetPoolPath(args[0].(uint64)) },
		lpTokenId,
	).(string)
}

func (t *TestStaker) GetDepositTickLower(lpTokenId uint64) int32 {
	return t.ExecuteFn(
		"GetDepositTickLower",
		func(args ...any) any { return t.instance.GetDepositTickLower(args[0].(uint64)) },
		lpTokenId,
	).(int32)
}

func (t *TestStaker) GetDepositTickUpper(lpTokenId uint64) int32 {
	return t.ExecuteFn(
		"GetDepositTickUpper",
		func(args ...any) any { return t.instance.GetDepositTickUpper(args[0].(uint64)) },
		lpTokenId,
	).(int32)
}

func (t *TestStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	return t.ExecuteFn(
		"GetIncentiveEndTimestamp",
		func(args ...any) any { return t.instance.GetIncentiveEndTimestamp(args[0].(string), args[1].(string)) },
		poolPath, incentiveId,
	).(int64)
}

func (t *TestStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	return t.ExecuteFn(
		"GetIncentiveRewardAmount",
		func(args ...any) any { return t.instance.GetIncentiveRewardAmount(args[0].(string), args[1].(string)) },
		poolPath, incentiveId,
	).(*u256.Uint)
}

func (t *TestStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	return t.ExecuteFn(
		"GetIncentiveRewardAmountAsString",
		func(args ...any) any {
			return t.instance.GetIncentiveRewardAmountAsString(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(string)
}

func (t *TestStaker) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	return t.ExecuteFn(
		"GetIncentiveRewardPerSecond",
		func(args ...any) any {
			return t.instance.GetIncentiveRewardPerSecond(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(int64)
}

func (t *TestStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	return t.ExecuteFn(
		"GetIncentiveRewardToken",
		func(args ...any) any { return t.instance.GetIncentiveRewardToken(args[0].(string), args[1].(string)) },
		poolPath, incentiveId,
	).(string)
}

func (t *TestStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	return t.ExecuteFn(
		"GetIncentiveStartTimestamp",
		func(args ...any) any {
			return t.instance.GetIncentiveStartTimestamp(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(int64)
}

func (t *TestStaker) GetMinimumRewardAmount() int64 {
	return t.ExecuteFn(
		"GetMinimumRewardAmount",
		func(args ...any) any { return t.instance.GetMinimumRewardAmount() },
	).(int64)
}

func (t *TestStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return t.ExecuteFn(
		"GetMinimumRewardAmountForToken",
		func(args ...any) any { return t.instance.GetMinimumRewardAmountForToken(args[0].(string)) },
		tokenPath,
	).(int64)
}

func (t *TestStaker) GetPoolIncentiveIdList(poolPath string) []string {
	return t.ExecuteFn(
		"GetPoolIncentiveIdList",
		func(args ...any) any { return t.instance.GetPoolIncentiveIdList(args[0].(string)) },
		poolPath,
	).([]string)
}

func (t *TestStaker) GetPoolReward(tier uint64) int64 {
	return t.ExecuteFn(
		"GetPoolReward",
		func(args ...any) any { return t.instance.GetPoolReward(args[0].(uint64)) },
		tier,
	).(int64)
}

func (t *TestStaker) GetPoolTier(poolPath string) uint64 {
	return t.ExecuteFn(
		"GetPoolTier",
		func(args ...any) any { return t.instance.GetPoolTier(args[0].(string)) },
		poolPath,
	).(uint64)
}

func (t *TestStaker) GetPoolTierCount(tier uint64) uint64 {
	return t.ExecuteFn(
		"GetPoolTierCount",
		func(args ...any) any { return t.instance.GetPoolTierCount(args[0].(uint64)) },
		tier,
	).(uint64)
}

func (t *TestStaker) GetPoolTierRatio(poolPath string) uint64 {
	return t.ExecuteFn(
		"GetPoolTierRatio",
		func(args ...any) any { return t.instance.GetPoolTierRatio(args[0].(string)) },
		poolPath,
	).(uint64)
}

func (t *TestStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	result := t.ExecuteFn(
		"GetSpecificTokenMinimumRewardAmount",
		func(args ...any) any {
			r1, r2 := t.instance.GetSpecificTokenMinimumRewardAmount(args[0].(string))
			return []any{r1, r2}
		},
		tokenPath,
	).([]any)
	return result[0].(int64), result[1].(bool)
}

func (t *TestStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	return t.ExecuteFn(
		"GetTargetPoolPathByIncentiveId",
		func(args ...any) any {
			return t.instance.GetTargetPoolPathByIncentiveId(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(string)
}

func (t *TestStaker) GetUnstakingFee() int64 {
	return t.ExecuteFn(
		"GetUnstakingFee",
		func(args ...any) any { return t.instance.GetUnstakingFee() },
	).(int64)
}

func (t *TestStaker) IsArchivedExternalIncentive(incentiveId string) bool {
	return t.ExecuteFn(
		"IsArchivedExternalIncentive",
		func(args ...any) any { return t.instance.IsArchivedExternalIncentive(args[0].(string)) },
		incentiveId,
	).(bool)
}

func (t *TestStaker) IsStaked(positionId uint64) bool {
	return t.ExecuteFn(
		"IsStaked",
		func(args ...any) any { return t.instance.IsStaked(args[0].(uint64)) },
		positionId,
	).(bool)
}

func (t *TestStaker) GetUserIncentives(user address) []staker.ExternalIncentive {
	return t.ExecuteFn(
		"GetUserIncentives",
		func(args ...any) any { return t.instance.GetUserIncentives(args[0].(address)) },
		user,
	).([]staker.ExternalIncentive)
}

func (t *TestStaker) GetUserActiveIncentives(user address) []staker.ExternalIncentive {
	return t.ExecuteFn(
		"GetUserActiveIncentives",
		func(args ...any) any { return t.instance.GetUserActiveIncentives(args[0].(address)) },
		user,
	).([]staker.ExternalIncentive)
}

func (t *TestStaker) GetUserArchivedIncentives(user address) []staker.ExternalIncentive {
	return t.ExecuteFn(
		"GetUserArchivedIncentives",
		func(args ...any) any { return t.instance.GetUserArchivedIncentives(args[0].(address)) },
		user,
	).([]staker.ExternalIncentive)
}

// IStakerApi interface
func (t *TestStaker) ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	return t.ExecuteFn(
		"ApiGetExternalIncentiveById",
		func(args ...any) any {
			return t.instance.ApiGetExternalIncentiveById(args[0].(string), args[1].(string))
		},
		poolPath, incentiveId,
	).(string)
}

func (t *TestStaker) ApiGetExternalIncentives() string {
	return t.ExecuteFn(
		"ApiGetExternalIncentives",
		func(args ...any) any { return t.instance.ApiGetExternalIncentives() },
	).(string)
}

func (t *TestStaker) ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	return t.ExecuteFn(
		"ApiGetExternalIncentivesByPoolPath",
		func(args ...any) any { return t.instance.ApiGetExternalIncentivesByPoolPath(args[0].(string)) },
		targetPoolPath,
	).(string)
}

func (t *TestStaker) ApiGetInternalIncentives() string {
	return t.ExecuteFn(
		"ApiGetInternalIncentives",
		func(args ...any) any { return t.instance.ApiGetInternalIncentives() },
	).(string)
}

func (t *TestStaker) ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	return t.ExecuteFn(
		"ApiGetInternalIncentivesByPoolPath",
		func(args ...any) any { return t.instance.ApiGetInternalIncentivesByPoolPath(args[0].(string)) },
		targetPoolPath,
	).(string)
}

func (t *TestStaker) ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	return t.ExecuteFn(
		"ApiGetInternalIncentivesByTiers",
		func(args ...any) any { return t.instance.ApiGetInternalIncentivesByTiers(args[0].(uint64)) },
		targetTier,
	).(string)
}

func (t *TestStaker) ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	return t.ExecuteFn(
		"ApiGetRewardsByLpTokenId",
		func(args ...any) any { return t.instance.ApiGetRewardsByLpTokenId(args[0].(uint64)) },
		targetLpTokenId,
	).(string)
}

func (t *TestStaker) ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	return t.ExecuteFn(
		"ApiGetRewardTokensByPoolPath",
		func(args ...any) any { return t.instance.ApiGetRewardTokensByPoolPath(args[0].(string)) },
		targetPoolPath,
	).(string)
}

func (t *TestStaker) ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	return t.ExecuteFn(
		"ApiGetStakesByLpTokenId",
		func(args ...any) any { return t.instance.ApiGetStakesByLpTokenId(args[0].(uint64)) },
		targetLpTokenId,
	).(string)
}
