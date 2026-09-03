package governance

import (
	"errors"
	"time"

	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/gov/governance"
)

// GetLatestConfigVersion returns the current config version.
func (gv *governanceV1) GetLatestConfigVersion() int64 {
	return gv.getCurrentConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
func (gv *governanceV1) GetCurrentProposalID() int64 {
	return gv.getCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
func (gv *governanceV1) GetMaxSmoothingPeriod() int64 {
	return maxSmoothingPeriod
}

// GetLatestConfig returns the latest governance configuration.
func (gv *governanceV1) GetLatestConfig() governance.Config {
	currentVersion := gv.getCurrentConfigVersion()
	config, ok := gv.getConfig(currentVersion)
	if !ok {
		panic(errors.New(errDataNotFound))
	}

	return config
}

// GetConfig returns a specific governance configuration by version.
func (gv *governanceV1) GetConfig(configVersion int64) (governance.Config, error) {
	config, ok := gv.getConfig(configVersion)
	if !ok {
		// Construct the zero Config via the domain constructor so it is
		// allocated inside the governance domain realm (realm allocation check).
		return governance.NewConfig(0, 0, 0, 0, 0, 0, 0), ufmt.Errorf("config version %d not found", configVersion)
	}

	return config, nil
}

// GetProposals returns a read-only view of every proposal, keyed by the decimal
// string form of the proposal ID.
func (gv *governanceV1) GetProposals() *rotree.ReadOnlyTree {
	return rotree.Wrap(gv.store.GetProposals(), cloneProposalEntry)
}

// ExistsProposal checks if a proposal exists.
func (gv *governanceV1) ExistsProposal(proposalID int64) bool {
	_, exists := gv.store.GetProposal(proposalID)
	return exists
}

// GetProposerByProposalId returns the proposer address of a proposal.
func (gv *governanceV1) GetProposerByProposalId(proposalId int64) (address, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Proposer(), nil
}

// GetProposalTypeByProposalId returns the type of a proposal.
func (gv *governanceV1) GetProposalTypeByProposalId(proposalId int64) (governance.ProposalType, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return governance.ProposalType(0), ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Type(), nil
}

// GetProposalCreatedAt returns the creation timestamp of a proposal.
func (gv *governanceV1) GetProposalCreatedAt(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.CreatedAt(), nil
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
func (gv *governanceV1) GetProposalCreatedHeight(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.CreatedHeight(), nil
}

// GetProposalCommunityPoolSpendInfo returns the community pool spend info for a proposal.
func (gv *governanceV1) GetProposalCommunityPoolSpendInfo(proposalID int64) (*governance.CommunityPoolSpendInfo, error) {
	proposal, exists := gv.store.GetProposal(proposalID)
	if !exists {
		return nil, ufmt.Errorf("proposal %d not found", proposalID)
	}

	proposalData := proposal.Data()
	if proposalData == nil || proposalData.CommunityPoolSpend() == nil {
		return nil, ufmt.Errorf("proposal is not a community pool spend proposal")
	}

	return proposalData.CommunityPoolSpend(), nil
}

// GetProposalExecutionInfo returns the execution info for a proposal.
func (gv *governanceV1) GetProposalExecutionInfo(proposalID int64) (*governance.ExecutionInfo, error) {
	proposal, exists := gv.store.GetProposal(proposalID)
	if !exists {
		return nil, ufmt.Errorf("proposal %d not found", proposalID)
	}

	proposalData := proposal.Data()
	if proposalData == nil || proposalData.Execution() == nil {
		return nil, ufmt.Errorf("proposal is not a parameter change proposal")
	}

	return proposalData.Execution(), nil
}

// GetYeaByProposalId returns the yes vote weight of a proposal.
func (gv *governanceV1) GetYeaByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().YesWeight(), nil
}

// GetNayByProposalId returns the no vote weight of a proposal.
func (gv *governanceV1) GetNayByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().NoWeight(), nil
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
func (gv *governanceV1) GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.ConfigVersion(), nil
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
func (gv *governanceV1) GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().VoteStatus().QuorumAmount(), nil
}

// GetTitleByProposalId returns the title of a proposal.
func (gv *governanceV1) GetTitleByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Title(), nil
}

// GetDescriptionByProposalId returns the description of a proposal.
func (gv *governanceV1) GetDescriptionByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Description(), nil
}

// GetProposalStatusByProposalId returns the current status of a proposal.
func (gv *governanceV1) GetProposalStatusByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	proposalResolver := NewProposalResolver(proposal)
	return proposalResolver.Status(time.Now().Unix()), nil
}

// GetVoteStatus returns the vote status of a proposal.
//
// Returns:
//   - quorum: minimum vote weight required for proposal to pass
//   - maxVotingWeight: maximum possible voting weight
//   - yesWeight: total weight of "yes" votes
//   - noWeight: total weight of "no" votes
func (gv *governanceV1) GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, 0, 0, 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	voting := proposal.Status().VoteStatus()
	return voting.QuorumAmount(), voting.MaxVotingWeight(), voting.YesWeight(), voting.NoWeight(), nil
}

// GetVotingInfos returns a read-only view of a proposal's voting infos, keyed by
// voter address. nil is returned when the proposal has no votes.
func (gv *governanceV1) GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree {
	votingInfos, exists := gv.getProposalUserVotingInfos(proposalID)
	if !exists {
		return nil
	}
	return rotree.Wrap(votingInfos, cloneVotingInfoEntry)
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
func (gv *governanceV1) ExistsVotingInfo(proposalID int64, addr address) bool {
	_, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	return exists
}

// GetVoteWeight returns the voting weight of an address for a proposal.
func (gv *governanceV1) GetVoteWeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedWeight(), nil
}

// GetVotedHeight returns the block height when an address voted on a proposal.
func (gv *governanceV1) GetVotedHeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedHeight(), nil
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
func (gv *governanceV1) GetVotedAt(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedAt(), nil
}

// GetUserProposals returns a read-only view of the proposals created per user,
// keyed by creator address with the creator's proposal IDs as the value.
func (gv *governanceV1) GetUserProposals() *rotree.ReadOnlyTree {
	return rotree.Wrap(gv.store.GetUserProposals(), cloneProposalIDsEntry)
}

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
// This is used by gov/staker to prevent cleanup of delegation history that is still needed
// by active proposals for voting weight calculation.
func (gv *governanceV1) GetOldestActiveProposalSnapshotTime() (int64, bool) {
	snapshotIndex := gv.store.GetActiveProposalsBySnapshot()
	current := time.Now().Unix()
	var oldestSnapshotTime int64
	hasActiveProposal := false

	snapshotIndex.Iterate("", "", func(_ string, value any) bool {
		proposalID, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast active proposal ID to int64: %T", value))
		}
		proposal, exists := gv.getProposal(proposalID)
		if !exists || !NewProposalResolver(proposal).IsActive(current) {
			return false
		}
		oldestSnapshotTime = proposal.SnapshotTime()
		hasActiveProposal = true
		return true
	})
	return oldestSnapshotTime, hasActiveProposal
}

// GetCurrentVotingWeightSnapshot returns the current voting weight snapshot.
func (gv *governanceV1) GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	current := time.Now().Unix()
	config, ok := gv.getCurrentConfig()
	if !ok {
		return 0, 0, ufmt.Errorf("current config not found")
	}

	return gv.getVotingWeightSnapshot(current, config.VotingWeightSmoothingDuration)
}
