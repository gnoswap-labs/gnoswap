package gns

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

// NewEmissionState Tests

func TestNewEmissionState(t *testing.T) {
	tests := []struct {
		name           string
		startHeight    int64
		startTimestamp int64
		wantEndTs      int64
	}{
		{
			name:           "zero values",
			startHeight:    0,
			startTimestamp: 0,
			wantEndTs:      SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "positive values",
			startHeight:    100,
			startTimestamp: 1000,
			wantEndTs:      1000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "large timestamp",
			startHeight:    999999,
			startTimestamp: 1700000000,
			wantEndTs:      1700000000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
		{
			name:           "negative height",
			startHeight:    -100,
			startTimestamp: 1000,
			wantEndTs:      1000 + SECONDS_IN_YEAR*HALVING_END_YEAR - 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := NewEmissionState(tt.startHeight, tt.startTimestamp)

			uassert.Equal(t, tt.startHeight, es.getStartHeight())
			uassert.Equal(t, tt.startTimestamp, es.getStartTimestamp())
			uassert.Equal(t, tt.wantEndTs, es.getEndTimestamp())
			uassert.True(t, es.getHalvingData() != nil)
		})
	}
}

func TestNewEmissionStateOverflowPanic(t *testing.T) {
	tests := []struct {
		name           string
		startTimestamp int64
		panicMsg       string
	}{
		{
			name:           "overflow near MaxInt64",
			startTimestamp: math.MaxInt64 - (SECONDS_IN_YEAR * HALVING_END_YEAR) + 2,
			panicMsg:       "int64 addition overflow",
		},
		{
			name:           "overflow at MaxInt64",
			startTimestamp: math.MaxInt64,
			panicMsg:       "int64 addition overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.PanicsWithMessage(t, tt.panicMsg, func() {
				NewEmissionState(1, tt.startTimestamp)
			})
		})
	}
}

// isInitialized Tests

