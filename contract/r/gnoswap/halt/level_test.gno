package halt

import (
	"testing"

	"gno.land/p/demo/uassert"
)

func TestLevel_CompositeOpFromString(t *testing.T) {
	tests := []struct {
		name                 string
		input                string
		expectedResult       CompositeOp
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Success parse 'and' operator correctly",
			input:            "and",
			expectedResult:   CompositeOpAnd,
			expectedHasPanic: false,
		},
		{
			name:             "Success parse 'or' operator correctly",
			input:            "or",
			expectedResult:   CompositeOpOr,
			expectedHasPanic: false,
		},
		{
			name:                 "Error for invalid operator",
			input:                "invalid",
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedPanicMessage: "unknown composite operation: invalid",
		},
		{
			name:                 "Error for empty string",
			input:                "",
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedPanicMessage: "unknown composite operation: ",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if tc.expectedHasPanic {
						uassert.True(t, tc.expectedHasPanic)
					} else {
						t.Errorf("[%s] unexpected panic: %v", tc.name, r)
					}
				}
			}()

			// given
			// when
			got, err := CompositeOpFromString(tc.input)

			// then
			if tc.expectedHasPanic {
				uassert.True(t, err != nil)
			} else {
				uassert.Equal(t, uint8(tc.expectedResult), uint8(got))
				uassert.True(t, err == nil)
			}
		})
	}
}
