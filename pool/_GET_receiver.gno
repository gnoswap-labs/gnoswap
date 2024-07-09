package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// PoolGetPoolList returns a list of all pool paths
func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

func (pool *Pool) PoolGetSlot0() Slot0 {
	return pool.slot0
}

func (pool *Pool) PoolGetSlot0SqrtPriceX96() *u256.Uint {
	return pool.slot0.sqrtPriceX96
}

func (pool *Pool) PoolGetSlot0Tick() int32 {
	return pool.slot0.tick
}

func (pool *Pool) PoolGetPositionFeeGrowthInside0LastX128(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		return u256.Zero()
	}

	return position.feeGrowthInside0LastX128
}

func (pool *Pool) PoolGetPositionFeeGrowthInside1LastX128(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		return u256.Zero()
	}

	return position.feeGrowthInside1LastX128
}

func (pool *Pool) PoolGetTickFeeGrowthOutside0X128(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		return u256.Zero()
	}

	return tick.feeGrowthOutside0X128
}

func (pool *Pool) PoolGetTickFeeGrowthOutside1X128(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		return u256.Zero()
	}

	return tick.feeGrowthOutside1X128
}

func (pool *Pool) PoolGetToken0Path() string {
	return pool.token0Path
}

func (pool *Pool) PoolGetToken1Path() string {
	return pool.token1Path
}

func (pool *Pool) PoolGetFee() uint32 {
	return pool.fee
}

func (pool *Pool) PoolGetFeeGrowthGlobal0X128() *u256.Uint {
	return pool.feeGrowthGlobal0X128
}

func (pool *Pool) PoolGetFeeGrowthGlobal1X128() *u256.Uint {
	return pool.feeGrowthGlobal1X128
}

func (pool *Pool) PoolGetLiquidity() *u256.Uint {
	return pool.liquidity
}
