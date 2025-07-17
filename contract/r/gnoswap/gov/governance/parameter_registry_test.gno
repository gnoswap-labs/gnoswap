package governance

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

// TestParameterRegistry_RegisterAndHandler tests registration and handler retrieval
func TestParameterRegistry_RegisterAndHandler(t *testing.T) {
	tests := []struct {
		name              string
		pkgPath           string
		function          string
		paramCount        int
		handlerFunc       func([]string) error
		expectedError     bool
		expectedErrorMsg  string
	}{
		{
			name:     "Success - Register and retrieve handler",
			pkgPath:  "test/pkg",
			function: "testFunc",
			paramCount: 1,
			handlerFunc: func([]string) error {
				return nil
			},
			expectedError: false,
		},
		{
			name:     "Failure - Handler not found",
			pkgPath:  "nonexistent/pkg",
			function: "nonexistentFunc",
			paramCount: 0,
			handlerFunc: nil,
			expectedError: true,
			expectedErrorMsg: "handler not found for nonexistent/pkg:nonexistentFunc",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			registry := NewParameterRegistry()

			if tc.handlerFunc != nil {
				handler := ParameterHandlerOptions{
					pkgPath:    tc.pkgPath,
					function:   tc.function,
					paramCount: tc.paramCount,
					handlerFunc: tc.handlerFunc,
				}
				registry.register(handler)
			}

			// when
			handler, err := registry.handler(tc.pkgPath, tc.function)

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
		name              string
		paramCount        int
		params            []string
		handlerFunc       func([]string) error
		expectedError     bool
		expectedErrorMsg  string
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
			expectedError: true,
			expectedErrorMsg: "expected 2 parameters, got 1",
		},
		{
			name:       "Failure - Handler error",
			paramCount: 1,
			params:     []string{"param1"},
			handlerFunc: func([]string) error {
				return ufmt.Errorf("handler error")
			},
			expectedError: true,
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
	registry := createParameterHandlers()

	// then
	uassert.NotNil(t, registry)
	uassert.NotNil(t, registry.handlers)

	// Test some known handlers
	testCases := []struct {
		pkgPath  string
		function string
	}{
		{"gno.land/r/gnoswap/v1/halt", "SetHalt"},
		{"gno.land/r/gnoswap/v1/community_pool", "TransferToken"},
		{"gno.land/r/gnoswap/v1/emission", "ChangeDistributionPct"},
		{"gno.land/r/gnoswap/v1/gns", "SetAvgBlockTimeInMs"},
	}

	for _, tc := range testCases {
		handler, err := registry.handler(tc.pkgPath, tc.function)
		uassert.Nil(t, err)
		uassert.NotNil(t, handler)
	}
} 