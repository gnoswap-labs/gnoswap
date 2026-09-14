package governance

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/gov/governance"
)

// TestVotingInfo_NewVotingInfo tests the creation of new VotingInfo instances
func TestVotingInfo_NewVotingInfo(cur realm, t *testing.T) {
	tests := []struct {
		name               string
		availableWeight    int64
		expectedVotingInfo governance.VotingInfo
	}{
		{
			name:               "Create new voting info with positive weight",
			availableWeight:    100,
			expectedVotingInfo: governance.NewVotingInfo(100),
		},
		{
			name:               "Create new voting info with zero weight",
			availableWeight:    0,
			expectedVotingInfo: governance.NewVotingInfo(0),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// when
			result := governance.NewVotingInfo(tc.availableWeight)

			// then
			uassert.Equal(t, result.AvailableVoteWeight(), tc.expectedVotingInfo.AvailableVoteWeight())
			uassert.Equal(t, result.VotedWeight(), tc.expectedVotingInfo.VotedWeight())
			uassert.Equal(t, result.VotedHeight(), tc.expectedVotingInfo.VotedHeight())
			uassert.Equal(t, result.VotedAt(), tc.expectedVotingInfo.VotedAt())
			uassert.Equal(t, result.VotedYes(), tc.expectedVotingInfo.VotedYes())
			uassert.Equal(t, result.IsVoted(), tc.expectedVotingInfo.IsVoted())
		})
	}
}

// TestVotingInfo_VotingTypeAndStatus tests the voting type and status getters
func TestVotingInfo_VotingTypeAndStatus(cur realm, t *testing.T) {
	tests := []struct {
		name               string
		votingInfo         func() governance.VotingInfo
		expectedVotingType string
		expectedIsVoted    bool
		expectedVotedYes   bool
		expectedVotedNo    bool
	}{
		{
			name: "Yes vote status",
			votingInfo: func() governance.VotingInfo {
				vi, _ := withVote(governance.NewVotingInfo(100), true, 100, 0, 0)
				return vi
			},
			expectedVotingType: "yes",
			expectedIsVoted:    true,
			expectedVotedYes:   true,
			expectedVotedNo:    false,
		},
		{
			name: "No vote status",
			votingInfo: func() governance.VotingInfo {
				vi, _ := withVote(governance.NewVotingInfo(100), false, 100, 0, 0)
				return vi
			},
			expectedVotingType: "no",
			expectedIsVoted:    true,
			expectedVotedYes:   false,
			expectedVotedNo:    true,
		},
		{
			name: "Not voted status",
			votingInfo: func() governance.VotingInfo {
				vi := governance.NewVotingInfo(100)
				return vi
			},
			expectedVotingType: "no",
			expectedIsVoted:    false,
			expectedVotedYes:   false,
			expectedVotedNo:    true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// when & then
			uassert.Equal(t, tc.votingInfo().VotingType(), tc.expectedVotingType)
			uassert.Equal(t, tc.votingInfo().IsVoted(), tc.expectedIsVoted)
			uassert.Equal(t, tc.votingInfo().VotedYes(), tc.expectedVotedYes)
			uassert.Equal(t, tc.votingInfo().VotedNo(), tc.expectedVotedNo)
		})
	}
}

// TestVotingInfo_VoteWeights tests the vote weight getters
func TestVotingInfo_VoteWeights(cur realm, t *testing.T) {
	tests := []struct {
		name                    string
		votingInfo              func() governance.VotingInfo
		expectedAvailableWeight int64
		expectedVotedWeight     int64
	}{
		{
			name: "Get weights before voting",
			votingInfo: func() governance.VotingInfo {
				vi := governance.NewVotingInfo(100)
				return vi
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:     0,
		},
		{
			name: "Get weights after voting",
			votingInfo: func() governance.VotingInfo {
				vi, _ := withVote(governance.NewVotingInfo(100), false, 50, 0, 0)
				return vi
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:     50,
		},
		{
			name: "Get weights with zero available weight",
			votingInfo: func() governance.VotingInfo {
				vi := governance.NewVotingInfo(0)
				return vi
			},
			expectedAvailableWeight: 0,
			expectedVotedWeight:     0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(cur realm, t *testing.T) {
			// when & then
			uassert.Equal(t, tc.votingInfo().AvailableVoteWeight(), tc.expectedAvailableWeight)
			uassert.Equal(t, tc.votingInfo().VotedWeight(), tc.expectedVotedWeight)
		})
	}
}
