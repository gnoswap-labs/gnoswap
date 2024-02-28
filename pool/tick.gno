package pool

import (
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

func tickTickSpacingToMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := u256.NewUint(uint64(((maxTick - minTick) / tickSpacing) + 1))

	return new(u256.Uint).Div(u256.FromBigint(consts.MAX_UINT128), numTicks)
}

func (pool *Pool) tickGetFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (feeGrowthInside0X128, feeGrowthInside1X128 *u256.Uint) {
	// init return values
	feeGrowthInside0X128 = u256.Zero()
	feeGrowthInside1X128 = u256.Zero()

	// println("tickLower", tickLower)
	// println("tickUpper", tickUpper)
	// println("tickCurrent", tickCurrent)
	// println("feeGrowthGlobal0X128", feeGrowthGlobal0X128.Dec())
	// println("feeGrowthGlobal1X128", feeGrowthGlobal1X128.Dec())
	// println()

	// END INIT

	lower := pool.ticks[tickLower]
	upper := pool.ticks[tickUpper]

	feeGrowthBelow0X128 := u256.Zero()
	feeGrowthBelow1X128 := u256.Zero()

	// println("CHK", tickLower)
	// println("0x", lower.feeGrowthOutside0X128.Dec())
	// println("1x", lower.feeGrowthOutside1X128.Dec())
	if tickCurrent >= tickLower {
		feeGrowthBelow0X128 = lower.feeGrowthOutside0X128.NilToZero()
		feeGrowthBelow1X128 = lower.feeGrowthOutside1X128.NilToZero()
	} else {
		feeGrowthBelow0X128.Sub(feeGrowthGlobal0X128, lower.feeGrowthOutside0X128.NilToZero())
		feeGrowthBelow1X128.Sub(feeGrowthGlobal1X128, lower.feeGrowthOutside1X128.NilToZero())
	}

	// println("feeGrowthBelow0X128", feeGrowthBelow0X128.Dec())
	// println("feeGrowthBelow1X128", feeGrowthBelow1X128.Dec())

	feeGrowthAbove0X128 := u256.Zero()
	feeGrowthAbove1X128 := u256.Zero()

	if tickCurrent < tickUpper {
		feeGrowthAbove0X128 = upper.feeGrowthOutside0X128.NilToZero()
		feeGrowthAbove1X128 = upper.feeGrowthOutside1X128.NilToZero()
	} else {
		feeGrowthAbove0X128.Sub(feeGrowthGlobal0X128, upper.feeGrowthOutside0X128.NilToZero())
		feeGrowthAbove1X128.Sub(feeGrowthGlobal1X128, upper.feeGrowthOutside1X128.NilToZero())
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
	info.feeGrowthOutside0X128 = info.feeGrowthOutside0X128.NilToZero()
	info.feeGrowthOutside1X128 = info.feeGrowthOutside1X128.NilToZero()
	info.liquidityNet = info.liquidityNet.NilToZero()

	liquidityGrossBefore := info.liquidityGross

	if liquidityGrossBefore == nil {
		liquidityGrossBefore = u256.Zero()
	}

	// println("liquidityGrossBefore", liquidityGrossBefore.Dec())

	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(!liquidityGrossAfter.Lte(maxLiquidity), ufmt.Sprintf("[POOL] tick.gno__tickUpdate() || liquidityGrossAfter(%s) <= maxLiquidity(%s)", liquidityGrossAfter.Dec(), maxLiquidity.Dec()))
	// println("liquidityGrossAfter", liquidityGrossAfter.Dec())

	flipped = (liquidityGrossAfter.IsZero()) != (liquidityGrossBefore.IsZero())

	if liquidityGrossBefore.IsZero() {
		if tick <= tickCurrent {
			info.feeGrowthOutside0X128 = feeGrowthGlobal0X128
			info.feeGrowthOutside1X128 = feeGrowthGlobal1X128
		}

		info.initialized = true
	}

	// println("info.feeGrowthOutside0X128", info.feeGrowthOutside0X128.Dec())
	// println("info.feeGrowthOutside1X128", info.feeGrowthOutside1X128.Dec())

	info.liquidityGross = liquidityGrossAfter

	if upper {
		// println("11")
		// println("info.liquidityNet", info.liquidityNet.Dec())
		// println("liquidityDelta", liquidityDelta.Dec())
		info.liquidityNet.Sub(info.liquidityNet, liquidityDelta)
	} else {
		// println("22")
		// println("info.liquidityNet", info.liquidityNet.Dec())
		// println("liquidityDelta", liquidityDelta.Dec())
		info.liquidityNet.Add(info.liquidityNet, liquidityDelta)
	}
	// println("info.liquidityNet", info.liquidityNet.Dec())

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

	info.feeGrowthOutside0X128 = info.feeGrowthOutside0X128.NilToZero()
	info.feeGrowthOutside1X128 = info.feeGrowthOutside1X128.NilToZero()

	info.feeGrowthOutside0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, info.feeGrowthOutside0X128)
	info.feeGrowthOutside1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, info.feeGrowthOutside1X128)

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
