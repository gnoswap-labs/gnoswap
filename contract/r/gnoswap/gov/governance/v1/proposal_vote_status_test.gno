package v1

import (
	"testing"

	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalVoteStatus_VotingOperations tests voting operations and status
func TestProposalVoteStatus_VotingOperations(t *testing.T) {
	tests := []struct {
		name             string
		maxVotingWeight  int64
		quorum           int64
		yesVotes         int64
		noVotes          int64
		expectedFinished bool
		expectedRejected bool
		expectedPassed   bool
	}{
		{
			name:             "Not reached quorum",
			maxVotingWeight:  1000,
			quorum:           60,
			yesVotes:         300,
			noVotes:          200,
			expectedFinished: false,
			expectedRejected: false,
			expectedPassed:   false,
		},
		{
			name:             "Passed with quorum",
			maxVotingWeight:  1000,
			quorum:           60,
			yesVotes:         600,
			noVotes:          300,
			expectedFinished: true,
			expectedRejected: false,
			expectedPassed:   true,
		},
		{
			name:             "Rejected with quorum",
			maxVotingWeight:  1000,
			quorum:           60,
			yesVotes:         300,
			noVotes:          600,
			expectedFinished: true,
			expectedRejected: true,
			expectedPassed:   false,
		},
		{
			name:             "Equal votes with quorum",
			maxVotingWeight:  1000,
			quorum:           60,
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
			quorumAmount := safeMulDiv(tc.maxVotingWeight, tc.quorum, 100)
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// when
			if tc.yesVotes > 0 {
				_ = resolver.AddYesVoteWeight(tc.yesVotes)
			}
			if tc.noVotes > 0 {
				_ = resolver.AddNoVoteWeight(tc.noVotes)
			}

			// then
			uassert.Equal(t, resolver.YesWeight(), tc.yesVotes)
			uassert.Equal(t, resolver.NoWeight(), tc.noVotes)
			uassert.Equal(t, resolver.TotalVoteWeight(), tc.yesVotes+tc.noVotes)
			uassert.Equal(t, resolver.IsVotingFinished(), tc.expectedFinished)
			uassert.Equal(t, resolver.IsRejected(), tc.expectedRejected)
			uassert.Equal(t, resolver.IsPassed(), tc.expectedPassed)
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
			quorumAmount := safeMulDiv(tc.maxVotingWeight, tc.quorum, 100)
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// then
			uassert.NotNil(t, status)
			uassert.Equal(t, resolver.MaxVotingWeight(), tc.maxVotingWeight)
			uassert.Equal(t, resolver.QuorumAmount(), tc.expectedQuorum)
			uassert.Equal(t, resolver.YesWeight(), int64(0))
			uassert.Equal(t, resolver.NoWeight(), int64(0))
		})
	}
}
