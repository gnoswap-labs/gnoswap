package governance

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// TestProposalVoteStatus_VotingOperations tests voting operations and status
func TestProposalVoteStatus_VotingOperations(t *testing.T) {
	tests := []struct {
		name              string
		maxVotingWeight   int64
		quorum            int64
		yesVotes         int64
		noVotes          int64
		expectedFinished bool
		expectedRejected bool
		expectedPassed   bool
	}{
		{
			name:              "Not reached quorum",
			maxVotingWeight:   1000,
			quorum:            60,
			yesVotes:         300,
			noVotes:          200,
			expectedFinished: false,
			expectedRejected: false,
			expectedPassed:   false,
		},
		{
			name:              "Passed with quorum",
			maxVotingWeight:   1000,
			quorum:            60,
			yesVotes:         600,
			noVotes:          300,
			expectedFinished: true,
			expectedRejected: false,
			expectedPassed:   true,
		},
		{
			name:              "Rejected with quorum",
			maxVotingWeight:   1000,
			quorum:            60,
			yesVotes:         300,
			noVotes:          600,
			expectedFinished: true,
			expectedRejected: true,
			expectedPassed:   false,
		},
		{
			name:              "Equal votes with quorum",
			maxVotingWeight:   1000,
			quorum:            60,
			yesVotes:         300,
			noVotes:          300,
			expectedFinished: false,
			expectedRejected: false,
			expectedPassed:   false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalVoteStatus(tc.maxVotingWeight, tc.quorum)

			// when
			if tc.yesVotes > 0 {
				_ = status.addYesVoteWeight(tc.yesVotes)
			}
			if tc.noVotes > 0 {
				_ = status.addNoVoteWeight(tc.noVotes)
			}

			// then
			uassert.Equal(t, status.YesWeight(), tc.yesVotes)
			uassert.Equal(t, status.NoWeight(), tc.noVotes)
			uassert.Equal(t, status.TotalVoteWeight(), tc.yesVotes+tc.noVotes)
			uassert.Equal(t, status.IsVotingFinished(), tc.expectedFinished)
			uassert.Equal(t, status.IsRejected(), tc.expectedRejected)
			uassert.Equal(t, status.IsPassed(), tc.expectedPassed)
		})
	}
}

// TestProposalVoteStatus_UpdateVoteStatus tests vote status updates
func TestProposalVoteStatus_UpdateVoteStatus(t *testing.T) {
	tests := []struct {
		name            string
		initialMax      int64
		initialQuorum   int64
		newMax          int64
		newQuorum       int64
		expectedQuorum  int64
	}{
		{
			name:           "Update with higher values",
			initialMax:     1000,
			initialQuorum:  50,
			newMax:         2000,
			newQuorum:      60,
			expectedQuorum: 1200,
		},
		{
			name:           "Update with lower values",
			initialMax:     1000,
			initialQuorum:  50,
			newMax:         500,
			newQuorum:      40,
			expectedQuorum: 200,
		},
		{
			name:           "Update with same values",
			initialMax:     1000,
			initialQuorum:  50,
			newMax:         1000,
			newQuorum:      50,
			expectedQuorum: 500,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := NewProposalVoteStatus(tc.initialMax, tc.initialQuorum)

			// when
			_ = status.updateVoteStatus(tc.newMax, tc.newQuorum)

			// then
			uassert.Equal(t, status.maxVotingWeight, tc.newMax)
			uassert.Equal(t, status.quorumAmount, tc.expectedQuorum)
		})
	}
}

// TestNewProposalVoteStatus tests creation of new vote status
func TestNewProposalVoteStatus(t *testing.T) {
	tests := []struct {
		name            string
		maxVotingWeight int64
		quorum          int64
		expectedQuorum  int64
	}{
		{
			name:            "Create with standard values",
			maxVotingWeight: 1000,
			quorum:          50,
			expectedQuorum:  500,
		},
		{
			name:            "Create with zero values",
			maxVotingWeight: 0,
			quorum:          0,
			expectedQuorum:  0,
		},
		{
			name:            "Create with high values",
			maxVotingWeight: 10000,
			quorum:          75,
			expectedQuorum:  7500,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			status := NewProposalVoteStatus(tc.maxVotingWeight, tc.quorum)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, status.maxVotingWeight, tc.maxVotingWeight)
			uassert.Equal(t, status.quorumAmount, tc.expectedQuorum)
			uassert.Equal(t, status.yea, int64(0))
			uassert.Equal(t, status.nay, int64(0))
		})
	}
} 