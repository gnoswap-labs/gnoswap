package governance

import "std"

func assertCallerIsProposer(proposalID int64, caller std.Address) {
	proposal, exists := getProposal(proposalID)
	if !exists {
		panic(errProposalNotFound)
	}

	if !proposal.IsProposer(caller) {
		panic(errNotProposer)
	}
}
