package gnoswap


type TickInfo struct {
	// the total position liquidity that references this tick
	liquidityGross bigdec

	// amount of net liquidity added (subtracted) when tick is crossed from left to right (right to left),
	liquidityNet bigdec

	// fee growth per unit of liquidity on the _other_ side of this tick (relative to the current tick)
	// only has relative meaning, not absolute — the value depends on when the tick is initialized
	feeGrowthOutside0 bigdec
	feeGrowthOutside1 bigdec

	// the cumulative tick value on the other side of the tick
	tickCumulativeOutside bigdec

	// secondsPerLiquidityOutside bigdec
	// secondsOutside bigdec

	// true iff the tick is initialized, i.e. the value is exactly equivalent to the expression liquidityGross != 0
	// these 8 bits are set to prevent fresh sstores when crossing newly initialized ticks
	initialized bool
}




func TickTickSpacingToMaxLiquidityPerTick(tickSpacing bigint) bigint {
	var minTick bigint = (MIN_TICK / tickSpacing) * tickSpacing
	var maxTick bigint = (MAX_TICK / tickSpacing) * tickSpacing
	var numTicks bigint = ((maxTick - minTick) / tickSpacing) + 1

	return MAX_UINT128 / numTicks
}

func TicksUpdate(
	tick bigint,
	tickCurrent bigint,
	liquidityDelta bigdec,
	feeGrowthGlobal0 bigdec,
	feeGrowthGlobal1 bigdec,
	// secondsPerLiquidityCumulative bigdec,
	// tickCumulative bigdec,
	time int64,
	upper bool,
	maxLiquidity bigint,
) (flipped bool) {
	var info TickInfo
	var ok bool
	info, ok = ticks.Get(string(tick))
	if !ok {
		info = TickInfo{0, 0, 0, 0, 0, false}
		// panic("tick not found")
	}

	var liquidityGrossBefore bigdec = info.liquidityGross
	var liquidityGrossAfter bigdec = LiquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)

	require(liquidityGrossAfter <= bigdec(maxLiquidity), "L0")

	flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0)

	if liquidityGrossBefore == 0 {
		if tick <= tickCurrent {
			info.feeGrowthOutside0 = feeGrowthGlobal0
			info.feeGrowthOutside1 = feeGrowthGlobal1
			// XXX secondsPerLiquidityCumulativeOutside = secondsPerLiquidityCumulative
			// XXX tickCumulativeOutside = tickCumulative
			// XXX info.secondsOutside = time
		}

		info.initialized = true;
	}

	info.liquidityGross = liquidityGrossAfter

	if upper {
		info.liquidityNet -= liquidityDelta
	} else {
		info.liquidityNet += liquidityDelta
	}

	// XXX remove??
	ticks.Set(string(tick), info)
	return flipped
}

func TicksClear(tick bigint) {
	ticks.Remove(string(tick))
}

func TicksGetFeeGrowthInside(
	tickLower bigint,
	tickUpper bigint,
	tickCurrent bigint,
	feeGrowthGlobal0 bigdec,
	feeGrowthGlobal1 bigdec,
) (feeGrowthInside0, feeGrowthInside1 bigdec) {
	var lower TickInfo
	var upper TickInfo
	var ok bool

	lower, ok = ticks.Get(string(tickLower))
	if !ok {
		panic("tickLower not found")
	}

	upper, ok = ticks.Get(string(tickUpper))
	if !ok {
		panic("tickUpper not found")
	}
	
	var feeGrowthBelow0 bigdec
	var feeGrowthBelow1 bigdec
	if (tickCurrent >= tickLower) {
		feeGrowthBelow0 = lower.feeGrowthOutside0
		feeGrowthBelow1 = lower.feeGrowthOutside1
	} else {
		feeGrowthBelow0 = feeGrowthGlobal0 - lower.feeGrowthOutside0
		feeGrowthBelow1 = feeGrowthGlobal1 - lower.feeGrowthOutside1
	}

	var feeGrowthAbove0 bigdec
	var feeGrowthAbove1 bigdec
	if (tickCurrent < tickUpper) {
		feeGrowthAbove0 = upper.feeGrowthOutside0
		feeGrowthAbove1 = upper.feeGrowthOutside1
	} else {
		feeGrowthAbove0 = feeGrowthGlobal0 - upper.feeGrowthOutside0
		feeGrowthAbove1 = feeGrowthGlobal1 - upper.feeGrowthOutside1
	}

	feeGrowthInside0 = feeGrowthGlobal0 - feeGrowthBelow0 - feeGrowthAbove0
	feeGrowthInside1 = feeGrowthGlobal1 - feeGrowthBelow1 - feeGrowthAbove1

	return feeGrowthInside0, feeGrowthInside1
}



func TickCross(
	tick bigint,
	feeGrowthGlobal0 bigint,
	feeGrowthGlobal1 bigint,
	time int64
) (bigint) {
	info, _got := ticks.Get(string(tick))
	if !_got {
		panic("Tick Not Found")
	}

	info.feeGrowthOutSide0 = feeGrowthGlobal0 - info.feeGrowthOutside0
	info.feeGrowthOutSide1 = feeGrowthGlobal1 - info.feeGrowthOutside1
	// info.secondsOutside = time - info.secondsOutSide // XXX
	ticks.set(string(tick), info)
	liquidityNet := info.liquidityNet

	return liquidityNet
}