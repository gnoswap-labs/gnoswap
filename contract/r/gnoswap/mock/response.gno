package mock

type MockResponse struct {
	responses   map[string][]any
	methodCalls map[string]int64
}

func NewMockResponse() *MockResponse {
	return &MockResponse{
		responses:   make(map[string][]any),
		methodCalls: make(map[string]int64),
	}
}

func (m *MockResponse) Get(key string) ([]any, bool) {
	m.call(key)
	values, ok := m.responses[key]

	return values, ok
}

func (m *MockResponse) Set(key string, values ...any) {
	m.responses[key] = values
	m.methodCalls[key] = 0
}

func (m *MockResponse) CallCount(key string) int64 {
	return m.methodCalls[key]
}

func (m *MockResponse) call(key string) {
	callCount := m.methodCalls[key]
	if callCount == 0 {
		m.methodCalls[key] = 1
		return
	}

	m.methodCalls[key] = callCount + 1
}
