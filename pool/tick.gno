package pool

import (
	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
)

// calculateMaxLiquidityPerTick calculates the maximum liquidity
// per tick for a given tick spacing.
func calculateMaxLiquidityPerTick(tickSpacing int32) *u256.Uint {
	minTick := (consts.MIN_TICK / tickSpacing) * tickSpacing
	maxTick := (consts.MAX_TICK / tickSpacing) * tickSpacing
	numTicks := uint64((maxTick-minTick)/tickSpacing) + 1

	return new(u256.Uint).Div(u256.MustFromDecimal(consts.MAX_UINT128), u256.NewUint(numTicks))
}

func getFeeGrowthBelowX128(
	tickLower, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	lowerTick TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent >= tickLower {
		return lowerTick.feeGrowthOutside0X128, lowerTick.feeGrowthOutside1X128
	}

	below0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, lowerTick.feeGrowthOutside0X128)
	below1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, lowerTick.feeGrowthOutside1X128)

	return below0X128, below1X128
}

func getFeeGrowthAboveX128(
	tickUpper, tickCurrent int32,
	feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
	upperTick TickInfo,
) (*u256.Uint, *u256.Uint) {
	if tickCurrent < tickUpper {
		return upperTick.feeGrowthOutside0X128, upperTick.feeGrowthOutside1X128
	}

	above0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, upperTick.feeGrowthOutside0X128)
	above1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, upperTick.feeGrowthOutside1X128)

	return above0X128, above1X128
}

// calculateFeeGrowthInside calculates the fee growth inside a tick range,
// and returns the fee growth inside for both tokens.
func (p *Pool) calculateFeeGrowthInside(
	tickLower int32,
	tickUpper int32,
	tickCurrent int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) (*u256.Uint, *u256.Uint) {
	lower := p.getTick(tickLower)
	upper := p.getTick(tickUpper)

	feeGrowthBelow0X128, feeGrowthBelow1X128 := getFeeGrowthBelowX128(tickLower, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, lower)
	feeGrowthAbove0X128, feeGrowthAbove1X128 := getFeeGrowthAboveX128(tickUpper, tickCurrent, feeGrowthGlobal0X128, feeGrowthGlobal1X128, upper)

	feeGrowthInside0X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal0X128, feeGrowthBelow0X128), feeGrowthAbove0X128)
	feeGrowthInside1X128 := new(u256.Uint).Sub(new(u256.Uint).Sub(feeGrowthGlobal1X128, feeGrowthBelow1X128), feeGrowthAbove1X128)

	return feeGrowthInside0X128, feeGrowthInside1X128
}

// tickUpdate updates a tick's state and returns whether the tick was flipped.
func (p *Pool) tickUpdate(
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

	thisTick := p.getTick(tick)

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

	p.ticks[tick] = thisTick

	return flipped
}

// tickCross updates a tick's state when it is crossed and returns the liquidity net.
func (p *Pool) tickCross(
	tick int32,
	feeGrowthGlobal0X128 *u256.Uint,
	feeGrowthGlobal1X128 *u256.Uint,
) *i256.Int {
	thisTick := p.getTick(tick)

	thisTick.feeGrowthOutside0X128 = new(u256.Uint).Sub(feeGrowthGlobal0X128, thisTick.feeGrowthOutside0X128)
	thisTick.feeGrowthOutside1X128 = new(u256.Uint).Sub(feeGrowthGlobal1X128, thisTick.feeGrowthOutside1X128)

	p.ticks[tick] = thisTick

	return thisTick.liquidityNet.Clone()
}

// getTick returns a tick's state.
func (p *Pool) getTick(tick int32) TickInfo {
	tickInfo := p.ticks[tick]
	tickInfo.init()

	return tickInfo
}

// receiver getters
func (p *Pool) GetTickLiquidityGross(tick int32) *u256.Uint {
	return p.mustGetTick(tick).liquidityGross
}

func (p *Pool) GetTickLiquidityNet(tick int32) *i256.Int {
	return p.mustGetTick(tick).liquidityNet
}

func (p *Pool) GetTickFeeGrowthOutside0X128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).feeGrowthOutside0X128
}

func (p *Pool) GetTickFeeGrowthOutside1X128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).feeGrowthOutside1X128
}

func (p *Pool) GetTickCumulativeOutside(tick int32) int64 {
	return p.mustGetTick(tick).tickCumulativeOutside
}

func (p *Pool) GetTickSecondsPerLiquidityOutsideX128(tick int32) *u256.Uint {
	return p.mustGetTick(tick).secondsPerLiquidityOutsideX128
}

func (p *Pool) GetTickSecondsOutside(tick int32) uint32 {
	return p.mustGetTick(tick).secondsOutside
}

func (p *Pool) GetTickInitialized(tick int32) bool {
	return p.mustGetTick(tick).initialized
}

func (p *Pool) mustGetTick(tick int32) TickInfo {
	tickInfo, exist := p.ticks[tick]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("tick(%d) does not exist", tick),
		))
	}

	return tickInfo
}
