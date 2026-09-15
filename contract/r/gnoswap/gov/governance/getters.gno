package governance

import (
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// ==================================
// Store Data Getters
// ==================================

// GetLatestConfigVersion returns the current governance configuration version.
//
// Returns:
//   - int64: latest configuration version stored by governance
func GetLatestConfigVersion() int64 {
	return getImplementation().GetLatestConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
//
// Returns:
//   - int64: current proposal ID counter used for newly created proposals
func GetCurrentProposalID() int64 {
	return getImplementation().GetCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
//
// Returns:
//   - int64: maximum permitted smoothing period in seconds
func GetMaxSmoothingPeriod() int64 {
	return getImplementation().GetMaxSmoothingPeriod()
}

// ==================================
// Config Getters
// ==================================

// GetLatestConfig returns the latest governance configuration.
//
// Returns:
//   - Config: latest stored configuration for the current version
//   - error: nil on success, or an error when the current configuration is missing
func GetLatestConfig() (Config, error) {
	return getImplementation().GetLatestConfig()
}

// GetConfig returns a specific governance configuration by version.
//
// Parameters:
//   - configVersion: configuration version to retrieve
//
// Returns:
//   - Config: configuration stored under configVersion
//   - error: nil on success, or an error when configVersion is not found
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
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only proposal tree keyed by decimal proposal ID
func GetProposals() *rotree.ReadOnlyTree {
	return getImplementation().GetProposals()
}

// ExistsProposal checks whether a proposal is stored.
//
// Parameters:
//   - proposalID: proposal identifier to look up
//
// Returns:
//   - bool: true when proposalID is stored, otherwise false
func ExistsProposal(proposalID int64) bool {
	return getImplementation().ExistsProposal(proposalID)
}

// GetProposerByProposalId returns the proposer address of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up
//
// Returns:
//   - address: address that submitted the proposal
//   - error: nil on success, or an error when the proposal does not exist
func GetProposerByProposalId(proposalId int64) (address, error) {
	return getImplementation().GetProposerByProposalId(proposalId)
}

// GetProposalTypeByProposalId returns the type of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up
//
// Returns:
//   - ProposalType: type recorded for the proposal
//   - error: nil on success, or an error when the proposal does not exist
func GetProposalTypeByProposalId(proposalId int64) (ProposalType, error) {
	return getImplementation().GetProposalTypeByProposalId(proposalId)
}

// GetYeaByProposalId returns the yes vote weight of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - int64: total voting weight recorded for yes votes
//   - error: nil on success, or an error when the proposal does not exist
func GetYeaByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetYeaByProposalId(proposalId)
}

// GetNayByProposalId returns the no vote weight of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - int64: total voting weight recorded for no votes
//   - error: nil on success, or an error when the proposal does not exist
func GetNayByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetNayByProposalId(proposalId)
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - int64: governance configuration version captured by the proposal
//   - error: nil on success, or an error when the proposal does not exist
func GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetConfigVersionByProposalId(proposalId)
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - int64: minimum voting weight required for the proposal's quorum
//   - error: nil on success, or an error when the proposal does not exist
func GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetQuorumAmountByProposalId(proposalId)
}

// GetTitleByProposalId returns the title of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - string: proposal title
//   - error: nil on success, or an error when the proposal does not exist
func GetTitleByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetTitleByProposalId(proposalId)
}

// GetDescriptionByProposalId returns the description of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - string: proposal description
//   - error: nil on success, or an error when the proposal does not exist
func GetDescriptionByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetDescriptionByProposalId(proposalId)
}

// GetProposalStatusByProposalId returns the current status of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - string: status computed from the proposal and the current Unix time
//   - error: nil on success, or an error when the proposal does not exist
func GetProposalStatusByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetProposalStatusByProposalId(proposalId)
}

// GetProposalCreatedAt returns the creation timestamp of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up
//
// Returns:
//   - int64: Unix timestamp at which the proposal was created
//   - error: nil on success, or an error when the proposal does not exist
func GetProposalCreatedAt(proposalId int64) (int64, error) {
	return getImplementation().GetProposalCreatedAt(proposalId)
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to look up
//
// Returns:
//   - int64: block height at which the proposal was created
//   - error: nil on success, or an error when the proposal does not exist
func GetProposalCreatedHeight(proposalId int64) (int64, error) {
	return getImplementation().GetProposalCreatedHeight(proposalId)
}

// ==================================
// Vote Getters
// ==================================

// GetVoteStatus returns the vote status of a proposal.
//
// Parameters:
//   - proposalId: proposal identifier to inspect
//
// Returns:
//   - quorum: minimum vote weight required for the proposal to pass
//   - maxVotingWeight: maximum possible voting weight recorded for the proposal
//   - yesWeight: total weight of yes votes
//   - noWeight: total weight of no votes
//   - err: nil on success, or an error when the proposal does not exist
func GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	return getImplementation().GetVoteStatus(proposalId)
}

