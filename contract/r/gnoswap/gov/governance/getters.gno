package governance

// GetProposerByProposalId returns the proposer address of a proposal.
func GetProposerByProposalId(id int64) string {
	return getImplementation().GetProposerByProposalId(id)
}

// GetProposalTypeByProposalId returns the type of a proposal.
func GetProposalTypeByProposalId(id int64) string {
	return getImplementation().GetProposalTypeByProposalId(id)
}

// GetYeaByProposalId returns the yes vote count of a proposal.
func GetYeaByProposalId(id int64) int64 {
	return getImplementation().GetYeaByProposalId(id)
}

// GetNayByProposalId returns the no vote count of a proposal.
func GetNayByProposalId(id int64) int64 {
	return getImplementation().GetNayByProposalId(id)
}

// GetProposalById returns the complete proposal data as JSON.
func GetProposalById(id int64) string {
	return getImplementation().GetProposalById(id)
}

// GetVoteStatusFromProposalById returns the voting status of a proposal.
func GetVoteStatusFromProposalById(id int64) string {
	return getImplementation().GetVoteStatusFromProposalById(id)
}

// GetVoteByAddressFromProposalById returns a user's vote on a proposal.
func GetVoteByAddressFromProposalById(addr address, id int64) string {
	return getImplementation().GetVoteByAddressFromProposalById(addr, id)
}

// GetConfigVersionByProposalId returns the config version used by a proposal.
func GetConfigVersionByProposalId(id int64) int64 {
	return getImplementation().GetConfigVersionByProposalId(id)
}

// GetQuorumAmountByProposalId returns the quorum requirement for a proposal.
func GetQuorumAmountByProposalId(id int64) int64 {
	return getImplementation().GetQuorumAmountByProposalId(id)
}

// GetTitleByProposalId returns the title of a proposal.
func GetTitleByProposalId(id int64) string {
	return getImplementation().GetTitleByProposalId(id)
}

// GetDescriptionByProposalId returns the description of a proposal.
func GetDescriptionByProposalId(id int64) string {
	return getImplementation().GetDescriptionByProposalId(id)
}

// GetExecutionStateByProposalId returns the execution state of a proposal.
func GetExecutionStateByProposalId(id int64) string {
	return getImplementation().GetExecutionStateByProposalId(id)
}

// GetLatestConfig returns the latest governance configuration.
func GetLatestConfig() Config {
	return getImplementation().GetLatestConfig()
}

// GetConfig returns a specific governance configuration by version.
func GetConfig(configVersion int64) Config {
	return getImplementation().GetConfig(configVersion)
}

// GetVoteWeight returns the voting weight of an address for a proposal.
func GetVoteWeight(proposalID int64, address address) int64 {
	return getImplementation().GetVoteWeight(proposalID, address)
}

// GetVotedHeight returns the block height when an address voted on a proposal.
func GetVotedHeight(proposalID int64, address address) int64 {
	return getImplementation().GetVotedHeight(proposalID, address)
}

// GetVotedAt returns the timestamp when an address voted on a proposal.
func GetVotedAt(proposalID int64, address address) int64 {
	return getImplementation().GetVotedAt(proposalID, address)
}

// GetMaxSmoothingPeriod returns the maximum smoothing period for delegation history cleanup.
func GetMaxSmoothingPeriod() int64 {
	return implementation.GetMaxSmoothingPeriod()
}

// GetOldestActiveProposalSnapshotTime returns the oldest snapshot time among active proposals.
func GetOldestActiveProposalSnapshotTime() (int64, bool) {
	return implementation.GetOldestActiveProposalSnapshotTime()
}
