package gnoswap

import (
	"gno.land/p/demo/avl"
)

// Testing
func (pool *Pool) GetMaxLiquidityPerTick() bigint {
	return pool.maxLiquidityPerTick
}

func (pool *Pool) GetLiquidity() bigint {
	return pool.liquidity
}

func (pool *Pool) GetFee() bigint {
	return pool.fee
}

func (pool *Pool) GetTickSpacing() bigint {
	return pool.tickSpacing
}

func (pool *Pool) GetFeeGrowthGlobal0X128() bigint {
	return pool.feeGrowthGlobal0X128
}

func (pool *Pool) GetFeeGrowthGlobal1X128() bigint {
	return pool.feeGrowthGlobal1X128
}

func (pool *Pool) GetSlot0() Slot0 {
	return pool.slot0
}

func (pool *Pool) GetProtocolFees() ProtocolFees {
	return pool.protocolFees
}

func (pool *Pool) GetPosition(key string) PositionInfo {
	position, exists := pool.positions.Get(key).(PositionInfo)
	if !exists {
		panic("position does not exist #3")
	}
	return position
}

func (pool *Pool) GetPositions() avl.Tree {
	return pool.positions
}

func (pool *Pool) GetTick(key string) TickInfo {
	tick, exists := pool.ticks.Get(key).(TickInfo)
	if !exists {
		panic("tick does not exist")
	}
	return tick
}

func (pool *Pool) GetTicks() avl.Tree {
	return pool.ticks
}

func (pool *Pool) GetTickBitmap(key string) bigint {
	tickBitmap, exists := pool.tickBitmaps.Get(key).(bigint)
	if !exists {
		panic("tickBitmap does not exist")
	}
	return tickBitmap
}

func (pool *Pool) GetTickBitmaps() avl.Tree {
	return pool.tickBitmaps
}

func (pool *Pool) GetSqrtPriceX96() bigint {
	return pool.slot0.sqrtPriceX96
}

func Abs(x bigint) bigint {
	if x < 0 {
		return -x
	}
	return x
}
