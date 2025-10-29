package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// TestVotingInfo_NewVotingInfo tests the creation of new VotingInfo instances
func TestVotingInfo_NewVotingInfo(t *testing.T) {
	tests := []struct {
		name               string
		availableWeight    int64
		voterAddress       address
		expectedVotingInfo *governance.VotingInfo
	}{
		{
			name:            "Create new voting info with positive weight",
			availableWeight: 100,
			voterAddress:    address("g1voter"),
			expectedVotingInfo: governance.NewVotingInfo(100, address("g1voter")),
		},
		{
			name:            "Create new voting info with zero weight",
			availableWeight: 0,
			voterAddress:    address("g1voter2"),
			expectedVotingInfo: governance.NewVotingInfo(0, address("g1voter2")),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := governance.NewVotingInfo(tc.availableWeight, tc.voterAddress)

			// then
			uassert.Equal(t, result.AvailableVoteWeight(), tc.expectedVotingInfo.AvailableVoteWeight())
			uassert.Equal(t, result.VoterAddress(), tc.expectedVotingInfo.VoterAddress())
			uassert.Equal(t, result.VotedWeight(), tc.expectedVotingInfo.VotedWeight())
			uassert.Equal(t, result.VotedHeight(), tc.expectedVotingInfo.VotedHeight())
			uassert.Equal(t, result.VotedAt(), tc.expectedVotingInfo.VotedAt())
			uassert.Equal(t, result.VotedYes(), tc.expectedVotingInfo.VotedYes())
			uassert.Equal(t, result.IsVoted(), tc.expectedVotingInfo.IsVoted())
		})
	}
}

// TestVotingInfo_VoteExecution tests the voting execution functionality
func TestVotingInfo_VoteExecution(t *testing.T) {
	tests := []struct {
		name            string
		votingInfo      *governance.VotingInfo
		voteYes         bool
		weight          int64
		height          int64
		timestamp       int64
		expectedError   error
		expectedVoted   bool
		expectedVoteYes bool
	}{
		{
			name: "Vote yes successfully",
			votingInfo: governance.NewVotingInfo(100, address("g1voter")),
			voteYes:         true,
			weight:          50,
			height:          1000,
			timestamp:       1234567890,
			expectedError:   nil,
			expectedVoted:   true,
			expectedVoteYes: true,
		},
		{
			name: "Vote no successfully",
			votingInfo: governance.NewVotingInfo(100, address("g1voter")),
			voteYes:         false,
			weight:          50,
			height:          1000,
			timestamp:       1234567890,
			expectedError:   nil,
			expectedVoted:   true,
			expectedVoteYes: false,
		},
		{
			name: "Cannot vote twice",
			votingInfo: governance.NewVotingInfo(100, address("g1voter")),
			voteYes:         true,
			weight:          50,
			height:          1000,
			timestamp:       1234567890,
			expectedError:   errAlreadyVoted,
			expectedVoted:   true,
			expectedVoteYes: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			resolver := NewVotingInfoResolver(tc.votingInfo)
			err := resolver.vote(tc.voteYes, tc.weight, tc.height, tc.timestamp)

			// then
			if tc.expectedError == nil {
				uassert.Equal(t, tc.votingInfo.IsVoted(), tc.expectedVoted)
				uassert.Equal(t, tc.votingInfo.VotedYes(), tc.expectedVoteYes)
				uassert.Equal(t, tc.votingInfo.VotedWeight(), tc.weight)
				uassert.Equal(t, tc.votingInfo.VotedHeight(), tc.height)
				uassert.Equal(t, tc.votingInfo.VotedAt(), tc.timestamp)
			} else {
				uassert.ErrorIs(t, err, tc.expectedError)
			}
		})
	}
}

// TestVotingInfo_VotingTypeAndStatus tests the voting type and status getters
func TestVotingInfo_VotingTypeAndStatus(t *testing.T) {
	tests := []struct {
		name               string
		votingInfo         func() *governance.VotingInfo
		expectedVotingType string
		expectedIsVoted    bool
		expectedVotedYes   bool
		expectedVotedNo    bool
	}{
		{
			name: "Yes vote status",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(100, address("g1voter"))
				vi.SetVoted(true)
				vi.SetVotedYes(true)
				return vi
			},
			expectedVotingType: "yes",
			expectedIsVoted:    true,
			expectedVotedYes:   true,
			expectedVotedNo:    false,
		},
		{
			name: "No vote status",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(100, address("g1voter"))
				vi.SetVoted(true)
				vi.SetVotedYes(false)
				return vi
			},
			expectedVotingType: "no",
			expectedIsVoted:    true,
			expectedVotedYes:   false,
			expectedVotedNo:    true,
		},
		{
			name: "Not voted status",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(100, address("g1voter"))
				return vi
			},
			expectedVotingType: "no",
			expectedIsVoted:    false,
			expectedVotedYes:   false,
			expectedVotedNo:    true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when & then
			uassert.Equal(t, tc.votingInfo().VotingType(), tc.expectedVotingType)
			uassert.Equal(t, tc.votingInfo().IsVoted(), tc.expectedIsVoted)
			uassert.Equal(t, tc.votingInfo().VotedYes(), tc.expectedVotedYes)
			uassert.Equal(t, tc.votingInfo().VotedNo(), tc.expectedVotedNo)
		})
	}
}

// TestVotingInfo_VoteWeights tests the vote weight getters
func TestVotingInfo_VoteWeights(t *testing.T) {
	voterAddr := address("g1voter")
	tests := []struct {
		name                    string
		votingInfo              func() *governance.VotingInfo
		expectedAvailableWeight int64
		expectedVotedWeight     int64
	}{
		{
			name: "Get weights before voting",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(100, voterAddr)
				return vi
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:     0,
		},
		{
			name: "Get weights after voting",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(100, voterAddr)
				vi.SetVoted(true)
				vi.SetVotedWeight(50)
				return vi
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:     50,
		},
		{
			name: "Get weights with zero available weight",
			votingInfo: func() *governance.VotingInfo {
				vi := governance.NewVotingInfo(0, voterAddr)
				return vi
			},
			expectedAvailableWeight: 0,
			expectedVotedWeight:     0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when & then
			uassert.Equal(t, tc.votingInfo().AvailableVoteWeight(), tc.expectedAvailableWeight)
			uassert.Equal(t, tc.votingInfo().VotedWeight(), tc.expectedVotedWeight)
		})
	}
}
