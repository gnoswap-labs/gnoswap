package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// MockResponse is a simple mock response helper
type MockResponse struct {
	data      map[string][]any
	callCount map[string]int
}

func NewMockResponse() *MockResponse {
	return &MockResponse{
		data:      make(map[string][]any),
		callCount: make(map[string]int),
	}
}

func (m *MockResponse) Set(key string, values ...any) {
	m.data[key] = values
}

func (m *MockResponse) Get(key string) ([]any, bool) {
	if m.callCount == nil {
		m.callCount = make(map[string]int)
	}
	m.callCount[key]++

	val, ok := m.data[key]
	return val, ok
}

func (m *MockResponse) CallCount(key string) int {
	if m.callCount == nil {
		return 0
	}
	return m.callCount[key]
}

type MockStaker struct {
	Version  string
	Response *MockResponse
}

func (m *MockStaker) StakeToken(_ int, rlm realm, positionId uint64, referrer string) string {
	m.Response.Get("StakeToken")
	return "staked"
}

func (m *MockStaker) UnStakeToken(_ int, rlm realm, positionId uint64) string {
	m.Response.Get("UnStakeToken")
	return "unstaked"
}

func (m *MockStaker) CollectReward(_ int, rlm realm, positionId uint64) (string, string, map[string]int64, map[string]int64) {
	res, ok := m.Response.Get("CollectReward")
	if !ok {
		return "pool", "100", make(map[string]int64), make(map[string]int64)
	}

	return res[0].(string), res[1].(string), res[2].(map[string]int64), res[3].(map[string]int64)
}

func (m *MockStaker) CollectEmissionReward(_ int, rlm realm, positionId uint64) (int64, int64) {
	res, ok := m.Response.Get("CollectEmissionReward")
	if !ok {
		return 100, 0
	}

	return res[0].(int64), res[1].(int64)
}

func (m *MockStaker) CollectExternalIncentiveReward(_ int, rlm realm, positionId uint64, incentiveId string) (int64, int64) {
	res, ok := m.Response.Get("CollectExternalIncentiveReward")
	if !ok {
		return 100, 0
	}

	return res[0].(int64), res[1].(int64)
}

func (m *MockStaker) EmissionCacheUpdateHook(_ int, rlm realm, emissionAmountPerSecond int64) {
	m.Response.Get("EmissionCacheUpdateHook")
}

func (m *MockStaker) SetPoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	m.Response.Get("SetPoolTier")
}

func (m *MockStaker) ChangePoolTier(_ int, rlm realm, poolPath string, tier uint64) {
	m.Response.Get("ChangePoolTier")
}

func (m *MockStaker) RemovePoolTier(_ int, rlm realm, poolPath string) {
	m.Response.Get("RemovePoolTier")
}

func (m *MockStaker) CreateExternalIncentive(
	_ int,
	rlm realm,
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	m.Response.Get("CreateExternalIncentive")
}

func (m *MockStaker) EndExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) {
	m.Response.Get("EndExternalIncentive")
}

func (m *MockStaker) CancelExternalIncentive(_ int, rlm realm, targetPoolPath, incentiveId string) {
	m.Response.Get("CancelExternalIncentive")
}

func (m *MockStaker) CollectExternalIncentivePenalty(_ int, rlm realm, targetPoolPath, incentiveId string, refundAddress address) int64 {
	m.Response.Get("CollectExternalIncentivePenalty")
	return 0
}

func (m *MockStaker) AddToken(_ int, rlm realm, tokenPath string) {
	m.Response.Get("AddToken")
}

func (m *MockStaker) RemoveToken(_ int, rlm realm, tokenPath string) {
	m.Response.Get("RemoveToken")
}

func (m *MockStaker) SetWarmUp(_ int, rlm realm, pct, timeDuration int64) {
	m.Response.Get("SetWarmUp")
}

func (m *MockStaker) SetDepositGnsAmount(_ int, rlm realm, amount int64) {
	m.Response.Get("SetDepositGnsAmount")
}

func (m *MockStaker) SetMinimumRewardAmount(_ int, rlm realm, amount int64) {
	m.Response.Get("SetMinimumRewardAmount")
}

func (m *MockStaker) SetTokenMinimumRewardAmount(_ int, rlm realm, paramsStr string) {
	m.Response.Get("SetTokenMinimumRewardAmount")
}

