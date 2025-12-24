package gns

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	"gno.land/p/nt/uassert"
	"gno.land/p/onbloc/json"

	"gno.land/p/nt/ufmt"
)

var (
	govRealm = testing.NewCodeRealm("gno.land/r/gnoswap/gov/governance")

	startHeight int64 = runtime.ChainHeight()

	blockTime      int64 = 2000
	startTimestamp int64 = time.Now().Unix() + 2 // blockTime in seconds
)

var FIRST_TIMESTAMP_OF_HALVING_YEAR = []int64{
	startTimestamp + (SECONDS_IN_YEAR * 0),
	startTimestamp + (SECONDS_IN_YEAR * 1),
	startTimestamp + (SECONDS_IN_YEAR * 2),
	startTimestamp + (SECONDS_IN_YEAR * 3),
	startTimestamp + (SECONDS_IN_YEAR * 4),
	startTimestamp + (SECONDS_IN_YEAR * 5),
	startTimestamp + (SECONDS_IN_YEAR * 6),
	startTimestamp + (SECONDS_IN_YEAR * 7),
	startTimestamp + (SECONDS_IN_YEAR * 8),
	startTimestamp + (SECONDS_IN_YEAR * 9),
	startTimestamp + (SECONDS_IN_YEAR * 10),
	startTimestamp + (SECONDS_IN_YEAR * 11),
}

func TestGetHalvingYear(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	t.Run("during halving years", func(t *testing.T) {
		for year := HALVING_START_YEAR; year <= HALVING_END_YEAR; year++ {
			firstTimestampOfYear := FIRST_TIMESTAMP_OF_HALVING_YEAR[year-1]
			uassert.Equal(t, year, GetHalvingYear(firstTimestampOfYear))
		}
	})

	t.Run("no year after 12 years", func(t *testing.T) {
		uassert.Equal(t, int64(0), GetHalvingYear(GetEmissionEndTimestamp()+1))
	})
}

func TestEmissionState_CalculateAmountPerSeconds(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test emission state basic functions
	uassert.True(t, IsEmissionInitialized())

	es := getEmissionState()
	uassert.True(t, es.getStartTimestamp() > 0)
	uassert.True(t, es.getEndTimestamp() > es.getStartTimestamp())

	// Test amount per seconds for year 1
	expected := es.getHalvingYearAmountPerSecond(1)
	uassert.True(t, expected > 0)

	for y := int64(1); y <= HALVING_END_YEAR; y++ {
		amountPerSeconds := es.getHalvingYearAmountPerSecond(y)
		yearMaxAmount := GetHalvingYearMaxAmount(y)

		// Amount per seconds should be year max amount divided by seconds in year
		expected := yearMaxAmount / SECONDS_IN_YEAR
		uassert.Equal(
			t,
			expected,
			amountPerSeconds,
			ufmt.Sprintf("year %d amount per seconds mismatch: expected=%d, got=%d", y, expected, amountPerSeconds),
		)
	}
}

func TestHalvingYearGetters(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	t.Run("valid years (1-12)", func(t *testing.T) {
		var prevendTimestamp int64

		for year := int64(1); year <= HALVING_END_YEAR; year++ {
			startTimestamp := GetHalvingYearStartTimestamp(year)
			endTimestamp := GetHalvingYearEndTimestamp(year)

			// StartTimestamp and EndTimestamp should be positive
			uassert.True(t, startTimestamp > 0)
			uassert.True(t, endTimestamp > startTimestamp)

			// EndTimestamp should be startTimestamp + SECONDS_IN_YEAR - 1
			uassert.Equal(t, startTimestamp+SECONDS_IN_YEAR-1, endTimestamp)

			// GetHalvingYearTimestamp should equal GetHalvingYearStartTimestamp
			uassert.Equal(t, startTimestamp, GetHalvingYearTimestamp(year))

			// Year N+1 start should be Year N end + 1
			if year > 1 {
				uassert.Equal(t, prevendTimestamp+1, startTimestamp)
			}
			prevendTimestamp = endTimestamp

			// MaxAmount should match GetHalvingAmountsPerYear
			uassert.Equal(t, GetHalvingAmountsPerYear(year), GetHalvingYearMaxAmount(year))

			// MintAmount and AccuAmount should be 0 initially
			uassert.Equal(t, int64(0), GetHalvingYearMintAmount(year))
			uassert.Equal(t, int64(0), GetHalvingYearAccuAmount(year))
		}
	})

	t.Run("invalid year 0", func(t *testing.T) {
		uassert.Equal(t, int64(0), GetHalvingYearStartTimestamp(0))
		uassert.Equal(t, int64(0), GetHalvingYearEndTimestamp(0))
		uassert.Equal(t, int64(0), GetHalvingYearTimestamp(0))
		uassert.Equal(t, int64(0), GetHalvingYearMaxAmount(0))
		uassert.Equal(t, int64(0), GetHalvingYearMintAmount(0))
		uassert.Equal(t, int64(0), GetHalvingYearAccuAmount(0))
	})

	t.Run("invalid year 13", func(t *testing.T) {
		uassert.Equal(t, int64(0), GetHalvingYearStartTimestamp(13))
		uassert.Equal(t, int64(0), GetHalvingYearEndTimestamp(13))
		uassert.Equal(t, int64(0), GetHalvingYearTimestamp(13))
		uassert.Equal(t, int64(0), GetHalvingYearMaxAmount(13))
		uassert.Equal(t, int64(0), GetHalvingYearMintAmount(13))
		uassert.Equal(t, int64(0), GetHalvingYearAccuAmount(13))
	})
}

