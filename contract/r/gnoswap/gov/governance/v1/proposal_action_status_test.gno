package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalActionStatus_CancelAndExecute tests cancel and execute operations
func TestProposalActionStatus_CancelAndExecute(t *testing.T) {
	tests := []struct {
		name            string
		executable      bool
		operation       string // "cancel" or "execute"
		canceled        bool
		timestamp       int64
		height          int64
		actor           address
		expectedError   bool
		expectedSuccess bool
	}{
		{
			name:          "Success - Cancel executable proposal",
			executable:    true,
			operation:     "cancel",
			canceled:      false,
			timestamp:     1000,
			height:        100,
			actor:         address("g1canceler"),
			expectedError: false,
		},
		{
			name:          "Success - Execute executable proposal",
			executable:    true,
			operation:     "execute",
			canceled:      false,
			timestamp:     1000,
			height:        100,
			actor:         address("g1executor"),
			expectedError: false,
		},
		{
			name:          "Failure - Cancel already canceled proposal",
			executable:    false,
			operation:     "cancel",
			canceled:      true,
			timestamp:     1000,
			height:        100,
			actor:         address("g1canceler"),
			expectedError: true,
		},
		{
			name:          "Failure - Execute non-executable proposal",
			executable:    false,
			operation:     "execute",
			canceled:      false,
			timestamp:     1000,
			height:        100,
			actor:         address("g1executor"),
			expectedError: true,
		},
		{
			name:          "Failure - Execute already canceled proposal",
			executable:    true,
			operation:     "execute",
			canceled:      true,
			timestamp:     1000,
			height:        100,
			actor:         address("g1executor"),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := governance.NewProposalActionStatus(tc.executable)
			resolver := NewProposalActionStatusResolver(status)
			if tc.canceled {
				resolver.SetCanceled(true)
			}
			// when
			var err error
			if tc.operation == "cancel" {
				err = resolver.cancel(tc.timestamp, tc.height, tc.actor)
			} else {
				err = resolver.Execute(tc.timestamp, tc.height, tc.actor)
			}

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
				if tc.operation == "cancel" {
					uassert.True(t, resolver.Canceled())
					uassert.Equal(t, resolver.CanceledBy(), tc.actor)
				} else {
					uassert.True(t, resolver.IsExecuted())
					uassert.Equal(t, resolver.ExecutedBy(), tc.actor)
				}
			}
		})
	}
}

// TestNewProposalActionStatus tests the creation of new action status
func TestNewProposalActionStatus(t *testing.T) {
	tests := []struct {
		name       string
		executable bool
	}{
		{
			name:       "Create executable status",
			executable: true,
		},
		{
			name:       "Create non-executable status",
			executable: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			status := governance.NewProposalActionStatus(tc.executable)
			resolver := NewProposalActionStatusResolver(status)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, resolver.IsExecutable(), tc.executable)
			uassert.False(t, resolver.Canceled())
			uassert.False(t, resolver.IsExecuted())
		})
	}
}
