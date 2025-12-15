// Simplified test implementation for pool contract upgrade testing
package v3_valid

import (
	u256 "gno.land/p/gnoswap/uint256"
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

func NewV3ValidPool(store pool.IPoolStore) pool.IPool {
	return &TestPool{
		instance: v1.NewPoolV1(store),
	}
}

func init() {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		return NewV3ValidPool(store)
	})
}

// TestPool is a minimal test implementation that delegates to v1
type TestPool struct {
	instance pool.IPool
}

// IPoolManager interface
func (t *TestPool) CreatePool(token0Path string, token1Path string, fee uint32, sqrtPriceX96 string) {
	t.instance.CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}

func (t *TestPool) SetPoolCreationFee(fee int64) {
	t.instance.SetPoolCreationFee(fee)
}

func (t *TestPool) IncreaseObservationCardinalityLimit(token0Path string, token1Path string, fee uint32, cardinalityNext uint16) {
	t.instance.IncreaseObservationCardinalityLimit(token0Path, token1Path, fee, cardinalityNext)
}

// IPoolPosition interface
func (t *TestPool) Mint(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	return t.instance.Mint(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func (t *TestPool) Burn(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	return t.instance.Burn(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func (t *TestPool) Collect(token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string) {
	return t.instance.Collect(token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func (t *TestPool) SetWithdrawalFee(fee uint64) {
	t.instance.SetWithdrawalFee(fee)
}

func (t *TestPool) HandleWithdrawalFee(positionId uint64, token0Path string, amount0 string, token1Path string, amount1 string, poolPath string, positionCaller address) (string, string) {
	return t.instance.HandleWithdrawalFee(positionId, token0Path, amount0, token1Path, amount1, poolPath, positionCaller)
}

// IPoolSwap interface
func (t *TestPool) Swap(token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error) (string, string) {
	return t.instance.Swap(token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, payer, swapCallback)
}

func (t *TestPool) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	t.instance.SetSwapEndHook(hook)
}

func (t *TestPool) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	t.instance.SetSwapStartHook(hook)
}

func (t *TestPool) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	t.instance.SetTickCrossHook(hook)
}

func (t *TestPool) CollectProtocol(token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string) {
	return t.instance.CollectProtocol(token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
}

func (t *TestPool) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	t.instance.SetFeeProtocol(feeProtocol0, feeProtocol1)
}

// IPoolGetter interface
func (t *TestPool) DrySwap(token0Path string, token1Path string, fee uint32, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string) (string, string, bool) {
	return t.instance.DrySwap(token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

func (t *TestPool) ExistsPoolPath(poolPath string) bool {
	return t.instance.ExistsPoolPath(poolPath)
}

func (t *TestPool) GetPool(token0Path, token1Path string, fee uint32) *pool.Pool {
	return t.instance.GetPool(token0Path, token1Path, fee)
}

func (t *TestPool) GetBalanceToken0(poolPath string) string {
	return t.instance.GetBalanceToken0(poolPath)
}

func (t *TestPool) GetBalanceToken1(poolPath string) string {
	return t.instance.GetBalanceToken1(poolPath)
}

func (t *TestPool) GetFee(poolPath string) uint32 {
	return t.instance.GetFee(poolPath)
}

func (t *TestPool) GetFeeAmountTickSpacing(fee uint32) int32 {
	return t.instance.GetFeeAmountTickSpacing(fee)
}

func (t *TestPool) GetFeeGrowthGlobal0X128(poolPath string) string {
	return t.instance.GetFeeGrowthGlobal0X128(poolPath)
}

func (t *TestPool) GetFeeGrowthGlobal1X128(poolPath string) string {
	return t.instance.GetFeeGrowthGlobal1X128(poolPath)
}

func (t *TestPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return t.instance.GetFeeGrowthGlobalX128(poolPath)
}

func (t *TestPool) GetLiquidity(poolPath string) string {
	return t.instance.GetLiquidity(poolPath)
}

func (t *TestPool) GetMaxLiquidityPerTick(poolPath string) string {
	return t.instance.GetMaxLiquidityPerTick(poolPath)
}

func (t *TestPool) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	return t.instance.GetObservation(poolPath, secondsAgo)
}

func (t *TestPool) GetPoolCreationFee() int64 {
	return t.instance.GetPoolCreationFee()
}

func (t *TestPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return t.instance.GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

func (t *TestPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return t.instance.GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

func (t *TestPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return t.instance.GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

func (t *TestPool) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return t.instance.GetPositionLiquidity(poolPath, key)
}

func (t *TestPool) GetPositionTokensOwed0(poolPath, key string) string {
	return t.instance.GetPositionTokensOwed0(poolPath, key)
}

func (t *TestPool) GetPositionTokensOwed1(poolPath, key string) string {
	return t.instance.GetPositionTokensOwed1(poolPath, key)
}

func (t *TestPool) GetProtocolFeesToken0(poolPath string) string {
	return t.instance.GetProtocolFeesToken0(poolPath)
}

func (t *TestPool) GetProtocolFeesToken1(poolPath string) string {
	return t.instance.GetProtocolFeesToken1(poolPath)
}

func (t *TestPool) GetSlot0FeeProtocol(poolPath string) uint8 {
	return t.instance.GetSlot0FeeProtocol(poolPath)
}

func (t *TestPool) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return t.instance.GetSlot0SqrtPriceX96(poolPath)
}

func (t *TestPool) GetSlot0Tick(poolPath string) int32 {
	return t.instance.GetSlot0Tick(poolPath)
}

func (t *TestPool) GetSlot0Unlocked(poolPath string) bool {
	return t.instance.GetSlot0Unlocked(poolPath)
}

func (t *TestPool) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return t.instance.GetTickCumulativeOutside(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return t.instance.GetTickFeeGrowthOutside0X128(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return t.instance.GetTickFeeGrowthOutside1X128(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	return t.instance.GetTickFeeGrowthOutsideX128(poolPath, tick)
}

func (t *TestPool) GetTickInitialized(poolPath string, tick int32) bool {
	return t.instance.GetTickInitialized(poolPath, tick)
}

func (t *TestPool) GetTickLiquidityGross(poolPath string, tick int32) string {
	return t.instance.GetTickLiquidityGross(poolPath, tick)
}

func (t *TestPool) GetTickLiquidityNet(poolPath string, tick int32) string {
	return t.instance.GetTickLiquidityNet(poolPath, tick)
}

func (t *TestPool) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return t.instance.GetTickSecondsOutside(poolPath, tick)
}

func (t *TestPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return t.instance.GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

func (t *TestPool) GetTickSpacing(poolPath string) int32 {
	return t.instance.GetTickSpacing(poolPath)
}

func (t *TestPool) GetToken0Path(poolPath string) string {
	return t.instance.GetToken0Path(poolPath)
}

func (t *TestPool) GetToken1Path(poolPath string) string {
	return t.instance.GetToken1Path(poolPath)
}

func (t *TestPool) GetWithdrawalFee() uint64 {
	return t.instance.GetWithdrawalFee()
}

func (t *TestPool) ApiGetPool(poolPath string) string {
	return t.instance.ApiGetPool(poolPath)
}

func (t *TestPool) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return t.instance.ApiGetTWAP(poolPath, secondsAgo)
}
