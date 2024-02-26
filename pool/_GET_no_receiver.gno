package pool

import (
	"gno.land/p/demo/ufmt"
)

// Slot0
func PoolGetSlot0SqrtPriceX96(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetSlot0SqrtPriceX96() || pool(%s) does not exist", poolPath))

	return pool.slot0.sqrtPriceX96
}

func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetSlot0Tick() || pool(%s) does not exist", poolPath))

	return pool.slot0.tick
}

func PoolGetSlot0FeeProtocol(poolPath string) uint8 {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetSlot0FeeProtocol() || pool(%s) does not exist", poolPath))

	return pool.slot0.feeProtocol
}

// Balances
func PoolGetToken0Balance(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken0Balance() || pool(%s) does not exist", poolPath))

	return pool.balances.token0
}

func PoolGetToken1Balance(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken1Balance() || pool(%s) does not exist", poolPath))

	return pool.balances.token1
}

// ProtocolFees
func PoolGetToken0ProtocolFee(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken0ProtocolFee() || pool(%s) does not exist", poolPath))

	return pool.protocolFees.token0
}

func PoolGetToken1ProtocolFee(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken1ProtocolFee() || pool(%s) does not exist", poolPath))

	return pool.protocolFees.token1
}

// PositionInfo
func PoolGetPositionLiquidity(poolPath, key string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionLiquidity() || pool(%s) does not exist", poolPath))

	position, exist := pool.positions[key]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionLiquidity() || position(%s) does not exist", key))

	return position.liquidity
}

func PoolGetPositionFeeGrowthInside0LastX128(poolPath, key string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionFeeGrowthInside0LastX128() || pool(%s) does not exist", poolPath))

	position, exist := pool.positions[key]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionFeeGrowthInside0LastX128) || position(%s) does not exist", key))

	return position.feeGrowthInside0LastX128
}

func PoolGetPositionFeeGrowthInside1LastX128(poolPath, key string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionFeeGrowthInside1LastX128() || pool(%s) does not exist", poolPath))

	position, exist := pool.positions[key]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionFeeGrowthInside1LastX128() || position(%s) does not exist", key))

	return position.feeGrowthInside1LastX128
}

func PoolGetPositionTokensOwed0(poolPath, key string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionTokensOwed0() || pool(%s) does not exist", poolPath))

	position, exist := pool.positions[key]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionTokensOwed0() || position(%s) does not exist", key))

	return position.tokensOwed0
}

func PoolGetPositionTokensOwed1(poolPath, key string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionTokensOwed1() || pool(%s) does not exist", poolPath))

	position, exist := pool.positions[key]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPositionTokensOwed1() || position(%s) does not exist", key))

	return position.tokensOwed1
}

// TickInfo
func PoolGetTickLiquidityGross(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickLiquidityGross() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickLiquidityGross() || tick(%d) does not exist", x))

	return tick.liquidityGross
}

func PoolGetTickLiquidityNet(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickLiquidityNet() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickLiquidityNet() || tick(%d) does not exist", x))

	return tick.liquidityNet
}

func PoolGetTickFeeGrowthOutside0X128(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside0X128() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside0X128() || tick(%d) does not exist", x))

	return tick.feeGrowthOutside0X128
}

func PoolGetTickFeeGrowthOutside1X128(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside1X128() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside1X128() || tick(%d) does not exist", x))

	return tick.feeGrowthOutside1X128
}

func PoolGetTickTickCumulativeOutside(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickTickCumulativeOutside() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickTickCumulativeOutside() || tick(%d) does not exist", x))

	return tick.tickCumulativeOutside
}

func PoolGetTickSecondsPerLiquidityOutsideX128(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickSecondsPerLiquidityOutsideX128() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickSecondsPerLiquidityOutsideX128() || tick(%d) does not exist", x))

	return tick.secondsPerLiquidityOutsideX128
}

func PoolGetTickSecondsOutside(poolPath string, x int32) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickSecondsOutside() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickSecondsOutside() || tick(%d) does not exist", x))

	return tick.secondsOutside
}

func PoolGetTickInitialized(poolPath string, x int32) bool {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickInitialized() || pool(%s) does not exist", poolPath))

	tick, exist := pool.ticks[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickInitialized() || tick(%d) does not exist", x))

	return tick.initialized
}

// TickBitmaps
func PoolGetTickBitmap(poolPath string, x int16) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickBitmap() || pool(%s) does not exist", poolPath))

	tickBitmap, exist := pool.tickBitmaps[x]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickBitmap() || tickBitmap(%d) does not exist", x))

	return tickBitmap
}

// Pool
func PoolGetToken0Path(poolPath string) string {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken0Path() || pool(%s) does not exist", poolPath))

	return pool.token0Path
}

func PoolGetToken1Path(poolPath string) string {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetToken1Path() || pool(%s) does not exist", poolPath))

	return pool.token1Path
}

func PoolGetFee(poolPath string) uint16 {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetFee() || pool(%s) does not exist", poolPath))

	return pool.fee
}

func PoolGetTickSpacing(poolPath string) int32 {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickSpacing() || pool(%s) does not exist", poolPath))

	return pool.tickSpacing
}

func PoolGetFeeGrowthGlobal0X128(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetFeeGrowthGlobal0X128() || pool(%s) does not exist", poolPath))

	return pool.feeGrowthGlobal0X128
}

func PoolGetFeeGrowthGlobal1X128(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetFeeGrowthGlobal1X128() || pool(%s) does not exist", poolPath))

	return pool.feeGrowthGlobal1X128
}

func PoolGetLiquidity(poolPath string) bigint {
	pool, exist := pools[poolPath]
	requireExist(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetLiquidity() || pool(%s) does not exist", poolPath))

	return pool.liquidity
}
