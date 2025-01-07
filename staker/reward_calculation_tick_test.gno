package staker

import (
	"strconv"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/uassert"
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
	ticks := NewTicks()

	tick := ticks.Get(100)
	if tick == nil || tick.id != 100 {
		t.Errorf("Get(100) returned %v; want Tick with ID 100", tick)
	}

	tick.stakedLiquidityGross = u256.MustFromDecimal("1")
	ticks.Set(100, tick)
	uassert.True(t, ticks.Has(100))

	tick.stakedLiquidityGross = u256.Zero()
	ticks.Set(100, tick)
	uassert.False(t, ticks.Has(100))
}

func TestTick(t *testing.T) {
	tick := &Tick{
		id:                   100,
		stakedLiquidityGross: u256.Zero(),
		stakedLiquidityDelta: i256.Zero(),
		cross:                NewUintTree(),
	}

	tick.updateCross(10, true)
	tick.updateCross(20, false)
	crosses := tick.crossInfo(0, 30)

	expected := []int64{-10, 20}
	for i, v := range crosses {
		uassert.Equal(t, v, expected[i])
	}
}

func TestTicksBasic(t *testing.T) {
	ticks := NewTicks()

	tick100 := ticks.Get(100)
	uassert.True(t, ticks.Has(100))
	uassert.Equal(t, tick100.id, 100)

	tick100Again := ticks.Get(100)
	uassert.Equal(t, tick100Again, tick100)
	uassert.True(t, tick100Again.stakedLiquidityGross.IsZero())
	uassert.True(t, tick100Again.stakedLiquidityDelta.IsZero())

	ticks.Set(100, tick100)
	uassert.False(t, ticks.Has(100))
}

func TestTickCrossInfo(t *testing.T) {
	ticks := NewTicks()
	tick := ticks.Get(42)

	tick.updateCross(10, true)  // backward-cross
	tick.updateCross(20, false) // forward-cross
	tick.updateCross(30, true)  // backward-cross
	tick.updateCross(50, false) // forward-cross

	// 1 <= block <= 40
	crosses := tick.crossInfo(1, 40)
	// block=10, zeroForOne=true => -10
	// block=20, zeroForOne=false => +20
	// block=30, zeroForOne=true => -30
	// block=50 (out of range. no need to care about this)

	expected := []int64{-10, 20, -30}
	if !compareInt64Slices(t, crosses, expected) {
		t.Errorf("crossInfo(1, 40) = %v; want %v", crosses, expected)
	}

	crosses2 := tick.crossInfo(25, 100)
	expected2 := []int64{-30, 50}
	if !compareInt64Slices(t, crosses2, expected2) {
		t.Errorf("crossInfo(25, 100) = %v; want %v", crosses2, expected2)
	}
}

func TestTickPreviousCross(t *testing.T) {
	ticks := NewTicks()
	tick := ticks.Get(1)

	tick.updateCross(10, false)

	tick.updateCross(20, true)

	uassert.False(t, tick.previousCross(1))
	uassert.False(t, tick.previousCross(10))
	uassert.False(t, tick.previousCross(11))
	uassert.False(t, tick.previousCross(20))
	uassert.True(t, tick.previousCross(21))
}

func TestModifyDepositLower(t *testing.T) {
	ticks := NewTicks()
	tick := ticks.Get(100)

	// initial value must be zero
	uassert.True(t, tick.stakedLiquidityGross.IsZero())
	uassert.True(t, tick.stakedLiquidityDelta.IsZero())

	// deposit +10
	liquidityDelta := i256.NewInt(10) // +10
	tick.modifyDepositLower(50, 95, liquidityDelta)

	// stakedLiquidityGross += +10 => 10
	// stakedLiquidityDelta += +10 => 10
	if tick.stakedLiquidityGross.ToString() != "10" || tick.stakedLiquidityDelta.ToString() != "10" {
		t.Errorf("After deposit +10, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,10",
			tick.stakedLiquidityGross, tick.stakedLiquidityDelta)
	}

	// deposit another +5
	tick.modifyDepositLower(60, 95, i256.NewInt(5))
	// gross=15, delta=15
	if tick.stakedLiquidityGross.ToString() != "15" || tick.stakedLiquidityDelta.ToString() != "15" {
		t.Errorf("After deposit +5, stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 15,15",
			tick.stakedLiquidityGross, tick.stakedLiquidityDelta)
	}
}

