package governance

func GetProposerByProposalId(id int64) string {
	return getImplementation().GetProposerByProposalId(id)
}

func GetProposalTypeByProposalId(id int64) string {
	return getImplementation().GetProposalTypeByProposalId(id)
}

func GetYeaByProposalId(id int64) int64 {
	return getImplementation().GetYeaByProposalId(id)
}

func GetNayByProposalId(id int64) int64 {
	return getImplementation().GetNayByProposalId(id)
}

func GetProposalById(id int64) string {
	return getImplementation().GetProposalById(id)
}

func GetVoteStatusFromProposalById(id int64) string {
	return getImplementation().GetVoteStatusFromProposalById(id)
}

func GetVoteByAddressFromProposalById(addr address, id int64) string {
	return getImplementation().GetVoteByAddressFromProposalById(addr, id)
}

func GetConfigVersionByProposalId(id int64) int64 {
	return getImplementation().GetConfigVersionByProposalId(id)
}

func GetQuorumAmountByProposalId(id int64) int64 {
	return getImplementation().GetQuorumAmountByProposalId(id)
}

func GetTitleByProposalId(id int64) string {
	return getImplementation().GetTitleByProposalId(id)
}

func GetDescriptionByProposalId(id int64) string {
	return getImplementation().GetDescriptionByProposalId(id)
}

func GetExecutionStateByProposalId(id int64) string {
	return getImplementation().GetExecutionStateByProposalId(id)
}

func GetLatestConfig() Config {
	return getImplementation().GetLatestConfig()
}

func GetConfig(configVersion int64) Config {
	return getImplementation().GetConfig(configVersion)
}
