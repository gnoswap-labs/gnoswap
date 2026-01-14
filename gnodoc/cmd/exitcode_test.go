package cmd

import "testing"

func TestExitCode_Values(t *testing.T) {
	// Exit codes as per spec
	if ExitSuccess != 0 {
		t.Errorf("ExitSuccess should be 0, got %d", ExitSuccess)
	}
	if ExitError != 1 {
		t.Errorf("ExitError should be 1, got %d", ExitError)
	}
	if ExitPartialError != 2 {
		t.Errorf("ExitPartialError should be 2, got %d", ExitPartialError)
	}
}

func TestExitCode_String(t *testing.T) {
	tests := []struct {
		code     ExitCode
		expected string
	}{
		{ExitSuccess, "success"},
		{ExitError, "error"},
		{ExitPartialError, "partial error"},
		{ExitCode(99), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			got := tt.code.String()
			if got != tt.expected {
				t.Errorf("String() = %q, want %q", got, tt.expected)
			}
		})
	}
}
