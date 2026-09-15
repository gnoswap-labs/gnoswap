package governance

import (
	"errors"
	"time"

	rotree "gno.land/p/nt/bptree/rotree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/gov/governance"
)

// GetLatestConfigVersion returns the current governance configuration version.
//
// Returns:
//   - int64: latest configuration version stored by governance.
func (gv *governanceV1) GetLatestConfigVersion() int64 {
	return gv.getCurrentConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
//
// Returns:
//   - int64: current proposal ID counter used for newly created proposals.
func (gv *governanceV1) GetCurrentProposalID() int64 {
	return gv.getCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
//
// Returns:
//   - int64: maximum permitted smoothing period, in seconds.
func (gv *governanceV1) GetMaxSmoothingPeriod() int64 {
	return maxSmoothingPeriod
}

// GetLatestConfig returns the latest governance configuration.
//
// Returns:
//   - governance.Config: latest stored configuration for the current version.
//   - error: nil on success; an error when the current configuration is missing.
func (gv *governanceV1) GetLatestConfig() (governance.Config, error) {
	currentVersion := gv.getCurrentConfigVersion()
	config, ok := gv.getConfig(currentVersion)
	if !ok {
		return governance.NewConfig(0, 0, 0, 0, 0, 0, 0), errors.New(errDataNotFound)
	}

	return config, nil
}

// GetConfig returns a specific governance configuration by version.
//
// Parameters:
//   - configVersion: configuration version to retrieve.
//
// Returns:
//   - governance.Config: configuration stored under configVersion.
//   - error: nil on success; an error when configVersion is not found.
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
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only proposal tree with decimal proposal IDs as keys.
func (gv *governanceV1) GetProposals() *rotree.ReadOnlyTree {
	return rotree.Wrap(gv.store.GetProposals(), cloneProposalEntry)
}

// ExistsProposal checks if a proposal exists.
//
// Parameters:
//   - proposalID: proposal identifier to look up.
//
// Returns:
//   - bool: true when proposalID is stored, otherwise false.
func (gv *governanceV1) ExistsProposal(proposalID int64) bool {
	_, exists := gv.store.GetProposal(proposalID)
	return exists
}

// GetProposerByProposalId returns the proposer address of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up.
//
// Returns:
//   - address: address that submitted the proposal.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetProposerByProposalId(proposalId int64) (address, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Proposer(), nil
}

// GetProposalTypeByProposalId returns the type of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up.
//
// Returns:
//   - governance.ProposalType: type recorded for the proposal.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetProposalTypeByProposalId(proposalId int64) (governance.ProposalType, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return governance.ProposalType(0), ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Type(), nil
}

// GetProposalCreatedAt returns the creation timestamp of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up.
//
// Returns:
//   - int64: Unix timestamp at which the proposal was created.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetProposalCreatedAt(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.CreatedAt(), nil
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up.
//
// Returns:
//   - int64: block height at which the proposal was created.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetProposalCreatedHeight(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.CreatedHeight(), nil
}

// GetProposalCommunityPoolSpendInfo returns the community pool spend info for a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//
// Returns:
//   - *governance.CommunityPoolSpendInfo: spend details stored in the proposal.
//   - error: nil on success; an error when the proposal is missing or is not a
//     community pool spend proposal.
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
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//
// Returns:
//   - *governance.ExecutionInfo: execution messages and count stored in the proposal.
//   - error: nil on success; an error when the proposal is missing or is not a
//     parameter change proposal.
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
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - int64: total voting weight recorded for yes votes.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetYeaByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().YesWeight(), nil
}

// GetNayByProposalId returns the no vote weight of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - int64: total voting weight recorded for no votes.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetNayByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().NoWeight(), nil
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - int64: governance configuration version captured by the proposal.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.ConfigVersion(), nil
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - int64: minimum voting weight required for the proposal's quorum.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Status().VoteStatus().QuorumAmount(), nil
}

// GetTitleByProposalId returns the title of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - string: proposal title.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetTitleByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Title(), nil
}

// GetDescriptionByProposalId returns the description of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - string: proposal description.
//   - error: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetDescriptionByProposalId(proposalId int64) (string, error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return "", ufmt.Errorf("proposal %d not found", proposalId)
	}
	return proposal.Metadata().Description(), nil
}

// GetProposalStatusByProposalId returns the current status of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - string: status computed from the proposal and the current Unix time.
//   - error: nil on success; an error when the proposal does not exist.
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
// Parameters:
//   - proposalId: proposal identifier to inspect.
//
// Returns:
//   - quorum: minimum vote weight required for proposal to pass.
//   - maxVotingWeight: maximum possible voting weight recorded for the proposal.
//   - yesWeight: total weight of "yes" votes.
//   - noWeight: total weight of "no" votes.
//   - err: nil on success; an error when the proposal does not exist.
func (gv *governanceV1) GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	proposal, exists := gv.store.GetProposal(proposalId)
	if !exists {
		return 0, 0, 0, 0, ufmt.Errorf("proposal %d not found", proposalId)
	}
	voting := proposal.Status().VoteStatus()
	return voting.QuorumAmount(), voting.MaxVotingWeight(), voting.YesWeight(), voting.NoWeight(), nil
}

