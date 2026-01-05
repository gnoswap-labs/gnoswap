package gns

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestNewEmissionState(t *testing.T) {
	tests := []struct {
		name           string
		startHeight    int64
		startTimestamp int64
		wantEndTs      int64
		shouldPanic    bool
		panicMsg       string
	}{
		// Success cases
		{
			name:           "success - zero values",
			startHeight:    0,
			startTimestamp: 0,
			wantEndTs:      SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "success - positive values",
			startHeight:    100,
			startTimestamp: 1000,
			wantEndTs:      1000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "success - large timestamp",
			startHeight:    999999,
			startTimestamp: 1700000000,
			wantEndTs:      1700000000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "success - negative height",
			startHeight:    -100,
			startTimestamp: 1000,
			wantEndTs:      1000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "success - negative timestamp",
			startHeight:    1,
			startTimestamp: -1000,
			wantEndTs:      -1000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "success - max safe timestamp",
			startHeight:    1,
			startTimestamp: math.MaxInt64 - (SECONDS_IN_YEAR * HALVING_END_YEAR),
			wantEndTs:      math.MaxInt64 - 1,
		},
		// Panic cases
		{
			name:           "panic - overflow near MaxInt64",
			startHeight:    1,
			startTimestamp: math.MaxInt64 - (SECONDS_IN_YEAR * HALVING_END_YEAR) + 2,
			shouldPanic:    true,
			panicMsg:       "int64 addition overflow",
		},
		{
			name:           "panic - overflow at MaxInt64",
			startHeight:    1,
			startTimestamp: math.MaxInt64,
			shouldPanic:    true,
			panicMsg:       "int64 addition overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					NewEmissionState(tt.startHeight, tt.startTimestamp)
				})
				return
			}

			es := NewEmissionState(tt.startHeight, tt.startTimestamp)

			uassert.Equal(t, tt.startHeight, es.getStartHeight())
			uassert.Equal(t, tt.startTimestamp, es.getStartTimestamp())
			uassert.Equal(t, tt.wantEndTs, es.getEndTimestamp())
			uassert.True(t, es.getHalvingData() != nil)
		})
	}
}

