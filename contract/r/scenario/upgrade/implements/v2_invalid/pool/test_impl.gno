// Simplified test implementation for pool contract upgrade testing
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

func NewV2InvalidPool(store pool.IPoolStore) pool.IPool {
	instance := v1.NewPoolV1(store)

	return &TestPool{
		instance:      instance,
		activeMethods: make(map[string]bool),
	}
}

func init() {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		return NewV2InvalidPool(store)
	})
}

// TestPool is a minimal test implementation that delegates to v1 only when method is activated
type TestPool struct {
	instance      pool.IPool
	activeMethods map[string]bool
}

func (t *TestPool) SetActiveMethod(fnName string, activated bool) {
	t.activeMethods[fnName] = activated
}

func (t *TestPool) isActive(fnName string) bool {
	active, ok := t.activeMethods[fnName]
	return ok && active
}

// IPoolManager interface
func (t *TestPool) CreatePool(token0Path string, token1Path string, fee uint32, sqrtPriceX96 string) {
	if !t.isActive("CreatePool") {
		panic("test implementation: CreatePool not supported")
	}
	t.instance.CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}

func (t *TestPool) SetPoolCreationFee(fee int64) {
	if !t.isActive("SetPoolCreationFee") {
		panic("test implementation: SetPoolCreationFee not supported")
	}
	t.instance.SetPoolCreationFee(fee)
}

func (t *TestPool) IncreaseObservationCardinalityLimit(token0Path string, token1Path string, fee uint32, cardinalityNext uint16) {
	if !t.isActive("IncreaseObservationCardinalityLimit") {
		panic("test implementation: IncreaseObservationCardinalityLimit not supported")
	}
	t.instance.IncreaseObservationCardinalityLimit(token0Path, token1Path, fee, cardinalityNext)
}

// IPoolPosition interface
func (t *TestPool) Mint(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	if !t.isActive("Mint") {
		panic("test implementation: Mint not supported")
	}
	return t.instance.Mint(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func (t *TestPool) Burn(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	if !t.isActive("Burn") {
		panic("test implementation: Burn not supported")
	}
	return t.instance.Burn(token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller)
}

func (t *TestPool) Collect(token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string) {
	if !t.isActive("Collect") {
		panic("test implementation: Collect not supported")
	}
	return t.instance.Collect(token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested)
}

func (t *TestPool) SetWithdrawalFee(fee uint64) {
	if !t.isActive("SetWithdrawalFee") {
		panic("test implementation: SetWithdrawalFee not supported")
	}
	t.instance.SetWithdrawalFee(fee)
}

func (t *TestPool) HandleWithdrawalFee(positionId uint64, token0Path string, amount0 string, token1Path string, amount1 string, poolPath string, positionCaller address) (string, string) {
	if !t.isActive("HandleWithdrawalFee") {
		panic("test implementation: HandleWithdrawalFee not supported")
	}
	return t.instance.HandleWithdrawalFee(positionId, token0Path, amount0, token1Path, amount1, poolPath, positionCaller)
}

// IPoolSwap interface
func (t *TestPool) Swap(token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error) (string, string) {
	if !t.isActive("Swap") {
		panic("test implementation: Swap not supported")
	}
	return t.instance.Swap(token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, payer, swapCallback)
}

func (t *TestPool) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	if !t.isActive("SetSwapEndHook") {
		panic("test implementation: SetSwapEndHook not supported")
	}
	t.instance.SetSwapEndHook(hook)
}

func (t *TestPool) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	if !t.isActive("SetSwapStartHook") {
		panic("test implementation: SetSwapStartHook not supported")
	}
	t.instance.SetSwapStartHook(hook)
}

func (t *TestPool) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	if !t.isActive("SetTickCrossHook") {
		panic("test implementation: SetTickCrossHook not supported")
	}
	t.instance.SetTickCrossHook(hook)
}

func (t *TestPool) CollectProtocol(token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string) {
	if !t.isActive("CollectProtocol") {
		panic("test implementation: CollectProtocol not supported")
	}
	return t.instance.CollectProtocol(token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested)
}

func (t *TestPool) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	if !t.isActive("SetFeeProtocol") {
		panic("test implementation: SetFeeProtocol not supported")
	}
	t.instance.SetFeeProtocol(feeProtocol0, feeProtocol1)
}

