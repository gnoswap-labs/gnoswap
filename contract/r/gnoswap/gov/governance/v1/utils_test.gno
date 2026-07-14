package v1

import (
	"testing"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	uassert "gno.land/p/nt/uassert/v0"
)

// TestUtils_parseInt tests int parsing with overflow checking
func TestUtils_parseInt(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		input            string
		expected         int
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:     "parse positive integer",
			input:    "123",
			expected: 123,
		},
		{
			name:     "parse negative integer",
			input:    "-456",
			expected: -456,
		},
		{
			name:     "parse zero",
			input:    "0",
			expected: 0,
		},
		{
			name:             "parse empty string",
			input:            "",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int value: empty or whitespace string",
		},
		{
			name:             "parse whitespace string",
			input:            "   ",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int value: empty or whitespace string",
		},
		{
			name:             "parse invalid format",
			input:            "abc",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int value: abc",
		},
		{
			name:             "parse float string",
			input:            "123.45",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int value: 123.45",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, cur, tc.expectedPanicMsg, func() {
					parseInt(tc.input)
				})
			} else {
				// when
				result := parseInt(tc.input)

				// then
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestUtils_parseInt64 tests int64 parsing
func TestUtils_parseInt64(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		input            string
		expected         int64
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:     "parse positive int64",
			input:    "123456789",
			expected: 123456789,
		},
		{
			name:     "parse negative int64",
			input:    "-987654321",
			expected: -987654321,
		},
		{
			name:     "parse zero",
			input:    "0",
			expected: 0,
		},
		{
			name:     "parse max int64",
			input:    "9223372036854775807",
			expected: 9223372036854775807,
		},
		{
			name:     "parse min int64",
			input:    "-9223372036854775808",
			expected: -9223372036854775808,
		},
		{
			name:             "parse empty string",
			input:            "",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int64 value: empty or whitespace string",
		},
		{
			name:             "parse whitespace string",
			input:            "  \t  ",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int64 value: empty or whitespace string",
		},
		{
			name:             "parse invalid format",
			input:            "invalid",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int64 value: invalid",
		},
		{
			name:             "parse overflow",
			input:            "9223372036854775808",
			expectedPanic:    true,
			expectedPanicMsg: "invalid int64 value: 9223372036854775808",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, cur, tc.expectedPanicMsg, func() {
					parseInt64(tc.input)
				})
			} else {
				// when
				result := parseInt64(tc.input)

				// then
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestUtils_parseUint64 tests uint64 parsing
func TestUtils_parseUint64(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		input            string
		expected         uint64
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:     "parse positive uint64",
			input:    "123456789",
			expected: 123456789,
		},
		{
			name:     "parse zero",
			input:    "0",
			expected: 0,
		},
		{
			name:     "parse max uint64",
			input:    "18446744073709551615",
			expected: 18446744073709551615,
		},
		{
			name:             "parse negative number",
			input:            "-1",
			expectedPanic:    true,
			expectedPanicMsg: "invalid uint64 value: -1",
		},
		{
			name:             "parse empty string",
			input:            "",
			expectedPanic:    true,
			expectedPanicMsg: "invalid uint64 value: empty or whitespace string",
		},
		{
			name:             "parse whitespace string",
			input:            "   ",
			expectedPanic:    true,
			expectedPanicMsg: "invalid uint64 value: empty or whitespace string",
		},
		{
			name:             "parse invalid format",
			input:            "abc",
			expectedPanic:    true,
			expectedPanicMsg: "invalid uint64 value: abc",
		},
		{
			name:             "parse overflow",
			input:            "18446744073709551616",
			expectedPanic:    true,
			expectedPanicMsg: "invalid uint64 value: 18446744073709551616",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, cur, tc.expectedPanicMsg, func() {
					parseUint64(tc.input)
				})
			} else {
				// when
				result := parseUint64(tc.input)

				// then
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestUtils_SafeAddInt64 tests safe addition with overflow/underflow detection
func TestUtils_SafeAddInt64(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		description      string
		a                int64
		b                int64
		expected         int64
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:        "positive + positive",
			description: "normal addition of two positive numbers",
			a:           100,
			b:           200,
			expected:    300,
		},
		{
			name:        "negative + negative",
			description: "normal addition of two negative numbers",
			a:           -100,
			b:           -200,
			expected:    -300,
		},
		{
			name:        "positive + negative",
			description: "addition with mixed signs resulting in positive",
			a:           100,
			b:           -50,
			expected:    50,
		},
		{
			name:        "negative + positive",
			description: "addition with mixed signs resulting in negative",
			a:           -100,
			b:           50,
			expected:    -50,
		},
		{
			name:        "zero + positive",
			description: "adding zero to positive",
			a:           0,
			b:           100,
			expected:    100,
		},
		{
			name:        "zero + zero",
			description: "adding two zeros",
			a:           0,
			b:           0,
			expected:    0,
		},
		{
			name:        "max int64 + 0",
			description: "max value plus zero",
			a:           9223372036854775807,
			b:           0,
			expected:    9223372036854775807,
		},
		{
			name:        "min int64 + 0",
			description: "min value plus zero",
			a:           -9223372036854775808,
			b:           0,
			expected:    -9223372036854775808,
		},
		{
			name:             "overflow: max int64 + 1",
			description:      "overflow when adding 1 to max int64",
			a:                9223372036854775807,
			b:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 addition overflow",
		},
		{
			name:             "overflow: large positive + large positive",
			description:      "overflow when adding two large positive numbers",
			a:                9223372036854775000,
			b:                1000,
			expectedPanic:    true,
			expectedPanicMsg: "int64 addition overflow",
		},
		{
			name:             "underflow: min int64 + (-1)",
			description:      "underflow when adding -1 to min int64",
			a:                -9223372036854775808,
			b:                -1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 addition underflow",
		},
		{
			name:             "underflow: large negative + large negative",
			description:      "underflow when adding two large negative numbers",
			a:                -9223372036854775000,
			b:                -1000,
			expectedPanic:    true,
			expectedPanicMsg: "int64 addition underflow",
		},
		{
			name:        "boundary: max - 1 + 1",
			description: "boundary case that doesn't overflow",
			a:           9223372036854775806,
			b:           1,
			expected:    9223372036854775807,
		},
		{
			name:        "boundary: min + 1 + (-1)",
			description: "boundary case that doesn't underflow",
			a:           -9223372036854775807,
			b:           -1,
			expected:    -9223372036854775808,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, cur, tc.expectedPanicMsg, func() {
					gnsmath.SafeAddInt64(tc.a, tc.b)
				})
			} else {
				result := gnsmath.SafeAddInt64(tc.a, tc.b)
				uassert.Equal(t, tc.expected, result)
			}
		})
	}
}

