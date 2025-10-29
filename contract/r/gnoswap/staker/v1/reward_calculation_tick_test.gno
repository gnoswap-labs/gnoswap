package v1

import (
	"strconv"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/uassert"
	sr "gno.land/r/gnoswap/staker"
)

func TestEncodeInt(t *testing.T) {
	tests := []struct {
		input    int32
		expected string
	}{
		{123, "0000000123"},
		{-123, "-0000000123"},
		{0, "0000000000"},
		{2147483647, "2147483647"},   // int32 max
		{-2147483648, "-2147483648"}, // int32 min
	}

	for _, tt := range tests {
		t.Run(strconv.Itoa(int(tt.input)), func(t *testing.T) {
			uassert.Equal(t, EncodeInt(tt.input), tt.expected)
		})
	}
}

func TestTicks(t *testing.T) {
	ticks := sr.NewTicks()

	tick := ticks.Get(100)
	if tick == nil || tick.Id() != 100 {
		t.Errorf("Get(100) returned %v; want Tick with ID 100", tick)
	}

	tick.SetStakedLiquidityGross(u256.MustFromDecimal("1"))
	ticks.Tree().Set(EncodeInt(100), tick)
	uassert.True(t, ticks.Tree().Has(EncodeInt(100)))

	tick.SetStakedLiquidityGross(u256.Zero())
	ticks.Tree().Set(EncodeInt(100), tick)
	uassert.False(t, ticks.Tree().Has(EncodeInt(100)))
}

func TestTicksBasic(t *testing.T) {
	ticks := sr.NewTicks()

	tick100 := ticks.Get(100)
	uassert.True(t, ticks.Tree().Has(EncodeInt(100)))
	uassert.Equal(t, tick100.Id(), int32(100))

	tick100Again := ticks.Get(100)
	uassert.Equal(t, int32(tick100Again.Id()), int32(tick100.Id()))
	uassert.True(t, tick100Again.StakedLiquidityGross().IsZero())
	uassert.True(t, tick100Again.StakedLiquidityDelta().IsZero())

	ticks.Tree().Set(EncodeInt(100), tick100)
	uassert.False(t, ticks.Tree().Has(EncodeInt(100)))
}

func TestModifyDepositLower(t *testing.T) {
	ticks := sr.NewTicks()
	tick := ticks.Get(100)

	// initial value must be zero
	uassert.True(t, tick.StakedLiquidityGross().IsZero())
	uassert.True(t, tick.StakedLiquidityDelta().IsZero())

	// deposit +10
	liquidityDelta := i256.NewInt(10) // +10

	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositLower(50, liquidityDelta)

	// stakedLiquidityGross += +10 => 10
	// stakedLiquidityDelta += +10 => 10
	if tick.StakedLiquidityGross().ToString() != "10" || tick.StakedLiquidityDelta().ToString() != "10" {
		t.Errorf("After deposit +10, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,10",
			tick.StakedLiquidityGross(), tick.StakedLiquidityDelta())
	}

	// deposit another +5
	tickResolver.modifyDepositLower(60, i256.NewInt(5))
	// gross=15, delta=15
	if tickResolver.StakedLiquidityGross().ToString() != "15" || tickResolver.StakedLiquidityDelta().ToString() != "15" {
		t.Errorf("After deposit +5, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 15,15",
			tickResolver.StakedLiquidityGross(), tickResolver.StakedLiquidityDelta())
	}
}

func TestModifyDepositUpper(t *testing.T) {
	ticks := sr.NewTicks()
	tick := ticks.Get(200)

	// deposit +10 => modifyDepositUpper
	tickResolver := NewTickResolver(tick)
	tickResolver.modifyDepositUpper(70, i256.NewInt(10))

	// stakedLiquidityGross=10, stakedLiquidityDelta = -10
	// 	upper => delta = stakedLiquidityDelta - liquidity
	if tickResolver.StakedLiquidityGross().ToString() != "10" || tickResolver.StakedLiquidityDelta().ToString() != "-10" {
		t.Errorf("After deposit +10(upper), stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,-10",
			tickResolver.StakedLiquidityGross(), tickResolver.StakedLiquidityDelta())
	}
}

func compareRangeSlices(t *testing.T, a, b [][2]uint64) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func compareInt64Slices(t *testing.T, a, b []int64) bool {
	t.Helper()
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
