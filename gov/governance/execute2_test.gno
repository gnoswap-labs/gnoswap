package governance

import (
	"testing"
)

func TestParameterRegistry(t *testing.T) {
	tests := []struct {
		name       string
		pkgPath    string
		function   string
		handler    ParameterHandler
		wantErr    bool
		errMessage string
	}{
		{
			name:     "should register and retrieve handler successfully",
			pkgPath:  "test/pkg",
			function: "testFunc",
			handler: func(params []string) error {
				return nil
			},
			wantErr:    false,
			errMessage: "",
		},
		{
			name:       "should return error for non-existent handler",
			pkgPath:    "non/existent",
			function:   "missing",
			handler:    nil,
			wantErr:    true,
			errMessage: "handler not found for non/existent:missing",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			registry := NewParameterRegistry()

			// Register handler if provided
			if tt.handler != nil {
				registry.Register(tt.pkgPath, tt.function, tt.handler)
			}

			// Try to retrieve handler
			handler, err := registry.Handler(tt.pkgPath, tt.function)

			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error but got nil")
				}
				if err.Error() != tt.errMessage {
					t.Errorf("expected error message %q but got %q", tt.errMessage, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if handler == nil {
					t.Error("expected handler to be non-nil")
				}
			}
		})
	}
}