// GetVotingInfos returns a read-only view of a proposal's value-backed voting
// infos, keyed by voter address. Existing proposals have an empty view before
// the first vote; nil is returned only when the stored voting-info tree is absent.
//
// Parameters:
//   - proposalID: proposal identifier whose voting information is requested.
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only voting-info tree keyed by voter address, or
//     nil when no tree is stored for proposalID.
func (gv *governanceV1) GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree {
	votingInfos, exists := gv.getProposalUserVotingInfos(proposalID)
	if !exists {
		return nil
	}
	return rotree.Wrap(votingInfos, nil)
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//   - addr: voter address to look up within proposalID.
//
// Returns:
//   - bool: true when voting information exists for the proposal and address.
func (gv *governanceV1) ExistsVotingInfo(proposalID int64, addr address) bool {
	_, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	return exists
}

// GetVoteWeight returns the voting weight of an address for a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//   - addr: voter address whose recorded vote weight is requested.
//
// Returns:
//   - int64: weight recorded for addr's vote.
//   - error: nil on success; an error when no voting information exists for the
//     proposal and address.
func (gv *governanceV1) GetVoteWeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedWeight(), nil
}

// GetVotedHeight returns the block height when an address voted on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//   - addr: voter address whose vote height is requested.
//
// Returns:
//   - int64: block height recorded for addr's vote.
//   - error: nil on success; an error when no voting information exists for the
//     proposal and address.
func (gv *governanceV1) GetVotedHeight(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedHeight(), nil
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect.
//   - addr: voter address whose vote timestamp is requested.
//
// Returns:
//   - int64: Unix timestamp recorded for addr's vote.
//   - error: nil on success; an error when no voting information exists for the
//     proposal and address.
func (gv *governanceV1) GetVotedAt(proposalID int64, addr address) (int64, error) {
	votingInfo, exists := gv.getProposalUserVotingInfo(proposalID, addr)
	if !exists {
		return 0, ufmt.Errorf("voting info not found for proposal %d and address %s", proposalID, addr.String())
	}
	return votingInfo.VotedAt(), nil
}

// GetUserProposals returns a read-only view of the proposals created per user,
// keyed by creator address with the creator's proposal IDs as the value.
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only user-proposal tree keyed by creator address.
func (gv *governanceV1) GetUserProposals() *rotree.ReadOnlyTree {
	return rotree.Wrap(gv.store.GetUserProposals(), cloneProposalIDsEntry)
}

// GetOldestActiveProposalSnapshotTime examines only the first timestamp-ordered index entry.
// If it is inactive, the error identifies the proposal requiring maintenance
// cleanup. An error must never be treated as an empty index when deleting
// delegation history.
//
// Returns:
//   - int64: snapshot timestamp of the oldest active proposal, or zero when the
//     index is empty or an error occurs.
//   - bool: true when an active proposal was found at the oldest index entry.
//   - error: nil for an empty index or active entry; an error when the entry's
//     proposal is missing or inactive and the index needs cleanup.
func (gv *governanceV1) GetOldestActiveProposalSnapshotTime() (int64, bool, error) {
	index := gv.store.GetActiveProposalsBySnapshot()
	if index.Size() == 0 {
		return 0, false, nil
	}

	_, value := index.GetByIndex(0)
	proposalID, ok := value.(int64)
	if !ok {
		panic(ufmt.Sprintf("failed to cast active proposal ID to int64: %T", value))
	}

	proposal, exists := gv.getProposal(proposalID)
	if !exists {
		return 0, false, makeErrorWithDetails(
			errProposalNotFound, ufmt.Sprintf("proposalID: %d", proposalID),
		)
	}
	if !NewProposalResolver(proposal).IsActive(time.Now().Unix()) {
		return 0, false, makeErrorWithDetails(
			errProposalIndexNeedsCleanup, ufmt.Sprintf("proposalID: %d", proposalID),
		)
	}

	return proposal.SnapshotTime(), true, nil
}

// GetCurrentVotingWeightSnapshot returns the current total voting weight and
// timestamp anchor computed with the configured smoothing duration.
//
// Returns:
//   - int64: total voting weight averaged over the configured smoothing window.
//   - int64: Unix timestamp used as the snapshot history anchor.
//   - error: nil on success; an error when the current configuration or snapshot
//     data cannot be retrieved.
func (gv *governanceV1) GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	current := time.Now().Unix()
	config, ok := gv.getCurrentConfig()
	if !ok {
		return 0, 0, ufmt.Errorf("current config not found")
	}

	return gv.getVotingWeightSnapshot(current, config.VotingWeightSmoothingDuration)
}
