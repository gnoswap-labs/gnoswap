package gns

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
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

func TestGetEmissionAmountPerSecondInRangeEdgeCases(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	year3Start := GetHalvingYearStartTimestamp(3)

	tests := []struct {
		name           string
		fromTime       int64
		toTime         int64
		expectedLength int
	}{
		{"fromTime after toTime", GetHalvingYearStartTimestamp(5), GetHalvingYearStartTimestamp(1), 0},
		{"fromTime equals toTime at year start", year3Start, year3Start, 1},
		{"fromTime equals toTime not at year start", year3Start + 100, year3Start + 100, 0},
		{"Both before emission start", GetHalvingYearStartTimestamp(1) - 10000, GetHalvingYearStartTimestamp(1) - 1, 0},
		{"Both after emission end", GetHalvingYearEndTimestamp(12) + 1, GetHalvingYearEndTimestamp(12) + 10000, 0},
		{"Years 3 to 7", year3Start, GetHalvingYearEndTimestamp(7), 5},
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

func TestGetEmissionAmountPerSecondInRangeBoundary(t *testing.T) {
	resetEmissionState(t)
	InitGnsTest(t)

	year3Start := GetHalvingYearStartTimestamp(3)
	year4Start := GetHalvingYearStartTimestamp(4)
	year5Start := GetHalvingYearStartTimestamp(5)
	year5End := GetHalvingYearEndTimestamp(5)
	midYear3 := year3Start + (SECONDS_IN_YEAR / 2)

	verifyResult := func(t *testing.T, times, emissions []int64, expectedLen int) {
		uassert.Equal(t, expectedLen, len(times))
		uassert.Equal(t, expectedLen, len(emissions))
		for _, e := range emissions {
			uassert.True(t, e > 0)
		}
		for i := 1; i < len(times); i++ {
			uassert.True(t, times[i] > times[i-1])
		}
	}

	t.Run("fromTime at year start includes that year", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(year3Start, year5End)
		verifyResult(t, times, emissions, 3)
		uassert.Equal(t, year3Start, times[0])
	})

	t.Run("fromTime after year start excludes that year", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(year3Start+1, year5End)
		verifyResult(t, times, emissions, 2)
		uassert.Equal(t, year4Start, times[0])
	})

	t.Run("fromTime in middle of year to next year start-1 returns empty", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(midYear3, year4Start-1)
		verifyResult(t, times, emissions, 0)
	})

	t.Run("fromTime in middle of year to next year start includes only next year", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(midYear3, year4Start)
		verifyResult(t, times, emissions, 1)
		uassert.Equal(t, year4Start, times[0])
	})

	t.Run("toTime at year start includes that year", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(year3Start, year5Start)
		verifyResult(t, times, emissions, 3)
		uassert.Equal(t, year5Start, times[2])
	})

	t.Run("toTime one second before year start excludes that year", func(t *testing.T) {
		times, emissions := GetEmissionAmountPerSecondInRange(year3Start, year5Start-1)
		verifyResult(t, times, emissions, 2)
	})
}

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

func TestSimulateMintGns_NoStateChange(t *testing.T) {
	startTimestamp := int64(1000)
	emissionState = NewEmissionState(1, startTimestamp)

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(startTimestamp)

	currentTime := startTimestamp + 1
	beforeMinted := MintedEmissionAmount()
	beforeLeft := LeftEmissionAmount()
	beforeLast := LastMintedTimestamp()

	amount, err := simulateMintGnsAt(currentTime)
	uassert.NoError(t, err)
	uassert.Equal(t, GetAmountPerSecondPerHalvingYear(1), amount)
	uassert.Equal(t, beforeMinted, MintedEmissionAmount())
	uassert.Equal(t, beforeLeft, LeftEmissionAmount())
	uassert.Equal(t, beforeLast, LastMintedTimestamp())
}

func TestSimulateMintGns_ReflectsLeftAmount(t *testing.T) {
	startTimestamp := int64(2000)
	emissionState = NewEmissionState(1, startTimestamp)

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)

	year := int64(1)
	yearEnd := GetHalvingYearEndTimestamp(year)
	leftAmount := int64(12345)

	err := emissionState.getHalvingData().setLeftAmount(year, leftAmount)
	uassert.NoError(t, err)

	setLastMintedTimestamp(yearEnd - 1)

	amount, err := simulateMintGnsAt(yearEnd)
	uassert.NoError(t, err)
	uassert.Equal(t, leftAmount, amount)
}

func TestSimulateMintGnsAt_TimeProgression(t *testing.T) {
	startTimestamp := int64(3000)
	emissionState = NewEmissionState(1, startTimestamp)

	setLeftEmissionAmount(MAX_EMISSION_AMOUNT)
	setMintedEmissionAmount(0)
	setLastMintedTimestamp(startTimestamp)

	ctx := testing.GetContext()
	ctx.Time = time.Unix(startTimestamp+1, 0)
	testing.SetContext(ctx)

	amount1, err := simulateMintGnsAt(ctx.Time.Unix())
	uassert.NoError(t, err)

	ctx.Time = time.Unix(startTimestamp+2, 0)
	testing.SetContext(ctx)

	amount2, err := simulateMintGnsAt(ctx.Time.Unix())
	uassert.NoError(t, err)
	uassert.True(t, amount2 > amount1)
}

