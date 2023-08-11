package gov

func init() {
	proposals = avl.NewWithIntComparator()
	proposalQueue = avl.NewWithStringComparator()
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

var proposalQueue *avl.Tree // ({Deposit, Voting}EndTime | ProposalID) => ProposalID

var votersMap *avl.Tree // Address => Map[ProposalID]Vote

// retrieves proposal state by ID
func GetProposal(proposalID uint64) *Proposal {
	if proposals == nil {
		panic("Bug: gov.getProposal() called before gov.init()")
	}

	proposalInterface, ok := proposals.Get(proposalID)
	if !ok {
		return nil
	}

	proposal := proposalInterface.(*Proposal)

	return proposal
}

func proposalQueueKey(endtime uint64, proposalID uint64) string {
	return fmt.Sprintf("%020d:%020d", endtime, proposalID)
}

// sets proposal by ID, and updates the queue accordingly
func setProposal(proposalID uint64, proposalState ProposalState) {
	proposals.Set(proposalID, proposalState)
	
	if proposalState.Proposal.Status == ProposalStatusDepositPeriod {
		proposalQueue.Put(proposalQueueKey(proposalState.Proposal.DepositEndTime, proposalID), proposalID)
		return
	} 
	
	if proposalState.Proposal.Status == ProposalStatusVotingPeriod {
		proposalQueue.Put(proposalQueueKey(proposalState.Proposal.VotingEndTime, proposalID), proposalID)
		return
	}	

	// proposal is not in deposit or voting period, either rejected or failed to pass deposit period
	// no need to update queue
}

func updateVote(proposalID uint64, address string, option VoteOption, power bigint) {
	vote := Vote{option, power}
	oldVote, ok := p.Voters.Get(address)
	if !ok {
		oldVote = Vote{VoteNil, bigint(0)}
	}
	p.Proposal.updateVotingPower(oldVote.Power, vote.Power)
	p.Voters.Put(address, vote)
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