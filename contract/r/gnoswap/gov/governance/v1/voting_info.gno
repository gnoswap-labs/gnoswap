package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type VotingInfoResolver struct {
	*governance.VotingInfo
}

func NewVotingInfoResolver(votingInfo *governance.VotingInfo) *VotingInfoResolver {
	return &VotingInfoResolver{
		VotingInfo: votingInfo,
	}
}

// voteYes records a "yes" vote with the specified weight and timing information.
// This is an internal helper method that delegates to the main vote function.
//
// Parameters:
//   - weight: voting weight to use for this vote
//   - votedHeight: block height when vote is cast
//   - votedAt: timestamp when vote is cast
//
// Returns:
//   - error: voting error if vote cannot be recorded
func (v *VotingInfoResolver) voteYes(weight int64, votedHeight int64, votedAt int64) error {
	return v.vote(true, weight, votedHeight, votedAt)
}

// voteNo records a "no" vote with the specified weight and timing information.
// This is an internal helper method that delegates to the main vote function.
//
// Parameters:
//   - weight: voting weight to use for this vote
//   - votedHeight: block height when vote is cast
//   - votedAt: timestamp when vote is cast
//
// Returns:
//   - error: voting error if vote cannot be recorded
func (v *VotingInfoResolver) voteNo(weight int64, votedHeight int64, votedAt int64) error {
	return v.vote(false, weight, votedHeight, votedAt)
}

// vote records a vote with the specified choice, weight, and timing information.
// This is the core voting method that prevents double voting and records all vote details.
//
// Parameters:
//   - votedYes: true for "yes" vote, false for "no" vote
//   - weight: voting weight to use for this vote
//   - votedHeight: block height when vote is cast
//   - votedAt: timestamp when vote is cast
//
// Returns:
//   - error: voting error if user has already voted
func (v *VotingInfoResolver) vote(votedYes bool, weight int64, votedHeight int64, votedAt int64) error {
	// Prevent double voting - each user can only vote once per proposal
	if v.IsVoted() {
		return errAlreadyVoted
	}

	// Record all voting details
	v.SetVotedWeight(weight)
	v.SetVotedHeight(votedHeight)
	v.SetVotedAt(votedAt)
	v.SetVoted(true)
	v.SetVotedYes(votedYes)

	return nil
}