func TestEmissionActiveBoundaries(t *testing.T) {
	const testStartTimestamp = int64(1000000)
	emissionState = NewEmissionState(1, testStartTimestamp)

	endTimestamp := getEmissionState().getEndTimestamp()

	tests := []struct {
		name           string
		timestamp      int64
		expectedActive bool
		expectedEnded  bool
		expectedYear   int64
	}{
		{
			name:           "start-1: one second before emission starts",
			timestamp:      testStartTimestamp - 1,
			expectedActive: false,
			expectedEnded:  false,
			expectedYear:   0,
		},
		{
			name:           "start: exactly at emission start",
			timestamp:      testStartTimestamp,
			expectedActive: true,
			expectedEnded:  false,
			expectedYear:   1,
		},
		{
			name:           "start+1: one second after emission starts",
			timestamp:      testStartTimestamp + 1,
			expectedActive: true,
			expectedEnded:  false,
			expectedYear:   1,
		},
		{
			name:           "end-1: one second before emission ends",
			timestamp:      endTimestamp - 1,
			expectedActive: true,
			expectedEnded:  false,
			expectedYear:   12,
		},
		{
			name:           "end: exactly at emission end",
			timestamp:      endTimestamp,
			expectedActive: true,
			expectedEnded:  false,
			expectedYear:   12,
		},
		{
			name:           "end+1: one second after emission ends",
			timestamp:      endTimestamp + 1,
			expectedActive: false,
			expectedEnded:  true,
			expectedYear:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := getEmissionState()

			actualActive := es.isActive(tt.timestamp)
			uassert.Equal(t, tt.expectedActive, actualActive,
				"isActive mismatch for "+tt.name)

			actualEnded := es.isEnded(tt.timestamp)
			uassert.Equal(t, tt.expectedEnded, actualEnded,
				"isEnded mismatch for "+tt.name)

			actualYear := es.getCurrentYear(tt.timestamp)
			uassert.Equal(t, tt.expectedYear, actualYear,
				"getCurrentYear mismatch for "+tt.name)
		})
	}
}

// TestEmissionStateUninitializedBoundaries tests behavior when emission state is
// created with startTimestamp=0 (uninitialized). Note that getCurrentYear returns 1
// for timestamps >= 0 within the 12-year range because the calculation is:
// (timestamp - startTimestamp) / SECONDS_IN_YEAR + 1 = (timestamp - 0) / SECONDS_IN_YEAR + 1
// However, isActive returns false because isInitialized() is false (startBlock == 0).
func TestEmissionStateUninitializedBoundaries(t *testing.T) {
	emissionState = NewEmissionState(0, 0)
	endTimestamp := getEmissionState().getEndTimestamp()

	tests := []struct {
		name           string
		timestamp      int64
		expectedActive bool
		expectedEnded  bool
		expectedYear   int64
	}{
		{
			name:           "timestamp zero",
			timestamp:      0,
			expectedActive: false,
			expectedEnded:  false,
			expectedYear:   1,
		},
		{
			name:           "timestamp positive",
			timestamp:      1000,
			expectedActive: false,
			expectedEnded:  false,
			expectedYear:   1,
		},
		{
			name:           "timestamp negative",
			timestamp:      -1,
			expectedActive: false,
			expectedEnded:  false,
			expectedYear:   0,
		},
		{
			name:           "timestamp after end",
			timestamp:      endTimestamp + 1,
			expectedActive: false,
			expectedEnded:  true,
			expectedYear:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			es := getEmissionState()

			uassert.Equal(t, tt.expectedActive, es.isActive(tt.timestamp),
				"isActive mismatch for "+tt.name)
			uassert.Equal(t, tt.expectedEnded, es.isEnded(tt.timestamp),
				"isEnded mismatch for "+tt.name)
			uassert.Equal(t, tt.expectedYear, es.getCurrentYear(tt.timestamp),
				"getCurrentYear mismatch for "+tt.name)
		})
	}
}

func TestYearTransitionBoundaries(t *testing.T) {
	const testStartTimestamp = int64(1000000)
	emissionState = NewEmissionState(1, testStartTimestamp)

	for year := int64(1); year < HALVING_END_YEAR; year++ {
		yearEndTimestamp := testStartTimestamp + (SECONDS_IN_YEAR * year) - 1
		nextYearStartTimestamp := testStartTimestamp + (SECONDS_IN_YEAR * year)

		t.Run(ufmt.Sprintf("year %d to %d transition", year, year+1), func(t *testing.T) {
			es := getEmissionState()

			// Last second of current year
			yearAtEnd := es.getCurrentYear(yearEndTimestamp)
			uassert.Equal(t, year, yearAtEnd,
				"expected year at end timestamp")

			// First second of next year
			yearAtStart := es.getCurrentYear(nextYearStartTimestamp)
			uassert.Equal(t, year+1, yearAtStart,
				"expected year at next year start timestamp")

			// Both should be active
			uassert.True(t, es.isActive(yearEndTimestamp), "should be active at year end")
			uassert.True(t, es.isActive(nextYearStartTimestamp), "should be active at next year start")
		})
	}
}
