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

var proposals *avl.Tree // ProposalID => ProposalState

var proposalQueue *avl.Tree // ({Deposit, Voting}EndTime | ProposalID) => ProposalID

var voters *avl.Tree // Address => Map[ProposalID]Vote

// retrieves proposal state by ID
func getProposalState(proposalID uint64) *ProposalState {
	if proposals == nil {
		panic("Bug: gov.getProposal() called before gov.init()")
	}

	proposal, ok := proposals.Get(proposalID)
	if !ok {
		return nil
	}

	return proposal.(*ProposalState)
}

func proposalQueueKey(endtime uint64, proposalID uint64) string {
	return fmt.Sprintf("%020d:%020d", endtime, proposalID)
}

// peeks the earlist(either by deposit end time or voting end time, depending on the proposal status) proposal from the queue
func peekProposalQueue() *uint64 {
	if proposalQueue == nil {
		panic("Bug: gov.peekProposalQueue() called before gov.init()")
	}

	if proposalQueue.Size() == 0 {
		return nil
	}

	_, proposalID := proposalQueue.Iterate()
	return &proposalID
}

func popProposalQueue(id uint64) {
	if proposalQueue == nil {
		panic("Bug: gov.popProposalQueue() called before gov.init()")
	}

	first := proposalQueue.Iterate()
	if first == nil {
		panic("Bug: gov.popProposalQueue() called on an empty queue")
	}

	_, proposalID := first.(string)
	if proposalID != id {
		panic("Bug: gov.popProposalQueue() called on a non-first proposal")
	}

	proposalQueue.Remove(first.Key)
}

// sets proposal by ID, and updates the queue accordingly
func setProposal(proposalID uint64, proposalState ProposalState) {
	
}


type ProposalState struct {
	Proposal Proposal
	Voters *avl.Tree // Map[Address]Vote
}

func (p *ProposalState) createVote(address string, option VoteOption, power bigint) {
	vote := Vote{option, power}
	p.Voters.Put(address, vote)
	p.Proposal.setVotingPower(vote.Power)
	voters.Put(address, p.Proposal.ID)
}

func (p *ProposalState) updateVote(address string, option VoteOption, power bigint) {
	vote := Vote{option, power}
	oldVote, ok := p.Voters.Get(address)
	if !ok {
		panic("Bug: ProposalState.updateVote() called on a non-existent voter")
	}
	p.Proposal.updateVotingPower(oldVote.Power, vote.Power)
	p.Voters.Put(address, vote)
}

// panics if proposal is not in voting period
// if the vote type is the same with the existing vote, no-op.
// otherwise, the {Yes, No, Abstain}Votes of the proposal is updated accordingly with the voter's power.
func (p *ProposalState) vote(address string, option VoteOption) {
	if p == nil {
		panic("ProposalState.vote() called on a nil proposal")
	}

	if !p.isVotingPeriod() {
		panic("ProposalState.vote() called on a proposal not in voting period")
	}

	// p.Voters should never be nil
	if p.voters == nil { 
		panic("Bug: ProposalState.Voters is nil")
	}

	vote, ok := p.Voters.Get(address)
	if !ok {

	}


}

// panics if proposal is not in deposit period or the depositor does not have enough balance
func (p *ProposalState) deposit(address string, amount uint64) {

}