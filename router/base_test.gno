package router

import (
	"errors"
	"testing"
)

var errDummy = errors.New("dummy error")

type mockOperation struct {
	ValidateErr error
	ProcessErr  error
	Result      *SwapResult
}

func (m *mockOperation) Validate() error {
	return m.ValidateErr
}

func (m *mockOperation) Process() (*SwapResult, error) {
	return m.Result, m.ProcessErr
}

func TestExecuteSwapOperation(t *testing.T) {
	tests := []struct {
		name        string
		operation   RouterOperation
		expectError bool
	}{
		{
			name: "success case",
			operation: &mockOperation{
				ValidateErr: nil,
				ProcessErr:  nil,
				Result:      &SwapResult{},
			},
			expectError: false,
		},
		{
			name: "validate error",
			operation: &mockOperation{
				ValidateErr: errDummy,
				ProcessErr:  nil,
				Result:      &SwapResult{},
			},
			expectError: true,
		},
		{
			name: "process error",
			operation: &mockOperation{
				ValidateErr: nil,
				ProcessErr:  errDummy,
				Result:      nil,
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := executeSwapOperation(tt.operation)
			if tt.expectError && err == nil {
				t.Errorf("expected an error but got nil (test case: %s)", tt.name)
			}
			if !tt.expectError && err != nil {
				t.Errorf("unexpected error: %v (test case: %s)", err, tt.name)
			}
			if !tt.expectError && result == nil {
				t.Errorf("expected non-nil result but got nil (test case: %s)", tt.name)
			}
		})
	}
}
