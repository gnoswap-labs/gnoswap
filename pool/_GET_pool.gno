package pool

import (
	"gno.land/p/demo/ufmt"
)

func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

func (pool *Pool) PoolGetToken0Path() string {
	return pool.token0Path
}

func (pool *Pool) PoolGetToken1Path() string {
	return pool.token1Path
}

func (pool *Pool) PoolGetToken0Balance() bigint {
	return pool.balances.token0
}

func (pool *Pool) PoolGetToken1Balance() bigint {
	return pool.balances.token1
}

func (pool *Pool) PoolGetFee() uint16 {
	return pool.fee
}

func (pool *Pool) PoolGetTickSpacing() int32 {
	return pool.tickSpacing
}

func (pool *Pool) PoolGetSlot0() Slot0 {
	return pool.slot0
}

func (pool *Pool) PoolGetSlot0SqrtPriceX96() bigint {
	return pool.slot0.sqrtPriceX96
}

func (pool *Pool) PoolGetSlot0Tick() int32 {
	return pool.slot0.tick
}

func (pool *Pool) PoolGetSlot0FeeProtocol() uint8 {
	return pool.slot0.feeProtocol
}

func (pool *Pool) PoolGetFeeGrowthGlobal0X128() bigint {
	return pool.feeGrowthGlobal0X128
}

func (pool *Pool) PoolGetFeeGrowthGlobal1X128() bigint {
	return pool.feeGrowthGlobal1X128
}

func (pool *Pool) PoolGetLiquidity() bigint {
	return pool.liquidity
}

func (pool *Pool) PoolGetTick(x int32) TickInfo {
	tick, exist := pool.ticks[x]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTick() || tick(%d) does not exist", x))

	return tick
}

func (pool *Pool) PoolGetTickFeeGrowthOutside0X128(x int32) bigint {
	tick, exist := pool.ticks[x]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside0X128() || tick(%d) does not exist", x))
	// if !exist {
	// 	return 0
	// }

	return tick.feeGrowthOutside0X128
}

func (pool *Pool) PoolGetTickFeeGrowthOutside1X128(x int32) bigint {
	tick, exist := pool.ticks[x]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickFeeGrowthOutside1X128() || tick(%d) does not exist", x))
	// if !exist {
	// 	return 0
	// }

	return tick.feeGrowthOutside1X128
}

func (pool *Pool) PoolGetTickBitmap(x int16) bigint {
	tickBitmap, exist := pool.tickBitmaps[x]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetTickBitmap() || tickBitmap(%d) does not exist", x))
	// if !exist {
	// 	return 0
	// }

	return tickBitmap
}

func (pool *Pool) PoolGetPositions() Positions {
	return pool.positions
}

func (pool *Pool) PoolGetPosition(key string) PositionInfo {
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPosition() || position(%s) does not exist", key))

	return position
}

func (pool *Pool) PoolGetPositionFeeGrowthInside0LastX128(key string) bigint {
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPosition() || position(%s) does not exist", key))

	return position.feeGrowthInside0LastX128
}

func (pool *Pool) PoolGetPositionFeeGrowthInside1LastX128(key string) bigint {
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] _GET_pool.gno__PoolGetPosition() || position(%s) does not exist", key))

	return position.feeGrowthInside1LastX128
}
