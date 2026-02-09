package v1

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

type tickCrossEventInfo struct {
	tickID               int32
	stakedLiquidityGross *u256.Uint
	stakedLiquidityDelta *i256.Int
	outsideAccumulation  *u256.Uint
}

// Collect tick info for event
// - t: Tick ID
// - slg: Staked Liquidity Gross
// - sld: Staked Liquidity Delta
// - oa: Outside Accumulation
func (t *tickCrossEventInfo) ToString() string {
	return "{\"t\":" + formatAnyInt(t.tickID) +
		",\"slg\":\"" + t.stakedLiquidityGross.ToString() + "\"" +
		",\"sld\":\"" + t.stakedLiquidityDelta.ToString() + "\"" +
		",\"oa\":\"" + t.outsideAccumulation.ToString() + "\"}"
}

func NewTickCrossEventInfo(tickID int32, stakedLiquidityGross *u256.Uint, stakedLiquidityDelta *i256.Int, outsideAccumulation *u256.Uint) *tickCrossEventInfo {
	return &tickCrossEventInfo{
		tickID:               tickID,
		stakedLiquidityGross: stakedLiquidityGross,
		stakedLiquidityDelta: stakedLiquidityDelta,
		outsideAccumulation:  outsideAccumulation,
	}
}
