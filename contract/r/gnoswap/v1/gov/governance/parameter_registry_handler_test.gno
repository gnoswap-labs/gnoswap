package governance

import (
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/ufmt"
)

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
			handlerFn: &ParameterHandlerOptions{
				pkgPath:    "test/pkg",
				function:   "testFunc",
				paramCount: 2,
				handlerFunc: func([]string) error {
					return nil
				},
			},
			expectedError: false,
		},
		{
			name:   "Failure - Different param count",
			params: []string{"param1"},
			handlerFn: &ParameterHandlerOptions{
				pkgPath:    "test/pkg",
				function:   "testFunc",
				paramCount: 2,
				handlerFunc: func([]string) error {
					return ufmt.Errorf("test error")
				},
			},
			expectedError:  true,
			expectedErrMsg: "expected 2 parameters, got 1",
		},
		{
			name:   "Failure - Execute with error",
			params: []string{"param1"},
			handlerFn: &ParameterHandlerOptions{
				pkgPath:    "test/pkg",
				function:   "testFunc",
				paramCount: 1,
				handlerFunc: func([]string) error {
					return ufmt.Errorf("test error")
				},
			},
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