package gns

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestGetHalvingYearInfo verifies that GetHalvingYearInfo correctly calculates
// year-specific start and end timestamps and maintains consistency with other functions.
func TestGetHalvingYearInfo(t *testing.T) {
	const testStartTimestamp = int64(1000)
	emissionState = NewEmissionState(1, testStartTimestamp)
	halvingData := emissionState.getHalvingData()

	tests := []struct {
		name              string
		timestamp         int64
		expectedYear      int64
		expectedStartTime int64
		expectedEndTime   int64
	}{
		{
			name:              "Year 1 - Beginning",
			timestamp:         testStartTimestamp,
			expectedYear:      1,
			expectedStartTime: testStartTimestamp,
			expectedEndTime:   testStartTimestamp + SECONDS_IN_YEAR - 1,
		},
		{
			name:              "Year 1 - Middle",
			timestamp:         testStartTimestamp + SECONDS_IN_YEAR/2,
			expectedYear:      1,
			expectedStartTime: testStartTimestamp,
			expectedEndTime:   testStartTimestamp + SECONDS_IN_YEAR - 1,
		},
		{
			name:              "Year 2 - Beginning",
			timestamp:         testStartTimestamp + SECONDS_IN_YEAR,
			expectedYear:      2,
			expectedStartTime: testStartTimestamp + SECONDS_IN_YEAR,
			expectedEndTime:   testStartTimestamp + (2 * SECONDS_IN_YEAR) - 1,
		},
		{
			name:              "Year 12 - End of year",
			timestamp:         testStartTimestamp + (12 * SECONDS_IN_YEAR) - 1,
			expectedYear:      12,
			expectedStartTime: testStartTimestamp + (11 * SECONDS_IN_YEAR),
			expectedEndTime:   testStartTimestamp + (12 * SECONDS_IN_YEAR) - 1,
		},
		{
			name:              "Before emission start",
			timestamp:         testStartTimestamp - 1,
			expectedYear:      0,
			expectedStartTime: 0,
			expectedEndTime:   0,
		},
		{
			name:              "After emission end",
			timestamp:         testStartTimestamp + (12 * SECONDS_IN_YEAR),
			expectedYear:      0,
			expectedStartTime: 0,
			expectedEndTime:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			year, startTime, endTime := GetHalvingYearInfo(tt.timestamp)

			if year != tt.expectedYear {
				t.Errorf("Expected year %d, got %d", tt.expectedYear, year)
			}
			if startTime != tt.expectedStartTime {
				t.Errorf("Expected start time %d, got %d", tt.expectedStartTime, startTime)
			}
			if endTime != tt.expectedEndTime {
				t.Errorf("Expected end time %d, got %d", tt.expectedEndTime, endTime)
			}

			// For valid years, verify consistency with other functions and HalvingData
			if year > 0 && year <= HALVING_END_YEAR {
				// Consistency with HalvingData
				halvingStart := halvingData.getStartTimestamp(year)
				halvingEnd := halvingData.getEndTimestamp(year)

				if startTime != halvingStart {
					t.Errorf("Start time mismatch with HalvingData: got %d, expected %d", startTime, halvingStart)
				}
				if endTime != halvingEnd {
					t.Errorf("End time mismatch with HalvingData: got %d, expected %d", endTime, halvingEnd)
				}

				// Consistency with other getter functions
				halvingYear := GetHalvingYear(tt.timestamp)
				if year != halvingYear {
					t.Errorf("GetHalvingYearInfo year %d != GetHalvingYear %d", year, halvingYear)
				}

				expectedStart := GetHalvingYearStartTimestamp(year)
				expectedEnd := GetHalvingYearEndTimestamp(year)

				if startTime != expectedStart {
					t.Errorf("Start time %d != GetHalvingYearStartTimestamp %d", startTime, expectedStart)
				}
				if endTime != expectedEnd {
					t.Errorf("End time %d != GetHalvingYearEndTimestamp %d", endTime, expectedEnd)
				}
			}
		})
	}
}