func TestIsInitialized(t *testing.T) {
	tests := []struct {
		name           string
		startHeight    int64
		startTimestamp int64
		want           bool
	}{
		{
			name:           "both zero - not initialized",
			startHeight:    0,
			startTimestamp: 0,
			want:           false,
		},
		{
			name:           "only height set - not initialized",
			startHeight:    100,
			startTimestamp: 0,
			want:           false,
		},
		{
			name:           "only timestamp set - not initialized",
			startHeight:    0,
			startTimestamp: 1000,
			want:           false,
		},
		{
			name:           "both set - initialized",
			startHeight:    100,
			startTimestamp: 1000,
			want:           true,
		},
		{
			name:           "negative height with positive timestamp - initialized",
			startHeight:    -1,
			startTimestamp: 1000,
			want:           true,
		},
		{
			name:           "positive height with negative timestamp - initialized",
			startHeight:    100,
			startTimestamp: -1,
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

// isActive Tests

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
		{"far before start", startTs - 10000, false},
		{"one second before start", startTs - 1, false},

		// At boundaries
		{"exactly at start", startTs, true},
		{"one second after start", startTs + 1, true},
		{"one second before end", endTs - 1, true},
		{"exactly at end", endTs, true},
		{"one second after end", endTs + 1, false},

		// Middle of period
		{"middle of emission", startTs + (endTs-startTs)/2, true},

		// Far after emission
		{"far after end", endTs + 10000, false},

		// Edge cases with extreme values
		{"negative timestamp", -1, false},
		{"zero timestamp", 0, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.isActive(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestIsActiveUninitializedState(t *testing.T) {
	es := NewEmissionState(0, 0) // uninitialized

	timestamps := []int64{-1000, 0, 1, 1000, 999999999}
	for _, ts := range timestamps {
		uassert.False(t, es.isActive(ts), "uninitialized state should never be active")
	}
}

// isEnded Tests

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
		{"far before start", startTs - 10000, false},
		{"at start", startTs, false},
		{"middle of emission", startTs + (endTs-startTs)/2, false},
		{"one second before end", endTs - 1, false},
		{"exactly at end", endTs, false},

		// After emission ends
		{"one second after end", endTs + 1, true},
		{"far after end", endTs + 1000000, true},

		// Edge cases
		{"max int64", math.MaxInt64, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.isEnded(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

// getCurrentYear Tests

func TestGetCurrentYear(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	tests := []struct {
		name      string
		timestamp int64
		want      int64
	}{
		// Before emission
		{"before start", startTs - 1, 0},
		{"far before start", startTs - 10000, 0},

		// Year 1 boundaries
		{"first second of year 1", startTs, 1},
		{"middle of year 1", startTs + SECONDS_IN_YEAR/2, 1},
		{"last second of year 1", startTs + SECONDS_IN_YEAR - 1, 1},

		// Year 2 boundaries
		{"first second of year 2", startTs + SECONDS_IN_YEAR, 2},
		{"last second of year 2", startTs + (2*SECONDS_IN_YEAR - 1), 2},

		// Year transitions
		{"year 6 to 7 boundary - end of year 6", startTs + (6*SECONDS_IN_YEAR - 1), 6},
		{"year 6 to 7 boundary - start of year 7", startTs + (6 * SECONDS_IN_YEAR), 7},

		// Year 12 (last year)
		{"first second of year 12", startTs + (11 * SECONDS_IN_YEAR), 12},
		{"last second of year 12", startTs + (12*SECONDS_IN_YEAR - 1), 12},

		// After emission
		{"exactly after year 12", startTs + (12 * SECONDS_IN_YEAR), 0},
		{"far after emission", startTs + (15 * SECONDS_IN_YEAR), 0},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := es.getCurrentYear(tt.timestamp)
			uassert.Equal(t, tt.want, got)
		})
	}
}

func TestGetCurrentYearAllYears(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Test each year from 1 to 12
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		yearStartTs := startTs + (year-1)*SECONDS_IN_YEAR
		yearEndTs := startTs + year*SECONDS_IN_YEAR - 1

		// Test at year start
		gotStart := es.getCurrentYear(yearStartTs)
		uassert.Equal(t, year, gotStart, "year start mismatch for year "+formatInt(year))

		// Test at year end
		gotEnd := es.getCurrentYear(yearEndTs)
		uassert.Equal(t, year, gotEnd, "year end mismatch for year "+formatInt(year))

		// Test at year middle
		gotMid := es.getCurrentYear(yearStartTs + SECONDS_IN_YEAR/2)
		uassert.Equal(t, year, gotMid, "year middle mismatch for year "+formatInt(year))
	}
}

// Getter Tests (getStartHeight, getStartTimestamp, getEndTimestamp, getHalvingData)

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

// getHalvingYearStartTimestamp Tests

func TestGetHalvingYearStartTimestamp(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Valid years
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		expected := startTs + (year-1)*SECONDS_IN_YEAR
		got := es.getHalvingYearStartTimestamp(year)
		uassert.Equal(t, expected, got, "start timestamp mismatch for year "+formatInt(year))
	}

	// Invalid years - should return 0
	invalidYears := []int64{0, -1, 13, 100, -100}
	for _, year := range invalidYears {
		got := es.getHalvingYearStartTimestamp(year)
		uassert.Equal(t, int64(0), got, "invalid year "+formatInt(year)+" should return 0")
	}
}

// getHalvingYearEndTimestamp Tests

func TestGetHalvingYearEndTimestamp(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Valid years
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		expected := startTs + year*SECONDS_IN_YEAR - 1
		got := es.getHalvingYearEndTimestamp(year)
		uassert.Equal(t, expected, got, "end timestamp mismatch for year "+formatInt(year))
	}

	// Invalid years - should return 0
	invalidYears := []int64{0, -1, 13, 100, -100}
	for _, year := range invalidYears {
		got := es.getHalvingYearEndTimestamp(year)
		uassert.Equal(t, int64(0), got, "invalid year "+formatInt(year)+" should return 0")
	}
}

func TestHalvingYearTimestampContinuity(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Verify that year boundaries are continuous
	for year := int64(1); year < HALVING_END_YEAR; year++ {
		endTs := es.getHalvingYearEndTimestamp(year)
		nextStartTs := es.getHalvingYearStartTimestamp(year + 1)

		uassert.Equal(t, endTs+1, nextStartTs,
			"year "+formatInt(year)+" end should be followed by year "+formatInt(year+1)+" start")
	}
}

// getHalvingYearAmountPerSecond Tests

func TestGetHalvingYearAmountPerSecond(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Valid years
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		yearAmount := GetHalvingAmountsPerYear(year)
		expected := yearAmount / SECONDS_IN_YEAR
		got := es.getHalvingYearAmountPerSecond(year)
		uassert.Equal(t, expected, got, "amount per second mismatch for year "+formatInt(year))
	}

	// Invalid years - should return 0
	invalidYears := []int64{0, -1, 13, 100}
	for _, year := range invalidYears {
		got := es.getHalvingYearAmountPerSecond(year)
		uassert.Equal(t, int64(0), got, "invalid year "+formatInt(year)+" should return 0")
	}
}

func TestHalvingRates(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Verify halving pattern: years 1-2 same, 3-4 half, 5-6 quarter, etc.
	year1Rate := es.getHalvingYearAmountPerSecond(1)
	year2Rate := es.getHalvingYearAmountPerSecond(2)
	year3Rate := es.getHalvingYearAmountPerSecond(3)
	year7Rate := es.getHalvingYearAmountPerSecond(7)

	uassert.Equal(t, year1Rate, year2Rate, "years 1 and 2 should have same rate")
	uassert.Equal(t, year1Rate/2, year3Rate, "year 3 rate should be half of year 1")
	uassert.Equal(t, year1Rate/8, year7Rate, "year 7 rate should be 1/8 of year 1")
}

// getHalvingYearAccumulatedAmount Tests

func TestGetHalvingYearAccumulatedAmount(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Initial accumulated amounts should be 0
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		got := es.getHalvingYearAccumulatedAmount(year)
		uassert.Equal(t, int64(0), got, "initial accumulated amount for year "+formatInt(year)+" should be 0")
	}

	// Invalid years - should return 0
	invalidYears := []int64{0, -1, 13, 100}
	for _, year := range invalidYears {
		got := es.getHalvingYearAccumulatedAmount(year)
		uassert.Equal(t, int64(0), got, "invalid year "+formatInt(year)+" should return 0")
	}
}

