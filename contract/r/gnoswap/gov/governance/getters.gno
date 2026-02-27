package governance

import "errors"

// ==================================
// Store Data Getters
// ==================================

// GetLatestConfigVersion returns the current config version.
//
// Returns:
//   - version: current config version number
func GetLatestConfigVersion() int64 {
	return getImplementation().GetLatestConfigVersion()
}

// GetCurrentProposalID returns the current proposal ID counter.
//
// Returns:
//   - proposalId: current proposal ID counter
func GetCurrentProposalID() int64 {
	return getImplementation().GetCurrentProposalID()
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
//
// Returns:
//   - period: maximum smoothing period in seconds
func GetMaxSmoothingPeriod() int64 {
	return getImplementation().GetMaxSmoothingPeriod()
}

// ==================================
// Config Getters
// ==================================

// GetLatestConfig returns the latest governance configuration.
//
// Returns:
//   - config: latest governance configuration
func GetLatestConfig() Config {
	return getImplementation().GetLatestConfig()
}

// GetConfig returns a specific governance configuration by version.
//
// Parameters:
//   - configVersion: version number of the config
//
// Returns:
//   - config: governance configuration
//   - err: error if not found
func GetConfig(configVersion int64) (Config, error) {
	return getImplementation().GetConfig(configVersion)
}

// ==================================
// Proposal Getters
// ==================================

// GetProposalCount returns the total number of proposals.
//
// Returns:
//   - count: total number of proposals
func GetProposalCount() int {
	return getImplementation().GetProposalCount()
}

// GetProposalIDs returns a paginated list of proposal IDs.
//
// Parameters:
//   - offset: starting index
//   - count: number of IDs to return
//
// Returns:
//   - proposalIds: list of proposal IDs
func GetProposalIDs(offset, count int) []int64 {
	return getImplementation().GetProposalIDs(offset, count)
}

// ExistsProposal checks if a proposal exists.
//
// Parameters:
//   - proposalID: ID of the proposal
//
// Returns:
//   - exists: true if proposal exists
func ExistsProposal(proposalID int64) bool {
	return getImplementation().ExistsProposal(proposalID)
}

// GetProposal returns a proposal by ID.
// Returns a clone to prevent external modification.
//
// Parameters:
//   - proposalID: ID of the proposal
//
// Returns:
//   - proposal: proposal data or nil if not found
//   - err: error if retrieval fails
func GetProposal(proposalID int64) (*Proposal, error) {
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}
	return proposal.Clone(), nil
}

// GetProposerByProposalId returns the proposer address of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - proposer: proposer address
//   - err: error if not found
func GetProposerByProposalId(proposalId int64) (address, error) {
	return getImplementation().GetProposerByProposalId(proposalId)
}

// GetProposalTypeByProposalId returns the type of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - proposalType: type of the proposal
//   - err: error if not found
func GetProposalTypeByProposalId(proposalId int64) (ProposalType, error) {
	return getImplementation().GetProposalTypeByProposalId(proposalId)
}

// GetYeaByProposalId returns the yes vote weight of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - yea: total yes vote weight
//   - err: error if not found
func GetYeaByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetYeaByProposalId(proposalId)
}

// GetNayByProposalId returns the no vote weight of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - nay: total no vote weight
//   - err: error if not found
func GetNayByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetNayByProposalId(proposalId)
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - configVersion: config version number
//   - err: error if not found
func GetConfigVersionByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetConfigVersionByProposalId(proposalId)
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - quorum: required quorum amount
//   - err: error if not found
func GetQuorumAmountByProposalId(proposalId int64) (int64, error) {
	return getImplementation().GetQuorumAmountByProposalId(proposalId)
}

// GetTitleByProposalId returns the title of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - title: proposal title
//   - err: error if not found
func GetTitleByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetTitleByProposalId(proposalId)
}

// GetDescriptionByProposalId returns the description of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - description: proposal description
//   - err: error if not found
func GetDescriptionByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetDescriptionByProposalId(proposalId)
}

// GetProposalStatusByProposalId returns the current status of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - status: proposal status string
//   - err: error if not found
func GetProposalStatusByProposalId(proposalId int64) (string, error) {
	return getImplementation().GetProposalStatusByProposalId(proposalId)
}

// GetProposalCreatedAt returns the creation timestamp of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - timestamp: creation timestamp
//   - err: error if not found
func GetProposalCreatedAt(proposalId int64) (int64, error) {
	proposal, err := getImplementation().GetProposal(proposalId)
	if err != nil {
		return 0, err
	}

	return proposal.CreatedAt(), nil
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - height: creation block height
//   - err: error if not found
func GetProposalCreatedHeight(proposalId int64) (int64, error) {
	proposal, err := getImplementation().GetProposal(proposalId)
	if err != nil {
		return 0, err
	}

	return proposal.createdHeight, nil
}

// ==================================
// Vote Getters
// ==================================

// GetVoteStatus returns the vote status of a proposal.
//
// Parameters:
//   - proposalId: ID of the proposal
//
// Returns:
//   - quorum: minimum vote weight required for proposal to pass
//   - maxVotingWeight: maximum possible voting weight
//   - yesWeight: total weight of "yes" votes
//   - noWeight: total weight of "no" votes
//   - err: error if not found
func GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	return getImplementation().GetVoteStatus(proposalId)
}