func (m *MockStaker) SetUnStakingFee(_ int, rlm realm, fee uint64) {
	m.Response.Get("SetUnStakingFee")
}

func (m *MockStaker) GetPendingProtocolFees() map[string]int64 {
	res, ok := m.Response.Get("GetPendingProtocolFees")
	if !ok {
		return map[string]int64{}
	}

	return res[0].(map[string]int64)
}

// Getter methods
func (m *MockStaker) GetPool(poolPath string) (*Pool, error) {
	res, ok := m.Response.Get("GetPool")
	if !ok {
		return nil, nil
	}

	return res[0].(*Pool), nil
}

func (m *MockStaker) GetDeposit(lpTokenId uint64) (*Deposit, error) {
	res, ok := m.Response.Get("GetDeposit")
	if !ok {
		return nil, nil
	}

	return res[0].(*Deposit), nil
}

func (m *MockStaker) CollectableEmissionReward(positionId uint64) (int64, error) {
	res, ok := m.Response.Get("CollectableEmissionReward")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("CollectableExternalIncentiveReward")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetCreatedHeightOfIncentive")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveCreatedTimestamp")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveTotalRewardAmount")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveDistributedRewardAmount")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveRemainingRewardAmount")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveAccumulatedPenaltyAmount(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveAccumulatedPenaltyAmount")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveDepositGnsAmount")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveRefunded(poolPath string, incentiveId string) (bool, error) {
	res, ok := m.Response.Get("GetIncentiveRefunded")
	if !ok {
		return false, nil
	}

	return res[0].(bool), nil
}

func (m *MockStaker) IsIncentiveActive(poolPath string, incentiveId string) (bool, error) {
	res, ok := m.Response.Get("IsIncentiveActive")
	if !ok {
		return false, nil
	}

	return res[0].(bool), nil
}

