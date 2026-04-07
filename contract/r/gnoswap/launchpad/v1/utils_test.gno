package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
)

func TestUtils_parseProjectTierID(t *testing.T) {
	tests := []struct {
		name              string
		projectTierID     string
		expectedProjectID string
		expectedDuration  int64
		expectedPanic     bool
		expectedErrorMsg  string
	}{
		{
			name:              "valid project tier id with tier 30",
			projectTierID:     "gno.land/r/demo/token:100:30",
			expectedProjectID: "gno.land/r/demo/token:100",
			expectedDuration:  30,
			expectedPanic:     false,
		},
		{
			name:              "valid project tier id with tier 90",
			projectTierID:     "gno.land/r/demo/token:100:90",
			expectedProjectID: "gno.land/r/demo/token:100",
			expectedDuration:  90,
			expectedPanic:     false,
		},
		{
			name:              "valid project tier id with tier 180",
			projectTierID:     "gno.land/r/demo/token:100:180",
			expectedProjectID: "gno.land/r/demo/token:100",
			expectedDuration:  180,
			expectedPanic:     false,
		},
		{
			name:             "panic when tier id has only 2 parts",
			projectTierID:    "gno.land/r/demo/token:100",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-009",
		},
		{
			name:             "panic when tier id has only 1 part",
			projectTierID:    "gno.land/r/demo/token",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-009",
		},
		{
			name:             "panic when tier id has 4 parts",
			projectTierID:    "gno.land/r/demo/token:100:30:extra",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-009",
		},
		{
			name:             "panic when tier duration is not integer",
			projectTierID:    "gno.land/r/demo/token:100:invalid",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-009",
		},
		{
			name:             "panic when tier duration is invalid (not 30/90/180)",
			projectTierID:    "gno.land/r/demo/token:100:60",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-007",
		},
		{
			name:             "panic when tier duration is negative",
			projectTierID:    "gno.land/r/demo/token:100:-30",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-007",
		},
		{
			name:             "panic when tier duration is zero",
			projectTierID:    "gno.land/r/demo/token:100:0",
			expectedPanic:    true,
			expectedErrorMsg: "GNOSWAP-LAUNCHPAD-007",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectedPanic {
				defer func() {
					r := recover()
					uassert.NotNil(t, r)
					uassert.ErrorContains(t, r.(error), tt.expectedErrorMsg)
				}()
			}

			projectID, duration := parseProjectTierID(tt.projectTierID)

			if !tt.expectedPanic {
				uassert.Equal(t, projectID, tt.expectedProjectID)
				uassert.Equal(t, duration, tt.expectedDuration)
			}
		})
	}
}

func TestUtils_formatInt(t *testing.T) {
	tests := []struct {
		name     string
		value    int64
		expected string
	}{
		{
			name:     "format zero",
			value:    0,
			expected: "0",
		},
		{
			name:     "format positive number",
			value:    1000,
			expected: "1000",
		},
		{
			name:     "format negative number",
			value:    -1000,
			expected: "-1000",
		},
		{
			name:     "format MaxInt64",
			value:    9223372036854775807,
			expected: "9223372036854775807",
		},
		{
			name:     "format MinInt64",
			value:    -9223372036854775808,
			expected: "-9223372036854775808",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := formatInt(tt.value)
			uassert.Equal(t, result, tt.expected)
		})
	}
}
