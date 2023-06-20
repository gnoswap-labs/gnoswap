package factory

func TickTickSpacingToMaxLiquidityPerTick(tickSpacing bigint) bigint {
	var minTick bigint = (MIN_TICK / tickSpacing) * tickSpacing
	var maxTick bigint = (MAX_TICK / tickSpacing) * tickSpacing
	var numTicks bigint = ((maxTick - minTick) / tickSpacing) + 1
	requireUnsigned(numTicks, "tick.gno__TickTickSpacingToMaxLiquidityPerTick__numTicks")

	requireUnsigned(MAX_UINT64/numTicks, "tick.gno__TickTickSpacingToMaxLiquidityPerTick__MAX_UINT64 / numTicks")
	return MAX_UINT64 / numTicks
}
