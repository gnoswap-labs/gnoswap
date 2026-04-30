package gnsmath

import (
	"math"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"
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
		// Additional cases from pool
		{
			name:     "max + negative (safe)",
			a:        math.MaxInt64,
			b:        -1,
			expected: math.MaxInt64 - 1,
		},
		{
			name:     "min + positive (safe)",
			a:        math.MinInt64,
			b:        1,
			expected: math.MinInt64 + 1,
		},
		{
			name:        "overflow: large + large",
			a:           math.MaxInt64 / 2,
			b:           math.MaxInt64/2 + 2,
			shouldPanic: true,
			panicMsg:    "int64 addition overflow",
		},
		{
			name:        "underflow: large negative + large negative",
			a:           math.MinInt64 / 2,
			b:           math.MinInt64/2 - 1,
			shouldPanic: true,
			panicMsg:    "int64 addition underflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					SafeAddInt64(tt.a, tt.b)
				})
			} else {
				result := SafeAddInt64(tt.a, tt.b)
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
		// Additional cases from pool
		{
			name:     "max - positive (safe)",
			a:        math.MaxInt64,
			b:        1,
			expected: math.MaxInt64 - 1,
		},
		{
			name:     "min - negative (safe)",
			a:        math.MinInt64,
			b:        -1,
			expected: math.MinInt64 + 1,
		},
		{
			name:        "underflow: negative - large positive",
			a:           -100,
			b:           math.MaxInt64,
			shouldPanic: true,
			panicMsg:    "int64 subtraction underflow",
		},
		{
			name:        "overflow: positive - large negative",
			a:           100,
			b:           math.MinInt64,
			shouldPanic: true,
			panicMsg:    "int64 subtraction overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					SafeSubInt64(tt.a, tt.b)
				})
			} else {
				result := SafeSubInt64(tt.a, tt.b)
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
					SafeMulInt64(tt.a, tt.b)
				})
			} else {
				result := SafeMulInt64(tt.a, tt.b)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeMulDivInt64(t *testing.T) {
	tests := []struct {
		name        string
		a           int64
		b           int64
		c           int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "simple multiplication and division",
			a:        1000,
			b:        50,
			c:        100,
			expected: 500,
		},
		{
			name:     "100% of value",
			a:        1000,
			b:        100,
			c:        100,
			expected: 1000,
		},
		{
			name:     "10% of value",
			a:        1000,
			b:        10,
			c:        100,
			expected: 100,
		},
		// Zero cases
		{
			name:     "a is zero",
			a:        0,
			b:        100,
			c:        100,
			expected: 0,
		},
		{
			name:     "b is zero",
			a:        100,
			b:        0,
			c:        100,
			expected: 0,
		},
		{
			name:     "both a and b are zero",
			a:        0,
			b:        0,
			c:        100,
			expected: 0,
		},
		// Division by zero
		{
			name:        "division by zero",
			a:           100,
			b:           50,
			c:           0,
			shouldPanic: true,
			panicMsg:    "division by zero in SafeMulDivInt64",
		},
		// Result is zero after division (too small)
		{
			name:     "result too small - becomes zero",
			a:        1,
			b:        1,
			c:        100,
			expected: 0,
		},
		// Negative values
		{
			name:     "negative a",
			a:        -1000,
			b:        50,
			c:        100,
			expected: -500,
		},
		{
			name:     "negative b",
			a:        1000,
			b:        -50,
			c:        100,
			expected: -500,
		},
		{
			name:     "both negative",
			a:        -1000,
			b:        -50,
			c:        100,
			expected: 500,
		},
		// Large values
		{
			name:     "large values within range",
			a:        1000000000000,
			b:        50,
			c:        100,
			expected: 500000000000,
		},
		{
			name:        "int64 overflow on final conversion",
			a:           math.MaxInt64,
			b:           200,
			c:           100,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		{
			name:     "minInt64 allow negative value",
			a:        math.MinInt64,
			b:        -100,
			c:        -100,
			expected: math.MinInt64,
		},
		{
			name:        "minInt64 overflow on positive value",
			a:           math.MinInt64,
			b:           -100,
			c:           100,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		// Governance scenario cases
		{
			name:     "normal calculation: (10 * 50) / 100",
			a:        10,
			b:        50,
			c:        100,
			expected: 5,
		},
		{
			name:     "quorum calculation: (1000 * 60) / 100",
			a:        1000,
			b:        60,
			c:        100,
			expected: 600,
		},
		{
			name:     "large values within bounds",
			a:        1000000000,
			b:        100,
			c:        100,
			expected: 1000000000,
		},
		{
			name:     "negative divisor: (100 * 50) / -100",
			a:        100,
			b:        50,
			c:        -100,
			expected: -50,
		},
		{
			name:     "integer truncation: (10 * 3) / 7",
			a:        10,
			b:        3,
			c:        7,
			expected: 4,
		},
		{
			name:     "realistic voting weight with 50% quorum",
			a:        100000000000000000,
			b:        50,
			c:        100,
			expected: 50000000000000000,
		},
		{
			name:        "overflow: max int64 * 2 / 1",
			a:           9223372036854775807,
			b:           2,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		{
			name:        "overflow: large positive * large positive",
			a:           3000000000000000000,
			b:           4,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		{
			name:        "underflow: max int64 * -2",
			a:           9223372036854775807,
			b:           -2,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		{
			name:        "underflow: negative * large positive",
			a:           -3000000000000000000,
			b:           4,
			c:           1,
			shouldPanic: true,
			panicMsg:    "int64 overflow in SafeMulDivInt64",
		},
		{
			name:     "boundary safe: max / 2 * 2",
			a:        4611686018427387903,
			b:        2,
			c:        1,
			expected: 9223372036854775806,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					SafeMulDivInt64(tt.a, tt.b, tt.c)
				})
			} else {
				result := SafeMulDivInt64(tt.a, tt.b, tt.c)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeAbsInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       int64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		// Normal cases
		{
			name:     "positive number",
			input:    100,
			expected: 100,
		},
		{
			name:     "negative number",
			input:    -100,
			expected: 100,
		},
		{
			name:     "zero",
			input:    0,
			expected: 0,
		},
		// Boundary cases
		{
			name:     "MaxInt64",
			input:    9223372036854775807,
			expected: 9223372036854775807,
		},
		{
			name:     "negative one",
			input:    -1,
			expected: 1,
		},
		{
			name:     "positive one",
			input:    1,
			expected: 1,
		},
		// Large values
		{
			name:     "large positive",
			input:    9223372036854775800,
			expected: 9223372036854775800,
		},
		{
			name:     "large negative",
			input:    -9223372036854775800,
			expected: 9223372036854775800,
		},
		{
			name:     "MinInt64 + 1",
			input:    -9223372036854775807,
			expected: 9223372036854775807,
		},
		{
			name:        "MinInt64",
			input:       -9223372036854775808,
			shouldPanic: true,
			panicMsg:    "int64 abs overflow",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					SafeAbsInt64(tt.input)
				})
			} else {
				result := SafeAbsInt64(tt.input)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

func TestSafeConvertToInt64(t *testing.T) {
	tests := []struct {
		name          string
		value         *u256.Uint
		expected      int64
		shouldPanic   bool
		expectedError string
	}{
		{
			name:        "Normal case: small positive value",
			value:       u256.NewUint(1000),
			expected:    1000,
			shouldPanic: false,
		},
		{
			name:        "Normal case: zero",
			value:       u256.NewUint(0),
			expected:    0,
			shouldPanic: false,
		},
		{
			name:        "Boundary: int64 max",
			value:       u256.MustFromDecimal("9223372036854775807"),
			expected:    9223372036854775807,
			shouldPanic: false,
		},
		{
			name:          "Overflow: int64 max + 1",
			value:         u256.MustFromDecimal("9223372036854775808"),
			shouldPanic:   true,
			expectedError: "amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:          "Overflow: uint64 max (2^64 - 1)",
			value:         u256.MustFromDecimal("18446744073709551615"),
			shouldPanic:   true,
			expectedError: "amount(18446744073709551615) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:          "Overflow: beyond uint64 (2^64)",
			value:         u256.MustFromDecimal("18446744073709551616"),
			shouldPanic:   true,
			expectedError: "amount(18446744073709551616) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:          "Overflow: large value in uint64 range but beyond int64",
			value:         u256.MustFromDecimal("10000000000000000000"),
			shouldPanic:   true,
			expectedError: "amount(10000000000000000000) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:        "Normal case: typical token amount",
			value:       u256.MustFromDecimal("1000000000000000000"),
			expected:    1000000000000000000,
			shouldPanic: false,
		},
		{
			name:     "medium positive number",
			value:    u256.NewUint(1000000),
			expected: 1000000,
		},
		{
			name:     "2^32",
			value:    u256.NewUint(4294967296),
			expected: 4294967296,
		},
		{
			name:     "2^48",
			value:    u256.NewUint(281474976710656),
			expected: 281474976710656,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.expectedError, func() {
					SafeConvertToInt64(tt.value)
				})
			} else {
				result := SafeConvertToInt64(tt.value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestSafeConvertToUint64(t *testing.T) {
	tests := []struct {
		name      string
		value     *u256.Uint
		wantRes   uint64
		wantPanic bool
		errorMsg  string
	}{
		// Normal cases
		{
			name:      "normal conversion - small",
			value:     u256.NewUint(123),
			wantRes:   123,
			wantPanic: false,
		},
		{
			name:      "normal conversion - medium",
			value:     u256.NewUint(1000000),
			wantRes:   1000000,
			wantPanic: false,
		},
		{
			name:      "zero",
			value:     u256.NewUint(0),
			wantRes:   0,
			wantPanic: false,
		},
		// Boundary cases
		{
			name:      "max uint64 - 2",
			value:     u256.NewUint(18446744073709551613),
			wantRes:   18446744073709551613,
			wantPanic: false,
		},
		{
			name:      "max uint64 - 1",
			value:     u256.NewUint(18446744073709551614),
			wantRes:   18446744073709551614,
			wantPanic: false,
		},
		{
			name:      "max uint64",
			value:     u256.NewUint(1<<64 - 1),
			wantRes:   1<<64 - 1,
			wantPanic: false,
		},
		// Overflow cases
		{
			name:      "overflow - max uint64 + 1",
			value:     u256.MustFromDecimal("18446744073709551616"),
			wantRes:   0,
			wantPanic: true,
			errorMsg:  "amount(18446744073709551616) overflows uint64 range (max: 18446744073709551615)",
		},
		{
			name:      "overflow - large value",
			value:     u256.MustFromDecimal("340282366920938463463374607431768211455"),
			wantRes:   0,
			wantPanic: true,
			errorMsg:  "amount(340282366920938463463374607431768211455) overflows uint64 range (max: 18446744073709551615)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.wantPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					SafeConvertToUint64(tt.value)
				})
			} else {
				res := SafeConvertToUint64(tt.value)
				uassert.Equal(t, tt.wantRes, res)
			}
		})
	}
}

func TestSafeConvertToInt128(t *testing.T) {
	tests := []struct {
		name      string
		value     string
		wantRes   string
		wantPanic bool
		errorMsg  string
	}{
		// Normal cases
		{"zero", "0", "0", false, ""},
		{"small positive value", "123", "123", false, ""},
		{"medium positive value", "1000000", "1000000", false, ""},

		// Power of 2 boundaries
		{"2^64", "18446744073709551616", "18446744073709551616", false, ""},
		{"2^96", "79228162514264337593543950336", "79228162514264337593543950336", false, ""},

		// Boundary cases
		{"close to MAX_INT128", "170141183460469231731687303715884105726", "170141183460469231731687303715884105726", false, ""},
		{"MAX_INT128", "170141183460469231731687303715884105727", "170141183460469231731687303715884105727", false, ""},

		// Overflow cases
		{"just over MAX_INT128", "170141183460469231731687303715884105728", "", true, "amount(170141183460469231731687303715884105728) overflows int128 range"},
		{"large overflow (MAX_UINT128)", "340282366920938463463374607431768211455", "", true, "amount(340282366920938463463374607431768211455) overflows int128 range"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.wantPanic {
				uassert.PanicsWithMessage(t, tt.errorMsg, func() {
					SafeConvertToInt128(u256.MustFromDecimal(tt.value))
				})
			} else {
				res := SafeConvertToInt128(u256.MustFromDecimal(tt.value))
				uassert.Equal(t, tt.wantRes, res.ToString())
			}
		})
	}
}

func TestSafeConversions_ExactBoundaries(t *testing.T) {
	t.Run("uint64 exact boundary", func(t *testing.T) {
		maxValue := u256.MustFromDecimal("18446744073709551615")
		result := SafeConvertToUint64(maxValue)
		uassert.Equal(t, uint64(18446744073709551615), result)

		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"amount(18446744073709551616) overflows uint64 range (max: 18446744073709551615)",
			func() { SafeConvertToUint64(overValue) })
	})

	t.Run("int64 exact boundary", func(t *testing.T) {
		maxValue := u256.MustFromDecimal("9223372036854775807")
		result := SafeConvertToInt64(maxValue)
		uassert.Equal(t, int64(9223372036854775807), result)

		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
			func() { SafeConvertToInt64(overValue) })
	})

	t.Run("int128 exact boundary", func(t *testing.T) {
		maxValue := u256.MustFromDecimal("170141183460469231731687303715884105727")
		result := SafeConvertToInt128(maxValue)
		uassert.Equal(t, "170141183460469231731687303715884105727", result.ToString())

		overValue := new(u256.Uint).Add(maxValue, u256.One())
		uassert.PanicsWithMessage(t,
			"amount(170141183460469231731687303715884105728) overflows int128 range",
			func() { SafeConvertToInt128(overValue) })
	})
}

func TestSafeUint64ToInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       uint64
		expected    int64
		shouldPanic bool
		panicMsg    string
	}{
		{
			name:     "zero",
			input:    0,
			expected: 0,
		},
		{
			name:     "one",
			input:    1,
			expected: 1,
		},
		{
			name:     "max int64 minus one",
			input:    math.MaxInt64 - 1,
			expected: math.MaxInt64 - 1,
		},
		{
			name:     "max int64 boundary",
			input:    math.MaxInt64,
			expected: math.MaxInt64,
		},
		{
			name:        "max int64 plus one overflows",
			input:       uint64(math.MaxInt64) + 1,
			shouldPanic: true,
			panicMsg:    "amount(9223372036854775808) overflows int64 range (max: 9223372036854775807)",
		},
		{
			name:        "max uint64 overflows",
			input:       math.MaxUint64,
			shouldPanic: true,
			panicMsg:    "amount(18446744073709551615) overflows int64 range (max: 9223372036854775807)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsWithMessage(t, tt.panicMsg, func() {
					SafeUint64ToInt64(tt.input)
				})
			} else {
				result := SafeUint64ToInt64(tt.input)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}
