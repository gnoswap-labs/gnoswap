package staker

import (
	i256 "gno.land/p/gnoswap/int256/v1"
	u256 "gno.land/p/gnoswap/uint256/v1"
	"gno.land/p/gnoswap/utils/v1"
)

type tickCrossEventInfo struct {
	tickID               int32
	stakedLiquidityGross *u256.Uint
	stakedLiquidityDelta *i256.Int
	outsideAccumulation  *u256.Uint
}

// ToString serializes tick-cross information as a compact JSON object for event emission.
// - t: Tick ID
// - slg: Staked Liquidity Gross
// - sld: Staked Liquidity Delta
// - oa: Outside Accumulation
//
// Returns:
//   - json: JSON object string containing the tick ID and the three encoded liquidity/accumulation values.
func (t *tickCrossEventInfo) ToString() string {
	return "{\"t\":" + utils.FormatInt(t.tickID) +
		",\"slg\":\"" + t.stakedLiquidityGross.ToString() + "\"" +
		",\"sld\":\"" + t.stakedLiquidityDelta.ToString() + "\"" +
		",\"oa\":\"" + t.outsideAccumulation.ToString() + "\"}"
}

// NewTickCrossEventInfo captures the values emitted when a swap crosses a tick.
//
// Parameters:
//   - tickID: Tick index crossed during the swap.
//   - stakedLiquidityGross: Total staked liquidity at the crossed tick.
//   - stakedLiquidityDelta: Net staked liquidity change applied at the crossed tick.
//   - outsideAccumulation: Reward-ratio accumulation outside the crossed tick.
//
// Returns:
//   - info: Event payload containing the supplied tick-cross values.
func NewTickCrossEventInfo(tickID int32, stakedLiquidityGross *u256.Uint, stakedLiquidityDelta *i256.Int, outsideAccumulation *u256.Uint) *tickCrossEventInfo {
	return &tickCrossEventInfo{
		tickID:               tickID,
		stakedLiquidityGross: stakedLiquidityGross,
		stakedLiquidityDelta: stakedLiquidityDelta,
		outsideAccumulation:  outsideAccumulation,
	}
}
