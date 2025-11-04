package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestUtils_b64Encode tests base64 encoding
func TestUtils_b64Encode(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "encode simple string",
			input:    "hello",
			expected: "aGVsbG8=",
		},
		{
			name:     "encode empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "encode string with special characters",
			input:    "Hello, World!",
			expected: "SGVsbG8sIFdvcmxkIQ==",
		},
		{
			name:     "encode unicode string",
			input:    "안녕하세요",
			expected: "7JWI64WV7ZWY7IS47JqU",
		},
		{
			name:     "encode JSON string",
			input:    `{"key":"value"}`,
			expected: "eyJrZXkiOiJ2YWx1ZSJ9",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := b64Encode(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

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
