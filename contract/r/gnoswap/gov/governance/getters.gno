package governance

import "gno.land/p/nt/ufmt"

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

// GetProposalCount returns the total number of proposals.
func GetProposalCount() int {
	return getImplementation().GetProposalCount()
}

// GetProposalIDs returns a paginated list of proposal IDs.
func GetProposalIDs(offset, count int) []int64 {
	return getImplementation().GetProposalIDs(offset, count)
}

// ExistsProposal checks if a proposal exists.
func ExistsProposal(proposalID int64) bool {
	return getImplementation().ExistsProposal(proposalID)
}

// GetProposal returns a proposal by ID.
// Returns a clone to prevent external modification.
func GetProposal(proposalID int64) (*Proposal, error) {
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}
	return proposal.Clone(), nil
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
	proposal, err := getImplementation().GetProposal(proposalId)
	if err != nil {
		return 0, err
	}

	return proposal.CreatedAt(), nil
}

// GetProposalCreatedHeight returns the creation block height of a proposal.
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
// Returns:
//   - quorum: minimum vote weight required for proposal to pass
//   - maxVotingWeight: maximum possible voting weight
//   - yesWeight: total weight of "yes" votes
//   - noWeight: total weight of "no" votes
func GetVoteStatus(proposalId int64) (quorum, maxVotingWeight, yesWeight, noWeight int64, err error) {
	return getImplementation().GetVoteStatus(proposalId)
}

// GetVotingInfoCount returns the number of voters for a proposal.
func GetVotingInfoCount(proposalID int64) int {
	return getImplementation().GetVotingInfoCount(proposalID)
}

// GetVotingInfoAddresses returns a paginated list of voter addresses for a proposal.
func GetVotingInfoAddresses(proposalID int64, offset, count int) []address {
	return getImplementation().GetVotingInfoAddresses(proposalID, offset, count)
}

// ExistsVotingInfo checks if a voting info exists for a user on a proposal.
func ExistsVotingInfo(proposalID int64, addr address) bool {
	return getImplementation().ExistsVotingInfo(proposalID, addr)
}

// GetVotingInfo returns the voting info for a user on a proposal.
// Returns a clone to prevent external modification.
func GetVotingInfo(proposalID int64, addr address) (*VotingInfo, error) {
	votingInfo, err := getImplementation().GetVotingInfo(proposalID, addr)
	if err != nil {
		return nil, err
	}
	return votingInfo.Clone(), nil
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
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}

	proposalData := proposal.Data()
	if proposalData == nil || proposalData.CommunityPoolSpend() == nil {
		return nil, ufmt.Errorf("proposal is not a community pool spend proposal")
	}

	return proposalData.CommunityPoolSpend().Clone(), nil
}

// GetProposalExecutionInfo returns the execution info for a proposal.
func GetProposalExecutionInfo(proposalID int64) (*ExecutionInfo, error) {
	proposal, err := getImplementation().GetProposal(proposalID)
	if err != nil {
		return nil, err
	}

	proposalData := proposal.Data()

	if proposalData == nil || proposalData.Execution() == nil {
		return nil, ufmt.Errorf("proposal is not a parameter change proposal")
	}

	return proposalData.Execution().Clone(), nil
}

// ==================================
// User Proposal Getters
// ==================================

// GetUserProposalCount returns the number of proposals created by a user.
func GetUserProposalCount(user address) int {
	return getImplementation().GetUserProposalCount(user)
}

// GetUserProposalIDs returns a paginated list of proposal IDs created by a user.
func GetUserProposalIDs(user address, offset, count int) []int64 {
	return getImplementation().GetUserProposalIDs(user, offset, count)
}

// ==================================
// Active Proposal Query
// ==================================

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
func GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return getImplementation().GetOldestActiveProposalSnapshotTime()
}
