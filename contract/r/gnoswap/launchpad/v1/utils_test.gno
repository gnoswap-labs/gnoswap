package v1

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"
)

func TestFormatInt(t *testing.T) {
	tests := []struct {
		name     string
		input    int64
		expected string
	}{
		{"zero", 0, "0"},
		{"positive one", 1, "1"},
		{"negative one", -1, "-1"},
		{"positive number", 12345, "12345"},
		{"negative number", -12345, "-12345"},
		{"max int64", 9223372036854775807, "9223372036854775807"},
		{"min int64", -9223372036854775808, "-9223372036854775808"},
		{"small positive", 100, "100"},
		{"small negative", -100, "-100"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatInt(tt.input)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestParseProjectTierID(t *testing.T) {
	tests := []struct {
		name               string
		input              string
		expectedProjectID  string
		expectedDuration   int64
		shouldPanic        bool
		expectedPanicMsg   string
	}{
		// Valid cases
		{
			name:              "valid 30 day tier",
			input:             "gno.land/r/demo/token:1000:30",
			expectedProjectID: "gno.land/r/demo/token:1000",
			expectedDuration:  30,
			shouldPanic:       false,
		},
		{
			name:              "valid 90 day tier",
			input:             "gno.land/r/demo/token:2000:90",
			expectedProjectID: "gno.land/r/demo/token:2000",
			expectedDuration:  90,
			shouldPanic:       false,
		},
		{
			name:              "valid 180 day tier",
			input:             "gno.land/r/demo/token:3000:180",
			expectedProjectID: "gno.land/r/demo/token:3000",
			expectedDuration:  180,
			shouldPanic:       false,
		},
		// Invalid cases - wrong format
		{
			name:             "empty string",
			input:            "",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		{
			name:             "only one part",
			input:            "token",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		{
			name:             "only two parts",
			input:            "token:1000",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		{
			name:             "missing duration",
			input:            "token:1000:",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		// Invalid cases - non-numeric duration
		{
			name:             "non-numeric duration",
			input:            "token:1000:abc",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		{
			name:             "float duration",
			input:            "token:1000:30.5",
			shouldPanic:      true,
			expectedPanicMsg: "invalid data",
		},
		// Invalid cases - invalid tier duration
		{
			name:             "invalid tier 0",
			input:            "token:1000:0",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
		{
			name:             "invalid tier 1",
			input:            "token:1000:1",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
		{
			name:             "invalid tier 60",
			input:            "token:1000:60",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
		{
			name:             "invalid tier 120",
			input:            "token:1000:120",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
		{
			name:             "invalid tier 365",
			input:            "token:1000:365",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
		{
			name:             "negative duration",
			input:            "token:1000:-30",
			shouldPanic:      true,
			expectedPanicMsg: "invalid pool",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.expectedPanicMsg, func() {
					parseProjectTierID(tt.input)
				})
			} else {
				projectID, duration := parseProjectTierID(tt.input)
				uassert.Equal(t, tt.expectedProjectID, projectID)
				uassert.Equal(t, tt.expectedDuration, duration)
			}
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
		// Valid cases
		{"zero", "0", 0, false},
		{"one", "1", 1, false},
		{"small positive", "1000", 1000, false},
		{"max int64", "9223372036854775807", 9223372036854775807, false},
		{"mid value", "1234567890", 1234567890, false},
		// Invalid cases - overflow
		{"overflow by 1", "9223372036854775808", 0, true},
		{"overflow by 10", "9223372036854775817", 0, true},
		{"max uint64", "18446744073709551615", 0, true},
		{"large overflow", "999999999999999999999", 0, true},
		{"very large overflow", "123456789012345678901234567890", 0, true},
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

func TestAssertIsValidAmount(t *testing.T) {
	tests := []struct {
		name        string
		amount      int64
		shouldPanic bool
		panicMsg    string
	}{
		// Valid cases
		{"valid minimum amount", minimumDepositAmount, false, ""},
		{"valid 2x minimum", minimumDepositAmount * 2, false, ""},
		{"valid 10x minimum", minimumDepositAmount * 10, false, ""},
		{"valid 100x minimum", minimumDepositAmount * 100, false, ""},
		{"valid large multiple", minimumDepositAmount * 1000, false, ""},
		// Invalid cases - less than minimum
		{"zero amount", 0, true, "should greater than minimum"},
		{"one less than minimum", minimumDepositAmount - 1, true, "should greater than minimum"},
		{"half of minimum", minimumDepositAmount / 2, true, "should greater than minimum"},
		{"negative amount", -1000000, true, "should greater than minimum"},
		{"small positive", 1, true, "should greater than minimum"},
		// Invalid cases - not multiple of minimum
		{"one more than minimum", minimumDepositAmount + 1, true, "must be a multiple"},
		{"minimum + 100", minimumDepositAmount + 100, true, "must be a multiple"},
		{"2x minimum + 1", minimumDepositAmount*2 + 1, true, "must be a multiple"},
		{"minimum + half", minimumDepositAmount + minimumDepositAmount/2, true, "must be a multiple"},
		{"odd number", minimumDepositAmount*5 + 123, true, "must be a multiple"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.shouldPanic {
				uassert.PanicsContains(t, tt.panicMsg, func() {
					assertIsValidAmount(tt.amount)
				})
			} else {
				uassert.NotPanics(t, func() {
					assertIsValidAmount(tt.amount)
				})
			}
		})
	}
}

func TestMakeProjectIDEdgeCases(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		createdHeight int64
		expected      string
	}{
		{
			name:          "simple token path",
			tokenPath:     "gno.land/r/demo/token",
			createdHeight: 1000,
			expected:      "gno.land/r/demo/token:1000",
		},
		{
			name:          "zero height",
			tokenPath:     "gno.land/r/demo/token",
			createdHeight: 0,
			expected:      "gno.land/r/demo/token:0",
		},
		{
			name:          "large height",
			tokenPath:     "gno.land/r/demo/token",
			createdHeight: 9223372036854775807,
			expected:      "gno.land/r/demo/token:9223372036854775807",
		},
		{
			name:          "token path with colon",
			tokenPath:     "gno.land/r/demo/foo:bar",
			createdHeight: 500,
			expected:      "gno.land/r/demo/foo:bar:500",
		},
		{
			name:          "empty token path",
			tokenPath:     "",
			createdHeight: 100,
			expected:      ":100",
		},
		{
			name:          "negative height",
			tokenPath:     "gno.land/r/demo/token",
			createdHeight: -1,
			expected:      "gno.land/r/demo/token:-1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := makeProjectID(tt.tokenPath, tt.createdHeight)
			uassert.Equal(t, tt.expected, result)
		})
	}
}

func TestMakeProjectTierIDEdgeCases(t *testing.T) {
	tests := []struct {
		name      string
		projectID string
		duration  int64
		expected  string
	}{
		{
			name:      "30 day tier",
			projectID: "gno.land/r/demo/token:1000",
			duration:  30,
			expected:  "gno.land/r/demo/token:1000:30",
		},
		{
			name:      "90 day tier",
			projectID: "gno.land/r/demo/token:2000",
			duration:  90,
			expected:  "gno.land/r/demo/token:2000:90",
		},
		{
			name:      "180 day tier",
			projectID: "gno.land/r/demo/token:3000",
			duration:  180,
			expected:  "gno.land/r/demo/token:3000:180",
		},
		{
			name:      "zero duration",
			projectID: "gno.land/r/demo/token:1000",
			duration:  0,
			expected:  "gno.land/r/demo/token:1000:0",
		},
		{
			name:      "negative duration",
			projectID: "gno.land/r/demo/token:1000",
			duration:  -30,
			expected:  "gno.land/r/demo/token:1000:-30",
		},
		{
			name:      "empty project ID",
			projectID: "",
			duration:  30,
			expected:  ":30",
		},
		{
			name:      "project ID with multiple colons",
			projectID: "gno.land/r/demo/foo:bar:5000",
			duration:  90,
			expected:  "gno.land/r/demo/foo:bar:5000:90",
		},
		{
			name:      "large duration",
			projectID: "gno.land/r/demo/token:1000",
			duration:  365,
			expected:  "gno.land/r/demo/token:1000:365",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := makeProjectTierID(tt.projectID, tt.duration)
			uassert.Equal(t, tt.expected, result)
		})
	}
}
