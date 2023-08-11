package gov

type VoteOption uint8 

const (
	VoteNil VoteOption = iota
	VoteAbstain
	VoteNo
	VoteYes
)

type Vote struct {
	VoteOption VoteOption
	Power    bigint
}

func (p *Proposal) vote(caller Address, option VoteOption, amount bigint) {
	if p == nil {
		panic("Proposal.vote() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("Proposal.vote() called on a proposal not in voting period")
	}

	vote := Vote{option, amount}

	oldVote, ok := p.Voters.Get(caller)
	if !ok {
		oldVote = Vote{VoteNil, bigint(0)}
	}

	p.updateVote(oldVote, vote)

	proposalVotes, ok := proposalVotesMap.Get(p.ID)
	if !ok {
		proposalVotes = avl.NewTree()
	}

	proposalVotes.Put(caller, vote)
	proposalVotersMap.Set(p.ID, proposalVotes)

	votes, ok := votersMap.Get(newVote.Address)
	if !ok {
		voters = avl.NewTree()
	}
	votes.Put(p.ID, vote)
}

func (p Proposal) isVotingPeriod() bool {
	return p.Status == ProposalStatusVotingPeriod
}

// checks if the vote have met the pass condition
// this does not mean the proposal has passed, as the voting period may not have ended yet.
//
// returns true if:
// - proposal is in voting period
// - (YesVotes+NoVotes)/totalVotingPower >= VoteQuorumNumerator/VoteQuorumDenominator
// - YesVotes > NoVotes
func (p Proposal) isPassConditionMet(totalVotingPower bigint) bool {
	return p.isVotingPeriod() && p.YesVotes > p.NoVotes && p.YesVotes+p.NoVotes >= getVoteQuorumNumerator()*totalVotingPower/getVoteQuorumDenominator()
}

// checks if proposal has passed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns true
func (p Proposal) isVotingPassed() bool {
	return p.isVotingPeriod() && std.GetBlockTime() > p.VotingEndTime && p.isPassConditionMet()	
}

// checks if proposal has failed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns false
func (p Proposal) isVotingRejected() bool {
	return p.isVotingPeriod() && std.GetBlockTime() > p.VotingEndTime && !p.isPassConditionMet()
}

func (p *Proposal) updateVotingPower(oldPower bigint, newPower bigint) {
	if p == nil {
		panic("Bug: Proposal.updateVotingPower() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("Bug: Proposal.updateVotingPower() called on a proposal not in voting period")
	}

	p.TotalVotingPower += newPower - oldPower
}

func (p *Proposal) updateVote(oldVote Vote, newVote Vote) {
	if p == nil {
		panic("Bug: Proposal.updateVotingPower() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("Bug: Proposal.updateVotingPower() called on a proposal not in voting period")
	}

	switch oldVote.VoteOption {
	case VoteNil:
		break
	case VoteAbstain:
		p.AbstainVotes -= oldVote.Power
	case VoteNo:
		p.NoVotes -= oldVote.Power
	case VoteYes:
		p.YesVotes -= oldVote.Power
	}

	switch newVote.VoteOption {
	case VoteNil:
		panic("Bug: Proposal.updateVotingPower() called with a new vote of type VoteNil")
	case VoteAbstain:
		p.AbstainVotes += newVote.Power
	case VoteNo:
		p.NoVotes += newVote.Power
	case VoteYes:
		p.YesVotes += newVote.Power
	}

}

