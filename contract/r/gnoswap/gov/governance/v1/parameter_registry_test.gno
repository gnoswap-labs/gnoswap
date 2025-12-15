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

func TestValidateExecutions(t *testing.T) {
	tests := []struct {
		name                  string
		numToExecute          int64
		executions            string
		expectedError         bool
		expectedErrorContains string
	}{
		// Basic validation tests
		{
			name:          "Success - Valid execution with registered handler",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError: false,
		},
		{
			name:          "Success - Multiple valid executions",
			numToExecute:  2,
			executions:    "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*gno.land/r/gnoswap/pool*EXE*SetPoolCreationFee*EXE*1000",
			expectedError: false,
		},
		{
			name:                  "Failure - Non-existent package path",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/nonexistent*EXE*SomeFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/nonexistent:SomeFunction",
		},
		{
			name:                  "Failure - Non-existent function in valid package",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE*NonExistentFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/halt:NonExistentFunction",
		},
		{
			name:                  "Failure - Wrong parameter count",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*param1,param2",
			expectedError:         true,
			expectedErrorContains: "function 'gno.land/r/gnoswap/halt:SetHaltLevel' expects 1 parameter(s), but got 2",
		},
		{
			name:                  "Failure - Empty executions",
			numToExecute:          1,
			executions:            "",
			expectedError:         true,
			expectedErrorContains: "executions is empty",
		},
		{
			name:                  "Failure - Invalid execution count",
			numToExecute:          0,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "numToExecute is less than or equal to 0",
		},
		{
			name:                  "Failure - Execution count mismatch",
			numToExecute:          2,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "executions count (1) does not match numToExecute (2)",
		},
		{
			name:                  "Failure - Malformed execution format",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*SetHaltLevel",
			expectedError:         true,
			expectedErrorContains: "invalid format 'gno.land/r/gnoswap/halt*SetHaltLevel'. Expected format: <package>*EXE*<function>*EXE*<params>",
		},
		{
			name:                  "Failure - Empty package path",
			numToExecute:          1,
			executions:            "*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "package path is empty in '*EXE*SetHaltLevel*EXE*NONE'",
		},
		{
			name:                  "Failure - Empty function name",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/halt*EXE**EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "function name is empty in 'gno.land/r/gnoswap/halt*EXE**EXE*NONE'",
		},
		{
			name:         "Failure - Exceeds max executions",
			numToExecute: 11,
			executions: "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*" +
				"gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE",
			expectedError:         true,
			expectedErrorContains: "numToExecute is greater than 10",
		},
		// Complex scenarios
		{
			name:          "Success - Community pool transfer with correct params",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns,g1address,1000000",
			expectedError: false,
		},
		{
			name:                  "Failure - Community pool transfer with wrong param count",
			numToExecute:          1,
			executions:            "gno.land/r/gnoswap/community_pool*EXE*TransferToken*EXE*gno.land/r/gnoswap/gns,g1address",
			expectedError:         true,
			expectedErrorContains: "function 'gno.land/r/gnoswap/community_pool:TransferToken' expects 3 parameter(s), but got 2",
		},
		{
			name:          "Success - Governance reconfigure with all params",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/gov/governance*EXE*Reconfigure*EXE*86400,604800,3600,500000,1000,86400,259200",
			expectedError: false,
		},
		{
			name:                  "Failure - Mixed valid and invalid executions",
			numToExecute:          2,
			executions:            "gno.land/r/gnoswap/halt*EXE*SetHaltLevel*EXE*NONE*GOV*gno.land/r/gnoswap/fake*EXE*FakeFunction*EXE*param1",
			expectedError:         true,
			expectedErrorContains: "handler not found for gno.land/r/gnoswap/fake:FakeFunction",
		},
		{
			name:          "Success - Staker remove pool tier with single param",
			numToExecute:  1,
			executions:    "gno.land/r/gnoswap/staker*EXE*RemovePoolTier*EXE*poolId",
			expectedError: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			err := validateExecutions(tc.numToExecute, tc.executions)

			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.ErrorContains(t, err, tc.expectedErrorContains)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}