// GetVotingInfoCount returns the number of voters for a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//
// Returns:
//   - count: number of voters
func GetVotingInfoCount(proposalID int64) int {
	return getImplementation().GetVotingInfoCount(proposalID)
}

// GetVotingInfoAddresses returns a paginated list of voter addresses for a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - offset: starting index
//   - count: number of addresses to return
//
// Returns:
//   - addresses: list of voter addresses
func GetVotingInfoAddresses(proposalID int64, offset, count int) []address {
	return getImplementation().GetVotingInfoAddresses(proposalID, offset, count)
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - addr: voter address
//
// Returns:
//   - exists: true if voting info exists
func ExistsVotingInfo(proposalID int64, addr address) bool {
	return getImplementation().ExistsVotingInfo(proposalID, addr)
}

// GetVotingInfo returns the voting info for a user on a proposal.
// Returns a clone to prevent external modification.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - addr: voter address
//
// Returns:
//   - votingInfo: voting info data or nil if not found
//   - err: error if retrieval fails
func GetVotingInfo(proposalID int64, addr address) (*VotingInfo, error) {
	votingInfo, err := getImplementation().GetVotingInfo(proposalID, addr)
	if err != nil {
		return nil, err
	}
	return votingInfo.Clone(), nil
}

// GetVoteWeight returns the voting weight of an address for a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - addr: voter address
//
// Returns:
//   - weight: voting weight
//   - err: error if not found
func GetVoteWeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVoteWeight(proposalID, addr)
}

// GetVotedHeight returns the block height when an address voted on a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - addr: voter address
//
// Returns:
//   - height: block height when voted
//   - err: error if not found
func GetVotedHeight(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedHeight(proposalID, addr)
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//   - addr: voter address
//
// Returns:
//   - timestamp: time when voted
//   - err: error if not found
func GetVotedAt(proposalID int64, addr address) (int64, error) {
	return getImplementation().GetVotedAt(proposalID, addr)
}

// GetProposalCommunityPoolSpendInfo returns the community pool spend info for a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//
// Returns:
//   - spendInfo: community pool spend info
//   - err: error if not a community pool spend proposal
func GetProposalCommunityPoolSpendInfo(proposalID int64) (*CommunityPoolSpendInfo, error) {
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}

	proposalData := proposal.Data()
	if proposalData == nil || proposalData.CommunityPoolSpend() == nil {
		return nil, errors.New("proposal is not a community pool spend proposal")
	}

	return proposalData.CommunityPoolSpend().Clone(), nil
}

// GetProposalExecutionInfo returns the execution info for a proposal.
//
// Parameters:
//   - proposalID: ID of the proposal
//
// Returns:
//   - executionInfo: execution info
//   - err: error if not a parameter change proposal
func GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error) {
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}

	proposalData := proposal.Data()

	if proposalData == nil || proposalData.Execution() == nil {
		return nil, errors.New("proposal is not a parameter change proposal")
	}

	return proposalData.Execution().Clone(), nil
}

// ==================================
// User Proposal Getters
// ==================================

// GetUserProposalCount returns the number of proposals created by a user.
//
// Parameters:
//   - user: user address
//
// Returns:
//   - count: number of proposals created by user
func GetUserProposalCount(user address) int {
	return getImplementation().GetUserProposalCount(user)
}

// GetUserProposalIDs returns a paginated list of proposal IDs created by a user.
//
// Parameters:
//   - user: user address
//   - offset: starting index
//   - count: number of IDs to return
//
// Returns:
//   - proposalIds: list of proposal IDs
func GetUserProposalIDs(user address, offset, count int) []int64 {
	return getImplementation().GetUserProposalIDs(user, offset, count)
}

// ==================================
// Active Proposal Query
// ==================================

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
//
// Returns:
//   - snapshotTime: oldest snapshot timestamp
//   - exists: true if active proposals exist
func GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return getImplementation().GetOldestActiveProposalSnapshotTime()
}

// ==================================
// Voting weight snapshot getters
// ==================================

// GetCurrentVotingWeightSnapshot returns the current voting weight snapshot.
//
// Returns:
//   - snapshotHeight: snapshot block height
//   - snapshotTime: snapshot timestamp
//   - err: error if retrieval fails
func GetCurrentVotingWeightSnapshot() (int64, int64, error) {
	return getImplementation().GetCurrentVotingWeightSnapshot()
}
