package gov

var (
	proposalsMap        map[uint64]Proposal        = make(map[uint64]Proposal)        // proposalID -> Proposal
	proposalDepositsMap map[uint64][]Deposit       = make(map[uint64][]Deposit)       // proposalID -> []Deposit
	proposalVotesMap    map[uint64]map[string]Vote = make(map[uint64]map[string]Vote) // proposalID -> address -> Vote
	votersMap           map[string]map[uint64]Vote = make(map[string]map[uint64]Vote) // address -> proposalID -> Vote

	nextProposalID uint64 = 1
)

func getNextProposalID() uint64 {
	id := nextProposalID
	nextProposalID++
	return id
}

func updateVote(proposalID uint64, address string, option VoteOption, power uint64) {
	proposal := &proposalsMap[proposalID]
	proposalVotes := proposalVotesMap[proposalID]
	oldVote := proposalVotes[address]

	vote := Vote{option, power}

	proposal.updateVotingPower(oldVote.VoteOption, oldVote.Power, vote.Power)

	proposalVotes[address] = vote
	proposalVotesMap[proposalID] = proposalVotes
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
