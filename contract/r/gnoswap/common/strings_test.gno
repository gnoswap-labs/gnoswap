package common

import (
	"strings"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

func TestStrings_Split(t *testing.T) {
	tests := []struct {
		name                 string
		inputString          string
		inputSeparator       string
		inputLength          int
		expectedResult       []string
		expectedHasError     bool
		expectedErrorMessage string
	}{
		{
			name:             "Valid split with comma separator",
			inputString:      "a,b,c",
			inputSeparator:   ",",
			inputLength:      3,
			expectedResult:   []string{"a", "b", "c"},
			expectedHasError: false,
		},
		{
			name:             "Valid split with pipe separator",
			inputString:      "token1|token2",
			inputSeparator:   "|",
			inputLength:      2,
			expectedResult:   []string{"token1", "token2"},
			expectedHasError: false,
		},
		{
			name:             "Single element",
			inputString:      "single",
			inputSeparator:   ",",
			inputLength:      1,
			expectedResult:   []string{"single"},
			expectedHasError: false,
		},
		{
			name:                 "Invalid length - too many parts",
			inputString:          "a,b,c,d",
			inputSeparator:       ",",
			inputLength:          3,
			expectedResult:       nil,
			expectedHasError:     true,
			expectedErrorMessage: "invalid length: 4",
		},
		{
			name:                 "Invalid length - too few parts",
			inputString:          "a,b",
			inputSeparator:       ",",
			inputLength:          3,
			expectedResult:       nil,
			expectedHasError:     true,
			expectedErrorMessage: "invalid length: 2",
		},
		{
			name:             "Empty string with length 1",
			inputString:      "",
			inputSeparator:   ",",
			inputLength:      1,
			expectedResult:   []string{""},
			expectedHasError: false,
		},
		{
			name:             "String with empty parts",
			inputString:      "a,,c",
			inputSeparator:   ",",
			inputLength:      3,
			expectedResult:   []string{"a", "", "c"},
			expectedHasError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputStr := tc.inputString
			separator := tc.inputSeparator
			length := tc.inputLength

			// when
			result, err := Split(inputStr, separator, length)

			// then
			if tc.expectedHasError {
				uassert.Error(t, err)
				uassert.True(t, result == nil) // Check for nil specifically
				if tc.expectedErrorMessage != "" {
					uassert.Equal(t, tc.expectedErrorMessage, err.Error())
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, len(tc.expectedResult), len(result))
				for i, expected := range tc.expectedResult {
					uassert.Equal(t, expected, result[i])
				}
			}
		})
	}
}

func TestStrings_EncodeUint(t *testing.T) {
	tests := []struct {
		name           string
		inputNumber    uint64
		expectedResult string
	}{
		{
			name:           "Small number",
			inputNumber:    12345,
			expectedResult: "00000000000000012345",
		},
		{
			name:           "Zero",
			inputNumber:    0,
			expectedResult: "00000000000000000000",
		},
		{
			name:           "Large number",
			inputNumber:    18446744073709551615, // max uint64
			expectedResult: "18446744073709551615",
		},
		{
			name:           "Medium number",
			inputNumber:    1000000000000,
			expectedResult: "00000001000000000000",
		},
		{
			name:           "Single digit",
			inputNumber:    7,
			expectedResult: "00000000000000000007",
		},
		{
			name:           "Exact 20 digits",
			inputNumber:    12345678901234567890,
			expectedResult: "12345678901234567890",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputNumber := tc.inputNumber

			// when
			result := EncodeUint(inputNumber)

			// then
			uassert.Equal(t, tc.expectedResult, result)
			uassert.Equal(t, 20, len(result)) // Always 20 characters
		})
	}
}

func TestStrings_DecodeUint(t *testing.T) {
	tests := []struct {
		name                 string
		inputString          string
		expectedResult       uint64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:             "Valid zero-padded string",
			inputString:      "00000000000000012345",
			expectedResult:   12345,
			expectedHasPanic: false,
		},
		{
			name:             "Zero string",
			inputString:      "00000000000000000000",
			expectedResult:   0,
			expectedHasPanic: false,
		},
		{
			name:             "Max uint64 string",
			inputString:      "18446744073709551615",
			expectedResult:   18446744073709551615,
			expectedHasPanic: false,
		},
		{
			name:             "Medium number string",
			inputString:      "00000001000000000000",
			expectedResult:   1000000000000,
			expectedHasPanic: false,
		},
		{
			name:             "Single digit string",
			inputString:      "00000000000000000007",
			expectedResult:   7,
			expectedHasPanic: false,
		},
		{
			name:                 "Invalid string with letters",
			inputString:          "0000000000000001234a",
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedPanicMessage: "strconv.ParseUint: parsing \"0000000000000001234a\": invalid syntax",
		},
		{
			name:                 "Empty string",
			inputString:          "",
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedPanicMessage: "strconv.ParseUint: parsing \"\": invalid syntax",
		},
		{
			name:                 "String with special characters",
			inputString:          "000000000000000123-5",
			expectedResult:       0,
			expectedHasPanic:     true,
			expectedPanicMessage: "strconv.ParseUint: parsing \"000000000000000123-5\": invalid syntax",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			inputString := tc.inputString

			// when & then
			if tc.expectedHasPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					DecodeUint(inputString)
				})
			} else {
				result := DecodeUint(inputString)
				uassert.Equal(t, tc.expectedResult, result)
			}
		})
	}
}

