package v2

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

func assertIsValidSmoothingPeriod(smoothingPeriod int64) {
	if smoothingPeriod < 0 {
		panic(errInvalidSmoothingPeriod)
	}

	if smoothingPeriod > maxSmoothingPeriod {
		panic(errInvalidSmoothingPeriod)
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
