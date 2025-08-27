package governance

// ProposalVoteStatus tracks the voting tallies and requirements for a proposal.
// This structure manages vote counting, quorum calculation, and voting outcome determination.
type ProposalVoteStatus struct {
	yea             int64 // Total weight of "yes" votes collected
	nay             int64 // Total weight of "no" votes collected
	maxVotingWeight int64 // The max voting weight at the time of proposal creation
	quorumAmount    int64 // How many total votes must be collected for the proposal to be valid
}

// TotalVoteWeight returns the total weight of all votes cast (yes + no).
//
// Returns:
//   - int64: combined weight of all votes
func (p *ProposalVoteStatus) TotalVoteWeight() int64 {
	return p.yea + p.nay
}

// DiffVoteWeight returns the absolute difference between yes and no votes.
// This can be used to determine the margin of victory or defeat.
//
// Returns:
//   - int64: absolute difference between yes and no vote weights
func (p *ProposalVoteStatus) DiffVoteWeight() int64 {
	if p.yea > p.nay {
		return p.yea - p.nay
	}

	return p.nay - p.yea
}

// YesWeight returns the total weight of "yes" votes.
//
// Returns:
//   - int64: total "yes" vote weight
func (p *ProposalVoteStatus) YesWeight() int64 {
	return p.yea
}

// NoWeight returns the total weight of "no" votes.
//
// Returns:
//   - int64: total "no" vote weight
func (p *ProposalVoteStatus) NoWeight() int64 {
	return p.nay
}

// IsVotingFinished determines if voting has effectively ended due to mathematical impossibility
// of changing the outcome. This happens when the remaining uncast votes cannot change the result.
//
// Returns:
//   - bool: true if voting outcome is mathematically determined
func (p *ProposalVoteStatus) IsVotingFinished() bool {
	totalVotes := p.TotalVoteWeight()

	// If we haven't reached quorum yet, voting is not finished
	if totalVotes < p.quorumAmount {
		return false
	}

	// Calculate remaining votes that could still be cast
	remainingVotes := p.maxVotingWeight - totalVotes

	// If the difference between yes/no is greater than remaining votes,
	// the outcome cannot change, so voting is effectively finished
	return remainingVotes-p.DiffVoteWeight() <= 0
}

// IsRejected determines if the proposal has been rejected by voting.
// A proposal is rejected if voting is finished and it did not pass.
//
// Returns:
//   - bool: true if proposal has been rejected
func (p *ProposalVoteStatus) IsRejected() bool {
	// Only consider rejection if voting is finished
	if !p.IsVotingFinished() {
		return false
	}

	// Proposal is rejected if it didn't pass
	return !p.IsPassed()
}

// IsPassed determines if the proposal has passed the voting requirements.
// A proposal passes if it receives at least the quorum amount of "yes" votes.
//
// Returns:
//   - bool: true if proposal has passed
func (p *ProposalVoteStatus) IsPassed() bool {
	return p.yea >= p.quorumAmount
}

// addYesVoteWeight adds the specified weight to the "yes" vote tally.
// This is called when a user votes "yes" on the proposal.
//
// Parameters:
//   - yea: vote weight to add to "yes" votes
//
// Returns:
//   - error: always nil (reserved for future validation)
func (p *ProposalVoteStatus) addYesVoteWeight(yea int64) error {
	p.yea += yea

	return nil
}

// addNoVoteWeight adds the specified weight to the "no" vote tally.
// This is called when a user votes "no" on the proposal.
//
// Parameters:
//   - nay: vote weight to add to "no" votes
//
// Returns:
//   - error: always nil (reserved for future validation)
func (p *ProposalVoteStatus) addNoVoteWeight(nay int64) error {
	p.nay += nay

	return nil
}

// updateVoteStatus updates the voting parameters and recalculates the quorum requirement.
// This can be used if voting parameters change dynamically.
//
// Parameters:
//   - maxVotingWeight: updated maximum voting weight
//   - quorum: updated quorum percentage
//
// Returns:
//   - error: always nil (reserved for future validation)
func (p *ProposalVoteStatus) updateVoteStatus(maxVotingWeight, quorum int64) error {
	// Update maximum voting weight
	p.maxVotingWeight = maxVotingWeight

	// Recalculate quorum amount based on new parameters
	p.quorumAmount = maxVotingWeight * quorum / 100

	return nil
}

// NewProposalVoteStatus creates a new vote status for a proposal.
// Initializes vote tallies to zero and calculates the quorum requirement.
//
// Parameters:
//   - maxVotingWeight: maximum possible voting weight for this proposal
//   - quorum: quorum percentage required for passage (0-100)
//
// Returns:
//   - *ProposalVoteStatus: new vote status instance
func NewProposalVoteStatus(
	maxVotingWeight int64,
	quorum int64,
) *ProposalVoteStatus {
	// Calculate the absolute vote weight needed to meet quorum
	quorumAmount := maxVotingWeight * quorum / 100

	return &ProposalVoteStatus{
		yea:             0,               // Start with no "yes" votes
		nay:             0,               // Start with no "no" votes
		maxVotingWeight: maxVotingWeight, // Set maximum possible votes
		quorumAmount:    quorumAmount,    // Set required votes for passage
	}
}