// TestUtils_SafeSubInt64 tests safe subtraction with overflow/underflow detection
func TestUtils_SafeSubInt64(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		description      string
		a                int64
		b                int64
		expected         int64
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:        "positive - positive (positive result)",
			description: "normal subtraction resulting in positive",
			a:           200,
			b:           100,
			expected:    100,
		},
		{
			name:        "positive - positive (negative result)",
			description: "normal subtraction resulting in negative",
			a:           100,
			b:           200,
			expected:    -100,
		},
		{
			name:        "negative - negative",
			description: "subtraction of two negatives",
			a:           -100,
			b:           -200,
			expected:    100,
		},
		{
			name:        "positive - negative",
			description: "subtracting negative from positive",
			a:           100,
			b:           -50,
			expected:    150,
		},
		{
			name:        "negative - positive",
			description: "subtracting positive from negative",
			a:           -100,
			b:           50,
			expected:    -150,
		},
		{
			name:        "zero - positive",
			description: "subtracting from zero",
			a:           0,
			b:           100,
			expected:    -100,
		},
		{
			name:        "zero - zero",
			description: "zero minus zero",
			a:           0,
			b:           0,
			expected:    0,
		},
		{
			name:        "max int64 - 0",
			description: "max value minus zero",
			a:           9223372036854775807,
			b:           0,
			expected:    9223372036854775807,
		},
		{
			name:        "min int64 - 0",
			description: "min value minus zero",
			a:           -9223372036854775808,
			b:           0,
			expected:    -9223372036854775808,
		},
		{
			name:             "underflow: min int64 - 1",
			description:      "underflow when subtracting 1 from min int64",
			a:                -9223372036854775808,
			b:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 subtraction underflow",
		},
		{
			name:             "underflow: min int64 - max int64",
			description:      "underflow when subtracting max from min",
			a:                -9223372036854775808,
			b:                9223372036854775807,
			expectedPanic:    true,
			expectedPanicMsg: "int64 subtraction underflow",
		},
		{
			name:             "overflow: max int64 - (-1)",
			description:      "overflow when subtracting -1 from max int64",
			a:                9223372036854775807,
			b:                -1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 subtraction overflow",
		},
		{
			name:             "overflow: max int64 - min int64",
			description:      "overflow when subtracting min from max",
			a:                9223372036854775807,
			b:                -9223372036854775808,
			expectedPanic:    true,
			expectedPanicMsg: "int64 subtraction overflow",
		},
		{
			name:        "boundary: min int64 + 1 - 1",
			description: "boundary case that doesn't underflow",
			a:           -9223372036854775807,
			b:           1,
			expected:    -9223372036854775808,
		},
		{
			name:        "boundary: max int64 - 1 - (-1)",
			description: "boundary case that doesn't overflow",
			a:           9223372036854775806,
			b:           -1,
			expected:    9223372036854775807,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, cur, tc.expectedPanicMsg, func() {
					gnsmath.SafeSubInt64(tc.a, tc.b)
				})
			} else {
				result := gnsmath.SafeSubInt64(tc.a, tc.b)
				uassert.Equal(t, tc.expected, result)
			}
		})
	}
}