func TestIsInitialized(t *testing.T) {
	tests := []struct {
		name           string
		startHeight    int64
		startTimestamp int64
		want           bool
	}{
		{
			name:           "not initialized - both zero",
			startHeight:    0,
			startTimestamp: 0,
			want:           false,
		},
		{
			name:           "not initialized - only height set",
			startHeight:    100,
			startTimestamp: 0,
			want:           false,
		},
		{
			name:           "not initialized - only timestamp set",
			startHeight:    0,
			startTimestamp: 1000,
			want:           false,
		},
		{
			name:           "initialized - both positive",
			startHeight:    100,
			startTimestamp: 1000,
			want:           true,
		},
		{
			name:           "initialized - negative height with positive timestamp",
			startHeight:    -1,
			startTimestamp: 1000,
			want:           true,
		},
		{
			name:           "initialized - positive height with negative timestamp",
			startHeight:    100,
			startTimestamp: -1,
			want:           true,
		},
		{
			name:           "initialized - both negative",
			startHeight:    -1,
			startTimestamp: -1,
			want:           true,
		},
		{
			name:           "initialized - min int64 values",
			startHeight:    math.MinInt64,
			startTimestamp: 1,
			want:           true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(tt.startHeight, tt.startTimestamp)
			got := es.isInitialized()
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestIsActive(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)
	endTs := es.getEndTimestamp()

	tests := []struct {
		name      string
		timestamp int64
		want      bool
	}{
		// Before emission period
		{"not active - far before start", startTs - 10000, false},
		{"not active - one second before start", startTs - 1, false},

		// At boundaries
		{"active - exactly at start", startTs, true},
		{"active - one second after start", startTs + 1, true},
		{"active - one second before end", endTs - 1, true},
		{"active - exactly at end", endTs, true},
		{"not active - one second after end", endTs + 1, false},

		// Middle of period
		{"active - middle of emission", startTs + (endTs-startTs)/2, true},

		// Far after emission
		{"not active - far after end", endTs + 10000, false},

		// Edge cases with extreme values
		{"not active - negative timestamp", -1, false},
		{"not active - zero timestamp", 0, false},
		{"not active - max int64", math.MaxInt64, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.isActive(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestIsActive_UninitializedState(t *testing.T) {
	es := NewEmissionState(0, 0) // uninitialized

	tests := []struct {
		name      string
		timestamp int64
	}{
		{"negative timestamp", -1000},
		{"zero", 0},
		{"one", 1},
		{"large positive", 1000},
		{"very large", 999999999},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.False(t, es.isActive(tt.timestamp), "uninitialized state should never be active")
		})
	}
}

func TestIsActive_NegativeStartTimestamp(t *testing.T) {
	es := NewEmissionState(1, -1000)

	tests := []struct {
		name      string
		timestamp int64
		want      bool
	}{
		{"active - at start", -1000, true},
		{"active - after start", -500, true},
		{"not active - before start", -1001, false},
		{"active - at zero", 0, true},
		{"active - positive", 1000, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.isActive(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestIsEnded(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)
	endTs := es.getEndTimestamp()

	tests := []struct {
		name      string
		timestamp int64
		want      bool
	}{
		// Before emission ends
		{"not ended - far before start", startTs - 10000, false},
		{"not ended - at start", startTs, false},
		{"not ended - middle of emission", startTs + (endTs-startTs)/2, false},
		{"not ended - one second before end", endTs - 1, false},
		{"not ended - exactly at end", endTs, false},

		// After emission ends
		{"ended - one second after end", endTs + 1, true},
		{"ended - far after end", endTs + 1000000, true},

		// Edge cases
		{"ended - max int64", math.MaxInt64, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.isEnded(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestGetCurrentYear(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name      string
		timestamp int64
		want      int64
	}{
		// Before emission
		{"year 0 - before start", startTs - 1, 0},
		{"year 0 - far before start", startTs - 10000, 0},

		// Year 1 boundaries
		{"year 1 - first second", startTs, 1},
		{"year 1 - middle", startTs + SECONDS_IN_YEAR/2, 1},
		{"year 1 - last second", startTs + SECONDS_IN_YEAR - 1, 1},

		// Year 2 boundaries
		{"year 2 - first second", startTs + SECONDS_IN_YEAR, 2},
		{"year 2 - last second", startTs + (2*SECONDS_IN_YEAR - 1), 2},

		// Year transitions
		{"year 6 - last second", startTs + (6*SECONDS_IN_YEAR - 1), 6},
		{"year 7 - first second", startTs + (6 * SECONDS_IN_YEAR), 7},

		// Year 12 (last year)
		{"year 12 - first second", startTs + (11 * SECONDS_IN_YEAR), 12},
		{"year 12 - last second", startTs + (12*SECONDS_IN_YEAR - 1), 12},

		// After emission
		{"year 0 - exactly after year 12", startTs + (12 * SECONDS_IN_YEAR), 0},
		{"year 0 - far after emission", startTs + (15 * SECONDS_IN_YEAR), 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getCurrentYear(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestGetCurrentYear_AllYearBoundaries(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Test each year from 1 to 12
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		yearStartTs := startTs + (year-1)*SECONDS_IN_YEAR
		yearEndTs := startTs + year*SECONDS_IN_YEAR - 1
		yearMidTs := yearStartTs + SECONDS_IN_YEAR/2

		tests := []struct {
			name string
			ts   int64
		}{
			{"start", yearStartTs},
			{"middle", yearMidTs},
			{"end", yearEndTs},
		}

		for _, tt := range tests {
			t.Run("year_"+formatInt(year)+"_"+tt.name, func(t *testing.T) {
				got := es.getCurrentYear(tt.ts)
				uassert.Equal(t, year, got)
			})
		}
	}
}

func TestGetters(t *testing.T) {
	tests := []struct {
		name           string
		startHeight    int64
		startTimestamp int64
	}{
		{"zero values", 0, 0},
		{"positive values", 100, 1000},
		{"large values", 1000000, 1700000000},
		{"negative height", -100, 1000},
		{"negative timestamp", 100, -1000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(tt.startHeight, tt.startTimestamp)

			uassert.Equal(t, tt.startHeight, es.getStartHeight())
			uassert.Equal(t, tt.startTimestamp, es.getStartTimestamp())

			expectedEnd := tt.startTimestamp + SECONDS_IN_YEAR*HALVING_END_YEAR - 1
			uassert.Equal(t, expectedEnd, es.getEndTimestamp())
			uassert.True(t, es.getHalvingData() != nil)
		})
	}
}

func TestGetHalvingYearStartTimestamp(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name     string
		year     int64
		expected int64
	}{
		// Valid years
		{"year 1", 1, startTs},
		{"year 2", 2, startTs + SECONDS_IN_YEAR},
		{"year 6", 6, startTs + 5*SECONDS_IN_YEAR},
		{"year 12", 12, startTs + 11*SECONDS_IN_YEAR},

		// Invalid years
		{"invalid year 0", 0, 0},
		{"invalid year -1", -1, 0},
		{"invalid year 13", 13, 0},
		{"invalid year 100", 100, 0},
		{"invalid year -100", -100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearStartTimestamp(tt.year)
			uassert.Equal(t, tt.expected, got)
		})
	}
}

func TestGetHalvingYearEndTimestamp(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name     string
		year     int64
		expected int64
	}{
		// Valid years
		{"year 1", 1, startTs + SECONDS_IN_YEAR - 1},
		{"year 2", 2, startTs + 2*SECONDS_IN_YEAR - 1},
		{"year 6", 6, startTs + 6*SECONDS_IN_YEAR - 1},
		{"year 12", 12, startTs + 12*SECONDS_IN_YEAR - 1},

		// Invalid years
		{"invalid year 0", 0, 0},
		{"invalid year -1", -1, 0},
		{"invalid year 13", 13, 0},
		{"invalid year 100", 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearEndTimestamp(tt.year)
			uassert.Equal(t, tt.expected, got)
		})
	}
}

func TestHalvingYearTimestampContinuity(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Verify that year boundaries are continuous
	for year := int64(1); year < HALVING_END_YEAR; year++ {
		t.Run("year_"+formatInt(year)+"_to_"+formatInt(year+1), func(t *testing.T) {
			endTs := es.getHalvingYearEndTimestamp(year)
			nextStartTs := es.getHalvingYearStartTimestamp(year + 1)

			uassert.Equal(t, endTs+1, nextStartTs)
		})
	}
}

func TestGetHalvingYearAmountPerSecond(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name     string
		year     int64
		expected int64
	}{
		// Valid years - calculated from halving amounts
		{"year 1", 1, GetHalvingAmountsPerYear(1) / SECONDS_IN_YEAR},
		{"year 2", 2, GetHalvingAmountsPerYear(2) / SECONDS_IN_YEAR},
		{"year 3", 3, GetHalvingAmountsPerYear(3) / SECONDS_IN_YEAR},
		{"year 6", 6, GetHalvingAmountsPerYear(6) / SECONDS_IN_YEAR},
		{"year 12", 12, GetHalvingAmountsPerYear(12) / SECONDS_IN_YEAR},

		// Invalid years
		{"invalid year 0", 0, 0},
		{"invalid year -1", -1, 0},
		{"invalid year 13", 13, 0},
		{"invalid year 100", 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearAmountPerSecond(tt.year)
			uassert.Equal(t, tt.expected, got)
		})
	}
}

func TestHalvingRates(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name       string
		year       int64
		compareTo  int64
		multiplier int64 // year rate should be year1Rate / multiplier
	}{
		{"years 1 and 2 same rate", 2, 1, 1},
		{"year 3 half of year 1", 3, 1, 2},
		{"year 4 half of year 1", 4, 1, 2},
		{"year 5 quarter of year 1", 5, 1, 4},
		{"year 7 eighth of year 1", 7, 1, 8},
		{"year 11 sixty-fourth of year 1", 11, 1, 16},
	}

	year1Rate := es.getHalvingYearAmountPerSecond(1)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearAmountPerSecond(tt.year)
			expected := year1Rate / tt.multiplier
			uassert.Equal(t, expected, got)
		})
	}
}

func TestGetHalvingYearAccumulatedAmount(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name     string
		year     int64
		expected int64
	}{
		// Valid years - initial value should be 0
		{"year 1 initial", 1, 0},
		{"year 6 initial", 6, 0},
		{"year 12 initial", 12, 0},

		// Invalid years
		{"invalid year 0", 0, 0},
		{"invalid year -1", -1, 0},
		{"invalid year 13", 13, 0},
		{"invalid year 100", 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearAccumulatedAmount(tt.year)
			uassert.Equal(t, tt.expected, got)
		})
	}
}