func TestAmountPerSecondsPerHalvingYear(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the amount per seconds for a valid year
	amountPerSeconds := GetAmountPerSecondPerHalvingYear(6)
	uassert.True(t, amountPerSeconds > 0)
}

func TestGetHalvingInfo(t *testing.T) {
	jsonStr, err := json.Unmarshal([]byte(GetHalvingInfo()))
	uassert.NoError(t, err)

	halving := jsonStr.MustKey("halvings").MustArray()
	uassert.Equal(t, len(halving), 12)
}

func TestValidBlockTime(t *testing.T) {
	const maxBlockTime int64 = 1_000_000_000 // 1e9

	tests := []struct {
		name        string
		blockTime   int64
		shouldError bool
	}{
		// Lower boundary
		{"blockTime = -1 (invalid)", -1, true},
		{"blockTime = 0 (invalid)", 0, true},
		{"blockTime = 1 (valid, min boundary)", 1, false},

		// Upper boundary
		{"blockTime = maxBlockTime-1 (valid, max boundary)", maxBlockTime - 1, false},
		{"blockTime = maxBlockTime (invalid)", maxBlockTime, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validBlockTime(tt.blockTime)
			if tt.shouldError {
				uassert.ErrorIs(t, errInvalidAvgBlockTimeInMs, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestGetHalvingYearInfoValidation tests various scenarios for GetHalvingYearInfo
// to ensure proper validation and handling of edge cases
func TestGetHalvingYearInfoValidation(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	es := getEmissionState()

	tests := []struct {
		name            string
		timestampOffset int64 // offset from start timestamp
		expectedYear    int64
		description     string
	}{
		{
			name:            "Before emission start",
			timestampOffset: -1000,
			expectedYear:    0,
			description:     "Should return year 1 even before emission starts",
		},
		{
			name:            "Start of emission",
			timestampOffset: 0,
			expectedYear:    1,
			description:     "Should return year 1 at emission start",
		},
		{
			name:            "Middle of year 1",
			timestampOffset: SECONDS_IN_YEAR / 2,
			expectedYear:    1,
			description:     "Should return year 1 in the middle of first year",
		},
		{
			name:            "End of year 1",
			timestampOffset: SECONDS_IN_YEAR - 1,
			expectedYear:    1,
			description:     "Should return year 1 at the end of first year",
		},
		{
			name:            "Start of year 2",
			timestampOffset: SECONDS_IN_YEAR,
			expectedYear:    2,
			description:     "Should return year 2 at the start of second year",
		},
		{
			name:            "Middle of year 6",
			timestampOffset: (SECONDS_IN_YEAR * 5) + (SECONDS_IN_YEAR / 2),
			expectedYear:    6,
			description:     "Should return year 6 in the middle of sixth year",
		},
		{
			name:            "Start of year 12",
			timestampOffset: SECONDS_IN_YEAR * 11,
			expectedYear:    12,
			description:     "Should return year 12 at the start of final year",
		},
		{
			name:            "End of year 12",
			timestampOffset: (SECONDS_IN_YEAR * 12) - 1,
			expectedYear:    12,
			description:     "Should return year 12 at the end of emission period",
		},
		{
			name:            "Just after emission end",
			timestampOffset: (SECONDS_IN_YEAR * 12) + 1,
			expectedYear:    0,
			description:     "Should return 0 immediately after emission ends",
		},
		{
			name:            "Far after emission end",
			timestampOffset: SECONDS_IN_YEAR * 20,
			expectedYear:    0,
			description:     "Should return 0 far after emission ends",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			timestamp := es.getStartTimestamp() + tt.timestampOffset
			year, _, _ := GetHalvingYearInfo(timestamp)

			uassert.Equal(t, tt.expectedYear, year,
				"Year mismatch for %s: %s", tt.name, tt.description)
		})
	}
}

// TestHalvingDataGettersWithInvalidYear tests that HalvingData getters handle invalid years properly
func TestHalvingDataGettersWithInvalidYear(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	hd := &HalvingData{
		startTimestamps: make([]int64, HALVING_END_YEAR),
		endTimestamps:   make([]int64, HALVING_END_YEAR),
		maxAmount:       make([]int64, HALVING_END_YEAR),
		mintedAmount:    make([]int64, HALVING_END_YEAR),
		leftAmount:      make([]int64, HALVING_END_YEAR),
		accumAmount:     make([]int64, HALVING_END_YEAR),
		amountPerSecond: make([]int64, HALVING_END_YEAR),
	}

	// Set test values for valid years
	for i := int64(0); i < HALVING_END_YEAR; i++ {
		hd.startTimestamps[i] = 1000 + i*100
		hd.endTimestamps[i] = 2000 + i*100
		hd.maxAmount[i] = 4000 + i*100
		hd.mintedAmount[i] = 5000 + i*100
		hd.leftAmount[i] = 6000 + i*100
		hd.accumAmount[i] = 7000 + i*100
		hd.amountPerSecond[i] = 8000 + i*100
	}

	tests := []struct {
		name     string
		year     int64
		getter   func(int64) int64
		expected int64
	}{
		// Year 0 tests (should return 0)
		{"StartTimestamp with year 0", 0, hd.getStartTimestamp, 0},
		{"EndTimestamp with year 0", 0, hd.getEndTimestamp, 0},
		{"MaxAmount with year 0", 0, hd.getMaxAmount, 0},
		{"MintedAmount with year 0", 0, hd.getMintedAmount, 0},
		{"LeftAmount with year 0", 0, hd.getLeftAmount, 0},
		{"AccumAmount with year 0", 0, hd.getAccumAmount, 0},
		{"AmountPerSeconds with year 0", 0, hd.getAmountPerSecond, 0},

		// Year -1 tests (negative year, should return 0)
		{"StartTimestamp with year -1", -1, hd.getStartTimestamp, 0},
		{"EndTimestamp with year -1", -1, hd.getEndTimestamp, 0},
		{"MaxAmount with year -1", -1, hd.getMaxAmount, 0},

		// Year 13 tests (beyond max, should return 0)
		{"StartTimestamp with year 13", 13, hd.getStartTimestamp, 0},
		{"EndTimestamp with year 13", 13, hd.getEndTimestamp, 0},
		{"MaxAmount with year 13", 13, hd.getMaxAmount, 0},

		// Year 100 tests (far beyond max, should return 0)
		{"StartTimestamp with year 100", 100, hd.getStartTimestamp, 0},

		// Valid year tests
		{"StartTimestamp with year 1", 1, hd.getStartTimestamp, 1000},
		{"EndTimestamp with year 1", 1, hd.getEndTimestamp, 2000},
		{"MaxAmount with year 1", 1, hd.getMaxAmount, 4000},
		{"MintedAmount with year 1", 1, hd.getMintedAmount, 5000},
		{"LeftAmount with year 1", 1, hd.getLeftAmount, 6000},
		{"AccumAmount with year 1", 1, hd.getAccumAmount, 7000},
		{"AmountPerSeconds with year 1", 1, hd.getAmountPerSecond, 8000},

		// Last valid year tests
		{"StartTimestamp with year 12", 12, hd.getStartTimestamp, 2100},
		{"EndTimestamp with year 12", 12, hd.getEndTimestamp, 3100},
		{"MaxAmount with year 12", 12, hd.getMaxAmount, 5100},
		{"MintedAmount with year 12", 12, hd.getMintedAmount, 6100},
		{"LeftAmount with year 12", 12, hd.getLeftAmount, 7100},
		{"AccumAmount with year 12", 12, hd.getAccumAmount, 8100},
		{"AmountPerSeconds with year 12", 12, hd.getAmountPerSecond, 9100},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := tt.getter(tt.year)
			uassert.Equal(t, tt.expected, result,
				"Unexpected result for %s", tt.name)
		})
	}
}

// TestHalvingDataSettersWithInvalidYear tests all HalvingData setters with invalid years
func TestHalvingDataSettersWithInvalidYear(t *testing.T) {
	hd := NewHalvingData(1000)

	tests := []struct {
		name        string
		year        int64
		setter      func(int64) error
		shouldError bool
	}{
		// Year 0 tests
		{"setStartTimestamp with year 0", 0, func(y int64) error { return hd.setStartTimestamp(y, 2000) }, true},
		{"setEndTimestamp with year 0", 0, func(y int64) error { return hd.setEndTimestamp(y, 2000) }, true},
		{"setMaxAmount with year 0", 0, func(y int64) error { return hd.setMaxAmount(y, 1000) }, true},
		{"setMintedAmount with year 0", 0, func(y int64) error { return hd.setMintedAmount(y, 1000) }, true},
		{"setAccumAmount with year 0", 0, func(y int64) error { return hd.setAccumAmount(y, 1000) }, true},
		{"setLeftAmount with year 0", 0, func(y int64) error { return hd.setLeftAmount(y, 1000) }, true},
		{"setAmountPerSecond with year 0", 0, func(y int64) error { return hd.setAmountPerSecond(y, 1000) }, true},
		{"addAccumAmount with year 0", 0, func(y int64) error { return hd.addAccumAmount(y, 1000) }, true},

		// Negative year tests
		{"setStartTimestamp with year -1", -1, func(y int64) error { return hd.setStartTimestamp(y, 2000) }, true},
		{"setEndTimestamp with year -1", -1, func(y int64) error { return hd.setEndTimestamp(y, 2000) }, true},
		{"setMaxAmount with year -1", -1, func(y int64) error { return hd.setMaxAmount(y, 1000) }, true},
		{"setMaxAmount with year -100", -100, func(y int64) error { return hd.setMaxAmount(y, 1000) }, true},

		// Year > 12 tests
		{"setStartTimestamp with year 13", 13, func(y int64) error { return hd.setStartTimestamp(y, 2000) }, true},
		{"setEndTimestamp with year 13", 13, func(y int64) error { return hd.setEndTimestamp(y, 2000) }, true},
		{"setMaxAmount with year 13", 13, func(y int64) error { return hd.setMaxAmount(y, 1000) }, true},
		{"setMaxAmount with year 100", 100, func(y int64) error { return hd.setMaxAmount(y, 1000) }, true},

		// Valid year tests
		{"setStartTimestamp with year 1", 1, func(y int64) error { return hd.setStartTimestamp(y, 2000) }, false},
		{"setEndTimestamp with year 1", 1, func(y int64) error { return hd.setEndTimestamp(y, 2000) }, false},
		{"setMaxAmount with year 1", 1, func(y int64) error { return hd.setMaxAmount(y, 1000) }, false},
		{"setStartTimestamp with year 12", 12, func(y int64) error { return hd.setStartTimestamp(y, 2000) }, false},
		{"setEndTimestamp with year 12", 12, func(y int64) error { return hd.setEndTimestamp(y, 2000) }, false},
		{"setMaxAmount with year 12", 12, func(y int64) error { return hd.setMaxAmount(y, 1000) }, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.setter(tt.year)

			if tt.shouldError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// TestHalvingDataBoundaryTimestamps tests HalvingData with boundary timestamp values
func TestHalvingDataBoundaryTimestamps(t *testing.T) {
	tests := []struct {
		name           string
		startTimestamp int64
		year           int64
		expectedStart  int64
		expectedEnd    int64
	}{
		{
			name:           "Very small timestamp",
			startTimestamp: 1,
			year:           1,
			expectedStart:  1,
			expectedEnd:    1 + SECONDS_IN_YEAR - 1,
		},
		{
			name:           "Large timestamp",
			startTimestamp: 9999999999,
			year:           1,
			expectedStart:  9999999999,
			expectedEnd:    9999999999 + SECONDS_IN_YEAR - 1,
		},
		{
			name:           "Zero timestamp",
			startTimestamp: 0,
			year:           1,
			expectedStart:  0,
			expectedEnd:    SECONDS_IN_YEAR - 1,
		},
		{
			name:           "Year 12 with normal timestamp",
			startTimestamp: 1000,
			year:           12,
			expectedStart:  1000 + (SECONDS_IN_YEAR * 11),
			expectedEnd:    1000 + (SECONDS_IN_YEAR * 12) - 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hd := NewHalvingData(tt.startTimestamp)

			startTimestamp := hd.getStartTimestamp(tt.year)
			endTimestamp := hd.getEndTimestamp(tt.year)

			uassert.Equal(t, tt.expectedStart, startTimestamp, "Start timestamp mismatch")
			uassert.Equal(t, tt.expectedEnd, endTimestamp, "End timestamp mismatch")
		})
	}
}

// TestHalvingDataAmountOperations tests amount calculations with edge values
func TestHalvingDataAmountOperations(t *testing.T) {
	hd := NewHalvingData(1000)

	tests := []struct {
		name           string
		year           int64
		operation      func()
		validateAmount func(*testing.T)
	}{
		{
			name: "Add accumAmount multiple times",
			year: 1,
			operation: func() {
				hd.addAccumAmount(1, 100)
				hd.addAccumAmount(1, 200)
				hd.addAccumAmount(1, 300)
			},
			validateAmount: func(t *testing.T) {
				amount := hd.getAccumAmount(1)
				uassert.Equal(t, int64(600), amount, "Accumulated amount should be sum of additions")
			},
		},
		{
			name: "Set and modify left amount",
			year: 5,
			operation: func() {
				initialMax := hd.getMaxAmount(5)
				hd.setLeftAmount(5, initialMax-1000)
			},
			validateAmount: func(t *testing.T) {
				left := hd.getLeftAmount(5)
				max := hd.getMaxAmount(5)
				uassert.Equal(t, max-1000, left, "Left amount should be reduced")
			},
		},
		{
			name: "Amount per second consistency",
			year: 7,
			operation: func() {
				// No operation needed, just validation
			},
			validateAmount: func(t *testing.T) {
				yearAmount := hd.getMaxAmount(7)
				perSecond := hd.getAmountPerSecond(7)

				// perSecond * SECONDS_IN_YEAR should be approximately equal to yearAmount
				calculatedTotal := perSecond * SECONDS_IN_YEAR
				diff := yearAmount - calculatedTotal

				// Allow small difference due to integer division
				uassert.True(t, diff >= 0 && diff < SECONDS_IN_YEAR,
					"Amount per second calculation should be consistent")
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.operation()
			tt.validateAmount(t)
		})
	}
}

// TestHalvingDataAddAccumAmountOverflow tests overflow protection in HalvingData.addAccumAmount
func TestHalvingDataAddAccumAmountOverflow(t *testing.T) {
	tests := []struct {
		name         string
		year         int64
		initialValue int64
		addAmount    int64
		shouldPanic  bool
		panicMsg     string
	}{
		{
			name:         "normal addition year 1",
			year:         1,
			initialValue: 1000,
			addAmount:    2000,
			shouldPanic:  false,
		},
		{
			name:         "normal addition year 12",
			year:         12,
			initialValue: 5000,
			addAmount:    3000,
			shouldPanic:  false,
		},
		{
			name:         "overflow - MaxInt64 + 1",
			year:         1,
			initialValue: math.MaxInt64,
			addAmount:    1,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "overflow - near MaxInt64",
			year:         2,
			initialValue: math.MaxInt64 - 50,
			addAmount:    100,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "overflow - large positive values",
			year:         3,
			initialValue: math.MaxInt64/2 + 1,
			addAmount:    math.MaxInt64/2 + 1,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "boundary - exactly MaxInt64",
			year:         4,
			initialValue: math.MaxInt64 - 500,
			addAmount:    500,
			shouldPanic:  false,
		},
		{
			name:         "add zero",
			year:         5,
			initialValue: math.MaxInt64,
			addAmount:    0,
			shouldPanic:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			hd := NewHalvingData(1000)

			// Set initial accumulated amount
			hd.setAccumAmount(tt.year, tt.initialValue)

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					hd.addAccumAmount(tt.year, tt.addAmount)
				})
			} else {
				err := hd.addAccumAmount(tt.year, tt.addAmount)
				uassert.NoError(t, err)

				// Verify the result
				expected := tt.initialValue + tt.addAmount
				actual := hd.getAccumAmount(tt.year)
				uassert.Equal(t, expected, actual)
			}
		})
	}
}
