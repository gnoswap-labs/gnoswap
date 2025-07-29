package governance

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/uassert"
)

// TestProposalStatus_StatusType tests status type determination
func TestProposalStatus_StatusType(t *testing.T) {
	baseTime := time.Unix(1000, 0)
	config := Config{
		VotingStartDelay: 100,
		VotingPeriod:    200,
		ExecutionDelay:  100,
		ExecutionWindow: 200,
		Quorum:         50,
	}

	tests := []struct {
		name           string
		currentTime    time.Time
		maxVotingWeight int64
		executable     bool
		isExecuted     bool
		isCanceled     bool
		expectedStatus ProposalStatusType
	}{
		{
			name:            "Status Upcoming",
			currentTime:     baseTime.Add(time.Duration(50) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			expectedStatus:  StatusUpcoming,
		},
		{
			name:            "Status Active",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			expectedStatus:  StatusActive,
		},
		{
			name:            "Status Executed",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			isExecuted:      true,
			expectedStatus:  StatusExecuted,
		},
		{
			name:            "Status Canceled",
			currentTime:     baseTime.Add(time.Duration(150) * time.Second),
			maxVotingWeight: 1000,
			executable:      true,
			isCanceled:      true,
			expectedStatus:  StatusCanceled,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalStatus(config, tc.maxVotingWeight, tc.executable, baseTime.Unix())
			if tc.isExecuted {
				_ = status.execute(tc.currentTime.Unix(), 100, std.Address("g1executor"))
			}
			if tc.isCanceled {
				_ = status.cancel(tc.currentTime.Unix(), 100, std.Address("g1canceler"))
			}

			// when
			statusType := status.StatusType(tc.currentTime.Unix())

			// then
			uassert.Equal(t, statusType.String(), tc.expectedStatus.String())
		})
	}
}

// TestProposalStatus_VotingOperations tests voting operations
func TestProposalStatus_VotingOperations(t *testing.T) {
	tests := []struct {
		name            string
		maxVotingWeight int64
		quorum          int64
		voteYes         int64
		voteNo          int64
		expectedTotal   int64
		expectedDiff    int64
	}{
		{
			name:            "Voting with majority yes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         600,
			voteNo:          300,
			expectedTotal:   900,
			expectedDiff:    300,
		},
		{
			name:            "Voting with majority no",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         300,
			voteNo:          600,
			expectedTotal:   900,
			expectedDiff:    300,
		},
		{
			name:            "Equal votes",
			maxVotingWeight: 1000,
			quorum:          500,
			voteYes:         400,
			voteNo:          400,
			expectedTotal:   800,
			expectedDiff:    0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := Config{
				VotingStartDelay: 100,
				VotingPeriod:    200,
				ExecutionDelay:  100,
				ExecutionWindow: 200,
				Quorum:         tc.quorum,
			}
			status := NewProposalStatus(config, tc.maxVotingWeight, true, time.Now().Unix())

			// when
			if tc.voteYes > 0 {
				_ = status.vote(true, tc.voteYes)
			}
			if tc.voteNo > 0 {
				_ = status.vote(false, tc.voteNo)
			}

			// then
			uassert.Equal(t, status.YesWeight(), tc.voteYes)
			uassert.Equal(t, status.NoWeight(), tc.voteNo)
			uassert.Equal(t, status.TotalVoteWeight(), tc.expectedTotal)
			uassert.Equal(t, status.DiffVoteWeight(), tc.expectedDiff)
		})
	}
}

// TestProposalStatus_ExecutionOperations tests execution operations
func TestProposalStatus_ExecutionOperations(t *testing.T) {
	tests := []struct {
		name           string
		executable     bool
		operation     string // "execute" or "cancel"
		success       bool
		expectedError bool
	}{
		{
			name:          "Execute successful proposal",
			executable:    true,
			operation:    "execute",
			success:      true,
			expectedError: false,
		},
		{
			name:          "Cancel executable proposal",
			executable:    true,
			operation:    "cancel",
			expectedError: false,
		},
		{
			name:          "Execute non-executable proposal",
			executable:    false,
			operation:    "execute",
			expectedError: true,
		},
		{
			name:          "Cancel non-executable proposal",
			executable:    false,
			operation:    "cancel",
			expectedError: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			config := Config{
				VotingStartDelay: 100,
				VotingPeriod:    200,
				ExecutionDelay:  100,
				ExecutionWindow: 200,
				Quorum:         50,
			}
			status := NewProposalStatus(config, 1000, tc.executable, time.Now().Unix())

			// when
			var err error
			if tc.operation == "execute" {
				err = status.execute(time.Now().Unix(), 100, std.Address("g1executor"))
				if err == nil && tc.success {
					status.updateExecuteResult(true)
				}
			} else {
				err = status.cancel(time.Now().Unix(), 100, std.Address("g1canceler"))
			}

			// then
			if tc.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)
			}
		})
	}
} 