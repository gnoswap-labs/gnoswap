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

func (m *MockProtocolFee) DistributeProtocolFee() {
	m.Response.Get("DistributeProtocolFee")
}

func (m *MockProtocolFee) SetDevOpsPct(pct int64) {
	m.Response.Get("SetDevOpsPct")
}

func (m *MockProtocolFee) SetGovStakerPct(pct int64) {
	m.Response.Get("SetGovStakerPct")
}

func (m *MockProtocolFee) AddToProtocolFee(tokenPath string, amount int64) error {
	res, ok := m.Response.Get("AddToProtocolFee")
	if !ok || len(res) == 0 || res[0] == nil {
		return nil
	}
	return res[0].(error)
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

func (m *MockProtocolFee) GetReservedTokens() []string {
	res, ok := m.Response.Get("GetReservedTokens")
	if !ok {
		return nil
	}
	return res[0].([]string)
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

func (m *MockProtocolFee) GetActualDistributedToGovStaker() map[string]int64 {
	res, ok := m.Response.Get("GetActualDistributedToGovStaker")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) GetActualDistributedToDevOps() map[string]int64 {
	res, ok := m.Response.Get("GetActualDistributedToDevOps")
	if !ok {
		return nil
	}
	return res[0].(map[string]int64)
}

func (m *MockProtocolFee) GetActualDistributedToGovStakerByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetActualDistributedToGovStakerByTokenPath")
	if !ok {
		return 0
	}
	return res[0].(int64)
}

func (m *MockProtocolFee) GetActualDistributedToDevOpsByTokenPath(path string) int64 {
	res, ok := m.Response.Get("GetActualDistributedToDevOpsByTokenPath")
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
