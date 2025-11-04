package gns

import (
	"testing"
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
