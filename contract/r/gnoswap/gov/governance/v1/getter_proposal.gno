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
	proposalResolver := NewProposalResolver(proposal)
	return proposalResolver.Status(currentAt)
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

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
func (gv *governanceV1) GetMaxSmoothingPeriod() int64 {
	return maxSmoothingPeriod
}

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
// This is used by gov/staker to prevent cleanup of delegation history that is still needed
// by active proposals for voting weight calculation.
func (gv *governanceV1) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	currentTime := time.Now().Unix()
	currentProposalID := gv.getCurrentProposalID()

	var (
		oldestSnapshotTime int64
		hasActiveProposal  bool
	)

	// Iterate through all proposals to find active ones
	for id := int64(1); id <= currentProposalID; id++ {
		proposal, exists := gv.getProposal(id)
		if !exists {
			continue
		}

		proposalResolver := NewProposalResolver(proposal)

		if proposalResolver.IsActive(currentTime) {
			snapshotTime := proposal.SnapshotTime()
			if !hasActiveProposal || snapshotTime < oldestSnapshotTime {
				oldestSnapshotTime = snapshotTime
				hasActiveProposal = true
			}
		}
	}

	return oldestSnapshotTime, hasActiveProposal
}
