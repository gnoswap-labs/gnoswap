package governance

import "time"

func mustGetProposal(proposalId int64) *Proposal {
	proposal, ok := getProposal(proposalId)
	if !ok {
		panic(errDataNotFound)
	}

	return proposal
}

func GetProposerByProposalId(proposalId int64) string {
	return mustGetProposal(proposalId).proposer.String()
}

func GetProposalTypeByProposalId(proposalId int64) string {
	return mustGetProposal(proposalId).data.proposalType.String()
}

func GetYeaByProposalId(proposalId int64) int64 {
	return mustGetProposal(proposalId).status.YesWeight()
}

func GetNayByProposalId(proposalId int64) int64 {
	return mustGetProposal(proposalId).status.NoWeight()
}

func GetConfigVersionByProposalId(proposalId int64) int64 {
	return mustGetProposal(proposalId).configVersion
}

func GetQuorumAmountByProposalId(proposalId int64) int64 {
	return mustGetProposal(proposalId).status.voteStatus.quorumAmount
}

func GetTitleByProposalId(proposalId int64) string {
	return mustGetProposal(proposalId).metadata.title
}

func GetDescriptionByProposalId(proposalId int64) string {
	return mustGetProposal(proposalId).metadata.description
}

// GetExecutionStateByProposalId is deprecated. Use GetProposalStatusById instead.
// This function is kept for backward compatibility.
func GetExecutionStateByProposalId(proposalId int64) string {
	currentAt := time.Now().Unix()
	proposal := mustGetProposal(proposalId)

	return proposal.Status(currentAt)
}

func GetLatestConfig() Config {
	config, ok := getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	return config
}

func GetConfig(configVersion int64) Config {
	config, ok := getConfig(configVersion)
	if !ok {
		panic(errDataNotFound)
	}

	return config
}
