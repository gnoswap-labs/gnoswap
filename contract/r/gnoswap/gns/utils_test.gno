package gns

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

// TestValidEmissionAmountOverflow tests overflow protection in validEmissionAmount
func TestValidEmissionAmountOverflow(cur realm, t *testing.T) {
	// Save original values to restore after test
	originalMinted := mintedEmissionAmount

	tests := []struct {
		name         string
		amount       int64
		mintedAmount int64
		shouldPanic  bool
		panicMsg     string
		shouldError  bool
	}{
		{
			name:         "normal amount within limits",
			amount:       1000,
			mintedAmount: 0,
			shouldPanic:  false,
			shouldError:  false,
		},
		{
			name:         "amount causing overflow - MaxInt64 + positive",
			amount:       math.MaxInt64,
			mintedAmount: 1,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "large amount near MaxInt64",
			amount:       math.MaxInt64 - 100,
			mintedAmount: 200,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "both values at half MaxInt64",
			amount:       math.MaxInt64/2 + 1,
			mintedAmount: math.MaxInt64/2 + 1,
			shouldPanic:  true,
			panicMsg:     "int64 addition overflow",
		},
		{
			name:         "negative amount should error",
			amount:       -1,
			mintedAmount: 0,
			shouldPanic:  false,
			shouldError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Set minted amount for test
			mintedEmissionAmount = tt.mintedAmount

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, cur, tt.panicMsg, func() {
					validEmissionAmount(tt.amount)
				})
			} else {
				err := validEmissionAmount(tt.amount)
				if tt.shouldError {
					uassert.Error(t, err)
				} else {
					// Note: may still return error if amount exceeds MAX_EMISSION_AMOUNT
					// but should not panic
				}
			}
		})
	}

	// Restore original value
	mintedEmissionAmount = originalMinted
}
