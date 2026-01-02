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
		{
			name:             "Quorum met but no leads",
			maxVotingWeight:  5000,
			quorum:           40,
			yesVotes:         2000,
			noVotes:          2500,
			expectedFinished: true,
			expectedRejected: true,
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
		expectedDiffWeight  int64
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
			expectedDiffWeight:  300,
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
			expectedDiffWeight:  300000000000000000,
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
			expectedDiffWeight:  0,
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
			expectedDiffWeight:  0,
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
			expectedDiffWeight:  600,
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
			expectedDiffWeight:  8500,
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
			uassert.Equal(t, tc.expectedDiffWeight, resolver.DiffVoteWeight())
		})
	}
}

// TestProposalVoteStatus_IsVotingFinished tests early termination logic
func TestProposalVoteStatus_IsVotingFinished(t *testing.T) {
	tests := []struct {
		name             string
		description      string
		maxVotingWeight  int64
		quorumAmount     int64
		yesWeight        int64
		noWeight         int64
		expectedFinished bool
		expectedPassed   bool
		expectedRejected bool
	}{
		{
			name:             "Not finished: quorum not reached",
			description:      "Total votes haven't reached quorum",
			maxVotingWeight:  1000,
			quorumAmount:     600,
			yesWeight:        200,
			noWeight:         200,
			expectedFinished: false,
			expectedPassed:   false,
			expectedRejected: false,
		},
		{
			name:             "Not finished: quorum reached but outcome undetermined",
			description:      "Quorum reached but remaining votes could change outcome",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        350,
			noWeight:         250,
			expectedFinished: false, // remaining 400 > diff 100
			expectedPassed:   false,
			expectedRejected: false,
		},
		{
			name:             "Finished: yes votes mathematically determined",
			description:      "Yes votes lead by more than remaining votes",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        700,
			noWeight:         200,
			expectedFinished: true, // remaining 100 < diff 500
			expectedPassed:   true,
			expectedRejected: false,
		},
		{
			name:             "Finished: no votes mathematically determined",
			description:      "No votes lead by more than remaining votes",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        200,
			noWeight:         700,
			expectedFinished: true,
			expectedPassed:   false,
			expectedRejected: true,
		},
		{
			name:             "Finished: all votes cast with yes winning",
			description:      "All voting weight used, yes wins",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        600,
			noWeight:         400,
			expectedFinished: true,
			expectedPassed:   true,
			expectedRejected: false,
		},
		{
			name:             "Finished: all votes cast with no winning",
			description:      "All voting weight used, no wins",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        400,
			noWeight:         600,
			expectedFinished: true,
			expectedPassed:   false,
			expectedRejected: true,
		},
		{
			name:             "exactly at quorum boundary",
			description:      "Yes votes exactly at quorum amount",
			maxVotingWeight:  1000,
			quorumAmount:     500,
			yesWeight:        500,
			noWeight:         400,
			expectedFinished: true, // remaining 100 < diff 100, equal so finished
			expectedPassed:   true,
			expectedRejected: false,
		},
		{
			name:             "zero quorum",
			description:      "Zero quorum means any vote passes",
			maxVotingWeight:  1000,
			quorumAmount:     0,
			yesWeight:        1,
			noWeight:         0,
			expectedFinished: false, // remaining 999 > diff 1
			expectedPassed:   true,  // yes >= quorum (0)
			expectedRejected: false,
		},
		{
			name:             "Large values near max int64",
			description:      "Testing with large values close to int64 max",
			maxVotingWeight:  9000000000000000000,
			quorumAmount:     4500000000000000000,
			yesWeight:        5000000000000000000,
			noWeight:         3000000000000000000,
			expectedFinished: true, // remaining 1e18 < diff 2e18
			expectedPassed:   true,
			expectedRejected: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, tc.quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// when
			if tc.yesWeight > 0 {
				_ = resolver.AddYesVoteWeight(tc.yesWeight)
			}
			if tc.noWeight > 0 {
				_ = resolver.AddNoVoteWeight(tc.noWeight)
			}

			// then
			uassert.Equal(t, tc.expectedFinished, resolver.IsVotingFinished())
			uassert.Equal(t, tc.expectedPassed, resolver.IsPassed())
			uassert.Equal(t, tc.expectedRejected, resolver.IsRejected())
		})
	}
}

// TestProposalVoteStatus_DiffVoteWeight tests difference calculation
func TestProposalVoteStatus_DiffVoteWeight(t *testing.T) {
	tests := []struct {
		name            string
		description     string
		maxVotingWeight int64
		quorumAmount    int64
		yesWeight       int64
		noWeight        int64
		expectedDiff    int64
	}{
		{
			name:            "Yes leading",
			description:     "Positive difference when yes leads",
			maxVotingWeight: 1000,
			quorumAmount:    500,
			yesWeight:       600,
			noWeight:        300,
			expectedDiff:    300,
		},
		{
			name:            "No leading",
			description:     "Positive difference when no leads (absolute value)",
			maxVotingWeight: 1000,
			quorumAmount:    500,
			yesWeight:       200,
			noWeight:        700,
			expectedDiff:    500,
		},
		{
			name:            "Equal votes",
			description:     "Zero difference when tied",
			maxVotingWeight: 1000,
			quorumAmount:    500,
			yesWeight:       400,
			noWeight:        400,
			expectedDiff:    0,
		},
		{
			name:            "No votes cast",
			description:     "Zero difference with no votes",
			maxVotingWeight: 1000,
			quorumAmount:    500,
			yesWeight:       0,
			noWeight:        0,
			expectedDiff:    0,
		},
		{
			name:            "Large difference",
			description:     "Large values with significant difference",
			maxVotingWeight: 1000000000000000000,
			quorumAmount:    500000000000000000,
			yesWeight:       800000000000000000,
			noWeight:        100000000000000000,
			expectedDiff:    700000000000000000,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			status := governance.NewProposalVoteStatus(tc.maxVotingWeight, tc.quorumAmount)
			resolver := NewProposalVoteStatusResolver(status)

			// when
			if tc.yesWeight > 0 {
				_ = resolver.AddYesVoteWeight(tc.yesWeight)
			}
			if tc.noWeight > 0 {
				_ = resolver.AddNoVoteWeight(tc.noWeight)
			}

			// then
			uassert.Equal(t, tc.expectedDiff, resolver.DiffVoteWeight())
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
