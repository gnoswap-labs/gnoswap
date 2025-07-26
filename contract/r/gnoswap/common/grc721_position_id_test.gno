package common

import (
	"testing"

	"gno.land/p/demo/grc/grc721"
	"gno.land/p/demo/uassert"
)

func TestGrc721PositionId_PositionIdFrom(t *testing.T) {
	tests := []struct {
		name                 string
		inputPositionId      any
		expectedResult       grc721.TokenID
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid string input",
			inputPositionId:  "123",
			expectedResult:   grc721.TokenID("123"),
			expectedHasPanic: false,
		},
		{
			name:             "Valid int input",
			inputPositionId:  123,
			expectedResult:   grc721.TokenID("123"),
			expectedHasPanic: false,
		},
		{
			name:             "Valid uint64 input",
			inputPositionId:  uint64(123),
			expectedResult:   grc721.TokenID("123"),
			expectedHasPanic: false,
		},
		{
			name:             "Valid grc721.TokenID input",
			inputPositionId:  grc721.TokenID("123"),
			expectedResult:   grc721.TokenID("123"),
			expectedHasPanic: false,
		},
		{
			name:                 "Nil input should panic",
			inputPositionId:      nil,
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || can not be nil",
		},
		{
			name:                 "Unsupported type should panic",
			inputPositionId:      []byte("123"),
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || unsupported positionId type: []byte",
		},
		{
			name:             "Zero int input",
			inputPositionId:  0,
			expectedResult:   grc721.TokenID("0"),
			expectedHasPanic: false,
		},
		{
			name:             "Large uint64 input with overflow",
			inputPositionId:  uint64(18446744073709551615),
			expectedResult:   grc721.TokenID("-1"),
			expectedHasPanic: false,
		},
		{
			name:             "Empty string input",
			inputPositionId:  "",
			expectedResult:   grc721.TokenID(""),
			expectedHasPanic: false,
		},
		{
			name:             "Negative int input",
			inputPositionId:  -123,
			expectedResult:   grc721.TokenID("-123"),
			expectedHasPanic: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputPositionId := tc.inputPositionId

			// when & then
			if tc.expectedHasPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					PositionIdFrom(inputPositionId)
				})
			} else {
				result := PositionIdFrom(inputPositionId)
				uassert.Equal(t, string(tc.expectedResult), string(result))
			}
		})
	}
}

// TestGrc721PositionId_AdditionalEdgeCases tests additional edge cases for PositionIdFrom
func TestGrc721PositionId_AdditionalEdgeCases(t *testing.T) {
	tests := []struct {
		name                 string
		inputPositionId      any
		expectedResult       grc721.TokenID
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Very large uint64",
			inputPositionId:  uint64(9223372036854775807), // max int64
			expectedResult:   grc721.TokenID("9223372036854775807"),
			expectedHasPanic: false,
		},
		{
			name:             "Very large negative int",
			inputPositionId:  -9223372036854775808, // min int64
			expectedResult:   grc721.TokenID("-9223372036854775808"),
			expectedHasPanic: false,
		},
		{
			name:             "String with special characters",
			inputPositionId:  "position_123-abc",
			expectedResult:   grc721.TokenID("position_123-abc"),
			expectedHasPanic: false,
		},
		{
			name:             "String with unicode",
			inputPositionId:  "位置123",
			expectedResult:   grc721.TokenID("位置123"),
			expectedHasPanic: false,
		},
		{
			name:                 "Float type should panic",
			inputPositionId:      123.45,
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || unsupported positionId type: unknown",
		},
		{
			name:                 "Boolean type should panic",
			inputPositionId:      true,
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || unsupported positionId type: bool",
		},
		{
			name:                 "Slice type should panic",
			inputPositionId:      []string{"123"},
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || unsupported positionId type: unknown",
		},
		{
			name:                 "Map type should panic",
			inputPositionId:      map[string]int{"id": 123},
			expectedResult:       grc721.TokenID(""),
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-COMMON-007] invalid positionId || unsupported positionId type: unknown",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputPositionId := tc.inputPositionId

			// when & then
			if tc.expectedHasPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					PositionIdFrom(inputPositionId)
				})
			} else {
				result := PositionIdFrom(inputPositionId)
				uassert.Equal(t, string(tc.expectedResult), string(result))
			}
		})
	}
}

// TestGrc721PositionId_TypeConsistency tests that the function maintains type consistency
func TestGrc721PositionId_TypeConsistency(t *testing.T) {
	t.Run("Round trip conversion consistency", func(t *testing.T) {
		originalId := grc721.TokenID("12345")
		result := PositionIdFrom(originalId)
		uassert.Equal(t, string(originalId), string(result))
	})
	
	t.Run("String to TokenID conversion", func(t *testing.T) {
		stringId := "67890"
		result := PositionIdFrom(stringId)
		uassert.Equal(t, stringId, string(result))
	})
	
	t.Run("Int to string consistency", func(t *testing.T) {
		intId := 42
		result := PositionIdFrom(intId)
		expectedString := "42"
		uassert.Equal(t, expectedString, string(result))
	})
	
	t.Run("Uint64 to string consistency", func(t *testing.T) {
		uintId := uint64(987654321)
		result := PositionIdFrom(uintId)
		expectedString := "987654321"
		uassert.Equal(t, expectedString, string(result))
	})
}
