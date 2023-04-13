package gnoswap


type TickInfo struct {
	liquidityGross bigint
	liquidityNet bigint

	feeGrowthOutside0 bigint
	feeGrowthOutside1 bigint

	tickCumulativeOutside bigint

	secondsPerLiquidityOutside bigint
	secondsOutside bigint

	initialized bool
}

func TickTickSpacingToMaxLiquidityPerTick(tickSpacing bigint) bigint {
	var minTick bigint = (MIN_TICK / tickSpacing) * tickSpacing
	var maxTick bigint = (MAX_TICK / tickSpacing) * tickSpacing
	var numTicks bigint = bigint(((maxTick - minTick) / tickSpacing) + 1)

	return MAX_bigint / numTicks
}

func TickUpdate(
	tick bigint,
	tickCurrent bigint,
	liquidityDelta bigint,
	feeGrowthGlobal0 bigint,
	feeGrowthGlobal1 bigint,
	// secondsPerLiquidityCumulative bigdec,
	// tickCumulative bigint,
	time bigint,
	upper bool,
	maxLiquidity bigint,
) (flipped bool) {
	info := ticks[tick]
	
	liquidityGrossBefore := info.liquidityGross

	liquidityGrossAfter := LiquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(liquidityGrossAfter <= maxLiquidity, "[X] liquidityGrossAfter <= maxLiquidity")

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

	// // XXX remove??
	ticks[tick] = info
	return flipped
}

func TickClear(tick bigint) {
	delete(ticks, tick)
}

func TickGetFeeGrowthInside(
	tickLower bigint,
	tickUpper bigint,
	tickCurrent bigint,
	feeGrowthGlobal0 bigint,
	feeGrowthGlobal1 bigint,
) (feeGrowthInside0, feeGrowthInside1 bigint) {
	var lower TickInfo = ticks[tickLower]
	var upper TickInfo = ticks[tickUpper]
	
	var feeGrowthBelow0 bigint
	var feeGrowthBelow1 bigint
	if (tickCurrent >= tickLower) {
		feeGrowthBelow0 = lower.feeGrowthOutside0
		feeGrowthBelow1 = lower.feeGrowthOutside1
	} else {
		feeGrowthBelow0 = feeGrowthGlobal0 - lower.feeGrowthOutside0
		feeGrowthBelow1 = feeGrowthGlobal1 - lower.feeGrowthOutside1
	}

	var feeGrowthAbove0 bigint
	var feeGrowthAbove1 bigint
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
	time bigint,
) (bigint) {
	info := ticks[tick]

	info.feeGrowthOutside0 = feeGrowthGlobal0 - info.feeGrowthOutside0
	info.feeGrowthOutside1 = feeGrowthGlobal1 - info.feeGrowthOutside1
	// info.secondsOutside = time - info.secondsOutSide // XXX
	ticks[tick] = info
	liquidityNet := info.liquidityNet
	return liquidityNet
}