func TestGetHalvingYearLeftAmount(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name     string
		year     int64
		expected int64
	}{
		// Valid years - initial left should equal max
		{"year 1 initial", 1, GetHalvingAmountsPerYear(1)},
		{"year 6 initial", 6, GetHalvingAmountsPerYear(6)},
		{"year 12 initial", 12, GetHalvingAmountsPerYear(12)},

		// Invalid years
		{"invalid year 0", 0, 0},
		{"invalid year -1", -1, 0},
		{"invalid year 13", 13, 0},
		{"invalid year 100", 100, 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getHalvingYearLeftAmount(tt.year)
			uassert.Equal(t, tt.expected, got)
		})
	}
}

func TestAddHalvingYearAccumulatedAmount(t *testing.T) {
	tests := []struct {
		name        string
		year        int64
		amount      int64
		shouldError bool
	}{
		// Valid cases
		{"valid year 1", 1, 1000, false},
		{"valid year 6", 6, 5000, false},
		{"valid year 12", 12, 10000, false},
		{"zero amount", 5, 0, false},
		{"large amount", 3, 999999999, false},

		// Invalid year cases
		{"invalid year 0", 0, 1000, true},
		{"invalid year 13", 13, 1000, true},
		{"invalid negative year", -1, 1000, true},
		{"invalid year 100", 100, 1000, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)
			err := es.addHalvingYearAccumulatedAmount(tt.year, tt.amount)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				got := es.getHalvingYearAccumulatedAmount(tt.year)
				uassert.Equal(t, tt.amount, got)
			}
		})
	}
}

