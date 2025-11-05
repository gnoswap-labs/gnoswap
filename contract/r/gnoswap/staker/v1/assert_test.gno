package v1

import (
	"testing"
	"time"

	"gno.land/p/nt/uassert"
)

// Test assertIsValidAmount

func TestAssertIsValidAmount(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		expectPanic bool
	}{
		{
			name:        "valid positive amount",
			amount:      1000,
			expectPanic: false,
		},
		{
			name:        "valid zero amount",
			amount:      0,
			expectPanic: false,
		},
		{
			name:        "invalid negative amount",
			amount:      -1,
			expectPanic: true,
		},
		{
			name:        "large positive amount",
			amount:      1000000000,
			expectPanic: false,
		},
		{
			name:        "large negative amount",
			amount:      -1000000000,
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be positive", func() {
					assertIsValidAmount(tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidAmount(tt.amount)
				})
			}
		})
	}
}

// Test assertIsValidRewardAmountFormat

func TestAssertIsValidRewardAmountFormat(t *testing.T) {
	tests := []struct {
		name          string
		rewardAmtStr  string
		expectPanic   bool
		expectedError string
	}{
		{
			name:          "valid format",
			rewardAmtStr:  "gno.land/r/gnoswap/gns:1000",
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "valid format with large amount",
			rewardAmtStr:  "gno.land/r/onbloc/bar:999999999",
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "invalid format - missing colon",
			rewardAmtStr:  "gno.land/r/gnoswap/gns1000",
			expectPanic:   true,
			expectedError: "invalid format",
		},
		{
			name:          "invalid format - empty string",
			rewardAmtStr:  "",
			expectPanic:   true,
			expectedError: "invalid format",
		},
		{
			name:          "invalid format - only colon",
			rewardAmtStr:  ":",
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "invalid format - missing amount",
			rewardAmtStr:  "gno.land/r/gnoswap/gns:",
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "invalid format - missing token path",
			rewardAmtStr:  ":1000",
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "invalid format - multiple colons",
			rewardAmtStr:  "gno.land/r/gnoswap/gns:1000:extra",
			expectPanic:   false,
			expectedError: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, tt.expectedError, func() {
					assertIsValidRewardAmountFormat(tt.rewardAmtStr)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidRewardAmountFormat(tt.rewardAmtStr)
				})
			}
		})
	}
}

// Test assertIsValidPoolTier

func TestAssertIsValidPoolTier(t *testing.T) {
	tests := []struct {
		name        string
		tier        uint64
		expectPanic bool
	}{
		{
			name:        "valid tier 0",
			tier:        0,
			expectPanic: false,
		},
		{
			name:        "valid tier 1",
			tier:        1,
			expectPanic: false,
		},
		{
			name:        "valid tier 2",
			tier:        2,
			expectPanic: false,
		},
		{
			name:        "valid tier 3",
			tier:        3,
			expectPanic: false,
		},
		{
			name:        "invalid tier 4 (equal to AllTierCount)",
			tier:        4,
			expectPanic: true,
		},
		{
			name:        "invalid tier 5",
			tier:        5,
			expectPanic: true,
		},
		{
			name:        "invalid very large tier",
			tier:        1000,
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be less than", func() {
					assertIsValidPoolTier(tt.tier)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidPoolTier(tt.tier)
				})
			}
		})
	}
}

// Test assertIsValidFeeRate

func TestAssertIsValidFeeRate(t *testing.T) {
	tests := []struct {
		name        string
		fee         int64
		expectPanic bool
	}{
		{
			name:        "valid fee 0",
			fee:         0,
			expectPanic: false,
		},
		{
			name:        "valid fee 500 (5%)",
			fee:         500,
			expectPanic: false,
		},
		{
			name:        "valid fee 1000 (10% - max)",
			fee:         1000,
			expectPanic: false,
		},
		{
			name:        "invalid fee -1",
			fee:         -1,
			expectPanic: true,
		},
		{
			name:        "invalid fee 1001 (exceeds max)",
			fee:         1001,
			expectPanic: true,
		},
		{
			name:        "invalid fee 10000",
			fee:         10000,
			expectPanic: true,
		},
		{
			name:        "valid fee 100 (1%)",
			fee:         100,
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be in range", func() {
					assertIsValidFeeRate(tt.fee)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidFeeRate(tt.fee)
				})
			}
		})
	}
}

