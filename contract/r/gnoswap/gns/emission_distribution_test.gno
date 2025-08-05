package gns

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestEmissionDistributionAcrossYears verifies that emission distribution is correct
// for each year based on the halving schedule
func TestEmissionDistributionAcrossYears(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	// Test emission amounts for each year
	scenarios := []struct {
		name         string
		year         int64
		expectedRate int64 // expected emission per second
	}{
		{
			name:         "Year 1-4 emission rate",
			year:         1,
			expectedRate: int64(225_000_000_000_000) / SECONDS_IN_YEAR, // 225M per year
		},
		{
			name:         "Year 5-8 emission rate",
			year:         5,
			expectedRate: int64(56_250_000_000_000) / SECONDS_IN_YEAR, // 56.25M per year
		},
		{
			name:         "Year 7-8 emission rate (after halving)",
			year:         7,
			expectedRate: int64(28_125_000_000_000) / SECONDS_IN_YEAR, // 28.125M per year
		},
		{
			name:         "Year 9-10 emission rate",
			year:         9,
			expectedRate: int64(14_062_500_000_000) / SECONDS_IN_YEAR, // 14.0625M per year
		},
		{
			name:         "Year 11-12 emission rate",
			year:         11,
			expectedRate: int64(14_062_500_000_000) / SECONDS_IN_YEAR, // 14.0625M per year
		},
	}

	for _, sc := range scenarios {
		t.Run(sc.name, func(t *testing.T) {
			// Test emission rate at different points in the year
			startTs := GetHalvingYearStartTimestamp(sc.year)
			endTs := GetHalvingYearEndTimestamp(sc.year)
			midTs := startTs + (endTs-startTs)/2

			// Check emission rates at different timestamps
			startRate := GetEmissionAmountPerSecondsByTimestamp(startTs)
			midRate := GetEmissionAmountPerSecondsByTimestamp(midTs)
			endRate := GetEmissionAmountPerSecondsByTimestamp(endTs)

			// All rates should be equal within the same year
			uassert.Equal(t, sc.expectedRate, startRate,
				ufmt.Sprintf("%s: Start emission rate incorrect", sc.name))
			uassert.Equal(t, sc.expectedRate, midRate,
				ufmt.Sprintf("%s: Mid emission rate incorrect", sc.name))
			uassert.Equal(t, sc.expectedRate, endRate,
				ufmt.Sprintf("%s: End emission rate incorrect", sc.name))

			// Verify total year amount
			yearAmount := GetHalvingAmountsPerYear(sc.year)
			expectedYearAmount := sc.expectedRate * SECONDS_IN_YEAR
			expectedAmountDiff := yearAmount - expectedYearAmount
			uassert.True(t, expectedAmountDiff < SECONDS_IN_YEAR,
				ufmt.Sprintf("%s: Total year amount incorrect", sc.name))
		})
	}
}

// TestEmissionHalvingSchedule verifies the halving schedule is correct
func TestEmissionHalvingSchedule(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	// Verify halving amounts
	halvingTests := []struct {
		fromYear      int64
		toYear        int64
		expectedHalve bool
		description   string
	}{
		{1, 2, false, "Year 1-2: same period, no halving"},
		{4, 5, true, "Year 4-5: same period, no halving"},
		{6, 7, true, "Year 6-7: halving boundary"},
		{8, 9, true, "Year 8-9: halving boundary"},
		{10, 11, false, "Year 10-11: halving boundary"},
		{11, 12, false, "Year 11-12: same period, no halving"},
	}

	for _, tt := range halvingTests {
		t.Run(tt.description, func(t *testing.T) {
			amount1 := GetHalvingAmountsPerYear(tt.fromYear)
			amount2 := GetHalvingAmountsPerYear(tt.toYear)

			if tt.expectedHalve {
				// Should be approximately half
				ratio := float64(amount1) / float64(amount2)
				uassert.True(t, ratio > 1.9 && ratio < 2.1,
					ufmt.Sprintf("%s: Expected halving but got ratio %.2f", tt.description, ratio))
			} else {
				// Should be equal
				uassert.Equal(t, amount1, amount2,
					ufmt.Sprintf("%s: Expected same amount", tt.description))
			}
		})
	}
}
