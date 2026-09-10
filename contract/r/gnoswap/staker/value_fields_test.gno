package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestTickGrossLiquidityValueIsolation(t *testing.T) {
	tick := NewTick(-10)
	if tick.StakedLiquidityGross() == nil {
		panic("constructor omitted present zero gross liquidity")
	}
	uassert.Equal(t, "0", tick.StakedLiquidityGross().ToString())

	maxGross := u256.MaxUint256()
	maxGrossString := maxGross.ToString()
	tick.SetStakedLiquidityGross(maxGross)

	maxGross.Clear()
	uassert.Equal(t, maxGrossString, tick.StakedLiquidityGross().ToString())

	result := tick.StakedLiquidityGross()
	result.Clear()
	uassert.Equal(t, maxGrossString, tick.StakedLiquidityGross().ToString())

	zeroGross := u256.Zero()
	tick.SetStakedLiquidityGross(zeroGross)
	zeroGross.Set(u256.One())
	uassert.Equal(t, "0", tick.StakedLiquidityGross().ToString())

	tick.SetStakedLiquidityGross(u256.MaxUint256())
	clone := tick.Clone()
	clone.SetStakedLiquidityGross(u256.Zero())
	uassert.Equal(t, maxGrossString, tick.StakedLiquidityGross().ToString())
}
