package governance

// assertCallerIsProposer panics if the caller is not the proposer of the given proposal.
func assertCallerIsProposer(proposalID int64, caller address) {
	proposal, exists := getProposal(proposalID)
	if !exists {
		panic(errProposalNotFound)
	}

	if !proposal.IsProposer(caller) {
		panic(errNotProposer)
	}
}
