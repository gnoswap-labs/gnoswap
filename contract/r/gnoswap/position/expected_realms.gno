package position

import (
	"gno.land/r/gnoswap/v1/pool"
	u256 "gno.land/p/gnoswap/uint256"
)

// PoolI defines the interface for pool operations
type PoolI struct {
	GetPoolFromPoolPath func(poolPath string) *pool.Pool
	PoolGetSlot0SqrtPriceX96 func(poolPath string) string
	PoolGetSlot0Tick func(poolPath string) int32
	PoolGetFeeGrowthGlobal0X128 func(poolPath string) string
	PoolGetFeeGrowthGlobal1X128 func(poolPath string) string
	PoolGetTickFeeGrowthOutside0X128 func(poolPath string, tick int32) string
	PoolGetTickFeeGrowthOutside1X128 func(poolPath string, tick int32) string
}

var pl PoolI = PoolI{
	GetPoolFromPoolPath: pool.GetPoolFromPoolPath,
	PoolGetSlot0SqrtPriceX96: pool.PoolGetSlot0SqrtPriceX96,
	PoolGetSlot0Tick: pool.PoolGetSlot0Tick,
	PoolGetFeeGrowthGlobal0X128: pool.PoolGetFeeGrowthGlobal0X128,
	PoolGetFeeGrowthGlobal1X128: pool.PoolGetFeeGrowthGlobal1X128,
	PoolGetTickFeeGrowthOutside0X128: pool.PoolGetTickFeeGrowthOutside0X128,
	PoolGetTickFeeGrowthOutside1X128: pool.PoolGetTickFeeGrowthOutside1X128,
}