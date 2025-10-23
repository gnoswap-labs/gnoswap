package v1

import (
	"time"

	"gno.land/r/gnoswap/gov/governance"
)

func mustGetProposal(state *governanceState, proposalId int64) *Proposal {
	proposal, ok := state.getProposal(proposalId)
	if !ok {
		panic(errDataNotFound)
	}

	return proposal
}

func (gv *governanceV1) GetProposerByProposalId(proposalId int64) string {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).proposer.String()
}

func (gv *governanceV1) GetProposalTypeByProposalId(proposalId int64) string {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).data.proposalType.String()
}

func (gv *governanceV1) GetYeaByProposalId(proposalId int64) int64 {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).status.YesWeight()
}

func (gv *governanceV1) GetNayByProposalId(proposalId int64) int64 {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).status.NoWeight()
}

func (gv *governanceV1) GetConfigVersionByProposalId(proposalId int64) int64 {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).configVersion
}

func (gv *governanceV1) GetQuorumAmountByProposalId(proposalId int64) int64 {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).status.voteStatus.quorumAmount
}

func (gv *governanceV1) GetTitleByProposalId(proposalId int64) string {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).metadata.title
}

func (gv *governanceV1) GetDescriptionByProposalId(proposalId int64) string {
	state := gv.GetGovernanceState()
	return mustGetProposal(state, proposalId).metadata.description
}

// GetExecutionStateByProposalId is deprecated. Use GetProposalStatusById instead.
// This function is kept for backward compatibility.
func (gv *governanceV1) GetExecutionStateByProposalId(proposalId int64) string {
	state := gv.GetGovernanceState()
	currentAt := time.Now().Unix()
	proposal := mustGetProposal(state, proposalId)

	return proposal.Status(currentAt)
}

func (gv *governanceV1) GetLatestConfig() governance.Config {
	state := gv.GetGovernanceState()
	config, ok := state.getCurrentConfig()
	if !ok {
		panic(errDataNotFound)
	}

	return config
}

func (gv *governanceV1) GetConfig(configVersion int64) governance.Config {
	state := gv.GetGovernanceState()
	config, ok := state.getConfig(configVersion)
	if !ok {
		panic(errDataNotFound)
	}

	return config
}
