package pool

import (
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/demo/int256"
	u256 "gno.land/p/demo/uint256"
)

func tickTickSpacingToMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	_maxUint128 := u256.MustFromDecimal(consts.MAX_UINT128)
	return new(u256.Uint).Div(_maxUint128, u256.NewUint(numTicks))
}

func (pool *Pool) tickGetFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint, // uint256
	feeGrowthGlobal1X128 *u256.Uint, // uint256
) (*u256.Uint, *u256.Uint) { // uint256
	lower := pool.ticks[tickLower]
	upper := pool.ticks[tickUpper]

	var feeGrowthBelow0X128, feeGrowthBelow1X128 *u256.Uint
	if tickCurrent >= tickLower {
		feeGrowthBelow0X128 = lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = lower.feeGrowthOutside1X128
	} else {
		feeGrowthBelow0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, lower.feeGrowthOutside0X128)
		feeGrowthBelow1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, lower.feeGrowthOutside1X128)
	}

	var feeGrowthAbove0X128, feeGrowthAbove1X128 *u256.Uint
	if tickCurrent < tickUpper {
		feeGrowthAbove0X128 = upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = upper.feeGrowthOutside1X128
	} else {
		feeGrowthAbove0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, upper.feeGrowthOutside0X128)
		feeGrowthAbove1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, upper.feeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128), feeGrowthAbove0X128)
	feeGrowthInside1X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128), feeGrowthAbove1X128)

	return feeGrowthInside0X128, feeGrowthInside1X128
}

func (pool *Pool) tickUpdate(
	tick int32,
	tickCurrent int32,
	liquidityDelta *i256.Int, // int128
	feeGrowthGlobal0X128 *u256.Uint, // uint256
	feeGrowthGlobal1X128 *u256.Uint, // uint256
	upper bool,
	maxLiquidity *u256.Uint, // uint256
) (flipped bool) {
	// START PARAM INIT
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthGlobal0X128 = feeGrowthGlobal0X128.NilToZero()
	feeGrowthGlobal1X128 = feeGrowthGlobal1X128.NilToZero()
	// END PARAM INIT

	// START STRUCT INIT
	info := pool.ticks[tick]
	info.liquidityGross = info.liquidityGross.NilToZero()
	info.liquidityNet = info.liquidityNet.NilToZero()

	info.feeGrowthOutside0X128 = info.feeGrowthOutside0X128.NilToZero()
	info.feeGrowthOutside1X128 = info.feeGrowthOutside1X128.NilToZero()

	info.secondsPerLiquidityOutsideX128 = info.secondsPerLiquidityOutsideX128.NilToZero()
	// END STRUCT INIT

	liquidityGrossBefore := info.liquidityGross
	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)

	if !(liquidityGrossAfter.Lte(maxLiquidity)) {
		panic("tick panic #1")
	}

	flipped = (liquidityGrossAfter.IsZero()) != (liquidityGrossBefore.IsZero())

	if liquidityGrossBefore.IsZero() {
		if tick <= tickCurrent {
			info.feeGrowthOutside0X128 = feeGrowthGlobal0X128
			info.feeGrowthOutside1X128 = feeGrowthGlobal1X128
		}

		info.initialized = true
	}

	info.liquidityGross = liquidityGrossAfter

	if upper {
		info.liquidityNet = i256.Zero().Sub(info.liquidityNet, liquidityDelta)
	} else {
		info.liquidityNet = i256.Zero().Add(info.liquidityNet, liquidityDelta)
	}

	pool.ticks[tick] = info

	return flipped
}

func (pool *Pool) tickClear(tick int32) {
	pool.ticks = deleteFromPoolTicks(pool.ticks, tick)
}

func (pool *Pool) tickCross(
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint, // uint256
	feeGrowthGlobal1X128 *u256.Uint, // uint256
) *i256.Int {
	info := pool.ticks[tick]
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