func (m *MockStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositExternalRewardLastCollectTimestamp")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetDepositGnsAmount() int64 {
	res, ok := m.Response.Get("GetDepositGnsAmount")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) (int64, error) {
	res, ok := m.Response.Get("GetDepositInternalRewardLastCollectTimestamp")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetDepositCollectedInternalReward(lpTokenId uint64) (int64, error) {
	res, ok := m.Response.Get("GetDepositCollectedInternalReward")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositCollectedExternalReward")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetDepositLiquidity(lpTokenId uint64) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetDepositLiquidity")
	if !ok {
		return u256.Zero(), nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockStaker) GetDepositLiquidityAsString(lpTokenId uint64) (string, error) {
	res, ok := m.Response.Get("GetDepositLiquidityAsString")
	if !ok {
		return "0", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetDepositOwner(lpTokenId uint64) (address, error) {
	res, ok := m.Response.Get("GetDepositOwner")
	if !ok {
		return address(""), nil
	}

	return res[0].(address), nil
}

func (m *MockStaker) GetDepositStakeTime(lpTokenId uint64) (int64, error) {
	res, ok := m.Response.Get("GetDepositStakeTime")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetDepositTargetPoolPath(lpTokenId uint64) (string, error) {
	res, ok := m.Response.Get("GetDepositTargetPoolPath")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetDepositTickLower(lpTokenId uint64) (int32, error) {
	res, ok := m.Response.Get("GetDepositTickLower")
	if !ok {
		return 0, nil
	}

	return res[0].(int32), nil
}

func (m *MockStaker) GetDepositTickUpper(lpTokenId uint64) (int32, error) {
	res, ok := m.Response.Get("GetDepositTickUpper")
	if !ok {
		return 0, nil
	}

	return res[0].(int32), nil
}

func (m *MockStaker) GetDepositWarmUp(lpTokenId uint64) ([]Warmup, error) {
	res, ok := m.Response.Get("GetDepositWarmUp")
	if !ok {
		return nil, nil
	}

	return res[0].([]Warmup), nil
}

func (m *MockStaker) GetDepositExternalIncentiveIdList(lpTokenId uint64) ([]string, error) {
	res, ok := m.Response.Get("GetDepositExternalIncentiveIdList")
	if !ok {
		return nil, nil
	}

	return res[0].([]string), nil
}

func (m *MockStaker) GetExternalIncentiveByPoolPath(poolPath string) ([]ExternalIncentive, error) {
	res, ok := m.Response.Get("GetExternalIncentiveByPoolPath")
	if !ok {
		return nil, nil
	}

	return res[0].([]ExternalIncentive), nil
}

func (m *MockStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveEndTimestamp")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetIncentiveCreator(poolPath string, incentiveId string) (address, error) {
	res, ok := m.Response.Get("GetIncentiveCreator")
	if !ok {
		return address(""), nil
	}

	return res[0].(address), nil
}

func (m *MockStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetIncentiveRewardAmount")
	if !ok {
		return u256.Zero(), nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) (string, error) {
	res, ok := m.Response.Get("GetIncentiveRewardAmountAsString")
	if !ok {
		return "0", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetIncentiveRewardPerSecondX128(poolPath string, incentiveId string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetIncentiveRewardPerSecondX128")
	if !ok {
		return u256.Zero(), nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) (string, error) {
	res, ok := m.Response.Get("GetIncentiveRewardToken")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) (int64, error) {
	res, ok := m.Response.Get("GetIncentiveStartTimestamp")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetMinimumRewardAmount() int64 {
	res, ok := m.Response.Get("GetMinimumRewardAmount")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockStaker) GetMinimumRewardAmountForToken(tokenPath string) int64 {
	res, ok := m.Response.Get("GetMinimumRewardAmountForToken")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockStaker) GetPoolStakedLiquidity(poolPath string) (string, error) {
	res, ok := m.Response.Get("GetPoolStakedLiquidity")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetPoolsByTier(tier uint64) ([]string, error) {
	res, ok := m.Response.Get("GetPoolsByTier")
	if !ok {
		return []string{}, nil
	}

	return res[0].([]string), nil
}

func (m *MockStaker) GetPoolReward(tier uint64) (int64, error) {
	res, ok := m.Response.Get("GetPoolReward")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) GetPoolTier(poolPath string) uint64 {
	res, ok := m.Response.Get("GetPoolTier")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockStaker) GetPoolTierCount(tier uint64) uint64 {
	res, ok := m.Response.Get("GetPoolTierCount")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockStaker) GetPoolTierRatio(poolPath string) (uint64, error) {
	res, ok := m.Response.Get("GetPoolTierRatio")
	if !ok {
		return 0, nil
	}

	return res[0].(uint64), nil
}

func (m *MockStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	res, ok := m.Response.Get("GetSpecificTokenMinimumRewardAmount")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

func (m *MockStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) (string, error) {
	res, ok := m.Response.Get("GetTargetPoolPathByIncentiveId")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockStaker) GetUnstakingFee() uint64 {
	res, ok := m.Response.Get("GetUnstakingFee")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockStaker) HasUnstakedPosition(positionId uint64) bool {
	res, ok := m.Response.Get("HasUnstakedPosition")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockStaker) GetUnstakedPositionExitTime(positionId uint64) (int64, error) {
	res, ok := m.Response.Get("GetUnstakedPositionExitTime")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockStaker) IsStaked(lpTokenId uint64) bool {
	res, ok := m.Response.Get("IsStaked")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockStaker) GetTotalEmissionSent() int64 {
	res, ok := m.Response.Get("GetTotalEmissionSent")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockStaker) GetAllowedTokens() []string {
	res, ok := m.Response.Get("GetAllowedTokens")
	if !ok {
		return nil
	}

	return res[0].([]string)
}

func (m *MockStaker) GetWarmupTemplate() []Warmup {
	res, ok := m.Response.Get("GetWarmupTemplate")
	if !ok {
		return nil
	}

	return res[0].([]Warmup)
}

func (m *MockStaker) GetPoolRewardCaches(poolPath string) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPoolRewardCaches")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockStaker) GetPoolIncentives(poolPath string) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPoolIncentives")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockStaker) GetPoolGlobalRewardRatioAccumulations(poolPath string) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPoolGlobalRewardRatioAccumulations")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockStaker) GetPoolHistoricalTicks(poolPath string) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPoolHistoricalTicks")
	if !ok {
		return nil
	}
	return res[0].(*rotree.ReadOnlyTree)
}

func newMockStaker(version string) *MockStaker {
	return &MockStaker{
		Version:  version,
		Response: NewMockResponse(),
	}
}
