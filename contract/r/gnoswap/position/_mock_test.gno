package position

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

type MockPosition struct {
	Version  string
	Response *MockResponse
}

func (m *MockPosition) Mint(
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
	mintTo address,
	caller address,
	referrer string,
) (uint64, string, string, string) {
	res, ok := m.Response.Get("Mint")
	if !ok {
		return 0, "", "", ""
	}

	return res[0].(uint64), res[1].(string), res[2].(string), res[3].(string)
}

func (m *MockPosition) IncreaseLiquidity(
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	res, ok := m.Response.Get("IncreaseLiquidity")
	if !ok {
		return 0, "", "", "", ""
	}

	return res[0].(uint64), res[1].(string), res[2].(string), res[3].(string), res[4].(string)
}

func (m *MockPosition) DecreaseLiquidity(
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	res, ok := m.Response.Get("DecreaseLiquidity")
	if !ok {
		return 0, "", "", "", "", "", ""
	}

	return res[0].(uint64), res[1].(string), res[2].(string), res[3].(string), res[4].(string), res[5].(string), res[6].(string)
}

func (m *MockPosition) Reposition(
	positionId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, int32, int32, string, string) {
	res, ok := m.Response.Get("Reposition")
	if !ok {
		return 0, "", 0, 0, "", ""
	}

	return res[0].(uint64), res[1].(string), res[2].(int32), res[3].(int32), res[4].(string), res[5].(string)
}

func (m *MockPosition) CollectFee(
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	res, ok := m.Response.Get("CollectFee")
	if !ok {
		return 0, "", "", "", "", ""
	}

	return res[0].(uint64), res[1].(string), res[2].(string), res[3].(string), res[4].(string), res[5].(string)
}

func (m *MockPosition) SetPositionOperator(positionId uint64, operator address) {
	m.Response.Get("SetPositionOperator")
}

func (m *MockPosition) GetPositionCount() int {
	res, ok := m.Response.Get("GetPositionCount")
	if !ok {
		return 0
	}

	return res[0].(int)
}

func (m *MockPosition) GetPositionIDs(offset, count int) []uint64 {
	res, ok := m.Response.Get("GetPositionIDs")
	if !ok {
		return []uint64{}
	}

	return res[0].([]uint64)
}

func (m *MockPosition) GetPosition(positionId uint64) (Position, bool) {
	res, ok := m.Response.Get("GetPosition")
	if !ok {
		return Position{}, false
	}

	return res[0].(Position), res[1].(bool)
}

func (m *MockPosition) IsBurned(positionId uint64) bool {
	res, ok := m.Response.Get("IsBurned")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPosition) IsInRange(positionId uint64) bool {
	res, ok := m.Response.Get("IsInRange")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPosition) GetPositionFeeGrowthInside0LastX128(positionId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside0LastX128")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPosition) GetPositionFeeGrowthInside1LastX128(positionId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside1LastX128")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPosition) GetPositionLiquidity(positionId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetPositionLiquidity")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPosition) GetPositionOperator(positionId uint64) address {
	res, ok := m.Response.Get("GetPositionOperator")
	if !ok {
		return ""
	}

	return res[0].(address)
}

func (m *MockPosition) GetPositionPoolKey(positionId uint64) string {
	res, ok := m.Response.Get("GetPositionPoolKey")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPosition) GetPositionTickLower(positionId uint64) int32 {
	res, ok := m.Response.Get("GetPositionTickLower")
	if !ok {
		return 0
	}

	return res[0].(int32)
}

func (m *MockPosition) GetPositionTickUpper(positionId uint64) int32 {
	res, ok := m.Response.Get("GetPositionTickUpper")
	if !ok {
		return 0
	}

	return res[0].(int32)
}

func (m *MockPosition) GetPositionTokensOwed0(positionId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetPositionTokensOwed0")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPosition) GetPositionTokensOwed1(positionId uint64) *u256.Uint {
	res, ok := m.Response.Get("GetPositionTokensOwed1")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPosition) GetUnclaimedFee(positionId uint64) (*u256.Uint, *u256.Uint) {
	res, ok := m.Response.Get("GetUnclaimedFee")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), res[1].(*u256.Uint)
}

func (m *MockPosition) GetPositionOwner(positionId uint64) address {
	res, ok := m.Response.Get("GetPositionOwner")
	if !ok {
		return ""
	}

	return res[0].(address)
}

func newMockPosition(version string) *MockPosition {
	return &MockPosition{
		Version:  version,
		Response: NewMockResponse(),
	}
}
