package gnoswap


type TickInfo struct {
	liquidityGross bigint
	liquidityNet bigint

	feeGrowthOutside0X128 bigint
	feeGrowthOutside1X128 bigint

	tickCumulativeOutside bigint

	secondsPerLiquidityOutsideX128 bigint
	secondsOutside bigint

	initialized bool
}

func TickTickSpacingToMaxLiquidityPerTick(tickSpacing bigint) bigint {
	var minTick bigint = (MIN_TICK / tickSpacing) * tickSpacing
	var maxTick bigint = (MAX_TICK / tickSpacing) * tickSpacing
	var numTicks bigint = ((maxTick - minTick) / tickSpacing) + 1
	requireUnsigned(numTicks, "tick.gno__TickTickSpacingToMaxLiquidityPerTick__numTicks")

	requireUnsigned(MAX_UINT64 / numTicks, "tick.gno__TickTickSpacingToMaxLiquidityPerTick__MAX_UINT64 / numTicks")
	return  MAX_UINT64 / numTicks
}

func TickGetFeeGrowthInside(
	tickLower bigint,
	tickUpper bigint,
	tickCurrent bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) (feeGrowthInside0X128, feeGrowthInside1X128 bigint) {
	requireUnsigned(feeGrowthGlobal0X128, "tick.gno__TickGetFeeGrowthInside__feeGrowthGlobal0X128")
	requireUnsigned(feeGrowthGlobal1X128, "tick.gno__TickGetFeeGrowthInside__feeGrowthGlobal1X128")

	// var lower TickInfo = ticks[tickLower]
	var lower TickInfo
	_lower, exists := ticks.Get(string(tickLower))
	if (!exists) {
		lower = TickInfo{}
		// panic("lower tick does not exist")
	} else {
		lower = _lower.(TickInfo)
	}
	
	// var upper TickInfo = ticks[tickUpper]
	var upper TickInfo
	_upper, exists := ticks.Get(string(tickUpper))
	if (!exists) {
		upper = TickInfo{}
		// panic("upper tick does not exist")
	} else {
		upper = _upper.(TickInfo)
	}
	
	var feeGrowthBelow0X128 bigint
	var feeGrowthBelow1X128 bigint
	if (tickCurrent >= tickLower) {
		feeGrowthBelow0X128 = lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = lower.feeGrowthOutside1X128
	} else {
		feeGrowthBelow0X128 = feeGrowthGlobal0X128 - lower.feeGrowthOutside0X128
		feeGrowthBelow1X128 = feeGrowthGlobal1X128 - lower.feeGrowthOutside1X128
	}

	var feeGrowthAbove0X128 bigint
	var feeGrowthAbove1X128 bigint
	if (tickCurrent < tickUpper) {
		feeGrowthAbove0X128 = upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = upper.feeGrowthOutside1X128
	} else {
		feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upper.feeGrowthOutside0X128
		feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upper.feeGrowthOutside1X128
	}

	feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthBelow0X128 - feeGrowthAbove0X128
	feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthBelow1X128 - feeGrowthAbove1X128

	requireUnsigned(feeGrowthInside0X128, "tick.gno__TickGetFeeGrowthInside__feeGrowthInside0X128")
	requireUnsigned(feeGrowthInside1X128, "tick.gno__TickGetFeeGrowthInside__feeGrowthInside1X128")
	return feeGrowthInside0X128, feeGrowthInside1X128
}

func TickUpdate(
	tick bigint,
	tickCurrent bigint,
	liquidityDelta bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
	upper bool,
	maxLiquidity bigint,
) (flipped bool) {
	requireUnsigned(feeGrowthGlobal0X128, "tick.gno__TickUpdate__feeGrowthGlobal0X128")
	requireUnsigned(feeGrowthGlobal1X128, "tick.gno__TickUpdate__feeGrowthGlobal1X128")
	requireUnsigned(maxLiquidity, "tick.gno__TickUpdate__maxLiquidity")

	// info := ticks[tick]
	var info TickInfo
	_info, exists := ticks.Get(string(tick))
	if (!exists) {
		info = TickInfo{}
	} else {
		info = _info.(TickInfo)
	}
	liquidityGrossBefore := info.liquidityGross

	liquidityGrossAfter := LiquidityMathAddDelta(liquidityGrossBefore, liquidityDelta)
	require(liquidityGrossAfter <= maxLiquidity, "[X] liquidityGrossAfter <= maxLiquidity")

	flipped = (liquidityGrossAfter == 0) != (liquidityGrossBefore == 0)

	if liquidityGrossBefore == 0 {
		if tick <= tickCurrent {
			info.feeGrowthOutside0X128 = feeGrowthGlobal0X128
			info.feeGrowthOutside1X128 = feeGrowthGlobal1X128
		}

		info.initialized = true;
	}

	info.liquidityGross = liquidityGrossAfter

	if upper {
		info.liquidityNet -= liquidityDelta
	} else {
		info.liquidityNet += liquidityDelta
	}

	// ticks[tick] = info
	ticks.Set(string(tick), info)
	return flipped
}

func TickClear(tick bigint) {
	// delete(ticks, tick)
	ticks.Remove(string(tick))
}


func TickCross(
	tick bigint,
	feeGrowthGlobal0X128 bigint,
	feeGrowthGlobal1X128 bigint,
) (bigint) {
	requireUnsigned(feeGrowthGlobal0X128, "tick.gno__TickCross__feeGrowthGlobal0X128")
	requireUnsigned(feeGrowthGlobal1X128, "tick.gno__TickCross__feeGrowthGlobal1X128")

	// info := ticks[tick]
	var info TickInfo
	_info, exists := ticks.Get(string(tick))
	if (!exists) {
		// XXX panic("tick does not exist")
		info = TickInfo{}
	} else {
		info = _info.(TickInfo)
	}

	info.feeGrowthOutside0X128 = feeGrowthGlobal0X128 - info.feeGrowthOutside0X128
	info.feeGrowthOutside1X128 = feeGrowthGlobal1X128 - info.feeGrowthOutside1X128
	// ticks[tick] = info
	ticks.Set(string(tick), info)
	
	liquidityNet := info.liquidityNet
	return liquidityNet
}