// POSITION CONTRACT USES BELOW FUNCTIONS IN ITS LOGIC
package gnoswap

import (
	"std"
)

func (pool *Pool) GetPoolSlot0SqrtPriceX96() bigint {
	return pool.slot0.sqrtPriceX96
}

func (pool *Pool) GetPoolTickSpacing() bigint {
	return pool.tickSpacing
}

func (pool *Pool) GetPoolTickBitmap(x bigint) bigint {
	return pool.tickBitmaps[x]
}

func (pool *Pool) GetPoolPosition(key string) PositionInfo {
	return pool.positions[key]
}

func (pool *Pool) GetPoolPositionFeeGrowthInside0LastX128(key string) bigint {
	return pool.positions[key].feeGrowthInside0LastX128
}

func (pool *Pool) GetPoolPositionFeeGrowthInside1LastX128(key string) bigint {
	return pool.positions[key].feeGrowthInside0LastX128
}

func GetPoolAddress() std.Address {
	return std.DerivePkgAddr("gno.land/r/pool")
	// XXX return std.GetOrigPkgAddr()
}

func (pool *Pool) GetPoolSlot0Tick() bigint {
	return pool.slot0.tick
}

func (pool *Pool) GetPoolTicks(x bigint) TickInfo {
	return pool.ticks[x]
}

func (pool *Pool) GetPoolTickFeeGrowthOutside0X128(x bigint) bigint {
	return pool.ticks[x].feeGrowthOutside0X128
}

func (pool *Pool) GetPoolTickFeeGrowthOutside1X128(x bigint) bigint {
	return pool.ticks[x].feeGrowthOutside1X128
}
