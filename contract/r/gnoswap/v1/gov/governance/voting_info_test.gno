package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
)

// TestVotingInfo_NewVotingInfo tests the creation of new VotingInfo instances
func TestVotingInfo_NewVotingInfo(t *testing.T) {
	tests := []struct {
		name               string
		availableWeight    int64
		voterAddress       std.Address
		expectedVotingInfo *VotingInfo
	}{
		{
			name:            "Create new voting info with positive weight",
			availableWeight: 100,
			voterAddress:    std.Address("g1voter"),
			expectedVotingInfo: &VotingInfo{
				availableVoteWeight: 100,
				voterAddress:       std.Address("g1voter"),
				votedWeight:        0,
				votedHeight:        0,
				votedAt:            0,
				votedYes:          false,
				voted:             false,
			},
		},
		{
			name:            "Create new voting info with zero weight",
			availableWeight: 0,
			voterAddress:    std.Address("g1voter2"),
			expectedVotingInfo: &VotingInfo{
				availableVoteWeight: 0,
				voterAddress:       std.Address("g1voter2"),
				votedWeight:        0,
				votedHeight:        0,
				votedAt:            0,
				votedYes:          false,
				voted:             false,
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			result := NewVotingInfo(tc.availableWeight, tc.voterAddress)

			// then
			uassert.Equal(t, result.availableVoteWeight, tc.expectedVotingInfo.availableVoteWeight)
			uassert.Equal(t, result.voterAddress, tc.expectedVotingInfo.voterAddress)
			uassert.Equal(t, result.votedWeight, tc.expectedVotingInfo.votedWeight)
			uassert.Equal(t, result.votedHeight, tc.expectedVotingInfo.votedHeight)
			uassert.Equal(t, result.votedAt, tc.expectedVotingInfo.votedAt)
			uassert.Equal(t, result.votedYes, tc.expectedVotingInfo.votedYes)
			uassert.Equal(t, result.voted, tc.expectedVotingInfo.voted)
		})
	}
}

// TestVotingInfo_VoteExecution tests the voting execution functionality
func TestVotingInfo_VoteExecution(t *testing.T) {
	tests := []struct {
		name            string
		votingInfo     *VotingInfo
		voteYes        bool
		weight         int64
		height         int64
		timestamp      int64
		expectedError  error
		expectedVoted  bool
		expectedVoteYes bool
	}{
		{
			name: "Vote yes successfully",
			votingInfo: &VotingInfo{
				availableVoteWeight: 100,
				voterAddress:       std.Address("g1voter"),
			},
			voteYes:        true,
			weight:         50,
			height:         1000,
			timestamp:      1234567890,
			expectedError:  nil,
			expectedVoted:  true,
			expectedVoteYes: true,
		},
		{
			name: "Vote no successfully",
			votingInfo: &VotingInfo{
				availableVoteWeight: 100,
				voterAddress:       std.Address("g1voter"),
			},
			voteYes:        false,
			weight:         50,
			height:         1000,
			timestamp:      1234567890,
			expectedError:  nil,
			expectedVoted:  true,
			expectedVoteYes: false,
		},
		{
			name: "Cannot vote twice",
			votingInfo: &VotingInfo{
				availableVoteWeight: 100,
				voterAddress:       std.Address("g1voter"),
				voted:             true,
			},
			voteYes:        true,
			weight:         50,
			height:         1000,
			timestamp:      1234567890,
			expectedError:  errAlreadyVoted,
			expectedVoted:  true,
			expectedVoteYes: false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			err := tc.votingInfo.vote(tc.voteYes, tc.weight, tc.height, tc.timestamp)

			// then
			if tc.expectedError == nil {
				uassert.Equal(t, tc.votingInfo.voted, tc.expectedVoted)
				uassert.Equal(t, tc.votingInfo.votedYes, tc.expectedVoteYes)
				uassert.Equal(t, tc.votingInfo.votedWeight, tc.weight)
				uassert.Equal(t, tc.votingInfo.votedHeight, tc.height)
				uassert.Equal(t, tc.votingInfo.votedAt, tc.timestamp)
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
		votingInfo        *VotingInfo
		expectedVotingType string
		expectedIsVoted    bool
		expectedVotedYes   bool
		expectedVotedNo    bool
	}{
		{
			name: "Yes vote status",
			votingInfo: &VotingInfo{
				voted:    true,
				votedYes: true,
			},
			expectedVotingType: "yes",
			expectedIsVoted:    true,
			expectedVotedYes:   true,
			expectedVotedNo:    false,
		},
		{
			name: "No vote status",
			votingInfo: &VotingInfo{
				voted:    true,
				votedYes: false,
			},
			expectedVotingType: "no",
			expectedIsVoted:    true,
			expectedVotedYes:   false,
			expectedVotedNo:    true,
		},
		{
			name: "Not voted status",
			votingInfo: &VotingInfo{
				voted:    false,
				votedYes: false,
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
			uassert.Equal(t, tc.votingInfo.VotingType(), tc.expectedVotingType)
			uassert.Equal(t, tc.votingInfo.IsVoted(), tc.expectedIsVoted)
			uassert.Equal(t, tc.votingInfo.VotedYes(), tc.expectedVotedYes)
			uassert.Equal(t, tc.votingInfo.VotedNo(), tc.expectedVotedNo)
		})
	}
}

// TestVotingInfo_VoteWeights tests the vote weight getters
func TestVotingInfo_VoteWeights(t *testing.T) {
	tests := []struct {
		name                      string
		votingInfo               *VotingInfo
		expectedAvailableWeight   int64
		expectedVotedWeight       int64
	}{
		{
			name: "Get weights before voting",
			votingInfo: &VotingInfo{
				availableVoteWeight: 100,
				votedWeight:        0,
				voted:             false,
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:    0,
		},
		{
			name: "Get weights after voting",
			votingInfo: &VotingInfo{
				availableVoteWeight: 100,
				votedWeight:        50,
				voted:             true,
			},
			expectedAvailableWeight: 100,
			expectedVotedWeight:    50,
		},
		{
			name: "Get weights with zero available weight",
			votingInfo: &VotingInfo{
				availableVoteWeight: 0,
				votedWeight:        0,
				voted:             false,
			},
			expectedAvailableWeight: 0,
			expectedVotedWeight:    0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when & then
			uassert.Equal(t, tc.votingInfo.AvailableVoteWeight(), tc.expectedAvailableWeight)
			uassert.Equal(t, tc.votingInfo.VotedWeight(), tc.expectedVotedWeight)
		})
	}
} 