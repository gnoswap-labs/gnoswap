package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
)

// TestStore_int64ToString tests the private int64ToString function
func TestStore_int64ToString(t *testing.T) {
	tests := []struct {
		name           string
		input          int64
		expectedOutput string
	}{
		{
			name:           "zero",
			input:          0,
			expectedOutput: "0",
		},
		{
			name:           "positive small number",
			input:          123,
			expectedOutput: "123",
		},
		{
			name:           "negative small number",
			input:          -456,
			expectedOutput: "-456",
		},
		{
			name:           "max int64",
			input:          9223372036854775807,
			expectedOutput: "9223372036854775807",
		},
		{
			name:           "min int64",
			input:          -9223372036854775808,
			expectedOutput: "-9223372036854775808",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := int64ToString(tc.input)

			// then
			uassert.Equal(t, result, tc.expectedOutput)
		})
	}
}
