package staker

import (
	"strconv"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestEncodeInt tests the EncodeInt function.
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
			result := EncodeInt(tt.input)
			if result != tt.expected {
				t.Errorf("EncodeInt(%d) = %s; want %s", tt.input, result, tt.expected)
			}
		})
	}
}

// TestTicks tests the Ticks struct.
func TestTicks(t *testing.T) {
	ticks := NewTicks()

	// Test Get
	tick := ticks.Get(100)
	if tick == nil || tick.id != 100 {
		t.Errorf("Get(100) returned %v; want Tick with ID 100", tick)
	}

	// Test Set and Has
	tick.stakedLiquidityGross = u256.MustFromDecimal("1")
	ticks.Set(100, tick)
	if !ticks.Has(100) {
		t.Errorf("Has(100) = false; want true")
	}

	// Test Remove
	tick.stakedLiquidityGross = u256.Zero()
	ticks.Set(100, tick)
	if ticks.Has(100) {
		t.Errorf("Has(100) = true after removal; want false")
	}
}

// TestTick tests the Tick struct.
func TestTick(t *testing.T) {
	tick := &Tick{
		id:                   100,
		stakedLiquidityGross: u256.Zero(),
		stakedLiquidityDelta: i256.Zero(),
		cross:                NewUintTree(),
	}

	// Test updateCross and crossInfo
	tick.updateCross(10, true)
	tick.updateCross(20, false)
	crosses := tick.crossInfo(0, 30)

	expected := []int64{-10, 20}
	for i, v := range crosses {
		if v != expected[i] {
			t.Errorf("crossInfo returned %v; want %v", crosses, expected)
		}
	}
}
