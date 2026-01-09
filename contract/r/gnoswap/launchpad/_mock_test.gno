package launchpad

import (
	u256 "gno.land/p/gnoswap/uint256"
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

type MockLaunchpad struct {
	Version  string
	Response *MockResponse
}

func (m *MockLaunchpad) CreateProject(
	name string,
	tokenPath string,
	recipient address,
	depositAmount int64,
	conditionTokens string,
	conditionAmounts string,
	tier30Ratio int64,
	tier90Ratio int64,
	tier180Ratio int64,
	startTime int64,
) string {
	res, ok := m.Response.Get("CreateProject")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) TransferLeftFromProjectByAdmin(projectID string, recipient address) int64 {
	res, ok := m.Response.Get("TransferLeftFromProjectByAdmin")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockLaunchpad) CollectProtocolFee() {
	m.Response.Get("CollectProtocolFee")
}

func (m *MockLaunchpad) DepositGns(targetProjectTierID string, depositAmount int64, referrer string) string {
	res, ok := m.Response.Get("DepositGns")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) CollectDepositGns(depositID string) (int64, error) {
	res, ok := m.Response.Get("CollectDepositGns")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 {
		return res[0].(int64), nil
	}
	if res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) CollectRewardByDepositId(depositID string) int64 {
	res, ok := m.Response.Get("CollectRewardByDepositId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockLaunchpad) GetProjectCount() int {
	res, ok := m.Response.Get("GetProjectCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockLaunchpad) GetDepositCount() int {
	res, ok := m.Response.Get("GetDepositCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockLaunchpad) GetProjectTierRewardManagerCount() int {
	res, ok := m.Response.Get("GetProjectTierRewardManagerCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockLaunchpad) GetCurrentDepositId() int64 {
	res, ok := m.Response.Get("GetCurrentDepositId")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockLaunchpad) GetProject(projectId string) (*Project, error) {
	res, ok := m.Response.Get("GetProject")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*Project), nil
	}
	return res[0].(*Project), res[1].(error)
}

func (m *MockLaunchpad) GetDeposit(depositId string) (*Deposit, error) {
	res, ok := m.Response.Get("GetDeposit")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*Deposit), nil
	}
	return res[0].(*Deposit), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTier(projectId string, tier int64) (*ProjectTier, error) {
	res, ok := m.Response.Get("GetProjectTier")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*ProjectTier), nil
	}
	return res[0].(*ProjectTier), res[1].(error)
}

func (m *MockLaunchpad) GetProjectCondition(projectId string, tokenPath string) (*ProjectCondition, error) {
	res, ok := m.Response.Get("GetProjectCondition")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*ProjectCondition), nil
	}
	return res[0].(*ProjectCondition), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardManager(projectTierId string) (*RewardManager, error) {
	res, ok := m.Response.Get("GetProjectTierRewardManager")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*RewardManager), nil
	}
	return res[0].(*RewardManager), res[1].(error)
}

func (m *MockLaunchpad) GetRewardState(projectTierId string, depositId string) (*RewardState, error) {
	res, ok := m.Response.Get("GetRewardState")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*RewardState), nil
	}
	return res[0].(*RewardState), res[1].(error)
}

func (m *MockLaunchpad) GetProjectActiveStatus(projectId string) (bool, error) {
	res, ok := m.Response.Get("GetProjectActiveStatus")
	if !ok {
		return false, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(bool), nil
	}
	return res[0].(bool), res[1].(error)
}

func (m *MockLaunchpad) GetProjectIDs(offset, count int) []string {
	res, ok := m.Response.Get("GetProjectIDs")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockLaunchpad) GetProjectTierDepositCount(projectId string, tier int64) int {
	res, ok := m.Response.Get("GetProjectTierDepositCount")
	if !ok {
		return 0
	}
	return res[0].(int)
}

func (m *MockLaunchpad) GetProjectTierDepositIDs(projectId string, tier int64, offset, count int) []string {
	res, ok := m.Response.Get("GetProjectTierDepositIDs")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockLaunchpad) GetProjectName(projectId string) (string, error) {
	res, ok := m.Response.Get("GetProjectName")
	if !ok {
		return "", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTokenPath(projectId string) (string, error) {
	res, ok := m.Response.Get("GetProjectTokenPath")
	if !ok {
		return "", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func (m *MockLaunchpad) GetProjectDepositAmount(projectId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectDepositAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectRecipient(projectId string) (address, error) {
	res, ok := m.Response.Get("GetProjectRecipient")
	if !ok {
		return "", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(address), nil
	}
	return res[0].(address), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTiersRatios(projectId string) (map[int64]int64, error) {
	res, ok := m.Response.Get("GetProjectTiersRatios")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(map[int64]int64), nil
	}
	return res[0].(map[int64]int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectCreatedHeight(projectId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectCreatedHeight")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectCreatedAt(projectId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectCreatedAt")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierDistributeAmountPerSecondX128(projectId string, tier int64) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetProjectTierDistributeAmountPerSecondX128")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*u256.Uint), nil
	}
	return res[0].(*u256.Uint), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalDistributeAmount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalDistributeAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalDepositAmount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalDepositAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalWithdrawAmount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalWithdrawAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalDepositCount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalDepositCount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalWithdrawCount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalWithdrawCount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierTotalCollectedAmount(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierTotalCollectedAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierStartTime(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierStartTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierEndTime(projectId string, tier int64) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierEndTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositProjectID(depositId string) (string, error) {
	res, ok := m.Response.Get("GetDepositProjectID")
	if !ok {
		return "", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func (m *MockLaunchpad) GetDepositTier(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositTier")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositProjectTierID(depositId string) (string, error) {
	res, ok := m.Response.Get("GetDepositProjectTierID")
	if !ok {
		return "", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func (m *MockLaunchpad) GetDepositAmount(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositWithdrawnHeight(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositWithdrawnHeight")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositWithdrawnTime(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositWithdrawnTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositCreatedHeight(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositCreatedHeight")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositCreatedAt(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositCreatedAt")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetDepositEndTime(depositId string) (int64, error) {
	res, ok := m.Response.Get("GetDepositEndTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardDistributeAmountPerSecondX128(projectTierId string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetProjectTierRewardDistributeAmountPerSecondX128")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*u256.Uint), nil
	}
	return res[0].(*u256.Uint), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardAccumulatedRewardPerDepositX128(projectTierId string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetProjectTierRewardAccumulatedRewardPerDepositX128")
	if !ok {
		return nil, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(*u256.Uint), nil
	}
	return res[0].(*u256.Uint), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardTotalDistributeAmount(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardTotalDistributeAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardTotalClaimedAmount(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardTotalClaimedAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardDistributeStartTime(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardDistributeStartTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardDistributeEndTime(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardDistributeEndTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardAccumulatedDistributeAmount(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardAccumulatedDistributeAmount")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardAccumulatedHeight(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardAccumulatedHeight")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardAccumulatedTime(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardAccumulatedTime")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func (m *MockLaunchpad) GetProjectTierRewardRewardClaimableDuration(projectTierId string) (int64, error) {
	res, ok := m.Response.Get("GetProjectTierRewardRewardClaimableDuration")
	if !ok {
		return 0, nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(int64), nil
	}
	return res[0].(int64), res[1].(error)
}

func newMockLaunchpad(version string) *MockLaunchpad {
	return &MockLaunchpad{
		Version:  version,
		Response: NewMockResponse(),
	}
}
