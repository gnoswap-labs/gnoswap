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

func (pool *Pool) GetPoolTickBitmap(x string) bigint {
	// return tickBitmaps[x]
	_tb, exists := pool.tickBitmaps.Get(x)
	if exists {
		return _tb.(bigint)
	} else {
		return bigint(0)
	}
}

func (pool *Pool) GetPoolPosition(key string) PositionInfo {
	// return positions[key]
	_pos, exists := pool.positions.Get(key)
	if exists {
		return _pos.(PositionInfo)
	} else {
		return PositionInfo{}
	}
}

func (pool *Pool) GetPoolPositionFeeGrowthInside0LastX128(key string) bigint {
	// return positions[key].feeGrowthInside0LastX128
	_posfgi0lx128, exists := pool.positions.Get(key)
	if exists {
		return _posfgi0lx128.(PositionInfo).feeGrowthInside0LastX128
	} else {
		return bigint(0)
	}
}

func (pool *Pool) GetPoolPositionFeeGrowthInside1LastX128(key string) bigint {
	// return positions[key].feeGrowthInside0LastX128
	_posfgi1lx128, exists := pool.positions.Get(key)
	if exists {
		return _posfgi1lx128.(PositionInfo).feeGrowthInside1LastX128
	} else {
		return bigint(0)
	}
}

func GetPoolAddress() std.Address {
	return std.DerivePkgAddr("gno.land/r/pool")
	// return std.Address("g17rgsdnfxzza0sdfsdma37sdwxagsz378833ca4")
	// XXX return std.GetOrigPkgAddr()
}

func (pool *Pool) GetPoolSlot0Tick() bigint {
	return pool.slot0.tick
}

func (pool *Pool) GetPoolTicks(x string) TickInfo {
	// return ticks[x]
	_tick, exists := pool.ticks.Get(x)
	if exists {
		return _tick.(TickInfo)
	} else {
		return TickInfo{}
	}
}

func (pool *Pool) GetPoolTickFeeGrowthOutside0X128(x string) bigint {
	// return ticks[x].feeGrowthOutside0X128
	_pooltfg0x128, exists := pool.ticks.Get(x)
	if exists {
		return _pooltfg0x128.(TickInfo).feeGrowthOutside0X128
	} else {
		return bigint(0)
	}
}

func (pool *Pool) GetPoolTickFeeGrowthOutside1X128(x string) bigint {
	// return ticks[x].feeGrowthOutside1X128
	_pooltfg1x128, exists := pool.ticks.Get(x)
	if exists {
		return _pooltfg1x128.(TickInfo).feeGrowthOutside1X128
	} else {
		return bigint(0)
	}
}
