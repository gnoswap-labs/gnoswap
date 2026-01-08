package staker

import u256 "gno.land/p/gnoswap/uint256"

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

func (m *MockStaker) StakeToken(positionId uint64, referrer string) string {
	m.Response.Get("StakeToken")
	return "staked"
}

func (m *MockStaker) UnStakeToken(positionId uint64, unwrapResult bool) string {
	m.Response.Get("UnStakeToken")
	return "unstaked"
}

func (m *MockStaker) MintAndStake(
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
) (uint64, string, string, string, string) {
	m.Response.Get("MintAndStake")
	return 1, "1000", "1000", "100", "100"
}

func (m *MockStaker) CollectReward(positionId uint64, unwrapResult bool) (string, string, map[string]int64, map[string]int64) {
	m.Response.Get("CollectReward")
	return "pool", "100", make(map[string]int64), make(map[string]int64)
}

func (m *MockStaker) SetPoolTier(poolPath string, tier uint64) {
	m.Response.Get("SetPoolTier")
}

func (m *MockStaker) ChangePoolTier(poolPath string, tier uint64) {
	m.Response.Get("ChangePoolTier")
}

func (m *MockStaker) RemovePoolTier(poolPath string) {
	m.Response.Get("RemovePoolTier")
}

func (m *MockStaker) CreateExternalIncentive(
	targetPoolPath string,
	rewardToken string,
	rewardAmount int64,
	startTimestamp int64,
	endTimestamp int64,
) {
	m.Response.Get("CreateExternalIncentive")
}

func (m *MockStaker) EndExternalIncentive(targetPoolPath, incentiveId string) {
	m.Response.Get("EndExternalIncentive")
}

func (m *MockStaker) AddToken(tokenPath string) {
	m.Response.Get("AddToken")
}

func (m *MockStaker) RemoveToken(tokenPath string) {
	m.Response.Get("RemoveToken")
}

func (m *MockStaker) SetWarmUp(pct, timeDuration int64) {
	m.Response.Get("SetWarmUp")
}

func (m *MockStaker) SetDepositGnsAmount(amount int64) {
	m.Response.Get("SetDepositGnsAmount")
}

func (m *MockStaker) SetMinimumRewardAmount(amount int64) {
	m.Response.Get("SetMinimumRewardAmount")
}

func (m *MockStaker) SetTokenMinimumRewardAmount(paramsStr string) {
	m.Response.Get("SetTokenMinimumRewardAmount")
}

func (m *MockStaker) SetUnStakingFee(fee int64) {
	m.Response.Get("SetUnStakingFee")
}

// Getter methods
func (m *MockStaker) GetPool(poolPath string) *Pool {
	res, ok := m.Response.Get("GetPool")
	if !ok {
		return nil
	}
	return res[0].(*Pool)
}

func (m *MockStaker) GetIncentive(poolPath string, incentiveId string) *ExternalIncentive {
	res, ok := m.Response.Get("GetIncentive")
	if !ok {
		return nil
	}
	return res[0].(*ExternalIncentive)
}

func (m *MockStaker) GetDeposit(lpTokenId uint64) *Deposit {
	res, ok := m.Response.Get("GetDeposit")
	if !ok {
		return nil
	}
	return res[0].(*Deposit)
}

