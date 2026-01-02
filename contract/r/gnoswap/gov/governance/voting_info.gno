package governance

// VotingInfo tracks voting-related information for a specific user on a specific proposal.
// This structure maintains the user's voting eligibility, voting history, and voting power.
type VotingInfo struct {
	availableVoteWeight int64   // Total voting weight available to this user for this proposal
	votedWeight         int64   // Actual weight used when voting (0 if not voted)
	votedHeight         int64   // Block height when vote was cast
	votedAt             int64   // Timestamp when vote was cast
	votedYes            bool    // True if voted "yes", false if voted "no"
	voted               bool    // True if user has already voted
}

// NewVotingInfo creates a new voting information structure for a user.
// This constructor initializes the voting eligibility based on delegation snapshots.
//
// Parameters:
//   - availableVoteWeight: total voting weight available to this user
//
// Returns:
//   - *VotingInfo: newly created voting information structure
func NewVotingInfo(availableVoteWeight int64) *VotingInfo {
	return &VotingInfo{
		availableVoteWeight: availableVoteWeight,
		// Other fields are initialized to zero values (false, 0)
		// voted starts as false, indicating no vote has been cast
	}
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

// VotedHeight returns the block height when the vote was cast.
// Returns 0 if the user hasn't voted yet.
//
// Returns:
//   - int64: block height when vote was cast
func (v *VotingInfo) VotedHeight() int64 {
	if !v.voted {
		return 0
	}

	return v.votedHeight
}

// VotedAt returns the timestamp when the vote was cast.
// Returns 0 if the user hasn't voted yet.
//
// Returns:
//   - int64: timestamp when vote was cast
func (v *VotingInfo) VotedAt() int64 {
	if !v.voted {
		return 0
	}

	return v.votedAt
}

/* Setter methods */
func (v *VotingInfo) SetAvailableVoteWeight(availableVoteWeight int64) {
	v.availableVoteWeight = availableVoteWeight
}

func (v *VotingInfo) SetVotedWeight(votedWeight int64) {
	v.votedWeight = votedWeight
}

func (v *VotingInfo) SetVotedHeight(votedHeight int64) {
	v.votedHeight = votedHeight
}

func (v *VotingInfo) SetVotedAt(votedAt int64) {
	v.votedAt = votedAt
}

func (v *VotingInfo) SetVotedYes(votedYes bool) {
	v.votedYes = votedYes
}

func (v *VotingInfo) SetVoted(voted bool) {
	v.voted = voted
}
