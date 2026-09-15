package pool

import (
	"gno.land/p/gnoswap/utils"

	pl "gno.land/r/gnoswap/pool"
)

type tickEventInfo struct {
	tickID   int32
	tickInfo pl.TickInfo
}

// ToString serializes tick event information as a compact JSON object.
// The object includes the tick index and every persisted TickInfo field using
// the short event keys documented below.
//
// Returns:
//   - string: JSON object containing tick, liquidity, fee-growth, cumulative-time, and initialization fields.
func (t *tickEventInfo) ToString() string {
	return "{\"t\":" + utils.FormatInt(t.tickID) +
		",\"lg\":\"" + t.tickInfo.LiquidityGross() + "\"" +
		",\"ln\":\"" + t.tickInfo.LiquidityNet() + "\"" +
		",\"fg0\":\"" + t.tickInfo.FeeGrowthOutside0X128() + "\"" +
		",\"fg1\":\"" + t.tickInfo.FeeGrowthOutside1X128() + "\"" +
		",\"tco\":\"" + utils.FormatInt(t.tickInfo.TickCumulativeOutside()) + "\"" +
		",\"spl\":\"" + t.tickInfo.SecondsPerLiquidityOutsideX128() + "\"" +
		",\"so\":\"" + utils.FormatUint(t.tickInfo.SecondsOutside()) + "\"" +
		",\"i\":\"" + utils.FormatBool(t.tickInfo.Initialized()) + "\"}"
}

// NewTickEventInfo creates event data for one tick and its persisted state.
//
// Parameters:
//   - tickID: tick index represented by the event.
//   - tickInfo: tick state whose fields are serialized by ToString.
//
// Returns:
//   - *tickEventInfo: event information value retaining the supplied tick index and state.
func NewTickEventInfo(tickID int32, tickInfo pl.TickInfo) *tickEventInfo {
	return &tickEventInfo{
		tickID:   tickID,
		tickInfo: tickInfo,
	}
}