func TestAddHalvingYearAccumulatedAmount_Cumulative(t *testing.T) {
	tests := []struct {
		name    string
		amounts []int64
	}{
		{"single add", []int64{100}},
		{"multiple adds", []int64{100, 200, 300, 400, 500}},
		{"add zeros", []int64{0, 100, 0, 200, 0}},
		{"large amounts", []int64{1000000, 2000000, 3000000}},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)
			expectedTotal := int64(0)

			for _, amount := range tt.amounts {
				err := es.addHalvingYearAccumulatedAmount(1, amount)
				uassert.NoError(t, err)
				expectedTotal += amount
				got := es.getHalvingYearAccumulatedAmount(1)
				uassert.Equal(t, expectedTotal, got)
			}
		})
	}
}

func TestAddHalvingYearAccumulatedAmount_Overflow(t *testing.T) {
	tests := []struct {
		name         string
		initialValue int64
		addAmount    int64
		panicMsg     string
	}{
		{
			name:         "overflow at boundary",
			initialValue: math.MaxInt64 - 100,
			addAmount:    200,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "overflow with max value",
			initialValue: math.MaxInt64,
			addAmount:    1,
			panicMsg:     "int64 addition overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)
			es.halvingData.setAccumAmount(1, tt.initialValue)

			uassert.PanicsWithMessage(t, tt.panicMsg, func() {
				es.addHalvingYearAccumulatedAmount(1, tt.addAmount)
			})
		})
	}
}

