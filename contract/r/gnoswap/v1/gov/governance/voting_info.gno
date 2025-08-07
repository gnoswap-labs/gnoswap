package governance

import (
	"std"
)

// VotingInfo tracks voting-related information for a specific user on a specific proposal.
// This structure maintains the user's voting eligibility, voting history, and voting power.
type VotingInfo struct {
	voterAddress        std.Address // Address of the voter
	availableVoteWeight int64       // Total voting weight available to this user for this proposal
	votedWeight         int64       // Actual weight used when voting (0 if not voted)
	votedHeight         int64       // Block height when vote was cast
	votedAt             int64       // Timestamp when vote was cast
	votedYes            bool        // True if voted "yes", false if voted "no"
	voted               bool        // True if user has already voted
}

// VotingType returns a human-readable string representation of the vote choice.
//
// Returns:
//   - string: "yes" or "no" based on voting choice
func (v *VotingInfo) VotingType() string {
	if v.votedYes {
		return "yes"
	}

	return "no"
}

// IsVoted checks if the user has already cast their vote.
//
// Returns:
//   - bool: true if user has voted on this proposal
func (v *VotingInfo) IsVoted() bool {
	return v.voted
}

// VotedYes checks if the user voted "yes" on the proposal.
// Only meaningful if IsVoted() returns true.
//
// Returns:
//   - bool: true if user voted "yes"
func (v *VotingInfo) VotedYes() bool {
	return v.votedYes
}

// VotedNo checks if the user voted "no" on the proposal.
// Only meaningful if IsVoted() returns true.
//
// Returns:
//   - bool: true if user voted "no"
func (v *VotingInfo) VotedNo() bool {
	return !v.votedYes
}

// AvailableVoteWeight returns the total voting weight available to this user.
// This weight is determined at proposal creation time based on delegation snapshots.
//
// Returns:
//   - int64: available voting weight
func (v *VotingInfo) AvailableVoteWeight() int64 {
	return v.availableVoteWeight
}

// VotedWeight returns the weight actually used when voting.
// Returns 0 if the user hasn't voted yet.
//
// Returns:
//   - int64: weight used for voting, or 0 if not voted
func (v *VotingInfo) VotedWeight() int64 {
	if !v.voted {
		return 0
	}

	return v.votedWeight
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
func (v *VotingInfo) voteYes(weight int64, votedHeight int64, votedAt int64) error {
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
func (v *VotingInfo) voteNo(weight int64, votedHeight int64, votedAt int64) error {
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
func (v *VotingInfo) vote(votedYes bool, weight int64, votedHeight int64, votedAt int64) error {
	// Prevent double voting - each user can only vote once per proposal
	if v.voted {
		return errAlreadyVoted
	}

	// Record all voting details
	v.votedWeight = weight
	v.votedHeight = votedHeight
	v.votedAt = votedAt
	v.voted = true
	v.votedYes = votedYes

	return nil
}

// NewVotingInfo creates a new voting information structure for a user.
// This constructor initializes the voting eligibility based on delegation snapshots.
//
// Parameters:
//   - availableVoteWeight: total voting weight available to this user
//   - voterAddress: address of the voter
//
// Returns:
//   - *VotingInfo: newly created voting information structure
func NewVotingInfo(availableVoteWeight int64, voterAddress std.Address) *VotingInfo {
	return &VotingInfo{
		availableVoteWeight: availableVoteWeight,
		voterAddress:        voterAddress,
		// Other fields are initialized to zero values (false, 0)
		// voted starts as false, indicating no vote has been cast
	}
}
