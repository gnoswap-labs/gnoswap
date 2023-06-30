package gov

type ProposalState struct {
	Proposal Proposal
	Voters *avl.Tree // Map[Address]Vote
}

var proposals *avl.Tree // ProposalID => ProposalState

var proposalQueue *avl.Tree // ({Deposit, Voting}EndTime | ProposalID) => ProposalID

var voters *avl.Tree // Address => Map[ProposalID]Vote

func init() {
	proposals = avl.NewWithIntComparator()
	proposalQueue = avl.NewWithStringComparator()
}

// retrieves proposal by ID
func getProposal(proposalID uint64) *ProposalState {
	panic("unimplemented")
}

// peeks the earlist(either by deposit end time or voting end time, depending on the proposal status) proposal from the queue
func peekProposalQueue() (uint64, uint64) {
	panic("unimplemented")
}

// sets proposal by ID, and updates the queue accordingly
func setProposal(proposalID uint64, proposalState ProposalState) {
	panic("unimplemented")
}