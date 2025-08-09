package governance

import "std"

// assertCallerIsProposer panics if the caller is not the proposer of the given proposal.
func assertCallerIsProposer(proposalID int64, caller std.Address) {
	proposal, exists := getProposal(proposalID)
	if !exists {
		panic(errProposalNotFound)
	}

	if !proposal.IsProposer(caller) {
		panic(errNotProposer)
	}
}
