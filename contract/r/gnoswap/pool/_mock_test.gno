package pool

import (
	"errors"

	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// MockResponse tracks method calls for testing purposes
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

type MockPool struct {
	Version  string
	Response *MockResponse
}

func (m *MockPool) CreatePool(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	m.Response.Get("CreatePool")
}

// SetPoolCreationFee sets the pool creation fee.
func (m *MockPool) SetPoolCreationFee(_ int, rlm realm, fee int64) {
	m.Response.Get("SetPoolCreationFee")
}

func (m *MockPool) IncreaseObservationCardinalityNext(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	m.Response.Get("IncreaseObservationCardinalityNext")
}

func (m *MockPool) Mint(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	res, ok := m.Response.Get("Mint")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

// Burn removes liquidity from a position.
func (m *MockPool) Burn(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	res, ok := m.Response.Get("Burn")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

// Collect transfers owed tokens from a position to recipient.
func (m *MockPool) Collect(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	res, ok := m.Response.Get("Collect")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockPool) SetWithdrawalFee(_ int, rlm realm, fee uint64) {
	m.Response.Get("SetWithdrawalFee")
}

func (m *MockPool) GetPendingProtocolFees() map[string]int64 {
	res, ok := m.Response.Get("GetPendingProtocolFees")
	if !ok {
		return map[string]int64{}
	}

	return res[0].(map[string]int64)
}

func (m *MockPool) HandleWithdrawalFee(
	_ int,
	rlm realm,
	token0Path string,
	amount0 string,
	token1Path string,
	amount1 string,
	positionCaller address,
) (string, string, string, string) {
	res, ok := m.Response.Get("HandleWithdrawalFee")
	if !ok {
		return "", "", "", ""
	}

	return res[0].(string), res[1].(string), res[2].(string), res[3].(string)
}

func (m *MockPool) Swap(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *CallbackMarker) error,
) (string, string) {
	res, ok := m.Response.Get("Swap")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockPool) SetSwapEndHook(_ int, rlm realm, hook func(cur realm, poolPath string) error) {
	m.Response.Get("SetSwapEndHook")
}

func (m *MockPool) SetSwapStartHook(_ int, rlm realm, hook func(cur realm, poolPath string, timestamp int64)) {
	m.Response.Get("SetSwapStartHook")
}

func (m *MockPool) SetTickCrossHook(_ int, rlm realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	m.Response.Get("SetTickCrossHook")
}

func (m *MockPool) CollectProtocol(
	_ int,
	rlm realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	res, ok := m.Response.Get("CollectProtocol")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockPool) SetFeeProtocol(_ int, rlm realm, feeProtocol0, feeProtocol1 uint8) {
	m.Response.Get("SetFeeProtocol")
}

// DrySwap proxies to the current pool implementation.
func (m *MockPool) DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string, error) {
	res, ok := m.Response.Get("DrySwap")
	if !ok {
		return "", "", nil
	}

	return res[0].(string), res[1].(string), res[2].(error)
}

func (m *MockPool) ExistsPoolPath(poolPath string) bool {
	res, ok := m.Response.Get("ExistsPoolPath")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPool) GetBalanceToken0(poolPath string) (int64, error) {
	res, ok := m.Response.Get("GetBalanceToken0")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetBalanceToken1(poolPath string) (int64, error) {
	res, ok := m.Response.Get("GetBalanceToken1")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetFee(poolPath string) (uint32, error) {
	res, ok := m.Response.Get("GetFee")
	if !ok {
		return 0, nil
	}

	return res[0].(uint32), nil
}

func (m *MockPool) GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error) {
	res, ok := m.Response.Get("GetFeeAmountTickSpacing")
	if !ok {
		return 0, nil
	}

	return res[0].(int32), nil
}

func (m *MockPool) GetFeeGrowthGlobal0X128(poolPath string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetFeeGrowthGlobal0X128")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockPool) GetFeeGrowthGlobal1X128(poolPath string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetFeeGrowthGlobal1X128")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint, error) {
	res, ok := m.Response.Get("GetFeeGrowthGlobalX128")
	if !ok {
		return nil, nil, nil
	}

	return res[0].(*u256.Uint), res[1].(*u256.Uint), nil
}

func (m *MockPool) GetLiquidity(poolPath string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetLiquidity")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockPool) GetMaxLiquidityPerTick(poolPath string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetMaxLiquidityPerTick")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockPool) GetPoolCreationFee() int64 {
	res, ok := m.Response.Get("GetPoolCreationFee")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockPool) GetPoolPath(token0Path, token1Path string, fee uint32) string {
	res, ok := m.Response.Get("GetPoolPath")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) (string, error) {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside0LastX128")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) (string, error) {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside1LastX128")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (string, string, error) {
	res, ok := m.Response.Get("GetPositionFeeGrowthInsideLastX128")
	if !ok {
		return "", "", nil
	}

	return res[0].(string), res[1].(string), nil
}

