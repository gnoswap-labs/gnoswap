package v1

func (gv *governanceV1) GetVoteWeight(proposalID int64, address address) int64 {
	state := gv.GetGovernanceState()
	proposalUserVotingInfo, ok := state.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedWeight()
}

func (gv *governanceV1) GetVotedHeight(proposalID int64, address address) int64 {
	state := gv.GetGovernanceState()
	proposalUserVotingInfo, ok := state.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedHeight()
}

func (gv *governanceV1) GetVotedAt(proposalID int64, address address) int64 {
	state := gv.GetGovernanceState()
	proposalUserVotingInfo, ok := state.getProposalUserVotingInfo(proposalID, address)
	if !ok {
		panic(errDataNotFound)
	}

	return proposalUserVotingInfo.VotedAt()
}
