package gns

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestEmissionBoundaryConditions tests for emission at year boundaries
func TestEmissionBoundaryConditions(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	tests := []struct {
		name           string
		timestamp      int64
		expectedAmount int64
		description    string
	}{
		{
			name:           "Emission at first second of year 1",
			timestamp:      GetHalvingYearStartTimestamp(1),
			expectedAmount: GetHalvingAmountsPerYear(1) / SECONDS_IN_YEAR,
			description:    "Should return year 1 amount at first second",
		},
		{
			name:           "Emission at last second of year 1",
			timestamp:      GetHalvingYearEndTimestamp(1),
			expectedAmount: GetHalvingAmountsPerYear(1) / SECONDS_IN_YEAR,
			description:    "Should return year 1 amount at last second",
		},
		{
			name:           "Emission at first second of year 2",
			timestamp:      GetHalvingYearStartTimestamp(2),
			expectedAmount: GetHalvingAmountsPerYear(2) / SECONDS_IN_YEAR,
			description:    "Should return year 2 amount at first second",
		},
		{
			name:           "Emission at boundary between year 6 and 7",
			timestamp:      GetHalvingYearEndTimestamp(6) + 1,
			expectedAmount: GetHalvingAmountsPerYear(7) / SECONDS_IN_YEAR,
			description:    "Should transition correctly between halving periods",
		},
		{
			name:           "Emission at last second of year 12",
			timestamp:      GetHalvingYearEndTimestamp(12),
			expectedAmount: GetHalvingAmountsPerYear(12) / SECONDS_IN_YEAR,
			description:    "Should return year 12 amount at last emission second",
		},
		{
			name:           "Emission after year 12 ends",
			timestamp:      GetHalvingYearEndTimestamp(12) + 1,
			expectedAmount: 0,
			description:    "Should return 0 after emission period ends",
		},
		{
			name:           "Emission far after emission period",
			timestamp:      GetHalvingYearEndTimestamp(12) + 1000000,
			expectedAmount: 0,
			description:    "Should return 0 far after emission ends",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount := GetEmissionAmountPerSecondsByTimestamp(tt.timestamp)
			uassert.Equal(t, tt.expectedAmount, amount,
				"%s: %s", tt.name, tt.description)
		})
	}
}

// TestEmissionAmountCalculation tests emission amount calculation for different timestamps
func TestEmissionAmountCalculation(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	tests := []struct {
		name           string
		year           int64
		timestampPct   int // percentage through the year (0-100)
		expectedAmount int64
		description    string
	}{
		{
			name:         "Start of year 1",
			year:         1,
			timestampPct: 0,
			expectedAmount: GetHalvingAmountsPerYear(1) / SECONDS_IN_YEAR,
			description:  "Should return year 1 rate at start",
		},
		{
			name:         "Middle of year 3",
			year:         3,
			timestampPct: 50,
			expectedAmount: GetHalvingAmountsPerYear(3) / SECONDS_IN_YEAR,
			description:  "Should return year 3 rate at middle",
		},
		{
			name:         "End of year 5",
			year:         5,
			timestampPct: 99,
			expectedAmount: GetHalvingAmountsPerYear(5) / SECONDS_IN_YEAR,
			description:  "Should return year 5 rate near end",
		},
		{
			name:         "Start of halving period (year 7)",
			year:         7,
			timestampPct: 0,
			expectedAmount: GetHalvingAmountsPerYear(7) / SECONDS_IN_YEAR,
			description:  "Should return halved rate at year 7",
		},
		{
			name:         "Last year emission",
			year:         12,
			timestampPct: 50,
			expectedAmount: GetHalvingAmountsPerYear(12) / SECONDS_IN_YEAR,
			description:  "Should return year 12 rate",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			startTs := GetHalvingYearStartTimestamp(tt.year)
			endTs := GetHalvingYearEndTimestamp(tt.year)
			duration := endTs - startTs
			
			targetTs := startTs + (duration * int64(tt.timestampPct) / 100)
			amount := GetEmissionAmountPerSecondsByTimestamp(targetTs)
			
			uassert.Equal(t, tt.expectedAmount, amount,
				"%s: %s", tt.name, tt.description)
		})
	}
}

