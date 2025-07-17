package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestProposalActionStatus_CancelAndExecute tests cancel and execute operations
func TestProposalActionStatus_CancelAndExecute(t *testing.T) {
	tests := []struct {
		name                string
		executable         bool
		operation          string // "cancel" or "execute"
		timestamp          int64
		height             int64
		actor              std.Address
		expectedError      bool
		expectedSuccess    bool
	}{
		{
			name:           "Success - Cancel executable proposal",
			executable:     true,
			operation:     "cancel",
			timestamp:     1000,
			height:        100,
			actor:         std.Address("g1canceler"),
			expectedError: false,
		},
		{
			name:           "Success - Execute executable proposal",
			executable:     true,
			operation:     "execute",
			timestamp:     1000,
			height:        100,
			actor:         std.Address("g1executor"),
			expectedError: false,
		},
		{
			name:           "Failure - Cancel non-executable proposal",
			executable:     false,
			operation:     "cancel",
			timestamp:     1000,
			height:        100,
			actor:         std.Address("g1canceler"),
			expectedError: true,
		},
		{
			name:           "Failure - Execute non-executable proposal",
			executable:     false,
			operation:     "execute",
			timestamp:     1000,
			height:        100,
			actor:         std.Address("g1executor"),
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalActionStatus(tc.executable)

			// when
			var err error
			if tc.operation == "cancel" {
				err = status.cancel(tc.timestamp, tc.height, tc.actor)
			} else {
				err = status.execute(tc.timestamp, tc.height, tc.actor)
			}

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
				if tc.operation == "cancel" {
					uassert.True(t, status.IsCanceled())
					uassert.Equal(t, status.CanceledBy(), tc.actor)
				} else {
					uassert.True(t, status.IsExecuted())
					uassert.Equal(t, status.ExecutedBy(), tc.actor)
				}
			}
		})
	}
}

// TestProposalActionStatus_UpdateResult tests result update functionality
func TestProposalActionStatus_UpdateResult(t *testing.T) {
	tests := []struct {
		name           string
		executable     bool
		executeFirst   bool
		success        bool
		expectedSuccess bool
	}{
		{
			name:            "Success - Update result after execution",
			executable:      true,
			executeFirst:    true,
			success:         true,
			expectedSuccess: true,
		},
		{
			name:            "Success - Update result without execution",
			executable:      true,
			executeFirst:    false,
			success:         true,
			expectedSuccess: false,
		},
		{
			name:            "Success - Update result with failure",
			executable:      true,
			executeFirst:    true,
			success:         false,
			expectedSuccess: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalActionStatus(tc.executable)
			if tc.executeFirst {
				_ = status.execute(1000, 100, std.Address("g1executor"))
			}

			// when
			status.updateResult(tc.success)

			// then
			uassert.Equal(t, status.IsSuccess(), tc.expectedSuccess)
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
			status := NewProposalActionStatus(tc.executable)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, status.IsExecutable(), tc.executable)
			uassert.False(t, status.IsCanceled())
			uassert.False(t, status.IsExecuted())
			uassert.False(t, status.IsSuccess())
		})
	}
} 