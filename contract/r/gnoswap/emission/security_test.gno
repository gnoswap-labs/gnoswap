package emission

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestCalculateAmount_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		bptPct               int64
		expectedResult       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid calculation",
			amount:           1000,
			bptPct:           7500,
			expectedResult:   750,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -1000,
			bptPct:               7500,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Negative percentage should panic",
			amount:               1000,
			bptPct:               -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Percentage over 100% should panic",
			amount:               1000,
			bptPct:               10001,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Amount too large should panic",
			amount:               9223372036854775807,
			bptPct:               10000,
			expectedHasPanic:     true,
			expectedPanicMessage: "amount too large, would cause overflow",
		},
		{
			name:             "Zero percentage should return zero",
			amount:           1000,
			bptPct:           0,
			expectedResult:   0,
			expectedHasPanic: false,
		},
		{
			name:             "Maximum safe amount",
			amount:           922337203685477,
			bptPct:           10000,
			expectedResult:   922337203685477,
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// when
			result := calculateAmount(tc.amount, tc.bptPct)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestSetLeftGNSAmount_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid positive amount",
			amount:           1000,
			expectedHasPanic: false,
		},
		{
			name:             "Zero amount",
			amount:           0,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "left GNS amount cannot be negative",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			resetObject(t)

			// when
			setLeftGNSAmount(tc.amount)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.amount, GetLeftGNSAmount())
			}
		})
	}
}

func TestSetLastExecutedHeight_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		timestamp            int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid positive timestamp",
			timestamp:        1000,
			expectedHasPanic: false,
		},
		{
			name:             "Zero timestamp",
			timestamp:        0,
			expectedHasPanic: false,
		},
		{
			name:                 "Negative timestamp should panic",
			timestamp:            -100,
			expectedHasPanic:     true,
			expectedPanicMessage: "last executed timestamp cannot be negative",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			resetObject(t)

			// when
			setLastExecutedTimestamp(tc.timestamp)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.timestamp, GetLastExecutedTimestamp())
			}
		})
	}
}

func TestAssertValidDistributionPct_SecurityValidation(t *testing.T) {
	tests := []struct {
		name                 string
		pct01                int64
		pct02                int64
		pct03                int64
		pct04                int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid percentages that sum to 100%",
			pct01:            2500,
			pct02:            2500,
			pct03:            2500,
			pct04:            2500,
			expectedHasPanic: false,
		},
		{
			name:                 "Sum exceeds 100%",
			pct01:                3000,
			pct02:                3000,
			pct03:                3000,
			pct04:                2000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-003] invalid emission percentage || sum of percentages must be 10000, got 11000",
		},
		{
			name:                 "Sum less than 100%",
			pct01:                2000,
			pct02:                2000,
			pct03:                2000,
			pct04:                2000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-003] invalid emission percentage || sum of percentages must be 10000, got 8000",
		},
		{
			name:                 "Negative percentage 1",
			pct01:                -1000,
			pct02:                4000,
			pct03:                3000,
			pct04:                4000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-003] invalid emission percentage || percentage 1 cannot be negative: -1000",
		},
		{
			name:                 "Percentage exceeds 100%",
			pct01:                15000,
			pct02:                0,
			pct03:                0,
			pct04:                0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-003] invalid emission percentage || percentage 1 cannot exceed 100%: 15000",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						if errStr, ok := r.(string); ok {
							uassert.Equal(t, tc.expectedPanicMessage, errStr)
						} else {
							uassert.Equal(t, tc.expectedPanicMessage, r.(error).Error())
						}
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// when
			assertValidDistributionPct(tc.pct01, tc.pct02, tc.pct03, tc.pct04)

			// then - if no panic expected, test passes
		})
	}
}

// Test the calculateAmount function in isolation
func TestCalculateAmount_IsolatedSecurity(t *testing.T) {
	tests := []struct {
		name                 string
		amount               int64
		bptPct               int64
		expectedResult       int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:           "Valid calculation 75%",
			amount:         1000,
			bptPct:         7500,
			expectedResult: 750,
		},
		{
			name:           "Zero percentage",
			amount:         1000,
			bptPct:         0,
			expectedResult: 0,
		},
		{
			name:           "Maximum safe amount",
			amount:         922337203685477,
			bptPct:         10000,
			expectedResult: 922337203685477,
		},
		{
			name:                 "Negative amount should panic",
			amount:               -1000,
			bptPct:               7500,
			expectedHasPanic:     true,
			expectedPanicMessage: "invalid amount or bptPct",
		},
		{
			name:                 "Overflow amount should panic",
			amount:               9223372036854775807,
			bptPct:               10000,
			expectedHasPanic:     true,
			expectedPanicMessage: "amount too large, would cause overflow",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.Equal(t, tc.expectedPanicMessage, r.(string))
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given - test parameters are set in table

			// when
			result := calculateAmount(tc.amount, tc.bptPct)

			// then
			if !tc.expectedHasPanic {
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestAssertValidDistributionPct_IsolatedSecurity(t *testing.T) {
	tests := []struct {
		name                 string
		pct01                int64
		pct02                int64
		pct03                int64
		pct04                int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:  "Valid percentages sum to 100%",
			pct01: 2500,
			pct02: 2500,
			pct03: 2500,
			pct04: 2500,
		},
		{
			name:                 "Negative percentage should panic",
			pct01:                -1000,
			pct02:                4000,
			pct03:                3000,
			pct04:                4000,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-EMISSION-003] invalid emission percentage || percentage 1 cannot be negative: -1000",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						// Handle both string and error types
						var actual string
						if err, ok := r.(error); ok {
							actual = err.Error()
						} else if str, ok := r.(string); ok {
							actual = str
						} else {
							t.Errorf("Unexpected panic type: %T", r)
							return
						}
						uassert.Equal(t, tc.expectedPanicMessage, actual)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given - test parameters are set in table

			// when
			assertValidDistributionPct(tc.pct01, tc.pct02, tc.pct03, tc.pct04)

			// then - if no panic expected, test passes
		})
	}
}

