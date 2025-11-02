package v1

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

// TestFormatUint tests uint64 formatting
func TestFormatUint(t *testing.T) {
	tests := []struct {
		name     string
		input    uint64
		expected string
	}{
		{
			name:     "Format zero",
			input:    0,
			expected: "0",
		},
		{
			name:     "Format positive number",
			input:    12345,
			expected: "12345",
		},
		{
			name:     "Format large number",
			input:    18446744073709551615, // max uint64
			expected: "18446744073709551615",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := formatUint(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestFormatInt tests int64 formatting
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected string
	}{
		{
			name:     "Format zero",
			input:    0,
			expected: "0",
		},
		{
			name:     "Format positive number",
			input:    12345,
			expected: "12345",
		},
		{
			name:     "Format negative number",
			input:    -12345,
			expected: "-12345",
		},
		{
			name:     "Format max int64",
			input:    9223372036854775807,
			expected: "9223372036854775807",
		},
		{
			name:     "Format min int64",
			input:    -9223372036854775808,
			expected: "-9223372036854775808",
		},
		{
			name:     "Format one",
			input:    1,
			expected: "1",
		},
		{
			name:     "Format negative one",
			input:    -1,
			expected: "-1",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := formatInt(tc.input)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestB64Encode tests base64 encoding
func TestB64Encode(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "Encode simple string",
			input:    "hello",
			expected: "aGVsbG8=",
		},
		{
			name:     "Encode empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "Encode complex string",
			input:    "Hello, World!",
			expected: "SGVsbG8sIFdvcmxkIQ==",
		},
		{
			name:     "Encode with spaces",
			input:    "hello world",
			expected: "aGVsbG8gd29ybGQ=",
		},
		{
			name:     "Encode special characters",
			input:    "!@#$%^&*()",
			expected: "IUAjJCVeJiooKQ==",
		},
		{
			name:     "Encode numbers",
			input:    "1234567890",
			expected: "MTIzNDU2Nzg5MA==",
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

func TestMilliToSec(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected int64
	}{
		{"zero milliseconds", 0, 0},
		{"one second", 1000, 1},
		{"ten seconds", 10000, 10},
		{"partial second", 1500, 1},
		{"negative milliseconds", -1000, -1},
		{"max value", 9223372036854775807, 9223372036854775},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := milliToSec(tt.input)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestSafeConvertToInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    int64
		shouldPanic bool
	}{
		{"zero", "0", 0, false},
		{"one", "1", 1, false},
		{"max int64", "9223372036854775807", 9223372036854775807, false},
		{"overflow by 1", "9223372036854775808", 0, true},
		{"max uint64", "18446744073709551615", 0, true},
		{"large overflow", "123456789012345678901234567890", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			value := u256.MustFromDecimal(tt.input)
			if tt.shouldPanic {
				uassert.PanicsContains(t, "overflows int64 range", func() {
					safeConvertToInt64(value)
				})
			} else {
				result := safeConvertToInt64(value)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}