func (m *MockStaker) CollectableEmissionReward(positionId uint64) int64 {
	res, ok := m.Response.Get("CollectableEmissionReward")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) CollectableExternalIncentiveReward(positionId uint64, incentiveId string) int64 {
	res, ok := m.Response.Get("CollectableExternalIncentiveReward")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetCreatedHeightOfIncentive(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetCreatedHeightOfIncentive")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveCreatedTimestamp(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveCreatedTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveTotalRewardAmount(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveTotalRewardAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveDistributedRewardAmount(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveDistributedRewardAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveRemainingRewardAmount(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveRemainingRewardAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveDepositGnsAmount(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveDepositGnsAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveRefunded(poolPath string, incentiveId string) bool {
	res, ok := m.Response.Get("GetIncentiveRefunded")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockStaker) IsIncentiveActive(poolPath string, incentiveId string) bool {
	res, ok := m.Response.Get("IsIncentiveActive")
	if !ok {
		return false
	}
	return res[0].(bool)
}

func (m *MockStaker) GetDepositExternalRewardLastCollectTimestamp(lpTokenId uint64, incentiveId string) int64 {
	res, ok := m.Response.Get("GetDepositExternalRewardLastCollectTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositGnsAmount() int64 {
	res, ok := m.Response.Get("GetDepositGnsAmount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositInternalRewardLastCollectTimestamp(lpTokenId uint64) int64 {
	res, ok := m.Response.Get("GetDepositInternalRewardLastCollectTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositStakeTimestamp(lpTokenId uint64) int64 {
	res, ok := m.Response.Get("GetDepositStakeTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositCollectedInternalReward(lpTokenId uint64) int64 {
	res, ok := m.Response.Get("GetDepositCollectedInternalReward")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositCollectedExternalReward(lpTokenId uint64, incentiveId string) int64 {
	res, ok := m.Response.Get("GetDepositCollectedExternalReward")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositLiquidity(lpTokenId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetDepositLiquidity")
	if !ok {
		return u256.Zero()
	}
	return res[0].(*u256.Uint)
}

func (m *MockStaker) GetDepositLiquidityAsString(lpTokenId uint64) string {
	res, ok := m.Response.Get("GetDepositLiquidityAsString")
	if !ok {
		return "0"
	}
	return res[0].(string)
}

func (m *MockStaker) GetDepositOwner(lpTokenId uint64) address {
	res, ok := m.Response.Get("GetDepositOwner")
	if !ok {
		return address("")
	}
	return res[0].(address)
}

func (m *MockStaker) GetDepositStakeTime(lpTokenId uint64) int64 {
	res, ok := m.Response.Get("GetDepositStakeTime")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetDepositTargetPoolPath(lpTokenId uint64) string {
	res, ok := m.Response.Get("GetDepositTargetPoolPath")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockStaker) GetDepositTickLower(lpTokenId uint64) int32 {
	res, ok := m.Response.Get("GetDepositTickLower")
	if !ok {
		return 0
	}
	return res[0].(int32)
}

func (m *MockStaker) GetDepositTickUpper(lpTokenId uint64) int32 {
	res, ok := m.Response.Get("GetDepositTickUpper")
	if !ok {
		return 0
	}
	return res[0].(int32)
}

func (m *MockStaker) GetDepositWarmUp(lpTokenId uint64) []Warmup {
	res, ok := m.Response.Get("GetDepositWarmUp")
	if !ok {
		return nil
	}
	return res[0].([]Warmup)
}

func (m *MockStaker) GetDepositExternalIncentiveIdList(lpTokenId uint64) []string {
	res, ok := m.Response.Get("GetDepositExternalIncentiveIdList")
	if !ok {
		return nil
	}
	return res[0].([]string)
}

func (m *MockStaker) GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	res, ok := m.Response.Get("GetExternalIncentiveByPoolPath")
	if !ok {
		return nil
	}
	return res[0].([]ExternalIncentive)
}

func (m *MockStaker) GetIncentiveEndTimestamp(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveEndTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveRefundee(poolPath string, incentiveId string) address {
	res, ok := m.Response.Get("GetIncentiveRefundee")
	if !ok {
		return address("")
	}
	return res[0].(address)
}

func (m *MockStaker) GetIncentiveRewardAmount(poolPath string, incentiveId string) *u256.Uint {
	res, ok := m.Response.Get("GetIncentiveRewardAmount")
	if !ok {
		return u256.Zero()
	}
	return res[0].(*u256.Uint)
}

func (m *MockStaker) GetIncentiveRewardAmountAsString(poolPath string, incentiveId string) string {
	res, ok := m.Response.Get("GetIncentiveRewardAmountAsString")
	if !ok {
		return "0"
	}
	return res[0].(string)
}

func (m *MockStaker) GetIncentiveRewardPerSecond(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveRewardPerSecond")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) GetIncentiveRewardToken(poolPath string, incentiveId string) string {
	res, ok := m.Response.Get("GetIncentiveRewardToken")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockStaker) GetIncentiveStartTimestamp(poolPath string, incentiveId string) int64 {
	res, ok := m.Response.Get("GetIncentiveStartTimestamp")
	if !ok {
		return 0
	}
	return res[0].(int64)
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

func (m *MockStaker) GetPoolIncentiveIdList(poolPath string) []string {
	res, ok := m.Response.Get("GetPoolIncentiveIdList")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockStaker) GetPoolStakedLiquidity(poolPath string) string {
	res, ok := m.Response.Get("GetPoolStakedLiquidity")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockStaker) GetPoolsByTier(tier uint64) []string {
	res, ok := m.Response.Get("GetPoolsByTier")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockStaker) GetPoolReward(tier uint64) int64 {
	res, ok := m.Response.Get("GetPoolReward")
	if !ok {
		return 0
	}
	return res[0].(int64)
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

func (m *MockStaker) GetPoolTierRatio(poolPath string) uint64 {
	res, ok := m.Response.Get("GetPoolTierRatio")
	if !ok {
		return 0
	}
	return res[0].(uint64)
}

func (m *MockStaker) GetSpecificTokenMinimumRewardAmount(tokenPath string) (int64, bool) {
	res, ok := m.Response.Get("GetSpecificTokenMinimumRewardAmount")
	if !ok {
		return 0, false
	}
	return res[0].(int64), res[1].(bool)
}

func (m *MockStaker) GetTargetPoolPathByIncentiveId(poolPath string, incentiveId string) string {
	res, ok := m.Response.Get("GetTargetPoolPathByIncentiveId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockStaker) GetUnstakingFee() int64 {
	res, ok := m.Response.Get("GetUnstakingFee")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockStaker) IsStaked(positionId uint64) bool {
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

func (m *MockStaker) GetTotalStakedPositionCount() uint64 {
	res, ok := m.Response.Get("GetTotalStakedPositionCount")
	if !ok {
		return 0
	}
	return res[0].(uint64)
}

func (m *MockStaker) GetStakedPositionsByUser(owner address, offset, count int) []uint64 {
	res, ok := m.Response.Get("GetStakedPositionsByUser")
	if !ok {
		return nil
	}
	return res[0].([]uint64)
}

func newMockStaker(version string) *MockStaker {
	return &MockStaker{
		Version:  version,
		Response: NewMockResponse(),
	}
}