// TestAssertValidDistributionTarget tests validation of single distribution targets
func TestAssertValidDistributionTarget(t *testing.T) {
	tests := []struct {
		name        string
		target      int
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "Valid target LIQUIDITY_STAKER",
			target:      LIQUIDITY_STAKER,
			shouldPanic: false,
		},
		{
			name:        "Valid target DEVOPS",
			target:      DEVOPS,
			shouldPanic: false,
		},
		{
			name:        "Valid target COMMUNITY_POOL",
			target:      COMMUNITY_POOL,
			shouldPanic: false,
		},
		{
			name:        "Valid target GOV_STAKER",
			target:      GOV_STAKER,
			shouldPanic: false,
		},
		{
			name:        "Invalid target 0",
			target:      0,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(0)",
		},
		{
			name:        "Invalid target -1",
			target:      -1,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(-1)",
		},
		{
			name:        "Invalid target 5",
			target:      5,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(5)",
		},
		{
			name:        "Invalid target 999",
			target:      999,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(999)",
		},
		{
			name:        "Invalid target max int",
			target:      2147483647,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(2147483647)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertValidDistributionTarget(tt.target)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertValidDistributionTarget(tt.target)
				})
			}
		})
	}
}

// TestAssertValidDistributionTargets tests validation of all four distribution targets
func TestAssertValidDistributionTargets_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		target01    int
		target02    int
		target03    int
		target04    int
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:        "All valid unique targets",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: false,
		},
		{
			name:        "All valid targets in different order",
			target01:    GOV_STAKER,
			target02:    COMMUNITY_POOL,
			target03:    DEVOPS,
			target04:    LIQUIDITY_STAKER,
			shouldPanic: false,
		},
		{
			name:        "First target invalid",
			target01:    0,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(0)",
		},
		{
			name:        "Last target invalid",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    COMMUNITY_POOL,
			target04:    99,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-002] invalid emission target || invalid target(99)",
		},
		{
			name:        "Duplicate first and second targets",
			target01:    LIQUIDITY_STAKER,
			target02:    LIQUIDITY_STAKER,
			target03:    COMMUNITY_POOL,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-004] duplicate emission target",
		},
		{
			name:        "Duplicate last two targets",
			target01:    LIQUIDITY_STAKER,
			target02:    DEVOPS,
			target03:    GOV_STAKER,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-004] duplicate emission target",
		},
		{
			name:        "All same targets",
			target01:    LIQUIDITY_STAKER,
			target02:    LIQUIDITY_STAKER,
			target03:    LIQUIDITY_STAKER,
			target04:    LIQUIDITY_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-004] duplicate emission target",
		},
		{
			name:        "Three targets same",
			target01:    DEVOPS,
			target02:    DEVOPS,
			target03:    DEVOPS,
			target04:    GOV_STAKER,
			shouldPanic: true,
			panicMsg:    "[GNOSWAP-EMISSION-004] duplicate emission target",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					assertValidDistributionTargets(tt.target01, tt.target02, tt.target03, tt.target04)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertValidDistributionTargets(tt.target01, tt.target02, tt.target03, tt.target04)
				})
			}
		})
	}
}

// TestFormatUint tests formatUint function with edge cases
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name        string
		value       any
		expected    string
		shouldPanic bool
	}{
		{
			name:     "uint8 zero",
			value:    uint8(0),
			expected: "0",
		},
		{
			name:     "uint8 max",
			value:    uint8(255),
			expected: "255",
		},
		{
			name:     "uint32 zero",
			value:    uint32(0),
			expected: "0",
		},
		{
			name:     "uint32 max",
			value:    uint32(4294967295),
			expected: "4294967295",
		},
		{
			name:     "uint64 zero",
			value:    uint64(0),
			expected: "0",
		},
		{
			name:     "uint64 max",
			value:    uint64(18446744073709551615),
			expected: "18446744073709551615",
		},
		{
			name:        "invalid type int",
			value:       int(123),
			shouldPanic: true,
		},
		{
			name:        "invalid type string",
			value:       "123",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic but got none")
					}
				}()
				formatUint(tt.value)
			} else {
				result := formatUint(tt.value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

// TestFormatInt tests formatInt function with edge cases
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name        string
		value       any
		expected    string
		shouldPanic bool
	}{
		{
			name:     "int zero",
			value:    int(0),
			expected: "0",
		},
		{
			name:     "int positive",
			value:    int(123),
			expected: "123",
		},
		{
			name:     "int negative",
			value:    int(-123),
			expected: "-123",
		},
		{
			name:     "int32 zero",
			value:    int32(0),
			expected: "0",
		},
		{
			name:     "int32 max",
			value:    int32(2147483647),
			expected: "2147483647",
		},
		{
			name:     "int32 min",
			value:    int32(-2147483648),
			expected: "-2147483648",
		},
		{
			name:     "int64 zero",
			value:    int64(0),
			expected: "0",
		},
		{
			name:     "int64 max",
			value:    int64(9223372036854775807),
			expected: "9223372036854775807",
		},
		{
			name:     "int64 min",
			value:    int64(-9223372036854775808),
			expected: "-9223372036854775808",
		},
		{
			name:        "invalid type uint",
			value:       uint(123),
			shouldPanic: true,
		},
		{
			name:        "invalid type string",
			value:       "123",
			shouldPanic: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("Expected panic but got none")
					}
				}()
				formatInt(tt.value)
			} else {
				result := formatInt(tt.value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}
