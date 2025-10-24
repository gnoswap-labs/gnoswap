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
		{
			name:     "Format int64",
			input:    int64(123),
			expected: "123",
		},
		{
			name:     "Format int32",
			input:    int32(456),
			expected: "456",
		},
		{
			name:     "Format int8",
			input:    int8(-12),
			expected: "-12",
		},
		{
			name:          "Invalid type",
			input:         "invalid",
			expectedPanic: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, "invalid type: string", func() {
					formatInt(tc.input)
				})
			} else {
				result := formatInt(tc.input)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}