// getHalvingYearLeftAmount Tests

func TestGetHalvingYearLeftAmount(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Initial left amounts should equal max amounts
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		expected := GetHalvingAmountsPerYear(year)
		got := es.getHalvingYearLeftAmount(year)
		uassert.Equal(t, expected, got, "initial left amount for year "+formatInt(year)+" should equal max")
	}

	// Invalid years - should return 0
	invalidYears := []int64{0, -1, 13, 100}
	for _, year := range invalidYears {
		got := es.getHalvingYearLeftAmount(year)
		uassert.Equal(t, int64(0), got, "invalid year "+formatInt(year)+" should return 0")
	}
}

// addHalvingYearAccumulatedAmount Tests

func TestAddHalvingYearAccumulatedAmount(t *testing.T) {
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
		{"large amount", 3, 999999999, false},
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

func TestAddHalvingYearAccumulatedAmountCumulative(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Add amounts cumulatively
	amounts := []int64{100, 200, 300, 400, 500}
	expectedTotal := int64(0)

	for _, amount := range amounts {
		err := es.addHalvingYearAccumulatedAmount(1, amount)
		uassert.NoError(t, err)
		expectedTotal += amount
		got := es.getHalvingYearAccumulatedAmount(1)
		uassert.Equal(t, expectedTotal, got)
	}
}

func TestAddHalvingYearAccumulatedAmountOverflowPanic(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Set initial value close to MaxInt64
	es.halvingData.setAccumAmount(1, math.MaxInt64-100)

	// Adding more should panic
	uassert.PanicsWithMessage(t, "int64 addition overflow", func() {
		es.addHalvingYearAccumulatedAmount(1, 200)
	})
}

// subHalvingYearLeftAmount Tests

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

func TestSubHalvingYearLeftAmountUnderflowPanic(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Set left amount to MinInt64 + 100
	es.halvingData.setLeftAmount(1, math.MinInt64+100)

	// Subtracting more should panic
	uassert.PanicsWithMessage(t, "int64 subtraction underflow", func() {
		es.subHalvingYearLeftAmount(1, 200)
	})
}

func TestAddSubConsistency(t *testing.T) {
	es := NewEmissionState(1, 10000)

	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		maxAmount := GetHalvingAmountsPerYear(year)
		emitAmount := int64(1000000)

		// Add to accumulated
		err := es.addHalvingYearAccumulatedAmount(year, emitAmount)
		uassert.NoError(t, err)

		// Subtract from left
		err = es.subHalvingYearLeftAmount(year, emitAmount)
		uassert.NoError(t, err)

		// Verify consistency: accum + left = max
		accum := es.getHalvingYearAccumulatedAmount(year)
		left := es.getHalvingYearLeftAmount(year)
		uassert.Equal(t, maxAmount, accum+left, "accum + left should equal max for year "+formatInt(year))
	}
}

