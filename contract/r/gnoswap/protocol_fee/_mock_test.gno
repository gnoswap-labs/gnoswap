package protocol_fee

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

type MockProtocolFee struct {
	Version  string
	Response *MockResponse
}

func (m *MockProtocolFee) DistributeProtocolFee() map[string]int64 {
	res, ok := m.Response.Get("DistributeProtocolFee")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) SetDevOpsPct(pct int64) {
	m.Response.Get("SetDevOpsPct")
}

func (m *MockProtocolFee) SetGovStakerPct(pct int64) {
	m.Response.Get("SetGovStakerPct")
}

func (m *MockProtocolFee) AddToProtocolFee(tokenPath string, amount int64) {
	m.Response.Get("AddToProtocolFee")
}

func (m *MockProtocolFee) ClearTokenListWithAmount() {
	m.Response.Get("ClearTokenListWithAmount")
}

func (m *MockProtocolFee) ClearAccuTransferToGovStaker() {
	m.Response.Get("ClearAccuTransferToGovStaker")
}

func (m *MockProtocolFee) GetDevOpsPct() int64 {
	res, ok := m.Response.Get("GetDevOpsPct")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetGovStakerPct() int64 {
	res, ok := m.Response.Get("GetGovStakerPct")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetTokenListWithAmount() map[string]int64 {
	res, ok := m.Response.Get("GetTokenListWithAmount")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) GetTokenList() []string {
	res, ok := m.Response.Get("GetTokenList")
	if !ok {
		return nil
	}
	return res[0].([]string)
}

func (m *MockProtocolFee) GetAmountOfToken(tokenPath string) int64 {
	res, ok := m.Response.Get("GetAmountOfToken")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetAccuTransfersToGovStaker() map[string]int64 {
	res, ok := m.Response.Get("GetAccuTransfersToGovStaker")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) GetAccuTransfersToDevOps() map[string]int64 {
	res, ok := m.Response.Get("GetAccuTransfersToDevOps")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) GetAccuTransferToGovStakerByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetAccuTransferToGovStakerByTokenPath")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetAccuTransferToDevOpsByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetAccuTransferToDevOpsByTokenPath")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetHistoryOfDistributedToGovStakerByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetHistoryOfDistributedToGovStakerByTokenPath")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetHistoryOfDistributedToDevOpsByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetHistoryOfDistributedToDevOpsByTokenPath")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) ApiGetAccuTransferToGovStaker() string {
	res, ok := m.Response.Get("ApiGetAccuTransferToGovStaker")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetAccuTransferToDevOps() string {
	res, ok := m.Response.Get("ApiGetAccuTransferToDevOps")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetHistoryTransferToGovStaker() string {
	res, ok := m.Response.Get("ApiGetHistoryTransferToGovStaker")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetHistoryTransferToDevOps() string {
	res, ok := m.Response.Get("ApiGetHistoryTransferToDevOps")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetActualBalance() string {
	res, ok := m.Response.Get("ApiGetActualBalance")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetRecordedBalance() string {
	res, ok := m.Response.Get("ApiGetRecordedBalance")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func (m *MockProtocolFee) ApiGetUnrecordedBalance() string {
	res, ok := m.Response.Get("ApiGetUnrecordedBalance")
	if !ok {
		return ""
	}
	return res[0].(string)
}

func newMockProtocolFee(version string) *MockProtocolFee {
	return &MockProtocolFee{
		Version:  version,
		Response: NewMockResponse(),
	}
}
