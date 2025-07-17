package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
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
