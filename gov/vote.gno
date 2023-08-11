package gov

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
)

type VoteOption uint8 

const (
	VoteNil VoteOption = iota
	VoteAbstain
	VoteNo
	VoteYes
)

type Vote struct {
	VoteOption VoteOption
	Power    uint64
}

func (p *Proposal) vote(caller std.Address, option VoteOption, amount uint64) {
	if p == nil {
		panic("Proposal.vote() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("Proposal.vote() called on a proposal not in voting period")
	}

	vote := Vote{option, amount}

	proposalVotesInterface, ok := proposalVotesMap.Get(proposalKey(p.ProposalID))
	if !ok {
		proposalVotesInterface = avl.NewTree()
	}

	proposalVotes := proposalVotesInterface.(*avl.Tree)

	oldVoteInterface, ok := proposalVotes.Get(string(caller))
	if !ok {
		oldVoteInterface = Vote{VoteNil, uint64(0)}
	}

	oldVote := oldVoteInterface.(Vote)

	p.updateVote(oldVote, vote)

	proposalVotes.Set(string(caller), vote)
	proposalVotesMap.Set(proposalKey(p.ProposalID), proposalVotes)

	votesInterface, ok := votersMap.Get(string(caller))
	if !ok {
		votesInterface = avl.NewTree()
	}
	votes := votesInterface.(*avl.Tree)
	votes.Set(proposalKey(p.ProposalID), vote)
}

func (p Proposal) isVotingPeriod() bool {
	return p.ProposalStatus == ProposalStatusVotingPeriod
}

// checks if the vote have met the pass condition
// this does not mean the proposal has passed, as the voting period may not have ended yet.
//
// returns true if:
// - proposal is in voting period
// - (YesVotes+NoVotes)/totalVotingPower >= VoteQuorumNumerator/VoteQuorumDenominator
// - YesVotes > NoVotes
func (p Proposal) isPassConditionMet(totalVotingPower uint64) bool {
	quorum := getVoteQuorum()
	return p.isVotingPeriod() && p.YesVotes > p.NoVotes && p.YesVotes+p.NoVotes >= quorum.Numerator*totalVotingPower/quorum.Denominator
}

// checks if proposal has passed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns true
func (p Proposal) isVotingPassed() bool {
	return p.isVotingPeriod() && uint64(time.Now().Unix()) > p.VotingEndTime && p.isPassConditionMet(1 /*TODO*/)	
}

// checks if proposal has failed
// returns true if:
// - proposal is in voting period
// - VotingEndTime has passed
// - proposal.isPassConditionMet() returns false
func (p Proposal) isVotingRejected() bool {
	return p.isVotingPeriod() && uint64(time.Now().Unix()) > p.VotingEndTime && !p.isPassConditionMet(1 /*TODO*/)
}

func (p *Proposal) updateVotingPower(option VoteOption, oldPower uint64, newPower uint64) {
	if p == nil {
		panic("Bug: Proposal.updateVotingPower() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("Bug: Proposal.updateVotingPower() called on a proposal not in voting period")
	}

	switch option {
	case VoteNil:
		break
	case VoteAbstain:
		p.AbstainVotes -= oldPower
		p.AbstainVotes += newPower
	case VoteNo:
		p.NoVotes -= oldPower
		p.NoVotes += newPower
	case VoteYes:
		p.YesVotes -= oldPower
		p.YesVotes += newPower
	}
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

