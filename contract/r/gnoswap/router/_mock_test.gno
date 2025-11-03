package router

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

type MockRouter struct {
	Version  string
	Response *MockResponse
}

func (m *MockRouter) ExactInSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	res, ok := m.Response.Get("ExactInSwapRoute")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockRouter) ExactInSingleSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	amountOutMin string,
	sqrtPriceLimitX96 string,
	deadline int64,
	referrer string,
) (string, string) {
	res, ok := m.Response.Get("ExactInSingleSwapRoute")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockRouter) ExactOutSwapRoute(
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	quoteArr string,
	amountInMax string,
	deadline int64,
	referrer string,
) (string, string) {
	res, ok := m.Response.Get("ExactOutSwapRoute")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockRouter) ExactOutSingleSwapRoute(
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	amountInMax string,
	sqrtPriceLimitX96 string,
	deadline int64,
	referrer string,
) (string, string) {
	res, ok := m.Response.Get("ExactOutSingleSwapRoute")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockRouter) DrySwapRoute(
	inputToken, outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit string,
) (string, string, bool) {
	res, ok := m.Response.Get("DrySwapRoute")
	if !ok {
		return "", "", false
	}

	return res[0].(string), res[1].(string), res[2].(bool)
}

func (m *MockRouter) SwapCallback(
	token0Path string,
	token1Path string,
	amount0Delta string,
	amount1Delta string,
	payer address,
) error {
	m.Response.Get("SwapCallback")
	return nil
}

func (m *MockRouter) GetSwapFee() uint64 {
	res, ok := m.Response.Get("GetSwapFee")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockRouter) SetSwapFee(fee uint64) {
	m.Response.Get("SetSwapFee")
}

func newMockRouter(version string) *MockRouter {
	return &MockRouter{
		Version:  version,
		Response: NewMockResponse(),
	}
}
