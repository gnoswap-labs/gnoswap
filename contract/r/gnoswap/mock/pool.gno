package mock

import (
	u256 "gno.land/p/gnoswap/uint256"
)

type MockPool struct {
	Version  string
	Response *MockResponse
}

func (m *MockPool) CreatePool(
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	m.Response.Get("CreatePool")
}

// SetPoolCreationFee sets the pool creation fee.
func (m *MockPool) SetPoolCreationFee(fee int64) {
	m.Response.Get("SetPoolCreationFee")
}

func (m *MockPool) IncreaseObservationCardinalityLimit(
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	m.Response.Get("IncreaseObservationCardinalityLimit")
}

func (m *MockPool) Mint(
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

func (m *MockPool) SetWithdrawalFee(fee uint64) {
	m.Response.Get("SetWithdrawalFee")
}

func (m *MockPool) HandleWithdrawalFee(
	positionId uint64,
	token0Path string,
	amount0 string,
	token1Path string,
	amount1 string,
	poolPath string,
	positionCaller address,
) (string, string) {
	res, ok := m.Response.Get("HandleWithdrawalFee")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockPool) Swap(
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer address,
	swapCallback func(cur realm, amount0Delta, amount1Delta string) error,
) (string, string) {
	res, ok := m.Response.Get("Swap")
	if !ok {
		return "", ""
	}

	return res[0].(string), res[1].(string)
}

func (m *MockPool) SetSwapEndHook(hook func(poolPath string) error) {
	m.Response.Get("SetSwapEndHook")
}

func (m *MockPool) SetSwapStartHook(hook func(poolPath string, timestamp int64)) {
	m.Response.Get("SetSwapStartHook")
}

func (m *MockPool) SetTickCrossHook(hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	m.Response.Get("SetTickCrossHook")
}

func (m *MockPool) CollectProtocol(
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

func (m *MockPool) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
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
) (string, string, bool) {
	res, ok := m.Response.Get("DrySwap")
	if !ok {
		return "", "", false
	}

	return res[0].(string), res[1].(string), res[2].(bool)
}

func (m *MockPool) ExistsPoolPath(poolPath string) bool {
	res, ok := m.Response.Get("ExistsPoolPath")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPool) GetBalanceToken0(poolPath string) string {
	res, ok := m.Response.Get("GetBalanceToken0")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetBalanceToken1(poolPath string) string {
	res, ok := m.Response.Get("GetBalanceToken1")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetFee(poolPath string) uint32 {
	res, ok := m.Response.Get("GetFee")
	if !ok {
		return 0
	}

	return res[0].(uint32)
}

func (m *MockPool) GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	res, ok := m.Response.Get("GetFeeAmountTickSpacing")
	if !ok {
		return 0
	}

	return res[0].(int32)
}

func (m *MockPool) GetFeeGrowthGlobal0X128(poolPath string) string {
	res, ok := m.Response.Get("GetFeeGrowthGlobal0X128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetFeeGrowthGlobal1X128(poolPath string) string {
	res, ok := m.Response.Get("GetFeeGrowthGlobal1X128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	res, ok := m.Response.Get("GetFeeGrowthGlobalX128")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), res[1].(*u256.Uint)
}

func (m *MockPool) GetLiquidity(poolPath string) string {
	res, ok := m.Response.Get("GetLiquidity")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetMaxLiquidityPerTick(poolPath string) string {
	res, ok := m.Response.Get("GetMaxLiquidityPerTick")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64) {
	res, ok := m.Response.Get("GetObservation")
	if !ok {
		return 0, "", "", 0
	}

	return res[0].(int64), res[1].(string), res[2].(string), res[3].(int64)
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

func (m *MockPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside0LastX128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	res, ok := m.Response.Get("GetPositionFeeGrowthInside1LastX128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	res, ok := m.Response.Get("GetPositionFeeGrowthInsideLastX128")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), res[1].(*u256.Uint)
}

func (m *MockPool) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	res, ok := m.Response.Get("GetPositionLiquidity")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPool) GetPositionTokensOwed0(poolPath, key string) string {
	res, ok := m.Response.Get("GetPositionTokensOwed0")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetPositionTokensOwed1(poolPath, key string) string {
	res, ok := m.Response.Get("GetPositionTokensOwed1")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetProtocolFeesToken0(poolPath string) string {
	res, ok := m.Response.Get("GetProtocolFeesToken0")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetProtocolFeesToken1(poolPath string) string {
	res, ok := m.Response.Get("GetProtocolFeesToken1")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetSlot0FeeProtocol(poolPath string) uint8 {
	res, ok := m.Response.Get("GetSlot0FeeProtocol")
	if !ok {
		return 0
	}

	return res[0].(uint8)
}

func (m *MockPool) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	res, ok := m.Response.Get("GetSlot0SqrtPriceX96")
	if !ok {
		return nil
	}

	return res[0].(*u256.Uint)
}

func (m *MockPool) GetSlot0Tick(poolPath string) int32 {
	res, ok := m.Response.Get("GetSlot0Tick")
	if !ok {
		return 0
	}

	return res[0].(int32)
}

func (m *MockPool) GetSlot0Unlocked(poolPath string) bool {
	res, ok := m.Response.Get("GetSlot0Unlocked")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPool) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	res, ok := m.Response.Get("GetTickCumulativeOutside")
	if !ok {
		return 0
	}

	return res[0].(int64)
}

func (m *MockPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	res, ok := m.Response.Get("GetTickFeeGrowthOutside0X128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	res, ok := m.Response.Get("GetTickFeeGrowthOutside1X128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	res, ok := m.Response.Get("GetTickFeeGrowthOutsideX128")
	if !ok {
		return nil, nil
	}

	return res[0].(*u256.Uint), res[1].(*u256.Uint)
}

func (m *MockPool) GetTickInitialized(poolPath string, tick int32) bool {
	res, ok := m.Response.Get("GetTickInitialized")
	if !ok {
		return false
	}

	return res[0].(bool)
}

func (m *MockPool) GetTickLiquidityGross(poolPath string, tick int32) string {
	res, ok := m.Response.Get("GetTickLiquidityGross")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetTickLiquidityNet(poolPath string, tick int32) string {
	res, ok := m.Response.Get("GetTickLiquidityNet")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	res, ok := m.Response.Get("GetTickSecondsOutside")
	if !ok {
		return 0
	}

	return res[0].(uint32)
}

func (m *MockPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	res, ok := m.Response.Get("GetTickSecondsPerLiquidityOutsideX128")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetTickSpacing(poolPath string) int32 {
	res, ok := m.Response.Get("GetTickSpacing")
	if !ok {
		return 0
	}

	return res[0].(int32)
}

func (m *MockPool) GetToken0Path(poolPath string) string {
	res, ok := m.Response.Get("GetToken0Path")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetToken1Path(poolPath string) string {
	res, ok := m.Response.Get("GetToken1Path")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) GetWithdrawalFee() uint64 {
	res, ok := m.Response.Get("GetWithdrawalFee")
	if !ok {
		return 0
	}

	return res[0].(uint64)
}

func (m *MockPool) ApiGetPool(poolPath string) string {
	res, ok := m.Response.Get("ApiGetPool")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func (m *MockPool) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	res, ok := m.Response.Get("ApiGetTWAP")
	if !ok {
		return ""
	}

	return res[0].(string)
}

func NewMockPool(version string) *MockPool {
	return &MockPool{
		Version:  version,
		Response: NewMockResponse(),
	}
}
