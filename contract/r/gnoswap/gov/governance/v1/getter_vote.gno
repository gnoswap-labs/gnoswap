package v1

func (gv *governanceV1) GetVoteWeight(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := gv.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedWeight()
}

func (gv *governanceV1) GetVotedHeight(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := gv.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedHeight()
}

func (gv *governanceV1) GetVotedAt(proposalID int64, address address) int64 {
	proposalUserVotingInfo, ok := gv.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedAt()
}
