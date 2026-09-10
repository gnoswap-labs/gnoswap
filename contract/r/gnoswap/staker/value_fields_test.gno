package staker

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestTickSignedLiquidityDeltaValueIsolation(t *testing.T) {
	tick := NewTick(-10)
	if tick.StakedLiquidityDelta() == nil {
		panic("constructor omitted present zero liquidity delta")
	}
	uassert.Equal(t, "0", tick.StakedLiquidityDelta().ToString())

	minDelta := i256.MinInt256()
	minDeltaString := minDelta.ToString()
	tick.SetStakedLiquidityDelta(minDelta)

	minDelta.SetInt64(0)
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())

	result := tick.StakedLiquidityDelta()
	result.SetInt64(0)
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())

	zeroDelta := i256.Zero()
	tick.SetStakedLiquidityDelta(zeroDelta)
	zeroDelta.SetInt64(1)
	uassert.Equal(t, "0", tick.StakedLiquidityDelta().ToString())

	tick.SetStakedLiquidityDelta(i256.MinInt256())
	clone := tick.Clone()
	clone.SetStakedLiquidityDelta(i256.Zero())
	uassert.Equal(t, minDeltaString, tick.StakedLiquidityDelta().ToString())
}
