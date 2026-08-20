package governance

import (
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// ==================================
// Store Data Getters
// ==================================

// GetLatestConfigVersion returns the current config version.
func GetLatestConfigVersion() int64 {
	return getImplementation().GetLatestConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
func GetCurrentProposalID() int64 {
	return getImplementation().GetCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
func GetMaxSmoothingPeriod() int64 {
	return getImplementation().GetMaxSmoothingPeriod()
}

// ==================================
// Config Getters
// ==================================

// GetLatestConfig returns the latest governance configuration.
func GetLatestConfig() Config {
	return getImplementation().GetLatestConfig()
}

// GetConfig returns a specific governance configuration by version.
func GetConfig(configVersion int64) (Config, error) {
	return getImplementation().GetConfig(configVersion)
}

// ==================================
// Proposal Getters
// ==================================

// GetProposals returns a read-only view of every proposal, keyed by the decimal
// string form of the proposal ID. Callers paginate it themselves through
// IterateByOffset. Reading an entry yields a clone, so the view cannot mutate
// realm state.
func GetProposals() *rotree.ReadOnlyTree {
	return getImplementation().GetProposals()
}

// ExistsProposal checks if a proposal exists.
func ExistsProposal(proposalID int64) bool {
	return getImplementation().ExistsProposal(proposalID)
}

// GetProposerByProposalId returns the proposer address of a proposal.
func GetProposerByProposalId(proposalId int64) (address, error) {
	return getImplementation().GetProposerByProposalId(proposalId)
}

// GetProposalTypeByProposalId returns the type of a proposal.
func GetProposalTypeByProposalId(proposalId int64) (ProposalType, error) {
	return getImplementation().GetProposalTypeByProposalId(proposalId)
}

// GetYeaByProposalId returns the yes vote weight of a proposal.
func GetYeaByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetYeaByProposalId(proposalId)
}

// GetNayByProposalId returns the no vote weight of a proposal.
func GetNayByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetNayByProposalId(proposalId)
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
func GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetConfigVersionByProposalId(proposalId)
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
func GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetQuorumAmountByProposalId(proposalId)
}

// GetTitleByProposalId returns the title of a proposal.
func GetTitleByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetTitleByProposalId(proposalId)
}

// GetDescriptionByProposalId returns the description of a proposal.
func GetDescriptionByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetDescriptionByProposalId(proposalId)
}

// GetProposalStatusByProposalId returns the current status of a proposal.
func GetProposalStatusByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetProposalStatusByProposalId(proposalId)
}

// GetProposalCreatedAt returns the creation timestamp of a proposal.
func GetProposalCreatedAt(proposalId int64) (int64, error) {
	return getImplementation().GetProposalCreatedAt(proposalId)
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
func GetProposalCreatedHeight(proposalId int64) (int64, error) {
	return getImplementation().GetProposalCreatedHeight(proposalId)
}

// ==================================
// Vote Getters
// ==================================

// GetVoteStatus returns the vote status of a proposal.
//
// Returns:
//   - quorum: minimum vote weight required for proposal to pass
//   - maxVotingWeight: maximum possible voting weight
//   - yesWeight: total weight of "yes" votes
//   - noWeight: total weight of "no" votes
func GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	return getImplementation().GetVoteStatus(proposalId)
}

// GetVotingInfos returns a read-only view of a proposal's voting infos, keyed by
// voter address. Reading an entry yields a clone, so the view cannot mutate
// realm state. nil is returned when the proposal has no votes.
func GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree {
	return getImplementation().GetVotingInfos(proposalID)
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
func ExistsVotingInfo(proposalID int64, addr address) bool {
	return getImplementation().ExistsVotingInfo(proposalID, addr)
}

// GetVoteWeight returns the voting weight of an address for a proposal.
func GetVoteWeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVoteWeight(proposalID, addr)
}

// GetVotedHeight returns the block height when an address voted on a proposal.
func GetVotedHeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedHeight(proposalID, addr)
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
func GetVotedAt(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedAt(proposalID, addr)
}

// GetProposalCommunityPoolSpendInfo returns the community pool spend info for a proposal.
func GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error) {
	info, err := getImplementation().GetProposalCommunityPoolSpendInfo(proposalID)
	if err != nil {
		return nil, err
	}

	return info.Clone(), nil
}

// GetProposalExecutionInfo returns the execution info for a proposal.
func GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error) {
	info, err := getImplementation().GetProposalExecutionInfo(proposalID)
	if err != nil {
		return nil, err
	}

	return info.Clone(), nil
}

// ==================================
// User Proposal Getters
// ==================================

// GetUserProposals returns a read-only view of the proposals created per user,
// keyed by creator address with the creator's proposal IDs as the value.
// Reading an entry yields a copy of the ID slice, so the view cannot mutate
// realm state.
func GetUserProposals() *rotree.ReadOnlyTree {
	return getImplementation().GetUserProposals()
}

// ==================================
// Active Proposal Query
// ==================================

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
func GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return getImplementation().GetOldestActiveProposalSnapshotTime()
}

// ==================================
// Voting weight snapshot getters
// ==================================

// GetCurrentVotingWeightSnapshot returns the current voting weight snapshot.
func GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	return getImplementation().GetCurrentVotingWeightSnapshot()
}
