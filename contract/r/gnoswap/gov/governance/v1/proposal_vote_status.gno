package governance

import (
	gnsmath "gno.land/p/gnoswap/gnsmath"

	"gno.land/r/gnoswap/gov/governance"
)

type ProposalVoteStatusResolver struct {
	status governance.ProposalVoteStatus
}

func MakeProposalVoteStatusResolver(status governance.ProposalVoteStatus) ProposalVoteStatusResolver {
	return ProposalVoteStatusResolver{status: status}
}

func (p ProposalVoteStatusResolver) Value() governance.ProposalVoteStatus {
	return p.status
}

func (p ProposalVoteStatusResolver) MaxVotingWeight() int64 {
	return p.status.MaxVotingWeight()
}

func (p ProposalVoteStatusResolver) QuorumAmount() int64 {
	return p.status.QuorumAmount()
}

func (p ProposalVoteStatusResolver) YesWeight() int64 {
	return p.status.YesWeight()
}

func (p ProposalVoteStatusResolver) NoWeight() int64 {
	return p.status.NoWeight()
}

// TotalVoteWeight returns the total weight of all votes cast (yes + no).
func (p ProposalVoteStatusResolver) TotalVoteWeight() int64 {
	return gnsmath.SafeAddInt64(p.status.YesWeight(), p.status.NoWeight())
}

// IsPassed determines if quorum is reached and yes votes exceed no votes.
func (p ProposalVoteStatusResolver) IsPassed() bool {
	if p.TotalVoteWeight() < p.status.QuorumAmount() {
		return false
	}
	return p.status.YesWeight() > p.status.NoWeight()
}

// AddYesVoteWeight returns a resolver with the updated yes tally.
func (p ProposalVoteStatusResolver) AddYesVoteWeight(yea int64) (ProposalVoteStatusResolver, error) {
	p.status = p.status.SetYesWeight(gnsmath.SafeAddInt64(p.status.YesWeight(), yea))
	return p, nil
}

// AddNoVoteWeight returns a resolver with the updated no tally.
func (p ProposalVoteStatusResolver) AddNoVoteWeight(nay int64) (ProposalVoteStatusResolver, error) {
	p.status = p.status.SetNoWeight(gnsmath.SafeAddInt64(p.status.NoWeight(), nay))
	return p, nil
}
