package governance

func GetProposerByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.Proposer.String()
}

func GetProposalTypeByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.ProposalType
}

func GetYeaByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.Yea.ToString()
}

func GetNayByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.Nay.ToString()
}

func GetConfigVersionByProposalId(proposalId uint64) uint64 {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.ConfigVersion
}

func GetQuorumAmountByProposalId(proposalId uint64) uint64 {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.QuorumAmount
}

func GetTitleByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.Title
}

func GetDescriptionByProposalId(proposalId uint64) string {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.Description
}

func GetExecutionStateByProposalId(proposalId uint64) ExecutionState {
	proposal, exist := proposals[proposalId]
	if !exist {
		panic("PROPOSAL_NOT_FOUND")
	}

	return proposal.ExecutionState
}