// updateHalvingData Tests

func TestUpdateHalvingData(t *testing.T) {
	es := NewEmissionState(1, 10000)
	originalStartTs := es.getHalvingYearStartTimestamp(1)

	// Update with new timestamp
	newStartTs := int64(50000)
	es.updateHalvingData(newStartTs)

	// Verify halving data was updated
	updatedStartTs := es.getHalvingYearStartTimestamp(1)
	uassert.Equal(t, newStartTs, updatedStartTs)
	uassert.True(t, originalStartTs != updatedStartTs)

	// Verify all years are updated correctly
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		expectedStart := newStartTs + (year-1)*SECONDS_IN_YEAR
		expectedEnd := newStartTs + year*SECONDS_IN_YEAR - 1
		uassert.Equal(t, expectedStart, es.getHalvingYearStartTimestamp(year))
		uassert.Equal(t, expectedEnd, es.getHalvingYearEndTimestamp(year))
	}
}

// getEmissionState Tests (Singleton pattern)

func TestGetEmissionState(t *testing.T) {
	// Reset global state
	resetEmissionState(t)

	// Get emission state
	es := getEmissionState()
	uassert.True(t, es != nil)
	uassert.True(t, es.isInitialized())

	// Getting again should return same instance
	es2 := getEmissionState()
	uassert.Equal(t, es.getStartHeight(), es2.getStartHeight())
	uassert.Equal(t, es.getStartTimestamp(), es2.getStartTimestamp())
}

func TestEmissionStateWithNegativeTimestamp(t *testing.T) {
	es := NewEmissionState(1, -1000)

	// Negative start timestamp should still work for calculations
	uassert.Equal(t, int64(-1000), es.getStartTimestamp())
	uassert.True(t, es.isInitialized())

	// isActive should handle negative ranges
	uassert.True(t, es.isActive(-1000))
	uassert.True(t, es.isActive(-500))
	uassert.False(t, es.isActive(-1001))
}

func TestEmissionStateYearBoundaryPrecision(t *testing.T) {
	startTs := int64(10000)
	es := NewEmissionState(1, startTs)

	// Test exact second transitions
	for year := int64(1); year < HALVING_END_YEAR; year++ {
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

	// Verify halving data matches emission state getters
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		uassert.Equal(t, halvingData.getStartTimestamp(year), es.getHalvingYearStartTimestamp(year))
		uassert.Equal(t, halvingData.getEndTimestamp(year), es.getHalvingYearEndTimestamp(year))
		uassert.Equal(t, halvingData.getAmountPerSecond(year), es.getHalvingYearAmountPerSecond(year))
		uassert.Equal(t, halvingData.getAccumAmount(year), es.getHalvingYearAccumulatedAmount(year))
		uassert.Equal(t, halvingData.getLeftAmount(year), es.getHalvingYearLeftAmount(year))
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

// Stress Tests

func TestEmissionStateRepeatedOperations(t *testing.T) {
	es := NewEmissionState(1, 10000)

	// Perform many add/sub operations
	for i := 0; i < 100; i++ {
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
		expected := year * 1000
		got := es.getHalvingYearAccumulatedAmount(year)
		uassert.Equal(t, expected, got)
	}
}
