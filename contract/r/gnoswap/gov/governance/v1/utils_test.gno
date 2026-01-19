package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestUtils_formatBool tests boolean formatting
func TestUtils_formatBool(t *testing.T) {
	tests := []struct {
		name     string
		input    bool
		expected string
	}{
		{
			name:     "format true",
			input:    true,
			expected: "true",
		},
		{
			name:     "format false",
			input:    false,
			expected: "false",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := formatBool(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestUtils_formatInt tests integer formatting
func TestUtils_formatInt(t *testing.T) {
	tests := []struct {
		name          string
		input         interface{}
		expected      string
		expectedPanic bool
	}{
		{
			name:     "format int64",
			input:    int64(123),
			expected: "123",
		},
		{
			name:     "format int32",
			input:    int32(456),
			expected: "456",
		},
		{
			name:     "format int8",
			input:    int8(-12),
			expected: "-12",
		},
		{
			name:     "format zero",
			input:    int64(0),
			expected: "0",
		},
		{
			name:     "format negative int64",
			input:    int64(-9223372036854775808),
			expected: "-9223372036854775808",
		},
		{
			name:     "format max int64",
			input:    int64(9223372036854775807),
			expected: "9223372036854775807",
		},
		{
			name:          "invalid type string",
			input:         "invalid",
			expectedPanic: true,
		},
		{
			name:          "invalid type float",
			input:         float64(123.45),
			expectedPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but did not panic")
					}
				}()
				formatInt(tc.input)
			} else {
				// when
				result := formatInt(tc.input)

				// then
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestUtils_parseInt tests int parsing with overflow checking
func TestUtils_parseInt(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
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
func TestUtils_parseInt64(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
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
func TestUtils_parseUint64(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
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
func TestUtils_SafeAddInt64(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					safeAddInt64(tc.a, tc.b)
				})
			} else {
				result := safeAddInt64(tc.a, tc.b)
				uassert.Equal(t, tc.expected, result)
			}
		})
	}
}

// TestUtils_SafeSubInt64 tests safe subtraction with overflow/underflow detection
func TestUtils_SafeSubInt64(t *testing.T) {
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
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					safeSubInt64(tc.a, tc.b)
				})
			} else {
				result := safeSubInt64(tc.a, tc.b)
				uassert.Equal(t, tc.expected, result)
			}
		})
	}
}

// TestUtils_SafeMulDiv tests safe multiplication and division
func TestUtils_SafeMulDiv(t *testing.T) {
	tests := []struct {
		name             string
		description      string
		a                int64
		b                int64
		c                int64
		expected         int64
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:        "normal calculation: (10 * 50) / 100",
			description: "standard percentage calculation",
			a:           10,
			b:           50,
			c:           100,
			expected:    5,
		},
		{
			name:        "quorum calculation: (1000 * 60) / 100",
			description: "typical quorum calculation",
			a:           1000,
			b:           60,
			c:           100,
			expected:    600,
		},
		{
			name:        "large values within bounds",
			description: "large but safe values",
			a:           1000000000,
			b:           100,
			c:           100,
			expected:    1000000000,
		},
		{
			name:        "zero numerator: (0 * 100) / 50",
			description: "zero in first operand",
			a:           0,
			b:           100,
			c:           50,
			expected:    0,
		},
		{
			name:        "zero multiplier: (100 * 0) / 50",
			description: "zero in second operand",
			a:           100,
			b:           0,
			c:           50,
			expected:    0,
		},
		{
			name:        "negative first operand: (-100 * 50) / 100",
			description: "negative value handling",
			a:           -100,
			b:           50,
			c:           100,
			expected:    -50,
		},
		{
			name:        "negative second operand: (100 * -50) / 100",
			description: "negative multiplier",
			a:           100,
			b:           -50,
			c:           100,
			expected:    -50,
		},
		{
			name:        "both negative: (-100 * -50) / 100",
			description: "two negatives make positive",
			a:           -100,
			b:           -50,
			c:           100,
			expected:    50,
		},
		{
			name:        "negative divisor: (100 * 50) / -100",
			description: "negative divisor",
			a:           100,
			b:           50,
			c:           -100,
			expected:    -50,
		},
		{
			name:        "integer truncation: (10 * 3) / 7",
			description: "result truncates towards zero",
			a:           10,
			b:           3,
			c:           7,
			expected:    4, // 30 / 7 = 4.28... -> 4
		},
		{
			name:        "realistic voting weight with 50% quorum",
			description: "realistic governance scenario with safe values",
			a:           100000000000000000, // 1e17 (safe for multiplication)
			b:           50,
			c:           100,
			expected:    50000000000000000, // 5e16
		},
		{
			name:             "division by zero",
			description:      "should panic on division by zero",
			a:                100,
			b:                50,
			c:                0,
			expectedPanic:    true,
			expectedPanicMsg: "division by zero in safeMulDiv",
		},
		{
			name:             "overflow: max int64 * 2",
			description:      "multiplication overflow",
			a:                9223372036854775807,
			b:                2,
			c:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 multiplication overflow in safeMulDiv",
		},
		{
			name:             "overflow: large positive * large positive",
			description:      "large values causing overflow",
			a:                3000000000000000000,
			b:                4,
			c:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 multiplication overflow in safeMulDiv",
		},
		{
			name:             "underflow: max int64 * -2",
			description:      "multiplication underflow with negative",
			a:                9223372036854775807,
			b:                -2,
			c:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 multiplication underflow in safeMulDiv",
		},
		{
			name:             "underflow: negative * large positive",
			description:      "large negative multiplication",
			a:                -3000000000000000000,
			b:                4,
			c:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 multiplication underflow in safeMulDiv",
		},
		{
			name:             "overflow: two large negatives",
			description:      "two negatives causing overflow",
			a:                -3000000000000000000,
			b:                -4,
			c:                1,
			expectedPanic:    true,
			expectedPanicMsg: "int64 multiplication overflow in safeMulDiv",
		},
		{
			name:        "boundary safe: max / 2 * 2",
			description: "boundary case that doesn't overflow",
			a:           4611686018427387903,
			b:           2,
			c:           1,
			expected:    9223372036854775806,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					safeMulDiv(tc.a, tc.b, tc.c)
				})
			} else {
				result := safeMulDiv(tc.a, tc.b, tc.c)
				uassert.Equal(t, tc.expected, result)
			}
		})
	}
}