// Test assertIsValidIncentiveEndTime

func TestAssertIsValidIncentiveEndTime(t *testing.T) {
	tests := []struct {
		name        string
		endTime     int64
		expectPanic bool
	}{
		{
			name:        "valid end time - current time",
			endTime:     time.Now().Unix(),
			expectPanic: false,
		},
		{
			name:        "valid end time - far future",
			endTime:     253402300798, // 9999-12-31 23:59:58
			expectPanic: false,
		},
		{
			name:        "invalid end time - at max epoch",
			endTime:     253402300799, // 9999-12-31 23:59:59 (MAX_UNIX_EPOCH_TIME)
			expectPanic: true,
		},
		{
			name:        "invalid end time - beyond max epoch",
			endTime:     253402300800,
			expectPanic: true,
		},
		{
			name:        "valid end time - year 2030",
			endTime:     1893456000, // 2030-01-01 00:00:00
			expectPanic: false,
		},
		{
			name:        "valid end time - zero",
			endTime:     0,
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "cannot be later than", func() {
					assertIsValidIncentiveEndTime(tt.endTime)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidIncentiveEndTime(tt.endTime)
				})
			}
		})
	}
}

// Test assertIsValidIncentiveDuration

func TestAssertIsValidIncentiveDuration(t *testing.T) {
	tests := []struct {
		name        string
		duration    int64
		expectPanic bool
	}{
		{
			name:        "valid duration - 90 days",
			duration:    TIMESTAMP_90DAYS,
			expectPanic: false,
		},
		{
			name:        "valid duration - 180 days",
			duration:    TIMESTAMP_180DAYS,
			expectPanic: false,
		},
		{
			name:        "valid duration - 365 days",
			duration:    TIMESTAMP_365DAYS,
			expectPanic: false,
		},
		{
			name:        "invalid duration - 1 day",
			duration:    86400,
			expectPanic: true,
		},
		{
			name:        "invalid duration - 30 days",
			duration:    2592000,
			expectPanic: true,
		},
		{
			name:        "invalid duration - 91 days",
			duration:    7862400,
			expectPanic: true,
		},
		{
			name:        "invalid duration - 0",
			duration:    0,
			expectPanic: true,
		},
		{
			name:        "invalid duration - negative",
			duration:    -1,
			expectPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be 90, 180, 365 days", func() {
					assertIsValidIncentiveDuration(tt.duration)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidIncentiveDuration(tt.duration)
				})
			}
		})
	}
}

// Test isMidnight

func TestIsMidnight(t *testing.T) {
	tests := []struct {
		name     string
		time     time.Time
		expected bool
	}{
		{
			name:     "midnight 00:00:00",
			time:     time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC),
			expected: true,
		},
		{
			name:     "not midnight 00:00:01",
			time:     time.Date(2024, 1, 1, 0, 0, 1, 0, time.UTC),
			expected: false,
		},
		{
			name:     "not midnight 00:01:00",
			time:     time.Date(2024, 1, 1, 0, 1, 0, 0, time.UTC),
			expected: false,
		},
		{
			name:     "not midnight 01:00:00",
			time:     time.Date(2024, 1, 1, 1, 0, 0, 0, time.UTC),
			expected: false,
		},
		{
			name:     "noon 12:00:00",
			time:     time.Date(2024, 1, 1, 12, 0, 0, 0, time.UTC),
			expected: false,
		},
		{
			name:     "almost midnight 23:59:59",
			time:     time.Date(2024, 1, 1, 23, 59, 59, 0, time.UTC),
			expected: false,
		},
		{
			name:     "midnight with nanoseconds",
			time:     time.Date(2024, 1, 1, 0, 0, 0, 999999999, time.UTC),
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isMidnight(tt.time)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

// Test assertIsValidIncentiveStartTime

func TestAssertIsValidIncentiveStartTime(t *testing.T) {
	// Calculate reference times
	now := time.Now()
	tomorrowMidnight := now.AddDate(0, 0, 1).Truncate(24 * time.Hour)
	dayAfterTomorrowMidnight := now.AddDate(0, 0, 2).Truncate(24 * time.Hour)

	tests := []struct {
		name          string
		startTime     int64
		expectPanic   bool
		expectedError string
	}{
		{
			name:          "valid start time - day after tomorrow midnight",
			startTime:     dayAfterTomorrowMidnight.Unix(),
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "invalid start time - milliseconds format",
			startTime:     time.Now().UnixMilli(),
			expectPanic:   true,
			expectedError: "must be in seconds format",
		},
		{
			name:          "invalid start time - today",
			startTime:     now.Unix(),
			expectPanic:   true,
			expectedError: "must be at least +1 day midnight",
		},
		{
			name:          "invalid start time - tomorrow but not midnight",
			startTime:     tomorrowMidnight.Add(1 * time.Hour).Unix(),
			expectPanic:   true,
			expectedError: "must be midnight",
		},
		{
			name:          "valid start time - far future midnight",
			startTime:     time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC).Unix(),
			expectPanic:   false,
			expectedError: "",
		},
		{
			name:          "valid start time - tomorrow midnight (boundary case)",
			startTime:     tomorrowMidnight.Unix(),
			expectPanic:   false,
			expectedError: "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, tt.expectedError, func() {
					assertIsValidIncentiveStartTime(tt.startTime)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidIncentiveStartTime(tt.startTime)
				})
			}
		})
	}
}

