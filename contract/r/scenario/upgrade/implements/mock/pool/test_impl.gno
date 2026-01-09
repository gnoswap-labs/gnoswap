// Simplified test implementation for pool contract upgrade testing
package mock

import (
	u256 "gno.land/p/gnoswap/uint256"
	pool "gno.land/r/gnoswap/pool"
	v1 "gno.land/r/gnoswap/pool/v1"
)

func NewV3ValidPool(store pool.IPoolStore) pool.IPool {
	instance := v1.NewPoolV1(store)

	return &TestPool{
		instance: instance,
		mockFns:  make(map[string]func(args ...any) any),
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
	mockFns  map[string]func(args ...any) any
}

func (t *TestPool) SetMockFn(fnName string, fn func(args ...any) any) {
	t.mockFns[fnName] = fn
}

func (t *TestPool) ExecuteFn(fnName string, actualFn func(args ...any) any, args ...any) any {
	fn, ok := t.mockFns[fnName]
	if !ok {
		return actualFn(args...)
	}

	return fn(args...)
}

// IPoolManager interface
func (t *TestPool) CreatePool(token0Path string, token1Path string, fee uint32, sqrtPriceX96 string) {
	t.ExecuteFn(
		"CreatePool",
		func(args ...any) any {
			t.instance.CreatePool(args[0].(string), args[1].(string), args[2].(uint32), args[3].(string))
			return nil
		},
		token0Path, token1Path, fee, sqrtPriceX96,
	)
}

func (t *TestPool) SetPoolCreationFee(fee int64) {
	t.ExecuteFn(
		"SetPoolCreationFee",
		func(args ...any) any { t.instance.SetPoolCreationFee(args[0].(int64)); return nil },
		fee,
	)
}

func (t *TestPool) IncreaseObservationCardinalityLimit(token0Path string, token1Path string, fee uint32, cardinalityNext uint16) {
	t.ExecuteFn(
		"IncreaseObservationCardinalityLimit",
		func(args ...any) any {
			t.instance.IncreaseObservationCardinalityLimit(args[0].(string), args[1].(string), args[2].(uint32), args[3].(uint16))
			return nil
		},
		token0Path, token1Path, fee, cardinalityNext,
	)
}

// IPoolPosition interface
func (t *TestPool) Mint(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	result := t.ExecuteFn(
		"Mint",
		func(args ...any) any {
			r1, r2 := t.instance.Mint(args[0].(string), args[1].(string), args[2].(uint32), args[3].(int32), args[4].(int32), args[5].(string), args[6].(address))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestPool) Burn(token0Path string, token1Path string, fee uint32, tickLower int32, tickUpper int32, liquidityAmount string, positionCaller address) (string, string) {
	result := t.ExecuteFn(
		"Burn",
		func(args ...any) any {
			r1, r2 := t.instance.Burn(args[0].(string), args[1].(string), args[2].(uint32), args[3].(int32), args[4].(int32), args[5].(string), args[6].(address))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee, tickLower, tickUpper, liquidityAmount, positionCaller,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestPool) Collect(token0Path string, token1Path string, fee uint32, recipient address, tickLower int32, tickUpper int32, amount0Requested string, amount1Requested string) (string, string) {
	result := t.ExecuteFn(
		"Collect",
		func(args ...any) any {
			r1, r2 := t.instance.Collect(args[0].(string), args[1].(string), args[2].(uint32), args[3].(address), args[4].(int32), args[5].(int32), args[6].(string), args[7].(string))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee, recipient, tickLower, tickUpper, amount0Requested, amount1Requested,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestPool) SetWithdrawalFee(fee uint64) {
	t.ExecuteFn(
		"SetWithdrawalFee",
		func(args ...any) any { t.instance.SetWithdrawalFee(args[0].(uint64)); return nil },
		fee,
	)
}

func (t *TestPool) HandleWithdrawalFee(positionId uint64, token0Path string, amount0 string, token1Path string, amount1 string, poolPath string, positionCaller address) (string, string) {
	result := t.ExecuteFn(
		"HandleWithdrawalFee",
		func(args ...any) any {
			r1, r2 := t.instance.HandleWithdrawalFee(args[0].(uint64), args[1].(string), args[2].(string), args[3].(string), args[4].(string), args[5].(string), args[6].(address))
			return []any{r1, r2}
		},
		positionId, token0Path, amount0, token1Path, amount1, poolPath, positionCaller,
	).([]any)
	return result[0].(string), result[1].(string)
}

// IPoolSwap interface
func (t *TestPool) Swap(token0Path string, token1Path string, fee uint32, recipient address, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string, payer address, swapCallback func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error) (string, string) {
	result := t.ExecuteFn(
		"Swap",
		func(args ...any) any {
			r1, r2 := t.instance.Swap(args[0].(string), args[1].(string), args[2].(uint32), args[3].(address), args[4].(bool), args[5].(string), args[6].(string), args[7].(address), args[8].(func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee, recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, payer, swapCallback,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestPool) SetSwapEndHook(hook func(cur realm, poolPath string) error) {
	t.ExecuteFn(
		"SetSwapEndHook",
		func(args ...any) any {
			t.instance.SetSwapEndHook(args[0].(func(cur realm, poolPath string) error))
			return nil
		},
		hook,
	)
}

func (t *TestPool) SetSwapStartHook(hook func(cur realm, poolPath string, timestamp int64)) {
	t.ExecuteFn(
		"SetSwapStartHook",
		func(args ...any) any {
			t.instance.SetSwapStartHook(args[0].(func(cur realm, poolPath string, timestamp int64)))
			return nil
		},
		hook,
	)
}

func (t *TestPool) SetTickCrossHook(hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	t.ExecuteFn(
		"SetTickCrossHook",
		func(args ...any) any {
			t.instance.SetTickCrossHook(args[0].(func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)))
			return nil
		},
		hook,
	)
}

func (t *TestPool) CollectProtocol(token0Path string, token1Path string, fee uint32, recipient address, amount0Requested string, amount1Requested string) (string, string) {
	result := t.ExecuteFn(
		"CollectProtocol",
		func(args ...any) any {
			r1, r2 := t.instance.CollectProtocol(args[0].(string), args[1].(string), args[2].(uint32), args[3].(address), args[4].(string), args[5].(string))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee, recipient, amount0Requested, amount1Requested,
	).([]any)
	return result[0].(string), result[1].(string)
}

func (t *TestPool) SetFeeProtocol(feeProtocol0, feeProtocol1 uint8) {
	t.ExecuteFn(
		"SetFeeProtocol",
		func(args ...any) any { t.instance.SetFeeProtocol(args[0].(uint8), args[1].(uint8)); return nil },
		feeProtocol0, feeProtocol1,
	)
}

// IPoolGetter interface
func (t *TestPool) DrySwap(token0Path string, token1Path string, fee uint32, zeroForOne bool, amountSpecified string, sqrtPriceLimitX96 string) (string, string, bool) {
	result := t.ExecuteFn(
		"DrySwap",
		func(args ...any) any {
			r1, r2, r3 := t.instance.DrySwap(args[0].(string), args[1].(string), args[2].(uint32), args[3].(bool), args[4].(string), args[5].(string))
			return []any{r1, r2, r3}
		},
		token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96,
	).([]any)
	return result[0].(string), result[1].(string), result[2].(bool)
}

func (t *TestPool) ExistsPoolPath(poolPath string) bool {
	return t.ExecuteFn(
		"ExistsPoolPath",
		func(args ...any) any { return t.instance.ExistsPoolPath(args[0].(string)) },
		poolPath,
	).(bool)
}

func (t *TestPool) GetPool(token0Path, token1Path string, fee uint32) (*pool.Pool, error) {
	result := t.ExecuteFn(
		"GetPool",
		func(args ...any) any {
			r1, r2 := t.instance.GetPool(args[0].(string), args[1].(string), args[2].(uint32))
			return []any{r1, r2}
		},
		token0Path, token1Path, fee,
	).([]any)
	return result[0].(*pool.Pool), result[1].(error)
}

func (t *TestPool) GetBalanceToken0(poolPath string) string {
	return t.ExecuteFn(
		"GetBalanceToken0",
		func(args ...any) any { return t.instance.GetBalanceToken0(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetBalanceToken1(poolPath string) string {
	return t.ExecuteFn(
		"GetBalanceToken1",
		func(args ...any) any { return t.instance.GetBalanceToken1(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetFee(poolPath string) uint32 {
	return t.ExecuteFn(
		"GetFee",
		func(args ...any) any { return t.instance.GetFee(args[0].(string)) },
		poolPath,
	).(uint32)
}

func (t *TestPool) GetFeeAmountTickSpacing(fee uint32) int32 {
	return t.ExecuteFn(
		"GetFeeAmountTickSpacing",
		func(args ...any) any { return t.instance.GetFeeAmountTickSpacing(args[0].(uint32)) },
		fee,
	).(int32)
}

func (t *TestPool) GetFeeGrowthGlobal0X128(poolPath string) string {
	return t.ExecuteFn(
		"GetFeeGrowthGlobal0X128",
		func(args ...any) any { return t.instance.GetFeeGrowthGlobal0X128(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetFeeGrowthGlobal1X128(poolPath string) string {
	return t.ExecuteFn(
		"GetFeeGrowthGlobal1X128",
		func(args ...any) any { return t.instance.GetFeeGrowthGlobal1X128(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	result := t.ExecuteFn(
		"GetFeeGrowthGlobalX128",
		func(args ...any) any {
			r1, r2 := t.instance.GetFeeGrowthGlobalX128(args[0].(string))
			return []any{r1, r2}
		},
		poolPath,
	).([]any)
	return result[0].(*u256.Uint), result[1].(*u256.Uint)
}

func (t *TestPool) GetLiquidity(poolPath string) string {
	return t.ExecuteFn(
		"GetLiquidity",
		func(args ...any) any { return t.instance.GetLiquidity(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetMaxLiquidityPerTick(poolPath string) string {
	return t.ExecuteFn(
		"GetMaxLiquidityPerTick",
		func(args ...any) any { return t.instance.GetMaxLiquidityPerTick(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetObservation(poolPath string, secondsAgo int64) (int64, string, string, int64) {
	result := t.ExecuteFn(
		"GetObservation",
		func(args ...any) any {
			r1, r2, r3, r4 := t.instance.GetObservation(args[0].(string), args[1].(int64))
			return []any{r1, r2, r3, r4}
		},
		poolPath, secondsAgo,
	).([]any)
	return result[0].(int64), result[1].(string), result[2].(string), result[3].(int64)
}

func (t *TestPool) GetPoolCreationFee() int64 {
	return t.ExecuteFn(
		"GetPoolCreationFee",
		func(args ...any) any { return t.instance.GetPoolCreationFee() },
	).(int64)
}

func (t *TestPool) GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return t.ExecuteFn(
		"GetPositionFeeGrowthInside0LastX128",
		func(args ...any) any {
			return t.instance.GetPositionFeeGrowthInside0LastX128(args[0].(string), args[1].(string))
		},
		poolPath, key,
	).(string)
}

func (t *TestPool) GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return t.ExecuteFn(
		"GetPositionFeeGrowthInside1LastX128",
		func(args ...any) any {
			return t.instance.GetPositionFeeGrowthInside1LastX128(args[0].(string), args[1].(string))
		},
		poolPath, key,
	).(string)
}

func (t *TestPool) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	result := t.ExecuteFn(
		"GetPositionFeeGrowthInsideLastX128",
		func(args ...any) any {
			r1, r2 := t.instance.GetPositionFeeGrowthInsideLastX128(args[0].(string), args[1].(string))
			return []any{r1, r2}
		},
		poolPath, key,
	).([]any)
	return result[0].(*u256.Uint), result[1].(*u256.Uint)
}

func (t *TestPool) GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return t.ExecuteFn(
		"GetPositionLiquidity",
		func(args ...any) any { return t.instance.GetPositionLiquidity(args[0].(string), args[1].(string)) },
		poolPath, key,
	).(*u256.Uint)
}

func (t *TestPool) GetPositionTokensOwed0(poolPath, key string) string {
	return t.ExecuteFn(
		"GetPositionTokensOwed0",
		func(args ...any) any { return t.instance.GetPositionTokensOwed0(args[0].(string), args[1].(string)) },
		poolPath, key,
	).(string)
}

func (t *TestPool) GetPositionTokensOwed1(poolPath, key string) string {
	return t.ExecuteFn(
		"GetPositionTokensOwed1",
		func(args ...any) any { return t.instance.GetPositionTokensOwed1(args[0].(string), args[1].(string)) },
		poolPath, key,
	).(string)
}

func (t *TestPool) GetProtocolFeesToken0(poolPath string) string {
	return t.ExecuteFn(
		"GetProtocolFeesToken0",
		func(args ...any) any { return t.instance.GetProtocolFeesToken0(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetProtocolFeesToken1(poolPath string) string {
	return t.ExecuteFn(
		"GetProtocolFeesToken1",
		func(args ...any) any { return t.instance.GetProtocolFeesToken1(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetSlot0FeeProtocol(poolPath string) uint8 {
	return t.ExecuteFn(
		"GetSlot0FeeProtocol",
		func(args ...any) any { return t.instance.GetSlot0FeeProtocol(args[0].(string)) },
		poolPath,
	).(uint8)
}

func (t *TestPool) GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return t.ExecuteFn(
		"GetSlot0SqrtPriceX96",
		func(args ...any) any { return t.instance.GetSlot0SqrtPriceX96(args[0].(string)) },
		poolPath,
	).(*u256.Uint)
}

func (t *TestPool) GetSlot0Tick(poolPath string) int32 {
	return t.ExecuteFn(
		"GetSlot0Tick",
		func(args ...any) any { return t.instance.GetSlot0Tick(args[0].(string)) },
		poolPath,
	).(int32)
}

func (t *TestPool) GetSlot0Unlocked(poolPath string) bool {
	return t.ExecuteFn(
		"GetSlot0Unlocked",
		func(args ...any) any { return t.instance.GetSlot0Unlocked(args[0].(string)) },
		poolPath,
	).(bool)
}

func (t *TestPool) GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return t.ExecuteFn(
		"GetTickCumulativeOutside",
		func(args ...any) any { return t.instance.GetTickCumulativeOutside(args[0].(string), args[1].(int32)) },
		poolPath, tick,
	).(int64)
}

func (t *TestPool) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return t.ExecuteFn(
		"GetTickFeeGrowthOutside0X128",
		func(args ...any) any {
			return t.instance.GetTickFeeGrowthOutside0X128(args[0].(string), args[1].(int32))
		},
		poolPath, tick,
	).(string)
}

func (t *TestPool) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return t.ExecuteFn(
		"GetTickFeeGrowthOutside1X128",
		func(args ...any) any {
			return t.instance.GetTickFeeGrowthOutside1X128(args[0].(string), args[1].(int32))
		},
		poolPath, tick,
	).(string)
}

func (t *TestPool) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	result := t.ExecuteFn(
		"GetTickFeeGrowthOutsideX128",
		func(args ...any) any {
			r1, r2 := t.instance.GetTickFeeGrowthOutsideX128(args[0].(string), args[1].(int32))
			return []any{r1, r2}
		},
		poolPath, tick,
	).([]any)
	return result[0].(*u256.Uint), result[1].(*u256.Uint)
}

func (t *TestPool) GetTickInitialized(poolPath string, tick int32) bool {
	return t.ExecuteFn(
		"GetTickInitialized",
		func(args ...any) any { return t.instance.GetTickInitialized(args[0].(string), args[1].(int32)) },
		poolPath, tick,
	).(bool)
}

func (t *TestPool) GetTickLiquidityGross(poolPath string, tick int32) string {
	return t.ExecuteFn(
		"GetTickLiquidityGross",
		func(args ...any) any { return t.instance.GetTickLiquidityGross(args[0].(string), args[1].(int32)) },
		poolPath, tick,
	).(string)
}

func (t *TestPool) GetTickLiquidityNet(poolPath string, tick int32) string {
	return t.ExecuteFn(
		"GetTickLiquidityNet",
		func(args ...any) any { return t.instance.GetTickLiquidityNet(args[0].(string), args[1].(int32)) },
		poolPath, tick,
	).(string)
}

func (t *TestPool) GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return t.ExecuteFn(
		"GetTickSecondsOutside",
		func(args ...any) any { return t.instance.GetTickSecondsOutside(args[0].(string), args[1].(int32)) },
		poolPath, tick,
	).(uint32)
}

func (t *TestPool) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return t.ExecuteFn(
		"GetTickSecondsPerLiquidityOutsideX128",
		func(args ...any) any {
			return t.instance.GetTickSecondsPerLiquidityOutsideX128(args[0].(string), args[1].(int32))
		},
		poolPath, tick,
	).(string)
}

func (t *TestPool) GetTickSpacing(poolPath string) int32 {
	return t.ExecuteFn(
		"GetTickSpacing",
		func(args ...any) any { return t.instance.GetTickSpacing(args[0].(string)) },
		poolPath,
	).(int32)
}

func (t *TestPool) GetToken0Path(poolPath string) string {
	return t.ExecuteFn(
		"GetToken0Path",
		func(args ...any) any { return t.instance.GetToken0Path(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetToken1Path(poolPath string) string {
	return t.ExecuteFn(
		"GetToken1Path",
		func(args ...any) any { return t.instance.GetToken1Path(args[0].(string)) },
		poolPath,
	).(string)
}

func (t *TestPool) GetWithdrawalFee() uint64 {
	return t.ExecuteFn(
		"GetWithdrawalFee",
		func(args ...any) any { return t.instance.GetWithdrawalFee() },
	).(uint64)
}

func (t *TestPool) GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	result := t.ExecuteFn(
		"GetTWAP",
		func(args ...any) any {
			r1, r2, r3 := t.instance.GetTWAP(args[0].(string), args[1].(uint32))
			return []any{r1, r2, r3}
		},
		poolPath, secondsAgo,
	).([]any)
	return result[0].(int32), result[1].(*u256.Uint), result[2].(error)
}

// Pool enumeration
func (t *TestPool) GetPoolCount() int {
	return t.ExecuteFn(
		"GetPoolCount",
		func(args ...any) any { return t.instance.GetPoolCount() },
	).(int)
}

func (t *TestPool) GetPoolPaths(offset, count int) []string {
	return t.ExecuteFn(
		"GetPoolPaths",
		func(args ...any) any { return t.instance.GetPoolPaths(args[0].(int), args[1].(int)) },
		offset, count,
	).([]string)
}

func (t *TestPool) GetFeeAmountTickSpacings() map[uint32]int32 {
	return t.ExecuteFn(
		"GetFeeAmountTickSpacings",
		func(args ...any) any { return t.instance.GetFeeAmountTickSpacings() },
	).(map[uint32]int32)
}

// Position enumeration
func (t *TestPool) GetPoolPositionCount(poolPath string) int {
	return t.ExecuteFn(
		"GetPoolPositionCount",
		func(args ...any) any { return t.instance.GetPoolPositionCount(args[0].(string)) },
		poolPath,
	).(int)
}

func (t *TestPool) GetPoolPositionKeys(poolPath string, offset, count int) []string {
	return t.ExecuteFn(
		"GetPoolPositionKeys",
		func(args ...any) any {
			return t.instance.GetPoolPositionKeys(args[0].(string), args[1].(int), args[2].(int))
		},
		poolPath, offset, count,
	).([]string)
}

// Tick enumeration
func (t *TestPool) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32 {
	return t.ExecuteFn(
		"GetInitializedTicksInRange",
		func(args ...any) any {
			return t.instance.GetInitializedTicksInRange(args[0].(string), args[1].(int32), args[2].(int32))
		},
		poolPath, tickLower, tickUpper,
	).([]int32)
}

// Structure getters
func (t *TestPool) GetTickInfo(poolPath string, tick int32) (pool.TickInfo, error) {
	result := t.ExecuteFn(
		"GetTickInfo",
		func(args ...any) any {
			r1, r2 := t.instance.GetTickInfo(args[0].(string), args[1].(int32))
			return []any{r1, r2}
		},
		poolPath, tick,
	).([]any)
	return result[0].(pool.TickInfo), result[1].(error)
}

func (t *TestPool) GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error) {
	result := t.ExecuteFn(
		"GetTickBitmaps",
		func(args ...any) any {
			r1, r2 := t.instance.GetTickBitmaps(args[0].(string), args[1].(int16))
			return []any{r1, r2}
		},
		poolPath, wordPos,
	).([]any)
	return result[0].(*u256.Uint), result[1].(error)
}

func (t *TestPool) GetPosition(poolPath, key string) (pool.PositionInfo, error) {
	result := t.ExecuteFn(
		"GetPosition",
		func(args ...any) any {
			r1, r2 := t.instance.GetPosition(args[0].(string), args[1].(string))
			return []any{r1, r2}
		},
		poolPath, key,
	).([]any)
	return result[0].(pool.PositionInfo), result[1].(error)
}

func (t *TestPool) GetObservationState(poolPath string) (*pool.ObservationState, error) {
	result := t.ExecuteFn(
		"GetObservationState",
		func(args ...any) any {
			r1, r2 := t.instance.GetObservationState(args[0].(string))
			return []any{r1, r2}
		},
		poolPath,
	).([]any)
	return result[0].(*pool.ObservationState), result[1].(error)
}
