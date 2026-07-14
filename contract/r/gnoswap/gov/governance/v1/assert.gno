package v1

import (
	"errors"
	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
)

// assertCallerIsProposer panics if the caller is not the proposer of the given proposal.
func assertCallerIsProposer(gv *governanceV1, proposalID int64, caller address) {
	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		panic(errors.New(errProposalNotFound))
	}

	if !proposal.IsProposer(caller) {
		panic(errors.New(errNotProposer))
	}
}

func assertIsValidSmoothingPeriod(smoothingPeriod int64) {
	if smoothingPeriod < 0 {
		panic(errors.New(errInvalidSmoothingPeriod))
	}

	if smoothingPeriod > maxSmoothingPeriod {
		panic(errors.New(errInvalidSmoothingPeriod))
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
