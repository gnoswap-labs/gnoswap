package governance

import (
	"time"
)

func GetProposerByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Proposer.String()
}

func GetProposalTypeByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).ProposalType.String()
}

func GetYeaByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Yea.ToString()
}

func GetNayByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Nay.ToString()
}

func GetConfigVersionByProposalId(proposalId uint64) uint64 {
	return mustGetProposal(proposalId).ConfigVersion
}

func GetQuorumAmountByProposalId(proposalId uint64) uint64 {
	return mustGetProposal(proposalId).QuorumAmount
}

func GetTitleByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Title
}

func GetDescriptionByProposalId(proposalId uint64) string {
	return mustGetProposal(proposalId).Description
}

func GetExecutionStateByProposalId(proposalId uint64) ProposalState {
	proposal := mustGetProposal(proposalId)
	
	// Get current status dynamically
	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
	status := updater.getCurrentStatus()
	
	// Create a synthetic ProposalState for backward compatibility
	syntheticState := ProposalState{
		CreatedAt: proposal.Status.Schedule.CreateTime,
		Upcoming:  status == StatusUpcoming,
		Active:    status == StatusActive,
		Passed:    status == StatusPassed,
		Rejected:  status == StatusRejected,
		Executed:  proposal.Status.ActionState.Executed,
		ExecutedAt: proposal.Status.ActionState.ExecutedAt,
		Canceled:  proposal.Status.ActionState.Canceled,
		CanceledAt: proposal.Status.ActionState.CanceledAt,
		Expired:   status == StatusExpired,
	}
	
	return syntheticState
}
