package emission

import (
	"testing"

	"gno.land/p/demo/uassert"
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