func TestStrings_EncodeDecodeRoundTrip(t *testing.T) {
	tests := []struct {
		name        string
		inputNumber uint64
	}{
		{
			name:        "Round trip with small number",
			inputNumber: 12345,
		},
		{
			name:        "Round trip with zero",
			inputNumber: 0,
		},
		{
			name:        "Round trip with large number",
			inputNumber: 9999999999999999999,
		},
		{
			name:        "Round trip with medium number",
			inputNumber: 1000000000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			originalNumber := tc.inputNumber

			// when
			encoded := EncodeUint(originalNumber)
			decoded := DecodeUint(encoded)

			// then
			uassert.Equal(t, originalNumber, decoded)
			uassert.Equal(t, 20, len(encoded))
		})
	}
}

// TestStrings_EdgeCasesAndBoundaries tests edge cases and boundary conditions
func TestStrings_EdgeCasesAndBoundaries(t *testing.T) {
	t.Run("Split with complex separators", func(t *testing.T) {
		tests := []struct {
			name           string
			input          string
			separator      string
			length         int
			expected       []string
			shouldError    bool
		}{
			{
				name:        "Multi-character separator",
				input:       "a::b::c",
				separator:   "::",
				length:      3,
				expected:    []string{"a", "b", "c"},
				shouldError: false,
			},
			{
				name:        "Separator longer than input",
				input:       "ab",
				separator:   "abcd",
				length:      1,
				expected:    []string{"ab"},
				shouldError: false,
			},
			{
				name:        "Input equals separator",
				input:       "abc",
				separator:   "abc",
				length:      2,
				expected:    []string{"", ""},
				shouldError: false,
			},
		}
		
		for _, tc := range tests {
			t.Run(tc.name, func(t *testing.T) {
				result, err := Split(tc.input, tc.separator, tc.length)
				if tc.shouldError {
					uassert.Error(t, err)
				} else {
					uassert.NoError(t, err)
					uassert.Equal(t, len(tc.expected), len(result))
					for i, expected := range tc.expected {
						uassert.Equal(t, expected, result[i])
					}
				}
			})
		}
	})
	
	t.Run("EncodeUint boundary values", func(t *testing.T) {
		tests := []struct {
			name     string
			input    uint64
			expected string
		}{
			{
				name:     "Maximum uint64",
				input:    18446744073709551615,
				expected: "18446744073709551615",
			},
			{
				name:     "Minimum uint64",
				input:    0,
				expected: "00000000000000000000",
			},
			{
				name:     "Powers of 10",
				input:    10000000000000000000,
				expected: "10000000000000000000",
			},
		}
		
		for _, tc := range tests {
			t.Run(tc.name, func(t *testing.T) {
				result := EncodeUint(tc.input)
				uassert.Equal(t, tc.expected, result)
			})
		}
	})
}

// TestStrings_Performance tests performance characteristics
func TestStrings_Performance(t *testing.T) {
	t.Run("Multiple encode/decode cycles", func(t *testing.T) {
		testValues := []uint64{0, 1, 999, 1000, 999999, 1000000, 18446744073709551615}
		
		for _, val := range testValues {
			for i := 0; i < 100; i++ {
				encoded := EncodeUint(val)
				decoded := DecodeUint(encoded)
				uassert.Equal(t, val, decoded)
			}
		}
	})
	
	t.Run("Large string splits", func(t *testing.T) {
		// Create a large string with many parts
		parts := make([]string, 100)
		for i := 0; i < 100; i++ {
			parts[i] = ufmt.Sprintf("part%d", i)
		}
		largeInput := strings.Join(parts, ",")
		
		result, err := Split(largeInput, ",", 100)
		uassert.NoError(t, err)
		uassert.Equal(t, 100, len(result))
		
		for i, part := range result {
			expected := ufmt.Sprintf("part%d", i)
			uassert.Equal(t, expected, part)
		}
	})
}

// TestStrings_ErrorMessageValidation tests error message formats
func TestStrings_ErrorMessageValidation(t *testing.T) {
	t.Run("Split error message format", func(t *testing.T) {
		_, err := Split("a,b,c", ",", 2)
		uassert.Error(t, err)
		
		errorMsg := err.Error()
		uassert.True(t, len(errorMsg) > 0)
		// Should contain information about the length
		uassert.True(t, strings.Contains(errorMsg, "invalid length"))
	})
	
	t.Run("DecodeUint panic message format", func(t *testing.T) {
		uassert.PanicsWithMessage(t, 
			"strconv.ParseUint: parsing \"invalid\": invalid syntax",
			func() {
				DecodeUint("invalid")
			})
	})
}
