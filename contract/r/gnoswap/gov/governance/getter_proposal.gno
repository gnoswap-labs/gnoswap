package governance

import "time"

func GetProposerByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Proposer.String()
}

func GetProposalTypeByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Data.ProposalType.String()
}

func GetYeaByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Voting.Yea.ToString()
}

func GetNayByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Voting.Nay.ToString()
}

func GetConfigVersionByProposalId(proposalId uint64) uint64 {
	return mustGetProposal(proposalId).ConfigVersion
}

func GetQuorumAmountByProposalId(proposalId uint64) uint64 {
	return mustGetProposal(proposalId).Voting.QuorumAmount
}

func GetTitleByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Metadata.Title
}

func GetDescriptionByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Metadata.Description
}

// GetExecutionStateByProposalId is deprecated. Use GetProposalStatusById instead.
// This function is kept for backward compatibility.
func GetExecutionStateByProposalId(proposalId uint64) string {
	proposal := mustGetProposal(proposalId)
	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
	status := updater.getCurrentStatus()
	return status.String()
}
