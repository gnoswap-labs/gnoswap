package v1

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"
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
	return gnsmath.SafeAddInt64(p.YesWeight(), p.NoWeight())
}

// IsPassed determines if the proposal has passed the voting requirements.
// A proposal passes when quorum is reached and "yes" votes strictly exceed "no" votes.
func (p *ProposalVoteStatusResolver) IsPassed() bool {
	if p.TotalVoteWeight() < p.QuorumAmount() {
		return false
	}

	return p.YesWeight() > p.NoWeight()
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
	p.SetYesWeight(gnsmath.SafeAddInt64(p.YesWeight(), yea))
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
	p.SetNoWeight(gnsmath.SafeAddInt64(p.NoWeight(), nay))
	return nil
}