// IPoolGetter interface
func (t *TestPool) DrySwap(token0Path string, token1Path string, fee uint32, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string) (string, string, bool) {
	if !t.isActive("DrySwap") {
		panic("test implementation: DrySwap not supported")
	}
	return t.instance.DrySwap(token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

func (t *TestPool) ExistsPoolPath(poolPath string) bool {
	if !t.isActive("ExistsPoolPath") {
		panic("test implementation: ExistsPoolPath not supported")
	}
	return t.instance.ExistsPoolPath(poolPath)
}

func (t *TestPool) GetPool(token0Path, token1Path string, fee uint32) (*pool.Pool, error) {
	if !t.isActive("GetPool") {
		panic("test implementation: GetPool not supported")
	}
	return t.instance.GetPool(token0Path, token1Path, fee)
}

func (t *TestPool) GetBalanceToken0(poolPath string) string {
	if !t.isActive("GetBalanceToken0") {
		panic("test implementation: GetBalanceToken0 not supported")
	}
	return t.instance.GetBalanceToken0(poolPath)
}

func (t *TestPool) GetBalanceToken1(poolPath string) string {
	if !t.isActive("GetBalanceToken1") {
		panic("test implementation: GetBalanceToken1 not supported")
	}
	return t.instance.GetBalanceToken1(poolPath)
}

func (t *TestPool) GetFee(poolPath string) uint32 {
	if !t.isActive("GetFee") {
		panic("test implementation: GetFee not supported")
	}
	return t.instance.GetFee(poolPath)
}

func (t *TestPool) GetFeeAmountTickSpacing(fee uint32) int32 {
	if !t.isActive("GetFeeAmountTickSpacing") {
		panic("test implementation: GetFeeAmountTickSpacing not supported")
	}
	return t.instance.GetFeeAmountTickSpacing(fee)
}

func (t *TestPool) GetFeeGrowthGlobal0X128(poolPath string) string {
	if !t.isActive("GetFeeGrowthGlobal0X128") {
		panic("test implementation: GetFeeGrowthGlobal0X128 not supported")
	}
	return t.instance.GetFeeGrowthGlobal0X128(poolPath)
}

func (t *TestPool) GetFeeGrowthGlobal1X128(poolPath string) string {
	if !t.isActive("GetFeeGrowthGlobal1X128") {
		panic("test implementation: GetFeeGrowthGlobal1X128 not supported")
	}
	return t.instance.GetFeeGrowthGlobal1X128(poolPath)
}

func (t *TestPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	if !t.isActive("GetFeeGrowthGlobalX128") {
		panic("test implementation: GetFeeGrowthGlobalX128 not supported")
	}
	return t.instance.GetFeeGrowthGlobalX128(poolPath)
}

func (t *TestPool) GetLiquidity(poolPath string) string {
	if !t.isActive("GetLiquidity") {
		panic("test implementation: GetLiquidity not supported")
	}
	return t.instance.GetLiquidity(poolPath)
}

func (t *TestPool) GetMaxLiquidityPerTick(poolPath string) string {
	if !t.isActive("GetMaxLiquidityPerTick") {
		panic("test implementation: GetMaxLiquidityPerTick not supported")
	}
	return t.instance.GetMaxLiquidityPerTick(poolPath)
}

func (t *TestPool) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	if !t.isActive("GetObservation") {
		panic("test implementation: GetObservation not supported")
	}
	return t.instance.GetObservation(poolPath, secondsAgo)
}

func (t *TestPool) GetPoolCreationFee() int64 {
	if !t.isActive("GetPoolCreationFee") {
		panic("test implementation: GetPoolCreationFee not supported")
	}
	return t.instance.GetPoolCreationFee()
}

func (t *TestPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	if !t.isActive("GetPositionFeeGrowthInside0LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside0LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

func (t *TestPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	if !t.isActive("GetPositionFeeGrowthInside1LastX128") {
		panic("test implementation: GetPositionFeeGrowthInside1LastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

func (t *TestPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	if !t.isActive("GetPositionFeeGrowthInsideLastX128") {
		panic("test implementation: GetPositionFeeGrowthInsideLastX128 not supported")
	}
	return t.instance.GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

func (t *TestPool) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	if !t.isActive("GetPositionLiquidity") {
		panic("test implementation: GetPositionLiquidity not supported")
	}
	return t.instance.GetPositionLiquidity(poolPath, key)
}

func (t *TestPool) GetPositionTokensOwed0(poolPath, key string) string {
	if !t.isActive("GetPositionTokensOwed0") {
		panic("test implementation: GetPositionTokensOwed0 not supported")
	}
	return t.instance.GetPositionTokensOwed0(poolPath, key)
}

func (t *TestPool) GetPositionTokensOwed1(poolPath, key string) string {
	if !t.isActive("GetPositionTokensOwed1") {
		panic("test implementation: GetPositionTokensOwed1 not supported")
	}
	return t.instance.GetPositionTokensOwed1(poolPath, key)
}

func (t *TestPool) GetProtocolFeesToken0(poolPath string) string {
	if !t.isActive("GetProtocolFeesToken0") {
		panic("test implementation: GetProtocolFeesToken0 not supported")
	}
	return t.instance.GetProtocolFeesToken0(poolPath)
}

func (t *TestPool) GetProtocolFeesToken1(poolPath string) string {
	if !t.isActive("GetProtocolFeesToken1") {
		panic("test implementation: GetProtocolFeesToken1 not supported")
	}
	return t.instance.GetProtocolFeesToken1(poolPath)
}

func (t *TestPool) GetSlot0FeeProtocol(poolPath string) uint8 {
	if !t.isActive("GetSlot0FeeProtocol") {
		panic("test implementation: GetSlot0FeeProtocol not supported")
	}
	return t.instance.GetSlot0FeeProtocol(poolPath)
}

func (t *TestPool) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	if !t.isActive("GetSlot0SqrtPriceX96") {
		panic("test implementation: GetSlot0SqrtPriceX96 not supported")
	}
	return t.instance.GetSlot0SqrtPriceX96(poolPath)
}

func (t *TestPool) GetSlot0Tick(poolPath string) int32 {
	if !t.isActive("GetSlot0Tick") {
		panic("test implementation: GetSlot0Tick not supported")
	}
	return t.instance.GetSlot0Tick(poolPath)
}

func (t *TestPool) GetSlot0Unlocked(poolPath string) bool {
	if !t.isActive("GetSlot0Unlocked") {
		panic("test implementation: GetSlot0Unlocked not supported")
	}
	return t.instance.GetSlot0Unlocked(poolPath)
}

func (t *TestPool) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	if !t.isActive("GetTickCumulativeOutside") {
		panic("test implementation: GetTickCumulativeOutside not supported")
	}
	return t.instance.GetTickCumulativeOutside(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	if !t.isActive("GetTickFeeGrowthOutside0X128") {
		panic("test implementation: GetTickFeeGrowthOutside0X128 not supported")
	}
	return t.instance.GetTickFeeGrowthOutside0X128(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	if !t.isActive("GetTickFeeGrowthOutside1X128") {
		panic("test implementation: GetTickFeeGrowthOutside1X128 not supported")
	}
	return t.instance.GetTickFeeGrowthOutside1X128(poolPath, tick)
}

func (t *TestPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	if !t.isActive("GetTickFeeGrowthOutsideX128") {
		panic("test implementation: GetTickFeeGrowthOutsideX128 not supported")
	}
	return t.instance.GetTickFeeGrowthOutsideX128(poolPath, tick)
}

func (t *TestPool) GetTickInitialized(poolPath string, tick int32) bool {
	if !t.isActive("GetTickInitialized") {
		panic("test implementation: GetTickInitialized not supported")
	}
	return t.instance.GetTickInitialized(poolPath, tick)
}

func (t *TestPool) GetTickLiquidityGross(poolPath string, tick int32) string {
	if !t.isActive("GetTickLiquidityGross") {
		panic("test implementation: GetTickLiquidityGross not supported")
	}
	return t.instance.GetTickLiquidityGross(poolPath, tick)
}

func (t *TestPool) GetTickLiquidityNet(poolPath string, tick int32) string {
	if !t.isActive("GetTickLiquidityNet") {
		panic("test implementation: GetTickLiquidityNet not supported")
	}
	return t.instance.GetTickLiquidityNet(poolPath, tick)
}

func (t *TestPool) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	if !t.isActive("GetTickSecondsOutside") {
		panic("test implementation: GetTickSecondsOutside not supported")
	}
	return t.instance.GetTickSecondsOutside(poolPath, tick)
}

func (t *TestPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	if !t.isActive("GetTickSecondsPerLiquidityOutsideX128") {
		panic("test implementation: GetTickSecondsPerLiquidityOutsideX128 not supported")
	}
	return t.instance.GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

func (t *TestPool) GetTickSpacing(poolPath string) int32 {
	if !t.isActive("GetTickSpacing") {
		panic("test implementation: GetTickSpacing not supported")
	}
	return t.instance.GetTickSpacing(poolPath)
}

func (t *TestPool) GetToken0Path(poolPath string) string {
	if !t.isActive("GetToken0Path") {
		panic("test implementation: GetToken0Path not supported")
	}
	return t.instance.GetToken0Path(poolPath)
}

func (t *TestPool) GetToken1Path(poolPath string) string {
	if !t.isActive("GetToken1Path") {
		panic("test implementation: GetToken1Path not supported")
	}
	return t.instance.GetToken1Path(poolPath)
}

func (t *TestPool) GetWithdrawalFee() uint64 {
	if !t.isActive("GetWithdrawalFee") {
		panic("test implementation: GetWithdrawalFee not supported")
	}
	return t.instance.GetWithdrawalFee()
}

func (t *TestPool) GetTWAP(poolPath string, secondsAgo uint32) (int32, error) {
	if !t.isActive("GetTWAP") {
		panic("test implementation: GetTWAP not supported")
	}
	return t.instance.GetTWAP(poolPath, secondsAgo)
}

// Pool enumeration
func (t *TestPool) GetPoolCount() int {
	if !t.isActive("GetPoolCount") {
		panic("test implementation: GetPoolCount not supported")
	}
	return t.instance.GetPoolCount()
}

func (t *TestPool) GetPoolPaths(offset, count int) []string {
	if !t.isActive("GetPoolPaths") {
		panic("test implementation: GetPoolPaths not supported")
	}
	return t.instance.GetPoolPaths(offset, count)
}

func (t *TestPool) GetFeeAmountTickSpacings() map[uint32]int32 {
	if !t.isActive("GetFeeAmountTickSpacings") {
		panic("test implementation: GetFeeAmountTickSpacings not supported")
	}
	return t.instance.GetFeeAmountTickSpacings()
}

// Position enumeration
func (t *TestPool) GetPoolPositionCount(poolPath string) int {
	if !t.isActive("GetPoolPositionCount") {
		panic("test implementation: GetPoolPositionCount not supported")
	}
	return t.instance.GetPoolPositionCount(poolPath)
}

func (t *TestPool) GetPoolPositionKeys(poolPath string, offset, count int) []string {
	if !t.isActive("GetPoolPositionKeys") {
		panic("test implementation: GetPoolPositionKeys not supported")
	}
	return t.instance.GetPoolPositionKeys(poolPath, offset, count)
}

// Tick enumeration
func (t *TestPool) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32 {
	if !t.isActive("GetInitializedTicksInRange") {
		panic("test implementation: GetInitializedTicksInRange not supported")
	}
	return t.instance.GetInitializedTicksInRange(poolPath, tickLower, tickUpper)
}

// Structure getters
func (t *TestPool) GetTickInfo(poolPath string, tick int32) (pool.TickInfo, error) {
	if !t.isActive("GetTickInfo") {
		panic("test implementation: GetTickInfo not supported")
	}
	return t.instance.GetTickInfo(poolPath, tick)
}

func (t *TestPool) GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error) {
	if !t.isActive("GetTickBitmaps") {
		panic("test implementation: GetTickBitmaps not supported")
	}
	return t.instance.GetTickBitmaps(poolPath, wordPos)
}

func (t *TestPool) GetPosition(poolPath, key string) (pool.PositionInfo, error) {
	if !t.isActive("GetPosition") {
		panic("test implementation: GetPosition not supported")
	}
	return t.instance.GetPosition(poolPath, key)
}

func (t *TestPool) GetObservationState(poolPath string) (*pool.ObservationState, error) {
	if !t.isActive("GetObservationState") {
		panic("test implementation: GetObservationState not supported")
	}
	return t.instance.GetObservationState(poolPath)
}
