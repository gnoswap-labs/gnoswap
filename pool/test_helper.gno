package gnoswap

import (
	"std"

	"gno.land/p/demo/grc/grc20"
	"gno.land/p/demo/ufmt"
)

// Testing
func (pool *Pool) GetMaxLiquidityPerTick() bigint {
	return pool.maxLiquidityPerTick
}

func (pool *Pool) GetLiquidity() bigint {
	return pool.liquidity
}

func (pool *Pool) GetToken0() *grc20.AdminToken {
	return pool.token0
}

func (pool *Pool) GetToken1() *grc20.AdminToken {
	return pool.token1
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

func (pool *Pool) GetFeeProtocol() bigint {
	return pool.slot0.feeProtocol
}

func (pool *Pool) GetProtocolFees() ProtocolFees {
	return pool.protocolFees
}

func (pool *Pool) GetPosition(key string) PositionInfo {
	position, exist := pool.positions[key]
	require(exist, ufmt.Sprintf("[POOL] test_helper.gno__GetPosition() || position(%s) does not exist", key))

	return position
}

func (pool *Pool) GetPositions() Positions {
	return pool.positions
}

func (pool *Pool) GetTick(key bigint) TickInfo {
	tick, exist := pool.ticks[key]
	require(exist, ufmt.Sprintf("[POOL] test_helper.gno__GetTick() || tick(%s) does not exist", key))

	return tick
}

func (pool *Pool) GetTicks() Ticks {
	return pool.ticks
}

func (pool *Pool) GetTickBitmap(key bigint) bigint {
	tickBitmap, exist := pool.tickBitmaps[key]
	require(exist, ufmt.Sprintf("[POOL] test_helper.gno__GetTickBitmap() || tickBitmap(%s) does not exist", key))

	return tickBitmap
}

func (pool *Pool) GetTickBitmaps() TickBitmaps {
	return pool.tickBitmaps
}

func (pool *Pool) GetSqrtPriceX96() bigint {
	return pool.slot0.sqrtPriceX96
}

func (pool *Pool) PrintUserBalance(name string, target std.Address) {
	println(name)
	println(" > Token0:", balanceOf(pool.token0, target))
	println(" > Token1:", balanceOf(pool.token1, target))
}
