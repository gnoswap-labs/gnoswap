package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestFormatInt tests integer formatting
func TestFormatInt(t *testing.T) {
	tests := []struct {
		name          string
		input         interface{}
		expected      string
		expectedPanic bool
	}{
		// Valid int64 cases
		{
			name:     "Format int64 positive",
			input:    int64(123),
			expected: "123",
		},
		{
			name:     "Format int64 zero",
			input:    int64(0),
			expected: "0",
		},
		{
			name:     "Format int64 negative",
			input:    int64(-123),
			expected: "-123",
		},
		{
			name:     "Format int64 max",
			input:    int64(9223372036854775807),
			expected: "9223372036854775807",
		},
		{
			name:     "Format int64 min",
			input:    int64(-9223372036854775808),
			expected: "-9223372036854775808",
		},
		// Valid int32 cases
		{
			name:     "Format int32 positive",
			input:    int32(456),
			expected: "456",
		},
		{
			name:     "Format int32 zero",
			input:    int32(0),
			expected: "0",
		},
		{
			name:     "Format int32 negative",
			input:    int32(-456),
			expected: "-456",
		},
		{
			name:     "Format int32 max",
			input:    int32(2147483647),
			expected: "2147483647",
		},
		{
			name:     "Format int32 min",
			input:    int32(-2147483648),
			expected: "-2147483648",
		},
		// Valid int8 cases
		{
			name:     "Format int8 positive",
			input:    int8(12),
			expected: "12",
		},
		{
			name:     "Format int8 negative",
			input:    int8(-12),
			expected: "-12",
		},
		{
			name:     "Format int8 max",
			input:    int8(127),
			expected: "127",
		},
		{
			name:     "Format int8 min",
			input:    int8(-128),
			expected: "-128",
		},
		// Invalid type cases
		{
			name:          "Invalid type string",
			input:         "invalid",
			expectedPanic: true,
		},
		{
			name:          "Invalid type uint",
			input:         uint(123),
			expectedPanic: true,
		},
		{
			name:          "Invalid type float64",
			input:         float64(123.45),
			expectedPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsContains(t, "invalid type", func() {
					formatInt(tc.input)
				})
			} else {
				result := formatInt(tc.input)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

func TestFormatBool(t *testing.T) {
	tests := []struct {
		name     string
		input    bool
		expected string
	}{
		{"true value", true, "true"},
		{"false value", false, "false"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatBool(tt.input)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestB64Encode(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{"empty string", "", ""},
		{"simple text", "hello", "aGVsbG8="},
		{"text with spaces", "hello world", "aGVsbG8gd29ybGQ="},
		{"special characters", "!@#$%^&*()", "IUAjJCVeJiooKQ=="},
		{"unicode", "こんにちは", "44GT44KT44Gr44Gh44Gv"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := b64Encode(tt.input)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestParseBoolEdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    bool
		shouldPanic bool
	}{
		{"valid true", "true", true, false},
		{"valid false", "false", false, false},
		{"invalid empty", "", false, true},
		{"invalid whitespace", "   ", false, true},
		{"invalid value", "yes", false, true},
		{"invalid 1", "1", false, true},
		{"invalid 0", "0", false, true},
		{"invalid TRUE", "TRUE", false, true},
		{"invalid False", "False", false, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid bool value", func() {
					parseBool(tt.input)
				})
			} else {
				result := parseBool(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestParseInt(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    int
		shouldPanic bool
	}{
		{"valid zero", "0", 0, false},
		{"valid positive", "123", 123, false},
		{"valid negative", "-123", -123, false},
		{"invalid empty", "", 0, true},
		{"invalid whitespace", "   ", 0, true},
		{"invalid non-numeric", "abc", 0, true},
		{"invalid float", "12.34", 0, true},
		{"invalid mixed", "12abc", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid int value", func() {
					parseInt(tt.input)
				})
			} else {
				result := parseInt(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestParseInt64(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    int64
		shouldPanic bool
	}{
		{"valid zero", "0", 0, false},
		{"valid positive", "123", 123, false},
		{"valid negative", "-123", -123, false},
		{"valid max int64", "9223372036854775807", 9223372036854775807, false},
		{"valid min int64", "-9223372036854775808", -9223372036854775808, false},
		{"invalid empty", "", 0, true},
		{"invalid whitespace", "   ", 0, true},
		{"invalid non-numeric", "abc", 0, true},
		{"invalid overflow", "9223372036854775808", 0, true},
		{"invalid underflow", "-9223372036854775809", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid int64 value", func() {
					parseInt64(tt.input)
				})
			} else {
				result := parseInt64(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestParseUint64(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    uint64
		shouldPanic bool
	}{
		{"valid zero", "0", 0, false},
		{"valid positive", "123", 123, false},
		{"valid max uint64", "18446744073709551615", 18446744073709551615, false},
		{"invalid negative", "-1", 0, true},
		{"invalid empty", "", 0, true},
		{"invalid whitespace", "   ", 0, true},
		{"invalid non-numeric", "abc", 0, true},
		{"invalid overflow", "18446744073709551616", 0, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid uint64 value", func() {
					parseUint64(tt.input)
				})
			} else {
				result := parseUint64(tt.input)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}

func TestParseNumberEdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		kind        numberKind
		expected    any
		shouldPanic bool
	}{
		// kindInt tests
		{"kindInt zero", "0", kindInt, 0, false},
		{"kindInt positive", "123", kindInt, 123, false},
		{"kindInt negative", "-123", kindInt, -123, false},
		{"kindInt empty", "", kindInt, nil, true},
		{"kindInt invalid", "abc", kindInt, nil, true},
		// kindInt64 tests
		{"kindInt64 zero", "0", kindInt64, int64(0), false},
		{"kindInt64 positive", "123", kindInt64, int64(123), false},
		{"kindInt64 max", "9223372036854775807", kindInt64, int64(9223372036854775807), false},
		{"kindInt64 empty", "", kindInt64, nil, true},
		// kindUint64 tests
		{"kindUint64 zero", "0", kindUint64, uint64(0), false},
		{"kindUint64 positive", "123", kindUint64, uint64(123), false},
		{"kindUint64 max", "18446744073709551615", kindUint64, uint64(18446744073709551615), false},
		{"kindUint64 negative", "-1", kindUint64, nil, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, "invalid", func() {
					parseNumber(tt.input, tt.kind)
				})
			} else {
				result := parseNumber(tt.input, tt.kind)
				uassert.Equal(t, tt.expected, result)
			}
		})
	}
}