func (m *MockPool) GetPositionLiquidity(poolPath, key string) (string, error) {
	res, ok := m.Response.Get("GetPositionLiquidity")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetPositionTokensOwed0(poolPath, key string) (int64, error) {
	res, ok := m.Response.Get("GetPositionTokensOwed0")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetPositionTokensOwed1(poolPath, key string) (int64, error) {
	res, ok := m.Response.Get("GetPositionTokensOwed1")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetProtocolFeesToken0(poolPath string) (int64, error) {
	res, ok := m.Response.Get("GetProtocolFeesToken0")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetProtocolFeesToken1(poolPath string) (int64, error) {
	res, ok := m.Response.Get("GetProtocolFeesToken1")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetSlot0FeeProtocol(poolPath string) (uint8, error) {
	res, ok := m.Response.Get("GetSlot0FeeProtocol")
	if !ok {
		return 0, nil
	}

	return res[0].(uint8), nil
}

func (m *MockPool) GetSlot0SqrtPriceX96(poolPath string) (*u256.Uint, error) {
	res, ok := m.Response.Get("GetSlot0SqrtPriceX96")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), nil
}

func (m *MockPool) GetSlot0Tick(poolPath string) (int32, error) {
	res, ok := m.Response.Get("GetSlot0Tick")
	if !ok {
		return 0, nil
	}

	return res[0].(int32), nil
}

func (m *MockPool) GetSlot0Unlocked(poolPath string) (bool, error) {
	res, ok := m.Response.Get("GetSlot0Unlocked")
	if !ok {
		return false, nil
	}

	return res[0].(bool), nil
}

func (m *MockPool) GetSlot0(poolPath string) Slot0 {
	res, ok := m.Response.Get("GetSlot0")
	if !ok {
		return NewSlot0(u256.Zero(), 0, 0, false)
	}

	return res[0].(Slot0)
}

func (m *MockPool) GetObservationAt(poolPath string, index uint16) (Observation, error) {
	res, ok := m.Response.Get("GetObservationAt")
	if !ok {
		return Observation{}, errors.New("not found")
	}

	if len(res) < 2 || res[1] == nil {
		return res[0].(Observation), nil
	}

	return res[0].(Observation), res[1].(error)
}

func (m *MockPool) Observe(poolPath string, secondsAgos []uint32) ([]int64, []string, error) {
	res, ok := m.Response.Get("Observe")
	if !ok {
		return nil, nil, errors.New("not found")
	}

	if len(res) < 3 || res[2] == nil {
		return res[0].([]int64), res[1].([]string), nil
	}

	return res[0].([]int64), res[1].([]string), res[2].(error)
}

func (m *MockPool) SnapshotCumulativesInside(
	poolPath string,
	tickLower int32,
	tickUpper int32,
) (int64, *u256.Uint, uint32, error) {
	res, ok := m.Response.Get("SnapshotCumulativesInside")
	if !ok {
		return 0, nil, 0, errors.New("not found")
	}

	if len(res) < 4 || res[3] == nil {
		return res[0].(int64), res[1].(*u256.Uint), res[2].(uint32), nil
	}

	return res[0].(int64), res[1].(*u256.Uint), res[2].(uint32), res[3].(error)
}

func (m *MockPool) GetTickCumulativeOutside(poolPath string, tick int32) (int64, error) {
	res, ok := m.Response.Get("GetTickCumulativeOutside")
	if !ok {
		return 0, nil
	}

	return res[0].(int64), nil
}

func (m *MockPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) (string, error) {
	res, ok := m.Response.Get("GetTickFeeGrowthOutside0X128")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) (string, error) {
	res, ok := m.Response.Get("GetTickFeeGrowthOutside1X128")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (string, string, error) {
	res, ok := m.Response.Get("GetTickFeeGrowthOutsideX128")
	if !ok {
		return "", "", nil
	}

	return res[0].(string), res[1].(string), nil
}

func (m *MockPool) GetTickInitialized(poolPath string, tick int32) (bool, error) {
	res, ok := m.Response.Get("GetTickInitialized")
	if !ok {
		return false, nil
	}

	return res[0].(bool), nil
}

func (m *MockPool) GetTickLiquidityGross(poolPath string, tick int32) (string, error) {
	res, ok := m.Response.Get("GetTickLiquidityGross")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetTickLiquidityNet(poolPath string, tick int32) (string, error) {
	res, ok := m.Response.Get("GetTickLiquidityNet")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetTickSecondsOutside(poolPath string, tick int32) (uint32, error) {
	res, ok := m.Response.Get("GetTickSecondsOutside")
	if !ok {
		return 0, nil
	}

	return res[0].(uint32), nil
}

func (m *MockPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) (string, error) {
	res, ok := m.Response.Get("GetTickSecondsPerLiquidityOutsideX128")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetTickSpacing(poolPath string) (int32, error) {
	res, ok := m.Response.Get("GetTickSpacing")
	if !ok {
		return 0, nil
	}

	return res[0].(int32), nil
}

func (m *MockPool) GetToken0Path(poolPath string) (string, error) {
	res, ok := m.Response.Get("GetToken0Path")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetToken1Path(poolPath string) (string, error) {
	res, ok := m.Response.Get("GetToken1Path")
	if !ok {
		return "", nil
	}

	return res[0].(string), nil
}

func (m *MockPool) GetWithdrawalFee() uint64 {
	res, ok := m.Response.Get("GetWithdrawalFee")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockPool) OracleConsult(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	res, ok := m.Response.Get("OracleConsult")
	if !ok {
		return 0, nil, errors.New("not found")
	}

	if len(res) < 3 || res[2] == nil {
		return res[0].(int32), res[1].(*u256.Uint), nil
	}

	return res[0].(int32), res[1].(*u256.Uint), res[2].(error)
}

func (m *MockPool) GetPools() *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPools")
	if !ok {
		return nil
	}

	return res[0].(*rotree.ReadOnlyTree)
}

func (m *MockPool) GetFeeAmountTickSpacings() map[uint32]int32 {
	res, ok := m.Response.Get("GetFeeAmountTickSpacings")
	if !ok {
		return nil
	}

	return res[0].(map[uint32]int32)
}

func (m *MockPool) GetPoolPositions(poolPath string) *rotree.ReadOnlyTree {
	res, ok := m.Response.Get("GetPoolPositions")
	if !ok {
		return nil
	}

	return res[0].(*rotree.ReadOnlyTree)
}

// Tick enumeration
func (m *MockPool) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) ([]int32, error) {
	res, ok := m.Response.Get("GetInitializedTicksInRange")
	if !ok {
		return []int32{}, nil
	}

	return res[0].([]int32), nil
}

// Structure getters
func (m *MockPool) GetTickInfo(poolPath string, tick int32) (TickInfo, error) {
	res, ok := m.Response.Get("GetTickInfo")
	if !ok {
		return TickInfo{}, errors.New("not found")
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(TickInfo), nil
	}
	return res[0].(TickInfo), res[1].(error)
}

func (m *MockPool) GetTickBitmaps(poolPath string, wordPos int16) (string, error) {
	res, ok := m.Response.Get("GetTickBitmaps")
	if !ok {
		return "", errors.New("not found")
	}
	if len(res) < 2 || res[1] == nil {
		return res[0].(string), nil
	}
	return res[0].(string), res[1].(error)
}

func newMockPool(version string) *MockPool {
	return &MockPool{
		Version:  version,
		Response: NewMockResponse(),
	}
}
