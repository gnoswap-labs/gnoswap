// Simplified test implementation for pool contract upgrade testing
package v2_invalid

import (
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/pool"
)

func init() {
	pool.RegisterInitializer(cross, func(store pool.IPoolStore) pool.IPool {
		return &TestPool{}
	})
}

// TestPool is a minimal test implementation that panics on all methods
type TestPool struct{}

// IPoolManager interface
func (t *TestPool) CreatePool(token0Path string, token1Path string, fee uint32, sqrtPriceX96 string) {
	panic("test implementation: CreatePool not supported")
}

func (t *TestPool) SetPoolCreationFee(fee int64) {
	panic("test implementation: SetPoolCreationFee not supported")
}

func (t *TestPool) IncreaseObservationCardinalityLimit(token0Path string, token1Path string, fee uint32, cardinalityNext uint16) {
	panic("test implementation: IncreaseObservationCardinalityLimit not supported")
}

// IPoolPosition interface
func (t *TestPool) Mint(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	panic("test implementation: Mint not supported")
}

func (t *TestPool) Burn(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	panic("test implementation: Burn not supported")
}

func (t *TestPool) Collect(token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string) {
	panic("test implementation: Collect not supported")
}

func (t *TestPool) SetWithdrawalFee(fee uint64) {
	panic("test implementation: SetWithdrawalFee not supported")
}

func (t *TestPool) HandleWithdrawalFee(positionId uint64, token0Path string, amount0 string, token1Path string, amount1 string, poolPath string, positionCaller address) (string, string) {
	panic("test implementation: HandleWithdrawalFee not supported")
}

// IPoolSwap interface
func (t *TestPool) Swap(token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(cur realm, amount0Delta, amount1Delta string) error) (string, string) {
	panic("test implementation: Swap not supported")
}

func (t *TestPool) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	panic("test implementation: SetSwapEndHook not supported")
}

func (t *TestPool) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	panic("test implementation: SetSwapStartHook not supported")
}

func (t *TestPool) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	panic("test implementation: SetTickCrossHook not supported")
}

func (t *TestPool) CollectProtocol(token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string) {
	panic("test implementation: CollectProtocol not supported")
}

func (t *TestPool) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	panic("test implementation: SetFeeProtocol not supported")
}

// IPoolGetter interface
func (t *TestPool) DrySwap(token0Path string, token1Path string, fee uint32, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string) (string, string, bool) {
	panic("test implementation: DrySwap not supported")
}

func (t *TestPool) ExistsPoolPath(poolPath string) bool {
	panic("test implementation: ExistsPoolPath not supported")
}

func (t *TestPool) GetPool(token0Path, token1Path string, fee uint32) *pool.Pool {
	panic("test implementation: GetPool not supported")
}

func (t *TestPool) GetBalanceToken0(poolPath string) string {
	panic("test implementation: GetBalanceToken0 not supported")
}

func (t *TestPool) GetBalanceToken1(poolPath string) string {
	panic("test implementation: GetBalanceToken1 not supported")
}

func (t *TestPool) GetFee(poolPath string) uint32 {
	panic("test implementation: GetFee not supported")
}

func (t *TestPool) GetFeeAmountTickSpacing(fee uint32) int32 {
	panic("test implementation: GetFeeAmountTickSpacing not supported")
}

func (t *TestPool) GetFeeGrowthGlobal0X128(poolPath string) string {
	panic("test implementation: GetFeeGrowthGlobal0X128 not supported")
}

func (t *TestPool) GetFeeGrowthGlobal1X128(poolPath string) string {
	panic("test implementation: GetFeeGrowthGlobal1X128 not supported")
}

func (t *TestPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	panic("test implementation: GetFeeGrowthGlobalX128 not supported")
}

func (t *TestPool) GetLiquidity(poolPath string) string {
	panic("test implementation: GetLiquidity not supported")
}

func (t *TestPool) GetMaxLiquidityPerTick(poolPath string) string {
	panic("test implementation: GetMaxLiquidityPerTick not supported")
}

func (t *TestPool) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	panic("test implementation: GetObservation not supported")
}

func (t *TestPool) GetPoolCreationFee() int64 {
	panic("test implementation: GetPoolCreationFee not supported")
}

func (t *TestPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	panic("test implementation: GetPositionFeeGrowthInside0LastX128 not supported")
}

func (t *TestPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	panic("test implementation: GetPositionFeeGrowthInside1LastX128 not supported")
}

func (t *TestPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	panic("test implementation: GetPositionFeeGrowthInsideLastX128 not supported")
}

func (t *TestPool) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	panic("test implementation: GetPositionLiquidity not supported")
}

func (t *TestPool) GetPositionTokensOwed0(poolPath, key string) string {
	panic("test implementation: GetPositionTokensOwed0 not supported")
}

func (t *TestPool) GetPositionTokensOwed1(poolPath, key string) string {
	panic("test implementation: GetPositionTokensOwed1 not supported")
}

func (t *TestPool) GetProtocolFeesToken0(poolPath string) string {
	panic("test implementation: GetProtocolFeesToken0 not supported")
}

func (t *TestPool) GetProtocolFeesToken1(poolPath string) string {
	panic("test implementation: GetProtocolFeesToken1 not supported")
}

func (t *TestPool) GetSlot0FeeProtocol(poolPath string) uint8 {
	panic("test implementation: GetSlot0FeeProtocol not supported")
}

func (t *TestPool) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	panic("test implementation: GetSlot0SqrtPriceX96 not supported")
}

func (t *TestPool) GetSlot0Tick(poolPath string) int32 {
	panic("test implementation: GetSlot0Tick not supported")
}

func (t *TestPool) GetSlot0Unlocked(poolPath string) bool {
	panic("test implementation: GetSlot0Unlocked not supported")
}

func (t *TestPool) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	panic("test implementation: GetTickCumulativeOutside not supported")
}

func (t *TestPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	panic("test implementation: GetTickFeeGrowthOutside0X128 not supported")
}

func (t *TestPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	panic("test implementation: GetTickFeeGrowthOutside1X128 not supported")
}

func (t *TestPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	panic("test implementation: GetTickFeeGrowthOutsideX128 not supported")
}

func (t *TestPool) GetTickInitialized(poolPath string, tick int32) bool {
	panic("test implementation: GetTickInitialized not supported")
}

func (t *TestPool) GetTickLiquidityGross(poolPath string, tick int32) string {
	panic("test implementation: GetTickLiquidityGross not supported")
}

func (t *TestPool) GetTickLiquidityNet(poolPath string, tick int32) string {
	panic("test implementation: GetTickLiquidityNet not supported")
}

func (t *TestPool) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	panic("test implementation: GetTickSecondsOutside not supported")
}

func (t *TestPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	panic("test implementation: GetTickSecondsPerLiquidityOutsideX128 not supported")
}

func (t *TestPool) GetTickSpacing(poolPath string) int32 {
	panic("test implementation: GetTickSpacing not supported")
}

func (t *TestPool) GetToken0Path(poolPath string) string {
	panic("test implementation: GetToken0Path not supported")
}

func (t *TestPool) GetToken1Path(poolPath string) string {
	panic("test implementation: GetToken1Path not supported")
}

func (t *TestPool) GetWithdrawalFee() uint64 {
	panic("test implementation: GetWithdrawalFee not supported")
}

func (t *TestPool) ApiGetPool(poolPath string) string {
	panic("test implementation: ApiGetPool not supported")
}

func (t *TestPool) ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	panic("test implementation: ApiGetTWAP not supported")
}