// Edge case tests

func TestAssertIsValidAmount_Boundaries(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		expectPanic bool
	}{
		{
			name:        "boundary - int64 max",
			amount:      9223372036854775807,
			expectPanic: false,
		},
		{
			name:        "boundary - int64 min",
			amount:      -9223372036854775808,
			expectPanic: true,
		},
		{
			name:        "boundary - just below zero",
			amount:      -1,
			expectPanic: true,
		},
		{
			name:        "boundary - exactly zero",
			amount:      0,
			expectPanic: false,
		},
		{
			name:        "boundary - just above zero",
			amount:      1,
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be positive", func() {
					assertIsValidAmount(tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidAmount(tt.amount)
				})
			}
		})
	}
}

func TestAssertIsValidFeeRate_Boundaries(t *testing.T) {
	tests := []struct {
		name        string
		fee         int64
		expectPanic bool
	}{
		{
			name:        "boundary - minimum valid (0)",
			fee:         0,
			expectPanic: false,
		},
		{
			name:        "boundary - maximum valid (1000)",
			fee:         1000,
			expectPanic: false,
		},
		{
			name:        "boundary - just below minimum",
			fee:         -1,
			expectPanic: true,
		},
		{
			name:        "boundary - just above maximum",
			fee:         1001,
			expectPanic: true,
		},
		{
			name:        "boundary - mid range",
			fee:         500,
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				uassert.PanicsContains(t, "must be in range", func() {
					assertIsValidFeeRate(tt.fee)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidFeeRate(tt.fee)
				})
			}
		})
	}
}

func TestAssertIsValidPoolTier_AllValues(t *testing.T) {
	// Test all valid tiers
	for tier := uint64(0); tier < AllTierCount; tier++ {
		t.Run("valid_tier_"+string(rune('0'+tier)), func(t *testing.T) {
			uassert.NotPanics(t, func() {
				assertIsValidPoolTier(tier)
			})
		})
	}

	// Test some invalid tiers
	invalidTiers := []uint64{AllTierCount, AllTierCount + 1, 100, 1000}
	for _, tier := range invalidTiers {
		t.Run("invalid_tier", func(t *testing.T) {
			uassert.PanicsContains(t, "must be less than", func() {
				assertIsValidPoolTier(tier)
			})
		})
	}
}

func TestIncentiveDuration_Constants(t *testing.T) {
	// Verify the duration constants are correct
	uassert.Equal(t, int64(7776000), TIMESTAMP_90DAYS)    // 90 * 24 * 60 * 60
	uassert.Equal(t, int64(15552000), TIMESTAMP_180DAYS)  // 180 * 24 * 60 * 60
	uassert.Equal(t, int64(31536000), TIMESTAMP_365DAYS)  // 365 * 24 * 60 * 60

	// Test that all three constants work
	uassert.NotPanics(t, func() {
		assertIsValidIncentiveDuration(TIMESTAMP_90DAYS)
	})
	uassert.NotPanics(t, func() {
		assertIsValidIncentiveDuration(TIMESTAMP_180DAYS)
	})
	uassert.NotPanics(t, func() {
		assertIsValidIncentiveDuration(TIMESTAMP_365DAYS)
	})
}