// GetVotingInfos returns a read-only view of a proposal's value-backed voting
// infos, keyed by voter address. Existing proposals have an empty view before
// the first vote; nil is returned only when the stored voting-info tree is absent.
//
// Parameters:
//   - proposalID: proposal identifier whose voting information is requested
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only voting-info tree keyed by voter address, or nil when no tree is stored
func GetVotingInfos(proposalID int64) *rotree.ReadOnlyTree {
	return getImplementation().GetVotingInfos(proposalID)
}

// ExistsVotingInfo checks whether voting information exists for a user on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//   - addr: voter address to look up within proposalID
//
// Returns:
//   - bool: true when voting information exists for the proposal and address
func ExistsVotingInfo(proposalID int64, addr address) bool {
	return getImplementation().ExistsVotingInfo(proposalID, addr)
}

// GetVoteWeight returns the voting weight of an address for a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//   - addr: voter address whose recorded vote weight is requested
//
// Returns:
//   - int64: weight recorded for addr's vote
//   - error: nil on success, or an error when no voting information exists for the proposal and address
func GetVoteWeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVoteWeight(proposalID, addr)
}

// GetVotedHeight returns the block height when an address voted on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//   - addr: voter address whose vote height is requested
//
// Returns:
//   - int64: block height recorded for addr's vote
//   - error: nil on success, or an error when no voting information exists for the proposal and address
func GetVotedHeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedHeight(proposalID, addr)
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//   - addr: voter address whose vote timestamp is requested
//
// Returns:
//   - int64: Unix timestamp recorded for addr's vote
//   - error: nil on success, or an error when no voting information exists for the proposal and address
func GetVotedAt(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedAt(proposalID, addr)
}

// GetProposalCommunityPoolSpendInfo returns a cloned copy of the community pool spend info for a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//
// Returns:
//   - *CommunityPoolSpendInfo: cloned community-pool spend details, or nil when an error occurs
//   - error: nil on success, or an error when the proposal is missing or has no spend data
func GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error) {
	info, err := getImplementation().GetProposalCommunityPoolSpendInfo(proposalID)
	if err != nil {
		return nil, err
	}

	return info.Clone(), nil
}

// GetProposalExecutionInfo returns a cloned copy of the execution info for a proposal.
//
// Parameters:
//   - proposalID: proposal identifier to inspect
//
// Returns:
//   - *ExecutionInfo: cloned parameter-change execution messages and count, or nil when an error occurs
//   - error: nil on success, or an error when the proposal is missing or has no execution data
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
//
// Returns:
//   - *rotree.ReadOnlyTree: read-only user-proposal tree keyed by creator address
func GetUserProposals() *rotree.ReadOnlyTree {
	return getImplementation().GetUserProposals()
}

// ==================================
// Active Proposal Query
// ==================================

// GetOldestActiveProposalSnapshotTime returns the oldest active proposal's
// timestamp anchor. An empty index returns no active proposal; a stale or
// missing first entry returns an error so cleanup cannot silently skip it.
//
// Returns:
//   - int64: snapshot timestamp of the oldest active proposal, or zero when the index is empty or an error occurs
//   - bool: true when an active proposal was found at the oldest index entry, otherwise false
//   - error: nil for an empty index or active entry, or an error when the entry is missing or inactive
func GetOldestActiveProposalSnapshotTime() (int64, bool, error) {
	return getImplementation().GetOldestActiveProposalSnapshotTime()
}

// ==================================
// Voting weight snapshot getters
// ==================================

// GetCurrentVotingWeightSnapshot returns the current total voting weight and its
// timestamp anchor computed with the configured smoothing duration.
//
// Returns:
//   - int64: total voting weight averaged over the configured smoothing window
//   - int64: Unix timestamp used as the snapshot history anchor
//   - error: nil on success, or an error when the current configuration or snapshot data cannot be retrieved
func GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	return getImplementation().GetCurrentVotingWeightSnapshot()
}
