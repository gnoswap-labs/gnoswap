package pool

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

func tickTickSpacingToMaxLiquidityPerTick(tickSpacing int32) bigint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := bigint((maxTick-minTick)/tickSpacing) + 1

	requireUnsigned(consts.MAX_UINT128/numTicks, ufmt.Sprintf("[POOL] tick.gno__tickTickSpacingToMaxLiquidityPerTick() || consts.MAX_UINT128(%d) / numTicks(%d) >= 0(%d)", consts.MAX_UINT128, numTicks, consts.MAX_UINT128/numTicks))
	return consts.MAX_UINT128 / numTicks
}

func (pool *Pool) tickGetFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) (feeGrowthInside0X128, feeGrowthInside1X128 bigint) {
	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__tickGetFeeGrowthInside() || feeGrowthGlobal0X128(%d) >= 0", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__tickGetFeeGrowthInside() || feeGrowthGlobal1X128(%d) >= 0", feeGrowthGlobal1X128))

	lower := pool.ticks[tickLower]
	upper := pool.ticks[tickUpper]

	var feeGrowthBelow0X128, feeGrowthBelow1X128 bigint
	if tickCurrent >= tickLower {
		feeGrowthBelow0X128 = lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = lower.feeGrowthOutside1X128
	} else {
		feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128
	}

	var feeGrowthAbove0X128, feeGrowthAbove1X128 bigint
	if tickCurrent < tickUpper {
		feeGrowthAbove0X128 = upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = upper.feeGrowthOutside1X128
	} else {
		feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128
	}

	feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128
	feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128

	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] tick.gno__tickGetFeeGrowthInside() || feeGrowthInside0X128(%d) >= 0", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] tick.gno__tickGetFeeGrowthInside() || feeGrowthInside1X128(%d) >= 0", feeGrowthInside1X128))
	return feeGrowthInside0X128, feeGrowthInside1X128
}

func (pool *Pool) tickUpdate(
	tick int32,
	tickCurrent int32,
	liquidityDelta bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
	upper bool,
	maxLiquidity bigint,
) (flipped bool) {

	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || feeGrowthGlobal0X128(%d) >= 0", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || feeGrowthGlobal1X128(%d) >= 0", feeGrowthGlobal1X128))
	requireUnsigned(maxLiquidity, ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || maxLiquidity(%d) >= 0", maxLiquidity))

	info := pool.ticks[tick]
	liquidityGrossBefore := info.liquidityGross
	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(liquidityGrossAfter <= maxLiquidity, ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || liquidityGrossAfter(%d) <= maxLiquidity(%d)", liquidityGrossAfter, maxLiquidity))

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
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) bigint {
	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__tickCross() || feeGrowthGlobal0X128(%d) >= 0", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__tickCross() || feeGrowthGlobal1X128(%d) >= 0", feeGrowthGlobal1X128))

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
