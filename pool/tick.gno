package pool

import (
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"
)

func tickTickSpacingToMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (MAX_TICK / tickSpacing) * tickSpacing
	numTicks := bigint((maxTick-minTick)/tickSpacing) + 1

	return new(u256.Uint).Div(MAX_UINT128, numTicks)
}

func (pool *Pool) tickGetFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (feeGrowthInside0X128, feeGrowthInside1X128 *u256.Uint) {
	lower := pool.ticks[tickLower]
	upper := pool.ticks[tickUpper]

	var feeGrowthBelow0X128, feeGrowthBelow1X128 *u256.Uint
	if tickCurrent >= tickLower {
		feeGrowthBelow0X128 = lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = lower.feeGrowthOutside1X128
	} else {
		feeGrowthBelow0X128.Sub(feeGrowthGlobal0X128, lower.feeGrowthOutside0X128)
		feeGrowthBelow1X128.Sub(feeGrowthGlobal1X128, lower.feeGrowthOutside1X128)
	}

	var feeGrowthAbove0X128, feeGrowthAbove1X128 *u256.Uint
	if tickCurrent < tickUpper {
		feeGrowthAbove0X128 = upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = upper.feeGrowthOutside1X128
	} else {
		feeGrowthAbove0X128.Sub(feeGrowthGlobal0X128, upper.feeGrowthOutside0X128)
		feeGrowthAbove1X128.Sub(feeGrowthGlobal1X128, upper.feeGrowthOutside1X128)
	}

	feeGrowthInside0X128.Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128)
	feeGrowthInside0X128.Sub(feeGrowthInside0X128, feeGrowthAbove0X128)

	feeGrowthInside1X128.Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128)
	feeGrowthInside1X128.Sub(feeGrowthInside1X128, feeGrowthAbove1X128)

	return feeGrowthInside0X128, feeGrowthInside1X128
}

func (pool *Pool) tickUpdate(
	tick int32,
	tickCurrent int32,
	liquidityDelta *u256.Int,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
	upper bool,
	maxLiquidity *u256.Uint,
) (flipped bool) {
	info := pool.ticks[tick]
	liquidityGrossBefore := info.liquidityGross
	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(liquidityGrossAfter.Lte(maxLiquidity), ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || liquidityGrossAfter(%d) <= maxLiquidity(%d)", liquidityGrossAfter, maxLiquidity))

	flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0)

	if liquidityGrossBefore == 0 {
		if tick <= tickCurrent {
			info.feeGrowthOutside0X128 = feeGrowthGlobal0X128
			info.feeGrowthOutside1X128 = feeGrowthGlobal1X128
		}

		info.initialized = true
	}

	info.liquidityGross = liquidityGrossAfter

	if upper {
		info.liquidityNet -= liquidityDelta
	} else {
		info.liquidityNet += liquidityDelta
	}

	pool.ticks[tick] = info

	return flipped
}

func (pool *Pool) tickClear(tick int32) {
	pool.ticks = deleteFromPoolTicks(pool.ticks, tick)
}

func (pool *Pool) tickCross(
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) *u256.Int {
	info := pool.ticks[tick]
	info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128
	info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128

	pool.ticks[tick] = info

	liquidityNet := info.liquidityNet
	return liquidityNet
}

func deleteFromPoolTicks(m map[int32]TickInfo, key int32) map[int32]TickInfo {
	if _, ok := m[key]; ok {
		newMap := make(map[int32]TickInfo)
		for k, v := range m {
			if k != key {
				newMap[k] = v
			}
		}

		return newMap
	}

	return m
}