func TestSubHalvingYearLeftAmount(t *testing.T) {
	tests := []struct {
		name        string
		year        int64
		amount      int64
		shouldError bool
	}{
		{"valid year 1", 1, 1000, false},
		{"valid year 6", 6, 5000, false},
		{"valid year 12", 12, 10000, false},
		{"zero amount", 5, 0, false},

		// Invalid year cases
		{"invalid year 0", 0, 1000, true},
		{"invalid year 13", 13, 1000, true},
		{"invalid negative year", -1, 1000, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)
			initialLeft := es.getHalvingYearLeftAmount(tt.year)
			err := es.subHalvingYearLeftAmount(tt.year, tt.amount)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				got := es.getHalvingYearLeftAmount(tt.year)
				uassert.Equal(t, initialLeft-tt.amount, got)
			}
		})
	}
}

func TestSubHalvingYearLeftAmount_Underflow(t *testing.T) {
	tests := []struct {
		name         string
		initialValue int64
		subAmount    int64
		panicMsg     string
	}{
		{
			name:         "underflow at boundary",
			initialValue: math.MinInt64 + 100,
			subAmount:    200,
			panicMsg:     "int64 subtraction underflow",
		},
		{
			name:         "underflow with min value",
			initialValue: math.MinInt64,
			subAmount:    1,
			panicMsg:     "int64 subtraction underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)
			es.halvingData.setLeftAmount(1, tt.initialValue)

			uassert.PanicsWithMessage(t, tt.panicMsg, func() {
				es.subHalvingYearLeftAmount(1, tt.subAmount)
			})
		})
	}
}

func TestAddSubConsistency(t *testing.T) {
	tests := []struct {
		name       string
		year       int64
		emitAmount int64
	}{
		{"year 1 small amount", 1, 1000000},
		{"year 6 medium amount", 6, 5000000},
		{"year 12 large amount", 12, 10000000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset emission state for each test
			es := NewEmissionState(1, 10000)
			maxAmount := GetHalvingAmountsPerYear(tt.year)

			// Add to accumulated
			err := es.addHalvingYearAccumulatedAmount(tt.year, tt.emitAmount)
			uassert.NoError(t, err)

			// Subtract from left
			err = es.subHalvingYearLeftAmount(tt.year, tt.emitAmount)
			uassert.NoError(t, err)

			// Verify consistency: accum + left = max
			accum := es.getHalvingYearAccumulatedAmount(tt.year)
			left := es.getHalvingYearLeftAmount(tt.year)
			uassert.Equal(t, maxAmount, accum+left)
		})
	}
}

func TestGetEmissionState(t *testing.T) {
	tests := []struct {
		name string
	}{
		{"first call returns initialized state"},
		{"second call returns same instance"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetEmissionState(t)

			es := getEmissionState()
			uassert.True(t, es != nil)
			uassert.True(t, es.isInitialized())

			// Getting again should return same instance
			es2 := getEmissionState()
			uassert.Equal(t, es.getStartHeight(), es2.getStartHeight())
			uassert.Equal(t, es.getStartTimestamp(), es2.getStartTimestamp())
		})
	}
}