// TestEmissionStateConsistency tests that emission state remains consistent
func TestEmissionStateConsistency(t *testing.T) {
	resetEmissionState(t)

	tests := []struct {
		name        string
		operation   func()
		validation  func(*testing.T)
		description string
	}{
		{
			name: "Initial state consistency",
			operation: func() {
				resetObject(t)
			},
			validation: func(t *testing.T) {
				totalMaxAmount := int64(0)
				for year := int64(1); year <= 12; year++ {
					totalMaxAmount += GetHalvingYearMaxAmount(year)

					uassert.Equal(t, GetHalvingYearMaxAmount(year), GetHalvingYearLeftAmount(year),
					"Year 1 left amount should equal max amount")

					// Verify initial minted/left amounts
					uassert.Equal(t, int64(0), GetHalvingYearMintAmount(year),
						"Initial minted amount should be 0")
					uassert.Equal(t, GetHalvingYearMaxAmount(year), GetHalvingYearLeftAmount(year),
						"Initial left amount should equal max amount")
				}

				// Total should be 900 billion (with 6 decimals)
				uassert.Equal(t, int64(900_000_000_000_000), totalMaxAmount,
					"Total emission should be 900 billion")
			},
			description: "Verify initial emission state is consistent",
		},
		{
			name: "Year boundaries maintain continuity",
			operation: func() {
				// No additional operation needed
			},
			validation: func(t *testing.T) {
				for year := int64(1); year < 12; year++ {
					endTimestamp := GetHalvingYearEndTimestamp(year)
					nextStartTimestamp := GetHalvingYearStartTimestamp(year + 1)

					uassert.Equal(t, endTimestamp+1, nextStartTimestamp,
						"Year end should be followed by next year start")
				}
			},
			description: "Verify year boundaries are continuous",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.operation()
			tt.validation(t)
		})
	}
}

// TestYearTransitions tests emission calculations at year transitions
func TestYearTransitions(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	tests := []struct {
		name        string
		fromYear    int64
		toYear      int64
		description string
	}{
		{
			name:        "Transition from year 1 to 2",
			fromYear:    1,
			toYear:      2,
			description: "Should maintain same emission rate",
		},
		{
			name:        "Transition from year 6 to 7 (halving)",
			fromYear:    6,
			toYear:      7,
			description: "Should halve emission rate",
		},
		{
			name:        "Transition from year 11 to 12",
			fromYear:    11,
			toYear:      12,
			description: "Should maintain same emission rate",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {

			// Test at the boundary
			endTs := GetHalvingYearEndTimestamp(tt.fromYear)
			nextStartTs := GetHalvingYearStartTimestamp(tt.toYear)
			
			// Verify continuity
			uassert.Equal(t, endTs+1, nextStartTs,
				"Timestamps should be continuous at year boundary")
			
			// Get emission amounts
			amountBefore := GetEmissionAmountPerSecondsByTimestamp(endTs)
			amountAfter := GetEmissionAmountPerSecondsByTimestamp(nextStartTs)
			
			// Check halving if applicable
			if tt.fromYear == 6 && tt.toYear == 7 {
				// Should be approximately half (allowing for rounding)
				ratio := float64(amountBefore) / float64(amountAfter)
				uassert.True(t, ratio > 1.9 && ratio < 2.1,
					"Emission should approximately halve at year 7")
			} else if tt.fromYear%4 == 0 && tt.toYear%4 == 1 {
				// Other halving boundaries
				ratio := float64(amountBefore) / float64(amountAfter)
				uassert.True(t, ratio > 1.9 && ratio < 2.1,
					"Emission should approximately halve at halving boundaries")
			} else {
				// Should maintain same rate within halving period
				uassert.Equal(t, amountBefore, amountAfter,
					"Emission rate should be constant within halving period")
			}
		})
	}
}

// TestEmissionTotalAmount tests that total emission amounts are correct
func TestEmissionTotalAmount(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	// Calculate total emission by summing all years
	totalEmission := int64(0)
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		yearAmount := GetHalvingAmountsPerYear(year)
		totalEmission += yearAmount
	}

	// Should equal MAX_EMISSION_AMOUNT (900 billion with 6 decimals)
	uassert.Equal(t, MAX_EMISSION_AMOUNT, totalEmission,
		"Total emission should equal MAX_EMISSION_AMOUNT")
	
	// Test emission per second consistency
	for year := int64(1); year <= HALVING_END_YEAR; year++ {
		yearAmount := GetHalvingAmountsPerYear(year)
		expectedPerSecond := yearAmount / SECONDS_IN_YEAR
		
		// Test at various points in the year
		startTs := GetHalvingYearStartTimestamp(year)
		midTs := startTs + SECONDS_IN_YEAR/2
		nearEndTs := GetHalvingYearEndTimestamp(year) - 100
		
		uassert.Equal(t, expectedPerSecond, GetEmissionAmountPerSecondsByTimestamp(startTs),
			ufmt.Sprintf("Year %d start emission rate incorrect", year))
		uassert.Equal(t, expectedPerSecond, GetEmissionAmountPerSecondsByTimestamp(midTs),
			ufmt.Sprintf("Year %d middle emission rate incorrect", year))
		uassert.Equal(t, expectedPerSecond, GetEmissionAmountPerSecondsByTimestamp(nearEndTs),
			ufmt.Sprintf("Year %d near-end emission rate incorrect", year))

	}
}