func TestModifyDepositUpper(t *testing.T) {
	ticks := NewTicks()
	tick := ticks.Get(200)

	// deposit +10 => modifyDepositUpper
	tick.modifyDepositUpper(70, 195, i256.NewInt(10))

	// stakedLiquidityGross=10, stakedLiquidityDelta = -10
	// 	upper => delta = stakedLiquidityDelta - liquidity
	if tick.stakedLiquidityGross.ToString() != "10" || tick.stakedLiquidityDelta.ToString() != "-10" {
		t.Errorf("After deposit +10(upper), stakedLiquidityGross=%v, stakedLiquidityDelta=%v; want 10,-10",
			tick.stakedLiquidityGross, tick.stakedLiquidityDelta)
	}
}

func TestForEachEligibleInterval(t *testing.T) {
	type CrossTest struct {
		startHeight      int64
		endHeight        int64
		currentInRange   bool
		tickUpperCross   []int64
		tickLowerCross   []int64
		wantRanges       [][2]uint64
		wantFinalInRange bool
	}

	tests := []CrossTest{
		{
			startHeight:    0,
			endHeight:      100,
			currentInRange: false,
			// block=10(backward cross=>enter range), block=30(forward cross=>exit range)
			tickUpperCross:   []int64{-10, 30},
			tickLowerCross:   []int64{},
			wantRanges:       [][2]uint64{{10, 30}},
			wantFinalInRange: false,
		},
		{
			startHeight:    0,
			endHeight:      40,
			currentInRange: false,
			// block=5(backward->enter), block=10(backward->enter again?), block=35(forward->exit)
			tickUpperCross: []int64{-5, -10, 35},
			tickLowerCross: []int64{},
			// -5 => block=5(backward => enter), -10 => block=10(backward => enter, already in-range but duplicate enter),
			// 35 => block=35(forward => exit). Therefore, a single interval (5..35).
			wantRanges:       [][2]uint64{{5, 35}},
			wantFinalInRange: false,
		},
		{
			startHeight:    0,
			endHeight:      100,
			currentInRange: false,
			tickUpperCross: []int64{-10, 20, -30, 40},
			tickLowerCross: []int64{},
			// Interpretation of tickUpperCross:
			//    -10 => block=10, backward cross => enter range
			//     20 => block=20, forward cross => exit range   => (10..20)
			//    -30 => block=30, backward cross => enter range => (30..??)
			//     40 => block=40, forward cross => exit range   => (30..40)
			// Ultimately, the intervals (10..20) and (30..40) become in-range and then end.
			// wantFinalInRange=false
			wantRanges:       [][2]uint64{{10, 20}, {30, 40}},
			wantFinalInRange: false,
		},
		{
			startHeight:    0,
			endHeight:      50,
			currentInRange: false,
			tickUpperCross: []int64{-10, 20},
			tickLowerCross: []int64{30},
			// tickUpperCross:
			//   -10 => block=10, backward => enter range => (10..??)
			//    20 => block=20, forward => exit range    => (10..20)
			// tickLowerCross:
			//    30 => block=30, (positive=forward cross) => enter range => (30..??)
			// endHeight=50 => ends without exit => (30..50)
			wantRanges:       [][2]uint64{{10, 20}, {30, 50}},
			wantFinalInRange: true,
		},
	}

	for i, tt := range tests {
		var gotRanges [][2]uint64
		f := func(s, e uint64) {
			gotRanges = append(gotRanges, [2]uint64{s, e})
		}
		inRange, remUpper, remLower := ForEachEligibleInterval(
			tt.startHeight, tt.endHeight, tt.currentInRange,
			tt.tickUpperCross, tt.tickLowerCross,
			f,
		)
		if inRange != tt.wantFinalInRange {
			t.Errorf("Test #%d: final inRange=%v; want %v", i, inRange, tt.wantFinalInRange)
		}
		if len(remUpper) != 0 || len(remLower) != 0 {
			t.Errorf("Test #%d: expected no leftover crosses, got remUpper=%v, remLower=%v",
				i, remUpper, remLower)
		}
		if !compareRangeSlices(t, gotRanges, tt.wantRanges) {
			t.Errorf("Test #%d: got ranges=%v; want %v", i, gotRanges, tt.wantRanges)
		}
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
