package pool

import (
	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
)

// tickTickSpacingToMaxLiquidityPerTick calculates the maximum liquidity
// per tick for a given tick spacing.
func tickTickSpacingToMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	return new(u256.Uint).Div(u256.MustFromDecimal(consts.MAX_UINT128), u256.NewUint(numTicks))
}

// tickGetFeeGrowthInside calculates the fee growth inside a tick range,
// and returns the fee growth inside for both tokens.
func (pool *Pool) tickGetFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	lower := pool.getTick(tickLower)
	upper := pool.getTick(tickUpper)

	feeGrowthBelow0X128, feeGrowthBelow1X128 := getFeeGrowthX128(tickLower, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, lower, true)
	feeGrowthAbove0X128, feeGrowthAbove1X128 := getFeeGrowthX128(tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, upper, false)

	feeGrowthInside0X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128), feeGrowthAbove0X128)
	feeGrowthInside1X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128), feeGrowthAbove1X128)

	return feeGrowthInside0X128, feeGrowthInside1X128
}

// tickUpdate updates a tick's state and returns whether the tick was flipped.
func (pool *Pool) tickUpdate(
	tick int32,
	tickCurrent int32,
	liquidityDelta *i256.Int, // int128
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
	upper bool,
	maxLiquidity *u256.Uint,
) (flipped bool) {
	liquidityDelta = liquidityDelta.NilToZero()
	feeGrowthGlobal0X128 = feeGrowthGlobal0X128.NilToZero()
	feeGrowthGlobal1X128 = feeGrowthGlobal1X128.NilToZero()

	thisTick := pool.getTick(tick)

	liquidityGrossBefore := thisTick.liquidityGross
	liquidityGrossAfter := liquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)

	if !(liquidityGrossAfter.Lte(maxLiquidity)) {
		panic(addDetailToError(
			errLiquidityCalculation,
			ufmt.Sprintf("tick.gno__tickUpdate() || liquidityGrossAfter(%s) overflows maxLiquidity(%s)", liquidityGrossAfter.ToString(), maxLiquidity.ToString()),
		))
	}

	flipped = (liquidityGrossAfter.IsZero()) != (liquidityGrossBefore.IsZero())

	if liquidityGrossBefore.IsZero() {
		if tick <= tickCurrent {
			thisTick.feeGrowthOutside0X128 = feeGrowthGlobal0X128
			thisTick.feeGrowthOutside1X128 = feeGrowthGlobal1X128
		}

		thisTick.initialized = true
	}

	thisTick.liquidityGross = liquidityGrossAfter

	if upper {
		thisTick.liquidityNet = i256.Zero().Sub(thisTick.liquidityNet, liquidityDelta)
	} else {
		thisTick.liquidityNet = i256.Zero().Add(thisTick.liquidityNet, liquidityDelta)
	}

	pool.ticks[tick] = thisTick

	return flipped
}

// tickCross updates a tick's state when it is crossed and returns the liquidity net.
func (pool *Pool) tickCross(
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) *i256.Int {
	thisTick := pool.getTick(tick)

	thisTick.feeGrowthOutside0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, thisTick.feeGrowthOutside0X128)
	thisTick.feeGrowthOutside1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, thisTick.feeGrowthOutside1X128)

	pool.ticks[tick] = thisTick

	return thisTick.liquidityNet
}

func (pool *Pool) getTick(tick int32) TickInfo {
	tickInfo := pool.ticks[tick]
	tickInfo.init()

	return tickInfo
}

func getFeeGrowthX128(
	tickCompare, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	tick TickInfo,
	lower bool,
) (*u256.Uint, *u256.Uint) {
	if lower && tickCurrent >= tickCompare {
		return tick.feeGrowthOutside0X128, tick.feeGrowthOutside1X128
	}

	if !lower && tickCurrent < tickCompare {
		return tick.feeGrowthOutside0X128, tick.feeGrowthOutside1X128
	}

	growth0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, tick.feeGrowthOutside0X128)
	growth1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, tick.feeGrowthOutside1X128)

	return growth0X128, growth1X128
}
