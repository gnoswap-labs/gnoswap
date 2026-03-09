package v1

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/gov/governance"
)

// TestProposalVoteStatus_VotingOperations tests voting operations and status
func TestProposalVoteStatus_VotingOperations(t *testing.T) {
	tests := []struct {
		name            string
		maxVotingWeight int64
		quorum          int64
		yesVotes        int64
		noVotes         int64
		expectedPassed  bool
	}{
		{
			name:            "Not reached quorum",
			maxVotingWeight: 1000,
			quorum:          60,
			yesVotes:        300,
			noVotes:         200,
			expectedPassed:  false,
		},
		{
			name:            "Passed with quorum",
			maxVotingWeight: 1000,
			quorum:          60,
			yesVotes:        600,
			noVotes:         300,
			expectedPassed:  true,
		},
		{
			name:            "Rejected with quorum",
			maxVotingWeight: 1000,
			quorum:          60,
			yesVotes:        300,
			noVotes:         600,
			expectedPassed:  false,
		},
		{
			name:            "Equal votes with quorum passes",
			maxVotingWeight: 1000,
			quorum:          60,
			yesVotes:        300,
			noVotes:         300,
			expectedPassed:  true,
		},
		{
			name:            "Equal votes but quorum not reached",
			maxVotingWeight: 1000,
			quorum:          60,
			yesVotes:        200,
			noVotes:         200,
			expectedPassed:  false,
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

// TestProposalVoteStatus_SafeMathOperations tests safe math operations in vote status
func TestProposalVoteStatus_SafeMathOperations(t *testing.T) {
	tests := []struct {
		name                string
		description         string
		maxVotingWeight     int64
		quorumAmount        int64
		yesVotes            []int64
		noVotes             []int64
		expectedYesWeight   int64
		expectedNoWeight    int64
		expectedTotalWeight int64
	}{
		{
			name:                "Normal voting with multiple votes",
			description:         "Standard voting scenario with multiple vote additions",
			maxVotingWeight:     1000,
			quorumAmount:        500,
			yesVotes:            []int64{100, 200, 150},
			noVotes:             []int64{50, 100},
			expectedYesWeight:   450,
			expectedNoWeight:    150,
			expectedTotalWeight: 600,
		},
		{
			name:                "Large voting weights",
			description:         "Voting with large but safe values",
			maxVotingWeight:     1000000000000000000,
			quorumAmount:        500000000000000000,
			yesVotes:            []int64{400000000000000000, 200000000000000000},
			noVotes:             []int64{300000000000000000},
			expectedYesWeight:   600000000000000000,
			expectedNoWeight:    300000000000000000,
			expectedTotalWeight: 900000000000000000,
		},
		{
			name:                "Zero votes",
			description:         "Initial state with no votes cast",
			maxVotingWeight:     1000,
			quorumAmount:        500,
			yesVotes:            []int64{},
			noVotes:             []int64{},
			expectedYesWeight:   0,
			expectedNoWeight:    0,
			expectedTotalWeight: 0,
		},
		{
			name:                "Equal yes and no votes",
			description:         "Tie scenario with equal votes",
			maxVotingWeight:     1000,
			quorumAmount:        500,
			yesVotes:            []int64{250, 100},
			noVotes:             []int64{200, 150},
			expectedYesWeight:   350,
			expectedNoWeight:    350,
			expectedTotalWeight: 700,
		},
		{
			name:                "No votes winning",
			description:         "More no votes than yes votes",
			maxVotingWeight:     1000,
			quorumAmount:        500,
			yesVotes:            []int64{100},
			noVotes:             []int64{500, 200},
			expectedYesWeight:   100,
			expectedNoWeight:    700,
			expectedTotalWeight: 800,
		},
		{
			name:                "Single large vote",
			description:         "One voter with most of the weight",
			maxVotingWeight:     10000,
			quorumAmount:        5000,
			yesVotes:            []int64{9000},
			noVotes:             []int64{500},
			expectedYesWeight:   9000,
			expectedNoWeight:    500,
			expectedTotalWeight: 9500,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, tc.quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// when - add yes votes
			for _, yesVote := range tc.yesVotes {
				err := resolver.AddYesVoteWeight(yesVote)
				uassert.Nil(t, err)
			}

			// when - add no votes
			for _, noVote := range tc.noVotes {
				err := resolver.AddNoVoteWeight(noVote)
				uassert.Nil(t, err)
			}

			// then
			uassert.Equal(t, tc.expectedYesWeight, resolver.YesWeight())
			uassert.Equal(t, tc.expectedNoWeight, resolver.NoWeight())
			uassert.Equal(t, tc.expectedTotalWeight, resolver.TotalVoteWeight())
		})
	}
}

// TestProposalVoteStatus_QuorumCalculation tests quorum-related calculations
func TestProposalVoteStatus_QuorumCalculation(t *testing.T) {
	tests := []struct {
		name             string
		description      string
		maxVotingWeight  int64
		quorumPercentage int64
		yesWeight        int64
		expectedQuorum   int64
		expectedPassed   bool
	}{
		{
			name:             "50% quorum not met",
			description:      "Yes votes below 50% quorum",
			maxVotingWeight:  1000,
			quorumPercentage: 50,
			yesWeight:        400,
			expectedQuorum:   500,
			expectedPassed:   false,
		},
		{
			name:             "50% quorum exactly met",
			description:      "Yes votes exactly at 50% quorum",
			maxVotingWeight:  1000,
			quorumPercentage: 50,
			yesWeight:        500,
			expectedQuorum:   500,
			expectedPassed:   true,
		},
		{
			name:             "50% quorum exceeded",
			description:      "Yes votes exceed 50% quorum",
			maxVotingWeight:  1000,
			quorumPercentage: 50,
			yesWeight:        600,
			expectedQuorum:   500,
			expectedPassed:   true,
		},
		{
			name:             "75% quorum with large values",
			description:      "High quorum with large voting weights",
			maxVotingWeight:  1000000000000,
			quorumPercentage: 75,
			yesWeight:        750000000001,
			expectedQuorum:   750000000000,
			expectedPassed:   true,
		},
		{
			name:             "10% quorum (low threshold)",
			description:      "Low quorum threshold scenario",
			maxVotingWeight:  1000,
			quorumPercentage: 10,
			yesWeight:        100,
			expectedQuorum:   100,
			expectedPassed:   true,
		},
		{
			name:             "100% quorum (full consensus required)",
			description:      "Full voting weight required as quorum",
			maxVotingWeight:  1000,
			quorumPercentage: 100,
			yesWeight:        999,
			expectedQuorum:   1000,
			expectedPassed:   false,
		},
		{
			name:             "100% quorum met",
			description:      "Full voting weight reached as quorum",
			maxVotingWeight:  1000,
			quorumPercentage: 100,
			yesWeight:        1000,
			expectedQuorum:   1000,
			expectedPassed:   true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			quorumAmount := safeMulDiv(tc.maxVotingWeight, tc.quorumPercentage, 100)
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// when
			if tc.yesWeight > 0 {
				_ = resolver.AddYesVoteWeight(tc.yesWeight)
			}

			// then
			uassert.Equal(t, tc.expectedQuorum, resolver.QuorumAmount())
			uassert.Equal(t, tc.expectedPassed, resolver.IsPassed())
		})
	}
}
