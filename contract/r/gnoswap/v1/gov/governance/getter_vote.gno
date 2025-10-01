package governance

func GetVoteWeight(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedWeight()
}

func GetVotedHeight(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.votedHeight
}

func GetVotedAt(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.votedAt
}
