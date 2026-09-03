// Simplified test implementation for staker contract upgrade testing
package mock

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
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
func (t *TestStaker) StakeToken(_ int, rlm realm, positionId uint64, referrer string) string {
	return t.ExecuteFn(
		"StakeToken",
		func(args ...any) any { return t.instance.StakeToken(0, rlm, args[0].(uint64), args[1].(string)) },
		positionId, referrer,
	).(string)
}

func (t *TestStaker) UnStakeToken(_ int, rlm realm, positionId uint64) string {
	return t.ExecuteFn(
		"UnStakeToken",
		func(args ...any) any { return t.instance.UnStakeToken(0, rlm, args[0].(uint64)) },
		positionId,
	).(string)
}

func (t *TestStaker) CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	result := t.ExecuteFn(
		"CollectReward",
		func(args ...any) any {
			r1, r2, r3, r4 := t.instance.CollectReward(0, rlm, args[0].(uint64))
			return []any{r1, r2, r3, r4}
		},
		positionId,
	).([]any)
	return result[0].(string), result[1].(string), result[2].(map[string]int64), result[3].(map[string]int64)
}

func (t *TestStaker) SetPoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	t.ExecuteFn(
		"SetPoolTier",
		func(args ...any) any { t.instance.SetPoolTier(0, rlm, args[0].(string), args[1].(uint64)); return nil },
		poolPath, tier,
	)
}

func (t *TestStaker) ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	t.ExecuteFn(
		"ChangePoolTier",
		func(args ...any) any {
			t.instance.ChangePoolTier(0, rlm, args[0].(string), args[1].(uint64))
			return nil
		},
		poolPath, tier,
	)
}

func (t *TestStaker) RemovePoolTier(_ int, rlm realm, poolPath string) {
	t.ExecuteFn(
		"RemovePoolTier",
		func(args ...any) any { t.instance.RemovePoolTier(0, rlm, args[0].(string)); return nil },
		poolPath,
	)
}

func (t *TestStaker) CreateExternalIncentive(_ int, rlm realm, targetPoolPath string, rewardToken string, rewardAmount int64, startTimestamp int64, endTimestamp int64) {
	t.ExecuteFn(
		"CreateExternalIncentive",
		func(args ...any) any {
			t.instance.CreateExternalIncentive(0, rlm, args[0].(string), args[1].(string), args[2].(int64), args[3].(int64), args[4].(int64))
			return nil
		},
		targetPoolPath, rewardToken, rewardAmount, startTimestamp, endTimestamp,
	)
}

func (t *TestStaker) EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) {
	t.ExecuteFn(
		"EndExternalIncentive",
		func(args ...any) any {
			t.instance.EndExternalIncentive(0, rlm, args[0].(string), args[1].(string), args[2].(address))
			return nil
		},
		targetPoolPath, incentiveId, refundAddress,
	)
}

func (t *TestStaker) CancelExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string) {
	t.ExecuteFn(
		"CancelExternalIncentive",
		func(args ...any) any {
			t.instance.CancelExternalIncentive(0, rlm, args[0].(string), args[1].(string))
			return nil
		},
		targetPoolPath, incentiveId,
	)
}

func (t *TestStaker) CollectExternalIncentivePenalty(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) int64 {
	return t.ExecuteFn(
		"CollectExternalIncentivePenalty",
		func(args ...any) any {
			return t.instance.CollectExternalIncentivePenalty(0, rlm, args[0].(string), args[1].(string), args[2].(address))
		},
		targetPoolPath, incentiveId, refundAddress,
	).(int64)
}

func (t *TestStaker) AddToken(_ int, rlm realm, tokenPath string) {
	t.ExecuteFn(
		"AddToken",
		func(args ...any) any { t.instance.AddToken(0, rlm, args[0].(string)); return nil },
		tokenPath,
	)
}

