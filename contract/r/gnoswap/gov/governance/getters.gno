package governance

func GetProposalById(id int64) string {
	return getImplementation().GetProposalById(id)
}

func GetVoteStatusFromProposalById(id int64) string {
	return getImplementation().GetVoteStatusFromProposalById(id)
}

func GetVoteByAddressFromProposalById(addr address, id int64) string {
	return getImplementation().GetVoteByAddressFromProposalById(addr, id)
}
