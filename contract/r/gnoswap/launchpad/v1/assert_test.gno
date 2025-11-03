package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

func TestAssert_assertIsValidAmount(t *testing.T) {
	tests := []struct {
		name          string
		amount        int64
		expectedPanic bool
		expectedError string
	}{
		{
			name:          "valid amount - exactly minimum",
			amount:        1_000_000,
			expectedPanic: false,
		},
		{
			name:          "valid amount - 2x minimum",
			amount:        2_000_000,
			expectedPanic: false,
		},
		{
			name:          "valid amount - 10x minimum",
			amount:        10_000_000,
			expectedPanic: false,
		},
		{
			name:          "valid amount - large multiple",
			amount:        1_000_000_000,
			expectedPanic: false,
		},
		{
			name:          "panic when amount is zero",
			amount:        0,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is less than minimum",
			amount:        999_999,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is less than minimum (small value)",
			amount:        100,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is not a multiple of minimum",
			amount:        1_000_001,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is not a multiple of minimum (large)",
			amount:        10_000_001,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
		{
			name:          "panic when amount is negative",
			amount:        -1_000_000,
			expectedPanic: true,
			expectedError: "GNOSWAP-LAUNCHPAD-017",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedPanic {
				defer func() {
					r := recover()
					uassert.NotNil(t, r)
					uassert.ErrorContains(t, r.(error), tt.expectedError)
				}()
			}

			assertIsValidAmount(tt.amount)

			if tt.expectedPanic {
				t.Fatal("expected panic but did not occur")
			}
		})
	}
}