func (t *TestStaker) RemoveToken(_ int, rlm realm, tokenPath string) {
	t.ExecuteFn(
		"RemoveToken",
		func(args ...any) any { t.instance.RemoveToken(0, rlm, args[0].(string)); return nil },
		tokenPath,
	)
}

func (t *TestStaker) SetWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	t.ExecuteFn(
		"SetWarmUp",
		func(args ...any) any { t.instance.SetWarmUp(0, rlm, args[0].(int64), args[1].(int64)); return nil },
		pct, timeDuration,
	)
}

func (t *TestStaker) SetDepositGnsAmount(_ int, rlm realm, amount int64) {
	t.ExecuteFn(
		"SetDepositGnsAmount",
		func(args ...any) any { t.instance.SetDepositGnsAmount(0, rlm, args[0].(int64)); return nil },
		amount,
	)
}

func (t *TestStaker) SetMinimumRewardAmount(_ int, rlm realm, amount int64) {
	t.ExecuteFn(
		"SetMinimumRewardAmount",
		func(args ...any) any { t.instance.SetMinimumRewardAmount(0, rlm, args[0].(int64)); return nil },
		amount,
	)
}

func (t *TestStaker) SetTokenMinimumRewardAmount(_ int, rlm realm, paramsStr string) {
	t.ExecuteFn(
		"SetTokenMinimumRewardAmount",
		func(args ...any) any { t.instance.SetTokenMinimumRewardAmount(0, rlm, args[0].(string)); return nil },
		paramsStr,
	)
}

func (t *TestStaker) SetUnStakingFee(_ int, rlm realm, fee uint64) {
	t.ExecuteFn(
		"SetUnStakingFee",
		func(args ...any) any { t.instance.SetUnStakingFee(0, rlm, args[0].(uint64)); return nil },
		fee,
	)
}

// IStakerGetter interface
func (t *TestStaker) GetPool(poolPath string) (*staker.Pool, error) {
	return t.instance.GetPool(poolPath)
}

func (t *TestStaker) GetDeposit(lpTokenId uint64) (*staker.Deposit, error) {
	return t.instance.GetDeposit(lpTokenId)
}

func (t *TestStaker) CollectableEmissionReward(positionId uint64) (int64, error) {
	return t.instance.CollectableEmissionReward(positionId)
}

func (t *TestStaker) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	return t.instance.CollectableExternalIncentiveReward(positionId, incentiveId)
}

func (t *TestStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetCreatedHeightOfIncentive(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveCreatedTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveTotalRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveDistributedRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveRemainingRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveAccumulatedPenaltyAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveDepositGnsAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	return t.instance.GetIncentiveRefunded(poolPath, incentiveId)
}

func (t *TestStaker) IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	return t.instance.IsIncentiveActive(poolPath, incentiveId)
}

func (t *TestStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	return t.instance.GetDepositExternalRewardLastCollectTimestamp(lpTokenId, incentiveId)
}

func (t *TestStaker) GetDepositGnsAmount() int64 {
	return t.instance.GetDepositGnsAmount()
}

func (t *TestStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	return t.instance.GetDepositInternalRewardLastCollectTimestamp(lpTokenId)
}

func (t *TestStaker) GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	return t.instance.GetDepositCollectedInternalReward(lpTokenId)
}

func (t *TestStaker) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	return t.instance.GetDepositCollectedExternalReward(lpTokenId, incentiveId)
}

func (t *TestStaker) GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	return t.instance.GetDepositLiquidity(lpTokenId)
}

func (t *TestStaker) GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	return t.instance.GetDepositLiquidityAsString(lpTokenId)
}

func (t *TestStaker) GetDepositOwner(lpTokenId uint64) (address, error) {
	return t.instance.GetDepositOwner(lpTokenId)
}

func (t *TestStaker) GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	return t.instance.GetDepositStakeTime(lpTokenId)
}

func (t *TestStaker) GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	return t.instance.GetDepositTargetPoolPath(lpTokenId)
}

func (t *TestStaker) GetDepositTickLower(lpTokenId uint64) (int32, error) {
	return t.instance.GetDepositTickLower(lpTokenId)
}