// TestValidYearEdgeCases tests validYear with boundary values
func TestValidYearEdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		year        int64
		shouldError bool
	}{
		{"Year 0", 0, true},
		{"Year -1", -1, true},
		{"Year -100", -100, true},
		{"Year 1 (min valid)", 1, false},
		{"Year 12 (max valid)", 12, false},
		{"Year 13", 13, true},
		{"Year 100", 100, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validYear(tt.year)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestValidEmissionAmountEdgeCases tests validEmissionAmount with boundary values
func TestValidEmissionAmountEdgeCases(t *testing.T) {
	tests := []struct {
		name             string
		currentMinted    int64
		amountToValidate int64
		shouldError      bool
	}{
		{"Zero amount with zero minted", 0, 0, false},
		{"Small amount with zero minted", 0, 1000, false},
		{"Exactly max emission amount", 0, MAX_EMISSION_AMOUNT, false},
		{"One over max emission amount", 0, MAX_EMISSION_AMOUNT + 1, true},
		{"Already at max, trying to mint more", MAX_EMISSION_AMOUNT, 1, true},
		{"One below max, trying to mint 1", MAX_EMISSION_AMOUNT - 1, 1, false},
		{"One below max, trying to mint 2", MAX_EMISSION_AMOUNT - 1, 2, true},
		{"Negative amount", 0, -1, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			setMintedEmissionAmount(tt.currentMinted)

			err := validEmissionAmount(tt.amountToValidate)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestGetEmissionAmountPerSecondInRangeEdgeCases tests edge cases for GetEmissionAmountPerSecondInRange
func TestGetEmissionAmountPerSecondInRangeEdgeCases(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	tests := []struct {
		name           string
		fromTime       int64
		toTime         int64
		expectedLength int
	}{
		{"fromTime after toTime", GetHalvingYearStartTimestamp(5), GetHalvingYearStartTimestamp(1), 0},
		{"fromTime equals toTime at year start", GetHalvingYearStartTimestamp(3), GetHalvingYearStartTimestamp(3), 1},
		{"fromTime equals toTime not at year start", GetHalvingYearStartTimestamp(3) + 100, GetHalvingYearStartTimestamp(3) + 100, 0},
		{"Both before emission start", GetHalvingYearStartTimestamp(1) - 10000, GetHalvingYearStartTimestamp(1) - 1, 0},
		{"Both after emission end", GetHalvingYearEndTimestamp(12) + 1, GetHalvingYearEndTimestamp(12) + 10000, 0},
		{"Years 3 to 7", GetHalvingYearStartTimestamp(3), GetHalvingYearEndTimestamp(7), 5},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			times, emissions := GetEmissionAmountPerSecondInRange(tt.fromTime, tt.toTime)

			uassert.Equal(t, tt.expectedLength, len(times))
			uassert.Equal(t, tt.expectedLength, len(emissions))
			uassert.Equal(t, len(times), len(emissions))

			for _, emission := range emissions {
				uassert.True(t, emission > 0)
			}

			for i := 1; i < len(times); i++ {
				uassert.True(t, times[i] > times[i-1])
			}
		})
	}
}

// TestGetEmissionFunctionsWithInvalidTimestamps tests getter functions with invalid timestamps
func TestGetEmissionFunctionsWithInvalidTimestamps(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	tests := []struct {
		name      string
		timestamp int64
	}{
		{"Before emission start", GetHalvingYearStartTimestamp(1) - 1},
		{"After emission end", GetHalvingYearEndTimestamp(12) + 1},
		{"Far before start", GetHalvingYearStartTimestamp(1) - 999999},
		{"Far after end", GetHalvingYearEndTimestamp(12) + 999999},
		{"Negative timestamp", -1000},
		{"Zero timestamp", 0},
	}

	for _, tt := range tests {
		t.Run(tt.name+" - GetEmissionAmountPerSecondByTimestamp", func(t *testing.T) {
			result := GetEmissionAmountPerSecondByTimestamp(tt.timestamp)
			uassert.Equal(t, int64(0), result)
		})

		t.Run(tt.name+" - GetEmissionLeftAmountByTimestamp", func(t *testing.T) {
			result := GetEmissionLeftAmountByTimestamp(tt.timestamp)
			uassert.Equal(t, int64(0), result)
		})

		t.Run(tt.name+" - GetEmissionAccumulatedAmountByTimestamp", func(t *testing.T) {
			result := GetEmissionAccumulatedAmountByTimestamp(tt.timestamp)
			uassert.Equal(t, int64(0), result)
		})
	}
}
