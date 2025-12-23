package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalVoteStatusResolver struct {
	*governance.ProposalVoteStatus
}

func NewProposalVoteStatusResolver(voteStatus *governance.ProposalVoteStatus) *ProposalVoteStatusResolver {
	return &ProposalVoteStatusResolver{voteStatus}
}

// TotalVoteWeight returns the total weight of all votes cast (yes + no).
//
// Returns:
//   - int64: combined weight of all votes
func (p *ProposalVoteStatusResolver) TotalVoteWeight() int64 {
	return safeAddInt64(p.YesWeight(), p.NoWeight())
}

// DiffVoteWeight returns the absolute difference between yes and no votes.
// This can be used to determine the margin of victory or defeat.
//
// Returns:
//   - int64: absolute difference between yes and no vote weights
func (p *ProposalVoteStatusResolver) DiffVoteWeight() int64 {
	yes := p.YesWeight()
	no := p.NoWeight()
	if yes > no {
		return safeSubInt64(yes, no)
	}

	return safeSubInt64(no, yes)
}

// IsVotingFinished determines if voting has effectively ended due to mathematical impossibility
// of changing the outcome. This happens when the remaining uncast votes cannot change the result.
//
// Returns:
//   - bool: true if voting outcome is mathematically determined
func (p *ProposalVoteStatusResolver) IsVotingFinished() bool {
	totalVotes := p.TotalVoteWeight()

	// If we haven't reached quorum yet, voting is not finished
	if totalVotes < p.QuorumAmount() {
		return false
	}

	// Calculate remaining votes that could still be cast
	remainingVotes := safeSubInt64(p.MaxVotingWeight(), totalVotes)

	// If the difference between yes/no is greater than remaining votes,
	// the outcome cannot change, so voting is effectively finished
	return safeSubInt64(remainingVotes, p.DiffVoteWeight()) <= 0
}

// IsRejected determines if the proposal has been rejected by voting.
// A proposal is rejected if voting is finished and it did not pass.
//
// Returns:
//   - bool: true if proposal has been rejected
func (p *ProposalVoteStatusResolver) IsRejected() bool {
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
func (p *ProposalVoteStatusResolver) IsPassed() bool {
	return p.YesWeight() >= p.QuorumAmount()
}

// addYesVoteWeight adds the specified weight to the "yes" vote tally.
// This is called when a user votes "yes" on the proposal.
//
// Parameters:
//   - yea: vote weight to add to "yes" votes
//
// Returns:
//   - error: always nil (reserved for future validation)
func (p *ProposalVoteStatusResolver) AddYesVoteWeight(yea int64) error {
	p.SetYesWeight(safeAddInt64(p.YesWeight(), yea))
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
func (p *ProposalVoteStatusResolver) AddNoVoteWeight(nay int64) error {
	p.SetNoWeight(safeAddInt64(p.NoWeight(), nay))
	return nil
}
