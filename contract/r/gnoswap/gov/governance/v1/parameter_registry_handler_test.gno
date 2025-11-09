package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"
)

// TestRegistryHandler_NewRegistryHandler tests the creation of registry handler
func TestRegistryHandler_NewRegistryHandler(t *testing.T) {
	tests := []struct {
		name          string
		handlerFn     func(params []string) error
		testParams    []string
		expectedError bool
	}{
		{
			name: "create handler with successful function",
			handlerFn: func(params []string) error {
				return nil
			},
			testParams:    []string{"param1", "param2"},
			expectedError: false,
		},
		{
			name: "create handler with failing function",
			handlerFn: func(params []string) error {
				return ufmt.Errorf("handler error")
			},
			testParams:    []string{"param1"},
			expectedError: true,
		},
		{
			name: "create handler with nil params",
			handlerFn: func(params []string) error {
				if len(params) == 0 {
					return ufmt.Errorf("no params")
				}
				return nil
			},
			testParams:    []string{},
			expectedError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// when
			handler := NewRegistryHandler(tt.handlerFn)

			// then
			uassert.NotNil(t, handler)

			// Verify it implements ParameterRegistryHandler
			registryHandler, ok := handler.(ParameterRegistryHandler)
			uassert.True(t, ok)

			// Verify it implements ParameterHandler (embedded interface)
			paramHandler, ok := handler.(ParameterHandler)
			uassert.True(t, ok)

			// Test Execute method via ParameterHandler interface
			err := paramHandler.Execute(tt.testParams)
			if tt.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
			}

			// Test GetState (should return nil for simple handler)
			state := registryHandler.GetState()
			uassert.Nil(t, state)

			// Test RestoreState (should not error for simple handler)
			err = registryHandler.RestoreState(nil)
			uassert.Nil(t, err)
		})
	}
}

// TestRegistryHandler_Execute tests the execution functionality of registry handler
func TestRegistryHandler_Execute(t *testing.T) {
	tests := []struct {
		name           string
		params         []string
		handlerFn      ParameterHandler
		expectedError  bool
		expectedErrMsg string
	}{
		{
			name:   "Success - Execute with valid params",
			params: []string{"param1", "param2"},
			handlerFn: NewParameterHandlerOptions(
				"test/pkg",
				"testFunc",
				2,
				func([]string) error {
					return nil
				},
			),
			expectedError: false,
		},
		{
			name:   "Failure - Different param count",
			params: []string{"param1"},
			handlerFn: NewParameterHandlerOptions(
				"test/pkg",
				"testFunc",
				2,
				func([]string) error {
					return ufmt.Errorf("test error")
				},
			),
			expectedError:  true,
			expectedErrMsg: "expected 2 parameters, got 1",
		},
		{
			name:   "Failure - Execute with error",
			params: []string{"param1"},
			handlerFn: NewParameterHandlerOptions(
				"test/pkg",
				"testFunc",
				1,
				func([]string) error {
					return ufmt.Errorf("test error")
				},
			),
			expectedError:  true,
			expectedErrMsg: "test error",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			handler := tc.handlerFn

			// when
			err := handler.Execute(tc.params)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.Equal(t, err.Error(), tc.expectedErrMsg)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}
