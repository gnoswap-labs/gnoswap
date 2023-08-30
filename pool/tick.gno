package gnoswap

import "gno.land/p/demo/ufmt"

func TickTickSpacingToMaxLiquidityPerTick(tickSpacing bigint) bigint {
	var minTick bigint = (MIN_TICK / tickSpacing) * tickSpacing
	var maxTick bigint = (MAX_TICK / tickSpacing) * tickSpacing
	var numTicks bigint = ((maxTick - minTick) / tickSpacing) + 1
	requireUnsigned(numTicks, ufmt.Sprintf("[POOL] tick.gno__TickTickSpacingToMaxLiquidityPerTick() || numTicks(%s) must be postivie", numTicks))

	requireUnsigned(MAX_UINT64/numTicks, ufmt.Sprintf("[POOL] tick.gno__TickTickSpacingToMaxLiquidityPerTick() || MAX_UINT64 / numTicks(%s) must be postivie", MAX_UINT64/numTicks))
	return MAX_UINT64 / numTicks
}

func (pool *Pool) TickGetFeeGrowthInside(
	tickLower bigint,
	tickUpper bigint,
	tickCurrent bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) (feeGrowthInside0X128, feeGrowthInside1X128 bigint) {
	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__TickGetFeeGrowthInside() || feeGrowthGlobal0X128(%s) must be postivie", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__TickGetFeeGrowthInside() || feeGrowthGlobal1X128(%s) must be postivie", feeGrowthGlobal1X128))

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

	requireUnsigned(feeGrowthInside0X128, ufmt.Sprintf("[POOL] tick.gno__TickGetFeeGrowthInside() || feeGrowthInside0X128(%s) must be postivie", feeGrowthInside0X128))
	requireUnsigned(feeGrowthInside1X128, ufmt.Sprintf("[POOL] tick.gno__TickGetFeeGrowthInside() || feeGrowthInside1X128(%s) must be postivie", feeGrowthInside1X128))
	return feeGrowthInside0X128, feeGrowthInside1X128
}

func (pool *Pool) TickUpdate(
	tick bigint,
	tickCurrent bigint,
	liquidityDelta bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
	upper bool,
	maxLiquidity bigint,
) (flipped bool) {

	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__TickUpdate() || feeGrowthGlobal0X128(%s) must be postivie", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__TickUpdate() || feeGrowthGlobal1X128(%s) must be postivie", feeGrowthGlobal1X128))
	requireUnsigned(maxLiquidity, ufmt.Sprintf("[POOL] tick.gno__TickUpdate() || maxLiquidity(%s) must be postivie", maxLiquidity))

	info := pool.ticks[tick]
	liquidityGrossBefore := info.liquidityGross
	liquidityGrossAfter := LiquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(liquidityGrossAfter <= maxLiquidity, ufmt.Sprintf("[POOL] tick.gno__TickUpdate() || liquidityGrossAfter(%s) <= maxLiquidity(%s)", liquidityGrossAfter, maxLiquidity))

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

func (pool *Pool) TickClear(tick bigint) {
	delete(pool.ticks, tick)
}

func (pool *Pool) TickCross(
	tick bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) bigint {
	requireUnsigned(feeGrowthGlobal0X128, ufmt.Sprintf("[POOL] tick.gno__TickCross() || feeGrowthGlobal0X128(%s) must be postivie", feeGrowthGlobal0X128))
	requireUnsigned(feeGrowthGlobal1X128, ufmt.Sprintf("[POOL] tick.gno__TickCross() || feeGrowthGlobal1X128(%s) must be postivie", feeGrowthGlobal1X128))

	info := pool.ticks[tick]
	info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128
	info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128

	pool.ticks[tick] = info

	liquidityNet := info.liquidityNet
	return liquidityNet
}
