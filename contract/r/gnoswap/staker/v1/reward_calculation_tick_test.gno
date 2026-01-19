package v1

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/uassert"
	sr "gno.land/r/gnoswap/staker"
)

func TestTicks(t *testing.T) {
	ticks := sr.NewTicks()

	tick := ticks.Get(100)
	if tick == nil || tick.Id() != 100 {
		t.Errorf("Get(100) returned %v; want Tick with ID 100", tick)
	}

	tick.SetStakedLiquidityGross(u256.MustFromDecimal("1"))
	ticks.SetTick(100, tick)
	uassert.True(t, ticks.Has(100))

	tick.SetStakedLiquidityGross(u256.Zero())
	ticks.SetTick(100, tick)
	uassert.False(t, ticks.Has(100))
}

func TestTicksBasic(t *testing.T) {
	ticks := sr.NewTicks()

	tick100 := ticks.Get(100)
	uassert.True(t, ticks.Has(100))
	uassert.Equal(t, tick100.Id(), int32(100))

	tick100Again := ticks.Get(100)
	uassert.Equal(t, int32(tick100Again.Id()), int32(tick100.Id()))
	uassert.True(t, tick100Again.StakedLiquidityGross().IsZero())
	uassert.True(t, tick100Again.StakedLiquidityDelta().IsZero())

	ticks.SetTick(100, tick100)
	uassert.False(t, ticks.Has(100))
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

// Test NewTickResolver
func TestNewTickResolver(t *testing.T) {
	tests := []struct {
		name   string
		tickID int32
	}{
		{
			name:   "create tick resolver for tick 100",
			tickID: 100,
		},
		{
			name:   "create tick resolver for tick -100",
			tickID: -100,
		},
		{
			name:   "create tick resolver for tick 0",
			tickID: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticks := sr.NewTicks()
			tick := ticks.Get(tt.tickID)

			tickResolver := NewTickResolver(tick)

			uassert.NotNil(t, tickResolver)
			uassert.NotNil(t, tickResolver.Tick)
			uassert.Equal(t, tt.tickID, tick.Id())
		})
	}
}

// Test CurrentOutsideAccumulation
func TestCurrentOutsideAccumulation(t *testing.T) {
	tests := []struct {
		name           string
		tickID         int32
		setupFunc      func(*sr.Tick)
		queryTimestamp int64
		expectedIsZero bool
	}{
		{
			name:   "empty accumulation returns zero",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				// No setup - empty accumulation
			},
			queryTimestamp: 1000,
			expectedIsZero: true,
		},
		{
			name:   "single accumulation entry",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				tick.OutsideAccumulation().Set(500, u256.NewUint(12345))
			},
			queryTimestamp: 1000,
			expectedIsZero: false,
		},
		{
			name:   "multiple accumulation entries",
			tickID: 100,
			setupFunc: func(tick *sr.Tick) {
				tick.OutsideAccumulation().Set(100, u256.NewUint(1000))
				tick.OutsideAccumulation().Set(500, u256.NewUint(5000))
				tick.OutsideAccumulation().Set(1000, u256.NewUint(10000))
			},
			queryTimestamp: 1500,
			expectedIsZero: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticks := sr.NewTicks()
			tick := ticks.Get(tt.tickID)

			if tt.setupFunc != nil {
				tt.setupFunc(tick)
			}

			tickResolver := NewTickResolver(tick)
			result := tickResolver.CurrentOutsideAccumulation(tt.queryTimestamp)

			uassert.NotNil(t, result)
			if tt.expectedIsZero {
				uassert.True(t, result.IsZero())
			} else {
				uassert.False(t, result.IsZero())
			}
		})
	}
}

// Test updateCurrentOutsideAccumulation
func TestUpdateCurrentOutsideAccumulation(t *testing.T) {
	tests := []struct {
		name         string
		tickID       int32
		currentAcc   *u256.Uint
		globalAcc    *u256.Uint
		timestamp    int64
		expectedDiff string
	}{
		{
			name:         "update with zero current accumulation",
			tickID:       100,
			currentAcc:   u256.Zero(),
			globalAcc:    u256.NewUint(1000),
			timestamp:    500,
			expectedDiff: "1000",
		},
		{
			name:         "update with non-zero current accumulation",
			tickID:       100,
			currentAcc:   u256.NewUint(300),
			globalAcc:    u256.NewUint(1000),
			timestamp:    500,
			expectedDiff: "700",
		},
		{
			name:         "update with equal accumulations",
			tickID:       100,
			currentAcc:   u256.NewUint(500),
			globalAcc:    u256.NewUint(500),
			timestamp:    500,
			expectedDiff: "0",
		},
		{
			name:         "update with underflow difference",
			tickID:       100,
			currentAcc:   u256.NewUint(600),
			globalAcc:    u256.NewUint(500),
			timestamp:    500,
			expectedDiff: "115792089237316195423570985008687907853269984665640564039457584007913129639836",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ticks := sr.NewTicks()
			tick := ticks.Get(tt.tickID)

			// Set up current accumulation
			if !tt.currentAcc.IsZero() {
				tick.OutsideAccumulation().Set(tt.timestamp-100, tt.currentAcc)
			}

			tickResolver := NewTickResolver(tick)
			tickResolver.updateCurrentOutsideAccumulation(tt.timestamp, tt.globalAcc)

			// Verify the update
			newAcc := tickResolver.CurrentOutsideAccumulation(tt.timestamp)
			uassert.Equal(t, tt.expectedDiff, newAcc.ToString())
		})
	}
}
