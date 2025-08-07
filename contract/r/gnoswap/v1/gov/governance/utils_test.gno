package governance

import (
	"testing"

	"gno.land/p/demo/uassert"
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

// TestParseNumber tests number parsing
func TestParseNumber(t *testing.T) {
	tests := []struct {
		name                 string
		input                string
		kind                 numberKind
		expected             interface{}
		expectedPanic        bool
		expectedPanicMessage string
	}{
		{
			name:     "Parse int",
			input:    "123",
			kind:     kindInt,
			expected: int(123),
		},
		{
			name:     "Parse int64",
			input:    "123456789",
			kind:     kindInt64,
			expected: int64(123456789),
		},
		{
			name:     "Parse uint64",
			input:    "123456789",
			kind:     kindUint64,
			expected: uint64(123456789),
		},
		{
			name:                 "Invalid number",
			input:                "invalid",
			kind:                 kindInt,
			expectedPanic:        true,
			expectedPanicMessage: "invalid int value: invalid",
		},
		{
			name:                 "Invalid kind",
			input:                "123",
			kind:                 numberKind(999),
			expectedPanic:        true,
			expectedPanicMessage: "unsupported number kind: %!v((unhandled))",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					parseNumber(tc.input, tc.kind)
				})
			} else {
				result := parseNumber(tc.input, tc.kind)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestParseBool tests boolean parsing
func TestParseBool(t *testing.T) {
	tests := []struct {
		name          string
		input         string
		expected      bool
		expectedPanic bool
		expectedPanicMessage string
	}{
		{
			name:     "Parse true",
			input:    "true",
			expected: true,
		},
		{
			name:     "Parse false",
			input:    "false",
			expected: false,
		},
		{
			name:          "Invalid boolean",
			input:         "invalid",
			expectedPanic: true,
			expectedPanicMessage: "invalid bool value: invalid",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMessage, func() {
					parseBool(tc.input)
				})
			} else {
				result := parseBool(tc.input)
				uassert.Equal(t, result, tc.expected)
			}
		})
	}
}

// TestMakeExecuteMessage tests message creation
func TestMakeExecuteMessage(t *testing.T) {
	tests := []struct {
		name     string
		pkgPath  string
		function string
		params   []string
		expected string
	}{
		{
			name:     "Create message with no params",
			pkgPath:  "test/pkg",
			function: "testFunc",
			params:   []string{},
			expected: "test/pkg*EXE*testFunc*EXE*",
		},
		{
			name:     "Create message with params",
			pkgPath:  "test/pkg",
			function: "testFunc",
			params:   []string{"param1", "param2"},
			expected: "test/pkg*EXE*testFunc*EXE*param1,param2",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := makeExecuteMessage(tc.pkgPath, tc.function, tc.params)

			// then
			uassert.Equal(t, result, tc.expected)
		})
	}
}

// TestParseMessage tests message parsing
func TestParseMessage(t *testing.T) {
	tests := []struct {
		name           string
		message        string
		expectedPkg    string
		expectedFunc   string
		expectedParams []string
		expectedError  bool
	}{
		{
			name:           "Parse valid message",
			message:        "test/pkg*EXE*testFunc*EXE*param1,param2",
			expectedPkg:    "test/pkg",
			expectedFunc:   "testFunc",
			expectedParams: []string{"param1", "param2"},
			expectedError:  false,
		},
		{
			name:          "Parse invalid message",
			message:       "invalid*message",
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			pkg, function, params, err := parseMessage(tc.message)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
				uassert.Equal(t, pkg, tc.expectedPkg)
				uassert.Equal(t, function, tc.expectedFunc)
				uassert.Equal(t, len(params), len(tc.expectedParams))
				for i, param := range params {
					uassert.Equal(t, param, tc.expectedParams[i])
				}
			}
		})
	}
}