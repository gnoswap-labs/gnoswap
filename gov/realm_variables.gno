package gov

import (
	"fmt"

	"gno.land/p/demo/avl"
)

func init() {
	proposals = avl.NewTree()
	proposalDepositsMap = avl.NewTree()
	proposalVotesMap = avl.NewTree()
	votersMap = avl.NewTree()
}

var nextProposalID uint64 = 1

func getNextProposalID() uint64 {
	id := nextProposalID
	nextProposalID++
	return id
}

var proposals *avl.Tree // ProposalID => Proposal

var proposalDepositsMap *avl.Tree // ProposalID => []Deposit

var proposalVotesMap *avl.Tree // ProposalID => Map[Address]Vote

var votersMap *avl.Tree // Address => Map[ProposalID]Vote

// retrieves proposal state by ID
func GetProposal(proposalID uint64) *Proposal {
	if proposals == nil {
		panic("Bug: gov.getProposal() called before gov.init()")
	}

	proposalInterface, ok := proposals.Get(proposalKey(proposalID))
	if !ok {
		return nil
	}

	proposal := proposalInterface.(Proposal)

	return &proposal
}

func proposalKey(proposalID uint64) string {
	return fmt.Sprintf("%020d", proposalID)
}

// sets proposal by ID, and updates the queue accordingly
func setProposal(proposal *Proposal) {
	proposals.Set(proposalKey(proposal.ProposalID), *proposal)
}

func updateVote(proposalID uint64, address string, option VoteOption, power uint64) {
	proposalInterface, ok := proposals.Get(proposalKey(proposalID))
	if !ok {
		panic("Bug: proposal is not retrievable from proposals")
	}
	p := proposalInterface.(*Proposal)
	vote := Vote{option, power}
	proposalVotesInterface, ok := proposalVotesMap.Get(proposalKey(proposalID))
	if !ok {
		panic("Bug: proposal is not retrievable from proposalVotesMap")
	}
	proposalVotes := proposalVotesInterface.(*avl.Tree)
	oldVoteInterface, ok := proposalVotes.Get(address)
	if !ok {
		oldVoteInterface = Vote{VoteNil, bigint(0)}
	}
	oldVote := oldVoteInterface.(Vote)
	p.updateVotingPower(oldVote.VoteOption, oldVote.Power, vote.Power)
	proposalVotes.Set(address, vote)
	proposalVotesMap.Set(proposalKey(proposalID), proposalVotes)
}

/*
// panics if proposal is not in voting period
// if the vote type is the same with the existing vote, no-op.
// otherwise, the {Yes, No, Abstain}Votes of the proposal is updated accordingly with the voter's power.
func vote(proposalID uint64, address string, option VoteOption) {	
	if p == nil {
		panic("ProposalState.vote() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("ProposalState.vote() called on a proposal not in voting period")
	}

	proposalVoters, ok := proposalVotersMap.Get(proposalID)
	if !ok {
		panic("Bug: ProposalState.Voters is nil")
	}

	vote, ok := p.Voters.Get(address)
	if !ok {
		// new voter, add to voters map and increase the total voting power
		p.updateVotingPower(bigint(0), power)

	}

}
*/