func TestEmissionStateYearBoundaryPrecision(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Test exact second transitions
	for year := int64(1); year < HALVING_END_YEAR; year++ {
		t.Run("year_"+formatInt(year)+"_to_"+formatInt(year+1), func(t *testing.T) {
			lastSecondOfYear := es.getHalvingYearEndTimestamp(year)
			firstSecondOfNextYear := es.getHalvingYearStartTimestamp(year + 1)

			// Last second should be year N
			gotYear := es.getCurrentYear(lastSecondOfYear)
			uassert.Equal(t, year, gotYear)

			// First second of next year should be year N+1
			gotNextYear := es.getCurrentYear(firstSecondOfNextYear)
			uassert.Equal(t, year+1, gotNextYear)

			// Difference should be exactly 1 second
			uassert.Equal(t, int64(1), firstSecondOfNextYear-lastSecondOfYear)
		})
	}
}

func TestEmissionStateTotalEmission(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Sum of all years' left amounts should equal MAX_EMISSION_AMOUNT
	totalLeft := int64(0)
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		totalLeft += es.getHalvingYearLeftAmount(year)
	}
	uassert.Equal(t, MAX_EMISSION_AMOUNT, totalLeft)
}

func TestEmissionStateHalvingDataIntegrity(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)
	halvingData := es.getHalvingData()

	uassert.True(t, halvingData != nil)

	// Verify halving data matches emission state getters for all years
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		t.Run("year_"+formatInt(year), func(t *testing.T) {
			uassert.Equal(t, halvingData.getStartTimestamp(year), es.getHalvingYearStartTimestamp(year))
			uassert.Equal(t, halvingData.getEndTimestamp(year), es.getHalvingYearEndTimestamp(year))
			uassert.Equal(t, halvingData.getAmountPerSecond(year), es.getHalvingYearAmountPerSecond(year))
			uassert.Equal(t, halvingData.getAccumAmount(year), es.getHalvingYearAccumulatedAmount(year))
			uassert.Equal(t, halvingData.getLeftAmount(year), es.getHalvingYearLeftAmount(year))
		})
	}
}

func TestEmissionStateEndTimestampCalculation(t *testing.T) {
	tests := []struct {
		name           string
		startTimestamp int64
	}{
		{"zero", 0},
		{"positive", 1000},
		{"large", 1700000000},
		{"negative", -1000},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, tt.startTimestamp)

			// End timestamp should be exactly 12 years - 1 second from start
			expectedEnd := tt.startTimestamp + SECONDS_IN_YEAR*HALVING_END_YEAR - 1
			uassert.Equal(t, expectedEnd, es.getEndTimestamp())

			// Verify end timestamp matches year 12 end timestamp
			year12End := es.getHalvingYearEndTimestamp(12)
			uassert.Equal(t, year12End, es.getEndTimestamp())
		})
	}
}

func TestEmissionStateRepeatedOperations(t *testing.T) {
	tests := []struct {
		name       string
		iterations int
	}{
		{"10 iterations", 10},
		{"50 iterations", 50},
		{"100 iterations", 100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(1, 10000)

			for i := 0; i < tt.iterations; i++ {
				amount := int64(1000 + i)
				err := es.addHalvingYearAccumulatedAmount(1, amount)
				uassert.NoError(t, err)
				err = es.subHalvingYearLeftAmount(1, amount)
				uassert.NoError(t, err)
			}

			// Verify final state
			maxAmount := GetHalvingAmountsPerYear(1)
			accum := es.getHalvingYearAccumulatedAmount(1)
			left := es.getHalvingYearLeftAmount(1)
			uassert.Equal(t, maxAmount, accum+left)
		})
	}
}

func TestEmissionStateAllYearsIndependent(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Modify each year independently
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		amount := year * 1000
		err := es.addHalvingYearAccumulatedAmount(year, amount)
		uassert.NoError(t, err)
	}

	// Verify each year was modified independently
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		t.Run("year_"+formatInt(year), func(t *testing.T) {
			expected := year * 1000
			got := es.getHalvingYearAccumulatedAmount(year)
			uassert.Equal(t, expected, got)
		})
	}
}
