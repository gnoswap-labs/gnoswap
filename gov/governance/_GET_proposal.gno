package governance

import (
	"gno.land/p/demo/ufmt"
)

func GetProposerByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetProposerByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.Proposer.String()
}

func GetProposalTypeByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetProposalTypeByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.ProposalType
}

func GetYeaByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetYeaByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.Yea.ToString()
}

func GetNayByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetNayByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.Nay.ToString()
}

func GetConfigVersionByProposalId(proposalId uint64) uint64 {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetConfigVersionByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.ConfigVersion
}

func GetQuorumAmountByProposalId(proposalId uint64) uint64 {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetQuorumAmountByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.QuorumAmount
}

func GetTitleByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetTitleByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.Title
}

func GetDescriptionByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetDescriptionByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.Description
}

func GetExecutionStateByProposalId(proposalId uint64) ExecutionState {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("_GET_proposal.gno__GetExecutionStateByProposalId() || proposalId(%d) not found", proposalId),
		))
	}

	return proposal.ExecutionState
}
