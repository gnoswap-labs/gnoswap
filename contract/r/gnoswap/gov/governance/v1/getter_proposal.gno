package v1

import (
	"time"

	"gno.land/r/gnoswap/gov/governance"
)

// mustGetProposal is now a method on governanceV1 (defined in instance.gno)

func (gv *governanceV1) GetProposerByProposalId(proposalId int64) string {
	return gv.mustGetProposal(proposalId).Proposer().String()
}

func (gv *governanceV1) GetProposalTypeByProposalId(proposalId int64) string {
	return gv.mustGetProposal(proposalId).Data().ProposalType().String()
}

func (gv *governanceV1) GetYeaByProposalId(proposalId int64) int64 {
	return gv.mustGetProposal(proposalId).Status().YesWeight()
}

func (gv *governanceV1) GetNayByProposalId(proposalId int64) int64 {
	return gv.mustGetProposal(proposalId).Status().NoWeight()
}

func (gv *governanceV1) GetConfigVersionByProposalId(proposalId int64) int64 {
	return gv.mustGetProposal(proposalId).ConfigVersion()
}

func (gv *governanceV1) GetQuorumAmountByProposalId(proposalId int64) int64 {
	return gv.mustGetProposal(proposalId).Status().VoteStatus().QuorumAmount()
}

func (gv *governanceV1) GetTitleByProposalId(proposalId int64) string {
	return gv.mustGetProposal(proposalId).Metadata().Title()
}

func (gv *governanceV1) GetDescriptionByProposalId(proposalId int64) string {
	return gv.mustGetProposal(proposalId).Metadata().Description()
}

// GetExecutionStateByProposalId is deprecated. Use GetProposalStatusById instead.
// This function is kept for backward compatibility.
func (gv *governanceV1) GetExecutionStateByProposalId(proposalId int64) string {
	currentAt := time.Now().Unix()
	proposal := gv.mustGetProposal(proposalId)

	return gv.proposalResolver.Status(proposal, currentAt)
}

func (gv *governanceV1) GetLatestConfig() governance.Config {
	currentVersion := gv.getCurrentConfigVersion()
	config, ok := gv.getConfig(currentVersion)
	if !ok {
		panic(errDataNotFound)
	}

	return config
}

func (gv *governanceV1) GetConfig(configVersion int64) governance.Config {
	config, ok := gv.getConfig(configVersion)
	if !ok {
		panic(errDataNotFound)
	}

	return config
}
