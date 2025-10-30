package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

// TestParameterRegistry_RegisterAndHandler tests registration and handler retrieval
func TestParameterRegistry_RegisterAndHandler(t *testing.T) {
	tests := []struct {
		name             string
		pkgPath          string
		function         string
		paramCount       int
		handlerFunc      func([]string) error
		expectedError    bool
		expectedErrorMsg string
	}{
		{
			name:       "Success - Register and retrieve handler",
			pkgPath:    "test/pkg",
			function:   "testFunc",
			paramCount: 1,
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError: false,
		},
		{
			name:             "Failure - Handler not found",
			pkgPath:          "nonexistent/pkg",
			function:         "nonexistentFunc",
			paramCount:       0,
			handlerFunc:      nil,
			expectedError:    true,
			expectedErrorMsg: "handler not found for nonexistent/pkg:nonexistentFunc",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			registry := NewParameterRegistry()

			if tc.handlerFunc != nil {
				handler := ParameterHandlerOptions{
					pkgPath:     tc.pkgPath,
					function:    tc.function,
					paramCount:  tc.paramCount,
					handlerFunc: tc.handlerFunc,
				}
				registry.Register(handler)
			}

			// when
			key := makeHandlerKey(tc.pkgPath, tc.function)
			handler, err := registry.Handler(key)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMsg)
			} else {
				uassert.Nil(t, err)
				uassert.NotNil(t, handler)
			}
		})
	}
}

// TestParameterHandlerOptions_Execute tests parameter handler execution
func TestParameterHandlerOptions_Execute(t *testing.T) {
	tests := []struct {
		name             string
		paramCount       int
		params           []string
		handlerFunc      func([]string) error
		expectedError    bool
		expectedErrorMsg string
	}{
		{
			name:       "Success - Execute with correct param count",
			paramCount: 2,
			params:     []string{"param1", "param2"},
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError: false,
		},
		{
			name:       "Failure - Wrong param count",
			paramCount: 2,
			params:     []string{"param1"},
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError:    true,
			expectedErrorMsg: "expected 2 parameters, got 1",
		},
		{
			name:       "Failure - Handler error",
			paramCount: 1,
			params:     []string{"param1"},
			handlerFunc: func([]string) error {
				return ufmt.Errorf("handler error")
			},
			expectedError:    true,
			expectedErrorMsg: "handler error",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			handler := NewParameterHandlerOptions(
				"test/pkg",
				"testFunc",
				tc.paramCount,
				tc.handlerFunc,
			)

			// when
			err := handler.Execute(tc.params)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrorMsg)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

// TestCreateParameterHandlers tests the creation of all parameter handlers
func TestCreateParameterHandlers(t *testing.T) {
	// given & when
	registry := CreateParameterHandlers()

	// then
	uassert.NotNil(t, registry)
	uassert.NotNil(t, registry.handlers)

	// Test some known handlers
	testCases := []struct {
		pkgPath  string
		function string
	}{
		{"gno.land/r/gnoswap/halt", "SetHaltLevel"},
		{"gno.land/r/gnoswap/community_pool", "TransferToken"},
		{"gno.land/r/gnoswap/emission", "ChangeDistributionPct"},
	}

	for _, tc := range testCases {
		key := makeHandlerKey(tc.pkgPath, tc.function)
		handler, err := registry.Handler(key)
		uassert.Nil(t, err)
		uassert.NotNil(t, handler)
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
		name                 string
		input                string
		expected             bool
		expectedPanic        bool
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
			name:                 "Invalid boolean",
			input:                "invalid",
			expectedPanic:        true,
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
