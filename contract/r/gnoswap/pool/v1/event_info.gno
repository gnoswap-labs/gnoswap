package v1

import (
	pl "gno.land/r/gnoswap/pool"
)

type tickEventInfo struct {
	tickID   int32
	tickInfo pl.TickInfo
}

// Collect tick info for event
// format key is:
// - t: tick
// - lg: liquidity gross
// - ln: liquidity net
// - fg0: fee growth outside 0
// - fg1: fee growth outside 1
// - tco: tick cumulative outside
// - spl: seconds per liquidity outside x128
// - so: seconds outside
// - i: initialized
func (t *tickEventInfo) ToString() string {
	return "{\"t\":" + formatInt(t.tickID) +
		",\"lg\":\"" + t.tickInfo.LiquidityGross().ToString() + "\"" +
		",\"ln\":\"" + t.tickInfo.LiquidityNet().ToString() + "\"" +
		",\"fg0\":\"" + t.tickInfo.FeeGrowthOutside0X128().ToString() + "\"" +
		",\"fg1\":\"" + t.tickInfo.FeeGrowthOutside1X128().ToString() + "\"" +
		",\"tco\":\"" + formatInt(t.tickInfo.TickCumulativeOutside()) + "\"" +
		",\"spl\":\"" + t.tickInfo.SecondsPerLiquidityOutsideX128().ToString() + "\"" +
		",\"so\":\"" + formatUint(t.tickInfo.SecondsOutside()) + "\"" +
		",\"i\":\"" + formatBool(t.tickInfo.Initialized()) + "\"}"
}

func NewTickEventInfo(tickID int32, tickInfo pl.TickInfo) *tickEventInfo {
	return &tickEventInfo{
		tickID:   tickID,
		tickInfo: tickInfo,
	}
}