func (t *TestStaker) GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	return t.instance.GetDepositTickUpper(lpTokenId)
}

func (t *TestStaker) GetDepositWarmUp(lpTokenId uint64) ([]staker.Warmup, error) {
	return t.instance.GetDepositWarmUp(lpTokenId)
}

func (t *TestStaker) GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	return t.instance.GetDepositExternalIncentiveIdList(lpTokenId)
}

func (t *TestStaker) GetExternalIncentiveByPoolPath(poolPath string) ([]staker.ExternalIncentive, error) {
	return t.instance.GetExternalIncentiveByPoolPath(poolPath)
}

func (t *TestStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveEndTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	return t.instance.GetIncentiveCreator(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	return t.instance.GetIncentiveRewardAmount(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	return t.instance.GetIncentiveRewardAmountAsString(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	return t.instance.GetIncentiveRewardPerSecondX128(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	return t.instance.GetIncentiveRewardToken(poolPath, incentiveId)
}

func (t *TestStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	return t.instance.GetIncentiveStartTimestamp(poolPath, incentiveId)
}

func (t *TestStaker) GetMinimumRewardAmount() int64 {
	return t.instance.GetMinimumRewardAmount()
}

func (t *TestStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	return t.instance.GetMinimumRewardAmountForToken(tokenPath)
}

func (t *TestStaker) GetPoolStakedLiquidity(poolPath string) (string, error) {
	return t.instance.GetPoolStakedLiquidity(poolPath)
}

func (t *TestStaker) GetPoolsByTier(tier uint64) ([]string, error) {
	return t.instance.GetPoolsByTier(tier)
}

func (t *TestStaker) GetPoolReward(tier uint64) (int64, error) {
	return t.instance.GetPoolReward(tier)
}

func (t *TestStaker) GetPoolTier(poolPath string) uint64 {
	return t.instance.GetPoolTier(poolPath)
}

func (t *TestStaker) GetPoolTierCount(tier uint64) uint64 {
	return t.instance.GetPoolTierCount(tier)
}

func (t *TestStaker) GetPoolTierRatio(poolPath string) (uint64, error) {
	return t.instance.GetPoolTierRatio(poolPath)
}

func (t *TestStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	return t.instance.GetSpecificTokenMinimumRewardAmount(tokenPath)
}

func (t *TestStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	return t.instance.GetTargetPoolPathByIncentiveId(poolPath, incentiveId)
}

func (t *TestStaker) GetUnstakingFee() uint64 {
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

func (t *TestStaker) GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	return t.ExecuteFn(
		"GetPoolRewardCaches",
		func(args ...any) any {
			return t.instance.GetPoolRewardCaches(args[0].(string))
		},
		poolPath,
	).(*rotree.ReadOnlyTree)
}

func (t *TestStaker) GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	return t.ExecuteFn(
		"GetPoolIncentives",
		func(args ...any) any {
			return t.instance.GetPoolIncentives(args[0].(string))
		},
		poolPath,
	).(*rotree.ReadOnlyTree)
}

func (t *TestStaker) GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	return t.ExecuteFn(
		"GetPoolGlobalRewardRatioAccumulations",
		func(args ...any) any {
			return t.instance.GetPoolGlobalRewardRatioAccumulations(args[0].(string))
		},
		poolPath,
	).(*rotree.ReadOnlyTree)
}

func (t *TestStaker) GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	return t.ExecuteFn(
		"GetPoolHistoricalTicks",
		func(args ...any) any {
			return t.instance.GetPoolHistoricalTicks(args[0].(string))
		},
		poolPath,
	).(*rotree.ReadOnlyTree)
}

func (t *TestStaker) GetPendingProtocolFees() map[string]int64 {
	return t.ExecuteFn(
		"GetPendingProtocolFees",
		func(args ...any) any { return t.instance.GetPendingProtocolFees() },
	).(map[string]int64)
}
