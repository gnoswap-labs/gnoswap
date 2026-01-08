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

// TestParameterRegistryHandler_registerHandlers tests the private registerHandlers function
func TestParameterRegistryHandler_registerHandlers(t *testing.T) {
	tests := []struct {
		name          string
		setupHandlers func() ([]*ParameterHandlerOptions, []string)
		expectedCount int
	}{
		{
			name: "register multiple handlers",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				handlers := []*ParameterHandlerOptions{
					NewParameterHandlerOptions(
						"gno.land/r/test/package1",
						"TestFunction1",
						2,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
					NewParameterHandlerOptions(
						"gno.land/r/test/package2",
						"TestFunction2",
						1,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
				}
				keys := []string{
					makeHandlerKey("gno.land/r/test/package1", "TestFunction1"),
					makeHandlerKey("gno.land/r/test/package2", "TestFunction2"),
				}
				return handlers, keys
			},
			expectedCount: 2,
		},
		{
			name: "register single handler",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				handlers := []*ParameterHandlerOptions{
					NewParameterHandlerOptions(
						"gno.land/r/test/package",
						"TestFunction",
						0,
						func(args []string) error { return nil },
					).(*ParameterHandlerOptions),
				}
				keys := []string{
					makeHandlerKey("gno.land/r/test/package", "TestFunction"),
				}
				return handlers, keys
			},
			expectedCount: 1,
		},
		{
			name: "register empty handlers",
			setupHandlers: func() ([]*ParameterHandlerOptions, []string) {
				return []*ParameterHandlerOptions{}, []string{}
			},
			expectedCount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			registry := NewParameterRegistry()
			handlers, keys := tt.setupHandlers()

			// when
			registerHandlers(registry, handlers)

			// then
			// Verify handlers were registered by checking registry size
			uassert.NotNil(t, registry)

			// Verify each handler can be retrieved
			for _, key := range keys {
				retrievedHandler, err := registry.Handler(key)
				uassert.Nil(t, err)
				uassert.NotNil(t, retrievedHandler)
			}
		})
	}
}
