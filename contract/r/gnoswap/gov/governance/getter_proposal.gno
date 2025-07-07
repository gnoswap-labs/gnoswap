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
	
	// Update state dynamically based on current status
	updater := newProposalStateUpdater(&proposal, uint64(time.Now().Unix()))
	status := updater.getCurrentStatus()
	
	// Build ProposalState based on current status
	state := proposal.State
	
	// Update state fields based on current status
	switch status {
	case StatusUpcoming:
		state.Upcoming = true
		state.Active = false
		state.Passed = false
		state.Rejected = false
		state.Expired = false
	case StatusActive:
		state.Upcoming = false
		state.Active = true
		state.Passed = false
		state.Rejected = false
		state.Expired = false
	case StatusPassed:
		state.Upcoming = false
		state.Active = false
		state.Passed = true
		state.Rejected = false
		state.Expired = false
	case StatusRejected:
		state.Upcoming = false
		state.Active = false
		state.Passed = false
		state.Rejected = true
		state.Expired = false
	case StatusExpired:
		state.Upcoming = false
		state.Active = false
		// Keep passed status if it was passed
		state.Expired = true
	case StatusExecuted:
		// Use existing executed state from ActionState
		if proposal.Status.Schedule.CreateTime != 0 {
			state.Executed = proposal.Status.ActionState.IsExecuted()
		} else {
			state.Executed = proposal.ActionState.IsExecuted()
		}
	case StatusCanceled:
		// Use existing canceled state from ActionState
		if proposal.Status.Schedule.CreateTime != 0 {
			state.Canceled = proposal.Status.ActionState.IsCanceled()
		} else {
			state.Canceled = proposal.ActionState.IsCanceled()
		}
	}
	
	return state
}
