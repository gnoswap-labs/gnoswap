package gns

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
)

func TestSafeAddInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive + positive",
			a:        100,
			b:        200,
			expected: 300,
		},
		{
			name:     "negative + negative",
			a:        -100,
			b:        -200,
			expected: -300,
		},
		{
			name:     "positive + negative",
			a:        100,
			b:        -50,
			expected: 50,
		},
		{
			name:     "negative + positive",
			a:        -100,
			b:        150,
			expected: 50,
		},
		{
			name:     "zero + zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "zero + positive",
			a:        0,
			b:        100,
			expected: 100,
		},
		{
			name:     "zero + negative",
			a:        0,
			b:        -100,
			expected: -100,
		},
		// Boundary cases - MaxInt64
		{
			name:     "MaxInt64 + 0",
			a:        9223372036854775807,
			b:        0,
			expected: 9223372036854775807,
		},
		{
			name:     "MaxInt64 - 1 + 1",
			a:        9223372036854775806,
			b:        1,
			expected: 9223372036854775807,
		},
		{
			name:        "MaxInt64 + 1 overflow",
			a:           9223372036854775807,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "MaxInt64 + MaxInt64 overflow",
			a:           9223372036854775807,
			b:           9223372036854775807,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:     "MaxInt64 + MinInt64",
			a:        9223372036854775807,
			b:        -9223372036854775808,
			expected: -1,
		},
		// Boundary cases - MinInt64
		{
			name:     "MinInt64 + 0",
			a:        -9223372036854775808,
			b:        0,
			expected: -9223372036854775808,
		},
		{
			name:     "MinInt64 + 1 + (-1)",
			a:        -9223372036854775807,
			b:        -1,
			expected: -9223372036854775808,
		},
		{
			name:        "MinInt64 + (-1) underflow",
			a:           -9223372036854775808,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:        "MinInt64 + MinInt64 underflow",
			a:           -9223372036854775808,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
		{
			name:     "MinInt64 + MaxInt64",
			a:        -9223372036854775808,
			b:        9223372036854775807,
			expected: -1,
		},
		// Large values near boundary
		{
			name:        "large positive overflow",
			a:           9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "large negative underflow",
			a:           -9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeAddInt64(tt.a, tt.b)
				})
			} else {
				result := safeAddInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeSubInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive - positive",
			a:        200,
			b:        100,
			expected: 100,
		},
		{
			name:     "negative - negative",
			a:        -100,
			b:        -200,
			expected: 100,
		},
		{
			name:     "positive - negative",
			a:        100,
			b:        -50,
			expected: 150,
		},
		{
			name:     "negative - positive",
			a:        -100,
			b:        50,
			expected: -150,
		},
		{
			name:     "zero - zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "zero - positive",
			a:        0,
			b:        100,
			expected: -100,
		},
		{
			name:     "zero - negative",
			a:        0,
			b:        -100,
			expected: 100,
		},
		// Boundary cases - MaxInt64
		{
			name:     "MaxInt64 - 0",
			a:        9223372036854775807,
			b:        0,
			expected: 9223372036854775807,
		},
		{
			name:     "MaxInt64 - 1",
			a:        9223372036854775807,
			b:        1,
			expected: 9223372036854775806,
		},
		{
			name:     "MaxInt64 - MaxInt64",
			a:        9223372036854775807,
			b:        9223372036854775807,
			expected: 0,
		},
		{
			name:        "MaxInt64 - (-1) overflow",
			a:           9223372036854775807,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		{
			name:        "MaxInt64 - MinInt64 overflow",
			a:           9223372036854775807,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		// Boundary cases - MinInt64
		{
			name:     "MinInt64 - 0",
			a:        -9223372036854775808,
			b:        0,
			expected: -9223372036854775808,
		},
		{
			name:     "MinInt64 - (-1)",
			a:        -9223372036854775808,
			b:        -1,
			expected: -9223372036854775807,
		},
		{
			name:     "MinInt64 - MinInt64",
			a:        -9223372036854775808,
			b:        -9223372036854775808,
			expected: 0,
		},
		{
			name:        "MinInt64 - 1 underflow",
			a:           -9223372036854775808,
			b:           1,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "MinInt64 - MaxInt64 underflow",
			a:           -9223372036854775808,
			b:           9223372036854775807,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		// Large values near boundary
		{
			name:        "large negative - positive underflow",
			a:           -9223372036854775800,
			b:           100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "large positive - negative overflow",
			a:           9223372036854775800,
			b:           -100,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
		// Edge case: 0 - MinInt64
		{
			name:        "0 - MinInt64 overflow",
			a:           0,
			b:           -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeSubInt64(tt.a, tt.b)
				})
			} else {
				result := safeSubInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeMulInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive * positive",
			a:        100,
			b:        200,
			expected: 20000,
		},
		{
			name:     "negative * negative",
			a:        -100,
			b:        -200,
			expected: 20000,
		},
		{
			name:     "positive * negative",
			a:        100,
			b:        -50,
			expected: -5000,
		},
		{
			name:     "negative * positive",
			a:        -100,
			b:        50,
			expected: -5000,
		},
		// Zero cases
		{
			name:     "zero * zero",
			a:        0,
			b:        0,
			expected: 0,
		},
		{
			name:     "zero * positive",
			a:        0,
			b:        100,
			expected: 0,
		},
		{
			name:     "zero * negative",
			a:        0,
			b:        -100,
			expected: 0,
		},
		{
			name:     "positive * zero",
			a:        100,
			b:        0,
			expected: 0,
		},
		{
			name:     "negative * zero",
			a:        -100,
			b:        0,
			expected: 0,
		},
		// One cases
		{
			name:     "positive * 1",
			a:        9223372036854775807,
			b:        1,
			expected: 9223372036854775807,
		},
		{
			name:     "negative * 1",
			a:        -9223372036854775808,
			b:        1,
			expected: -9223372036854775808,
		},
		{
			name:     "1 * positive",
			a:        1,
			b:        9223372036854775807,
			expected: 9223372036854775807,
		},
		{
			name:     "1 * negative",
			a:        1,
			b:        -9223372036854775808,
			expected: -9223372036854775808,
		},
		{
			name:     "-1 * -1",
			a:        -1,
			b:        -1,
			expected: 1,
		},
		// Boundary cases - positive * positive overflow
		{
			name:        "MaxInt64 * 2 overflow",
			a:           9223372036854775807,
			b:           2,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow",
		},
		{
			name:        "large positive * positive overflow",
			a:           3037000500,
			b:           3037000500,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow",
		},
		{
			name:     "sqrt(MaxInt64) * sqrt(MaxInt64) no overflow",
			a:        3037000499,
			b:        3037000499,
			expected: 9223372030926249001,
		},
		// Boundary cases - negative * negative overflow
		{
			name:        "MinInt64 * -1 overflow",
			a:           -9223372036854775808,
			b:           -1,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow",
		},
		{
			name:        "-MaxInt64 * -2 overflow",
			a:           -9223372036854775807,
			b:           -2,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow",
		},
		{
			name:        "large negative * negative overflow",
			a:           -3037000500,
			b:           -3037000500,
			shouldPanic: true,
			panicMsg:    "int64 multiplication overflow",
		},
		{
			name:     "-sqrt(MaxInt64) * -sqrt(MaxInt64) no overflow",
			a:        -3037000499,
			b:        -3037000499,
			expected: 9223372030926249001,
		},
		// Boundary cases - positive * negative underflow
		{
			name:        "MaxInt64 * -2 underflow",
			a:           9223372036854775807,
			b:           -2,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow",
		},
		{
			name:        "large positive * negative underflow",
			a:           3037000500,
			b:           -3037000500,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow",
		},
		{
			name:     "sqrt(MaxInt64) * -sqrt(MaxInt64) no underflow",
			a:        3037000499,
			b:        -3037000499,
			expected: -9223372030926249001,
		},
		// Boundary cases - negative * positive underflow
		{
			name:        "-MaxInt64 * 2 underflow",
			a:           -9223372036854775807,
			b:           2,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow",
		},
		{
			name:        "MinInt64 * 2 underflow",
			a:           -9223372036854775808,
			b:           2,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow",
		},
		{
			name:        "large negative * positive underflow",
			a:           -3037000500,
			b:           3037000500,
			shouldPanic: true,
			panicMsg:    "int64 multiplication underflow",
		},
		{
			name:     "-sqrt(MaxInt64) * sqrt(MaxInt64) no underflow",
			a:        -3037000499,
			b:        3037000499,
			expected: -9223372030926249001,
		},
		// Edge cases
		{
			name:     "MaxInt64 * -1",
			a:        9223372036854775807,
			b:        -1,
			expected: -9223372036854775807,
		},
		{
			name:     "-1 * MaxInt64",
			a:        -1,
			b:        9223372036854775807,
			expected: -9223372036854775807,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					safeMulInt64(tt.a, tt.b)
				})
			} else {
				result := safeMulInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

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
					safeMulInt64(tt.amountPerSecond, tt.seconds)
				})
			} else {
				result := safeMulInt64(tt.amountPerSecond, tt.seconds)
				expected := tt.amountPerSecond * tt.seconds
				uassert.Equal(t, expected, result)
			}
		})
	}
}
