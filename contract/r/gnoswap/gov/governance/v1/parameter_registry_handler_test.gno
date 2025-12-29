package v1

import (
	"errors"
	"testing"

	"gno.land/p/nt/uassert"
)

// TestRegistryHandler_Execute tests the execution functionality of registry handler
func TestRegistryHandler_Execute(t *testing.T) {
	tests := []struct {
		name             string
		params           []string
		handlerFactory   func() ParameterHandler
		expectedError    bool
		expectedErrMsg   string
		expectedPanic    bool
		expectedPanicMsg string
	}{
		{
			name:   "Success - Execute with valid params",
			params: []string{"param1", "param2"},
			handlerFactory: func() ParameterHandler {
				return NewParameterHandlerOptions(
					"test/pkg",
					"testFunc",
					2,
					func([]string) error {
						return nil
					},
				)
			},
			expectedError: false,
		},
		{
			name:   "Failure - Different param count",
			params: []string{"param1"},
			handlerFactory: func() ParameterHandler {
				return NewParameterHandlerOptions(
					"test/pkg",
					"testFunc",
					2,
					func([]string) error {
						return errors.New("test error")
					},
				)
			},
			expectedError:  true,
			expectedErrMsg: "expected 2 parameters, got 1",
		},
		{
			name:   "Failure - Execute with error",
			params: []string{"param1"},
			handlerFactory: func() ParameterHandler {
				return NewParameterHandlerOptions(
					"test/pkg",
					"testFunc",
					1,
					func([]string) error {
						return errors.New("test error")
					},
				)
			},
			expectedError:  true,
			expectedErrMsg: "test error",
		},
		{
			name: "Failure - Validator count mismatch",
			handlerFactory: func() ParameterHandler {
				return NewParameterHandlerOptions(
					"gno.land/r/gnoswap/test",
					"DoThing",
					2,
					func([]string) error { return nil },
					func(string) error { return nil },
				)
			},
			expectedPanic:    true,
			expectedPanicMsg: "invalid validator count for gno.land/r/gnoswap/test:DoThing: expected 2, got 1",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedPanic {
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					_ = tc.handlerFactory()
				})
				return
			}

			// given
			handler := tc.handlerFactory()

			// when
			err := handler.Execute(tc.params)

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
				uassert.ErrorContains(t, err, tc.expectedErrMsg)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}
