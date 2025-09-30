package gns

import (
	"std"
	"testing"
	"time"

	"gno.land/p/onbloc/json"
	"gno.land/p/nt/uassert"

	"gno.land/p/nt/ufmt"
)

var (
	govRealm = std.NewCodeRealm("gno.land/r/gnoswap/v1/gov/governance")

	startHeight int64 = std.ChainHeight()

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

func TestHalvingYearStartTimestamp(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the start timestamp for a valid year
	startTimestamp := GetHalvingYearStartTimestamp(1)
	uassert.True(t, startTimestamp > 0)
}

func TestHalvingYearTimestamp(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the timestamp for a valid year
	timestamp := GetHalvingYearTimestamp(2)
	uassert.True(t, timestamp > 0)
}

func TestHalvingYearMaxAmount(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the max amount for a valid year
	maxAmount := GetHalvingYearMaxAmount(3)
	uassert.True(t, maxAmount > 0)
}

func TestHalvingYearMintAmount(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the mint amount for a valid year (initially 0)
	mintAmount := GetHalvingYearMintAmount(4)
	uassert.Equal(t, int64(0), mintAmount)
}

func TestHalvingYearAccuAmount(t *testing.T) {
	resetObject(t)
	InitGnsTest(t)

	// Test that we can get the accumulated amount for a valid year (initially 0)
	accuAmount := GetHalvingYearAccuAmount(5)
	uassert.Equal(t, int64(0), accuAmount)
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
	// Test valid block time validation
	err := validBlockTime(0)
	uassert.ErrorIs(t, errInvalidAvgBlockTimeInMs, err)

	err = validBlockTime(-5)
	uassert.ErrorIs(t, errInvalidAvgBlockTimeInMs, err)

	err = validBlockTime(1000)
	uassert.NoError(t, err)
}

func TestEmissionState(t *testing.T) {
	/*
		Test basic emission state functionality
	*/
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
}

func TestAmountPerSecondsCalculation(t *testing.T) {
	/*
		Test that the amount per seconds is correctly calculated for all years
	*/
	resetObject(t)
	InitGnsTest(t)

	es := getEmissionState()

	// Test each year has correct amount per seconds calculation
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
