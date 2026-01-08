package launchpad

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

func (m *MockLaunchpad) GetProjectCount() int64 {
	res, ok := m.Response.Get("GetProjectCount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockLaunchpad) GetDepositCount() int64 {
	res, ok := m.Response.Get("GetDepositCount")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockLaunchpad) GetRewardManagerCount() int64 {
	res, ok := m.Response.Get("GetRewardManagerCount")
	if !ok {
		return 0
	}
	return res[0].(int64)
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

func (m *MockLaunchpad) GetRewardManager(projectTierId string) (*RewardManager, error) {
	res, ok := m.Response.Get("GetRewardManager")
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

func (m *MockLaunchpad) GetClaimableRewardByProjectId(projectId string) (string, error) {
	res, ok := m.Response.Get("GetClaimableRewardByProjectId")
	if !ok {
		return "0", nil
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func (m *MockLaunchpad) GetClaimableRewardByAddress(addr address) string {
	res, ok := m.Response.Get("GetClaimableRewardByAddress")
	if !ok {
		return "0"
	}
	return res[0].(string)
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

func (m *MockLaunchpad) GetProjects(offset, limit int64) []string {
	res, ok := m.Response.Get("GetProjects")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockLaunchpad) GetDeposits(offset, limit int64) []string {
	res, ok := m.Response.Get("GetDeposits")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func (m *MockLaunchpad) GetRewardManagers(offset, limit int64) []string {
	res, ok := m.Response.Get("GetRewardManagers")
	if !ok {
		return []string{}
	}
	return res[0].([]string)
}

func newMockLaunchpad(version string) *MockLaunchpad {
	return &MockLaunchpad{
		Version:  version,
		Response: NewMockResponse(),
	}
}
