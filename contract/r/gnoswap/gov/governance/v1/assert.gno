package governance

import (
	"errors"

	ufmt "gno.land/p/nt/ufmt/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/halt/v1"

	"gno.land/r/gnoswap/gov/governance"
)

// assertIsNotHaltedGovernanceForProposalData panics if governance is halted,
// unless the proposal only targets the halt realm.
// This keeps a recovery path open so governance can unhalt itself.
func assertIsNotHaltedGovernanceForProposalData(proposalData *governance.ProposalData) {
	if isHaltRecoveryProposalData(proposalData) {
		return
	}

	halt.AssertIsNotHaltedGovernance()
}

// assertIsNotHaltedGovernanceForProposal panics if governance is halted,
// unless the proposal only targets the halt realm.
func assertIsNotHaltedGovernanceForProposal(gv *governanceV1, proposalID int64) {
	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		halt.AssertIsNotHaltedGovernance()
		return
	}

	assertIsNotHaltedGovernanceForProposalData(proposal.Data())
}

// isHaltRecoveryProposalData returns true if the proposal is a parameter change
// whose every execution targets the halt realm.
func isHaltRecoveryProposalData(proposalData *governance.ProposalData) bool {
	if proposalData == nil || proposalData.ProposalType() != governance.ParameterChange {
		return false
	}

	infos, err := NewProposalDataResolver(proposalData).ParameterChangesInfos()
	if err != nil || len(infos) == 0 {
		return false
	}

	for _, info := range infos {
		if info.PkgPath() != HALT_PATH {
			return false
		}
	}

	return true
}

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
