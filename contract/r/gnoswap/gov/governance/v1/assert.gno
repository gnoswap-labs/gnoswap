package v1

import (
    "gno.land/p/nt/ufmt"
    "gno.land/r/gnoswap/common"
)

// assertCallerIsProposer panics if the caller is not the proposer of the given proposal.
func assertCallerIsProposer(gv *governanceV1, proposalID int64, caller address) {
	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		panic(errProposalNotFound)
	}

	if !proposal.IsProposer(caller) {
		panic(errNotProposer)
	}
}

func assertIsValidToken(tokenPath string) {
    if tokenPath == "" {
		panic(makeErrorWithDetails(
			errInvalidInput, "tokenPath is empty"))
	}

	if err := common.IsRegistered(tokenPath); err != nil {
		panic(makeErrorWithDetails(
			errInvalidInput,
			ufmt.Sprintf("token(%s) is not registered", tokenPath),
		))
	}
}
