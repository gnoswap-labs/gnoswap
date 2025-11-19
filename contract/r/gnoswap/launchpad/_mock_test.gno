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

func (m *MockLaunchpad) ApiGetProjectAndTierStatisticsByProjectId(projectId string) string {
	res, ok := m.Response.Get("ApiGetProjectAndTierStatisticsByProjectId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetProjectStatisticsByProjectId(projectId string) string {
	res, ok := m.Response.Get("ApiGetProjectStatisticsByProjectId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetTierStatisticsByProjectId(projectId string) string {
	res, ok := m.Response.Get("ApiGetTierStatisticsByProjectId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetProjectStatisticsByProjectTierId(tierId string) string {
	res, ok := m.Response.Get("ApiGetProjectStatisticsByProjectTierId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetProjectActiveOf(projectId string) string {
	res, ok := m.Response.Get("ApiGetProjectActiveOf")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetDepositByDepositId(depositId string) string {
	res, ok := m.Response.Get("ApiGetDepositByDepositId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetProjectRecipientRewardByProjectId(projectId string) string {
	res, ok := m.Response.Get("ApiGetProjectRecipientRewardByProjectId")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockLaunchpad) ApiGetProjectRecipientRewardByAddress(address address) string {
	res, ok := m.Response.Get("ApiGetProjectRecipientRewardByAddress")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func newMockLaunchpad(version string) *MockLaunchpad {
	return &MockLaunchpad{
		Version:  version,
		Response: NewMockResponse(),
	}
}
