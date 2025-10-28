package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalStatusResolver struct {}

func NewProposalStatusResolver() *ProposalStatusResolver {
	return &ProposalStatusResolver{}
}

// StatusType determines the current status of the proposal based on timing, voting, and actions.
// This is the main status calculation method that considers all factors.
//
// Parameters:
//   - current: current timestamp to evaluate status at
//
// Returns:
//   - ProposalStatusType: current status of the proposal
func (p *ProposalStatusResolver) StatusType(status *governance.ProposalStatus, current int64) governance.ProposalStatusType {
	// actionStatus := p.ActionStatus()

	// Check action-based statuses first (these override time-based statuses)
	if status.ActionStatus().IsExecuted() {
		return governance.StatusExecuted
	}

	if status.ActionStatus().IsCanceled() {
		return governance.StatusCanceled
	}

	schedule := status.Schedule()

	// Check time-based statuses
	if !schedule.IsPassedActiveAt(current) {
		return governance.StatusUpcoming
	}

	if !schedule.IsPassedVotingEndedAt(current) {
		return governance.StatusActive
	}

	voteStatus := status.VoteStatus()

	// Check voting outcome
	if voteStatus.IsRejected() {
		return governance.StatusRejected
	}

	// For passed proposals, check execution status
	if !status.ActionStatus().IsExecutable() || !schedule.IsPassedExecutableAt(current) {
		return governance.StatusPassed
	}

	if !schedule.IsPassedExpiredAt(current) {
		return governance.StatusExecutable
	}

	return governance.StatusExpired
}

// IsUpcoming checks if the proposal is in upcoming status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal is upcoming
func (p *ProposalStatusResolver) IsUpcoming(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusUpcoming
}

// IsActive checks if the proposal is in active voting status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal is active (voting period)
func (p *ProposalStatusResolver) IsActive(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusActive
}

// IsPassed checks if the proposal has passed voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has passed
func (p *ProposalStatusResolver) IsPassed(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusPassed
}

// IsRejected checks if the proposal has been rejected by voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal was rejected
func (p *ProposalStatusResolver) IsRejected(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusRejected
}

// IsExecutable checks if the proposal is in executable status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal can be executed
func (p *ProposalStatusResolver) IsExecutable(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusExecutable
}

// IsExpired checks if the proposal execution window has expired.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has expired
func (p *ProposalStatusResolver) IsExpired(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusExpired
}

// IsExecuted checks if the proposal has been executed.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been executed
func (p *ProposalStatusResolver) IsExecuted(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusExecuted
}

// IsCanceled checks if the proposal has been canceled.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been canceled
func (p *ProposalStatusResolver) IsCanceled(status *governance.ProposalStatus, current int64) bool {
	return p.StatusType(status, current) == governance.StatusCanceled
}

// cancel marks the proposal as canceled with the provided details.
// This delegates to the action status for actual cancellation logic.
//
// Parameters:
//   - canceledAt: timestamp when proposal was canceled
//   - canceledHeight: block height when proposal was canceled
//   - canceledBy: address that canceled the proposal
//
// Returns:
//   - error: cancellation error if operation fails
func (p *ProposalStatusResolver) cancel(status *governance.ProposalStatus, canceledAt int64, canceledHeight int64, canceledBy address) error {
	return status.ActionStatus().Cancel(canceledAt, canceledHeight, canceledBy)
}

// execute marks the proposal as executed with the provided details.
// This delegates to the action status for actual execution logic.
//
// Parameters:
//   - executedAt: timestamp when proposal was executed
//   - executedHeight: block height when proposal was executed
//   - executedBy: address that executed the proposal
//
// Returns:
//   - error: execution error if operation fails
func (p *ProposalStatusResolver) execute(status *governance.ProposalStatus, executedAt int64, executedHeight int64, executedBy address) error {
	return status.ActionStatus().Execute(executedAt, executedHeight, executedBy)
}

// vote records a vote on the proposal and updates vote tallies.
// This delegates to the vote status for actual vote recording.
//
// Parameters:
//   - votedYes: true for "yes" vote, false for "no" vote
//   - weight: voting weight to apply
//
// Returns:
//   - error: voting error if operation fails
func (p *ProposalStatusResolver) vote(status *governance.ProposalStatus, votedYes bool, weight int64) error {
	if votedYes {
		return status.VoteStatus().AddYesVoteWeight(weight)
	}

	return status.VoteStatus().AddNoVoteWeight(weight)
}

// updateVoteStatus updates the voting parameters and recalculates requirements.
// This is used when voting parameters change dynamically.
//
// Parameters:
//   - maxVotingWeight: updated maximum voting weight
//   - quorum: updated quorum percentage
//
// Returns:
//   - error: update error if operation fails
func (p *ProposalStatusResolver) updateVoteStatus(status *governance.ProposalStatus, maxVotingWeight, quorum int64) error {
	return status.VoteStatus().UpdateVoteStatus(maxVotingWeight, quorum)
}
