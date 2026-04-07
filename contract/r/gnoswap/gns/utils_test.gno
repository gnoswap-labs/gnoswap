package gns

import (
	"math"
	"testing"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	uassert "gno.land/p/nt/uassert/v0"
)

// TestValidEmissionAmountOverflow tests overflow protection in validEmissionAmount
func TestValidEmissionAmountOverflow(t *testing.T) {
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
		t.Run(tt.name, func(t *testing.T) {
			// Set minted amount for test
			mintedEmissionAmount = tt.mintedAmount

			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
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

// TestSafeMulInt64InCalculateAmountToMint tests safeMulInt64 with realistic emission values
func TestSafeMulInt64InCalculateAmountToMint(t *testing.T) {
	tests := []struct {
		name            string
		amountPerSecond int64
		seconds         int64
		shouldPanic     bool
		panicMsg        string
	}{
		{
			name:            "normal emission calculation - 1 year",
			amountPerSecond: 14269406392, // ~14 billion per second (year 1 rate)
			seconds:         SECONDS_IN_YEAR,
			shouldPanic:     false,
		},
		{
			name:            "normal emission calculation - 1 day",
			amountPerSecond: 14269406392,
			seconds:         86400, // 1 day in seconds
			shouldPanic:     false,
		},
		{
			name:            "overflow - extreme amountPerSecond",
			amountPerSecond: math.MaxInt64 / 2,
			seconds:         3,
			shouldPanic:     true,
			panicMsg:        "int64 multiplication overflow",
		},
		{
			name:            "overflow - both large values",
			amountPerSecond: 3037000500,
			seconds:         3037000500,
			shouldPanic:     true,
			panicMsg:        "int64 multiplication overflow",
		},
		{
			name:            "boundary - just under overflow",
			amountPerSecond: 3037000499,
			seconds:         3037000499,
			shouldPanic:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					gnsmath.SafeMulInt64(tt.amountPerSecond, tt.seconds)
				})
			} else {
				result := gnsmath.SafeMulInt64(tt.amountPerSecond, tt.seconds)
				expected := tt.amountPerSecond * tt.seconds
				uassert.Equal(t, expected, result)
			}
		})
	}
}
