package v1

import (
	"gno.land/r/gnoswap/gov/governance"
)

type ProposalStatusResolver struct {
	*governance.ProposalStatus
	scheduleResolver     *ProposalScheduleStatusResolver
	actionStatusResolver *ProposalActionStatusResolver
	voteStatusResolver   *ProposalVoteStatusResolver
}

func NewProposalStatusResolver(status *governance.ProposalStatus) *ProposalStatusResolver {
	return &ProposalStatusResolver{
		ProposalStatus:       status,
		scheduleResolver:     NewProposalScheduleStatusResolver(status.Schedule()),
		actionStatusResolver: NewProposalActionStatusResolver(status.ActionStatus()),
		voteStatusResolver:   NewProposalVoteStatusResolver(status.VoteStatus()),
	}
}

// TotalVoteWeight returns the total weight of all votes cast.
//
// Returns:
//   - int64: total vote weight
func (p *ProposalStatusResolver) TotalVoteWeight() int64 {
	return p.voteStatusResolver.TotalVoteWeight()
}

// StatusType determines the current status of the proposal based on timing, voting, and actions.
// This is the main status calculation method that considers all factors.
//
// Parameters:
//   - current: current timestamp to evaluate status at
//
// Returns:
//   - ProposalStatusType: current status of the proposal
func (p *ProposalStatusResolver) StatusType(current int64) governance.ProposalStatusType {
	actionStatus := p.ActionStatus()

	// Check action-based statuses first (these override time-based statuses)
	if actionStatus.IsExecuted() {
		return governance.StatusExecuted
	}

	if actionStatus.Canceled() {
		return governance.StatusCanceled
	}

	// Check time-based statuses
	if !p.scheduleResolver.IsPassedActiveAt(current) {
		return governance.StatusUpcoming
	}

	if !p.scheduleResolver.IsPassedVotingEndedAt(current) {
		return governance.StatusActive
	}

	// Check voting outcome after voting period ends
	if !p.voteStatusResolver.IsPassed() {
		return governance.StatusRejected
	}

	// For passed proposals, check execution status
	if !p.ActionStatus().IsExecutable() || !p.scheduleResolver.IsPassedExecutableAt(current) {
		return governance.StatusPassed
	}

	if !p.scheduleResolver.IsPassedExpiredAt(current) {
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
func (p *ProposalStatusResolver) IsUpcoming(current int64) bool {
	return p.StatusType(current) == governance.StatusUpcoming
}

// IsActive checks if the proposal is in active voting status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal is active (voting period)
func (p *ProposalStatusResolver) IsActive(current int64) bool {
	return p.StatusType(current) == governance.StatusActive
}

// IsPassed checks if the proposal has passed voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has passed
func (p *ProposalStatusResolver) IsPassed(current int64) bool {
	return p.StatusType(current) == governance.StatusPassed
}

// IsRejected checks if the proposal has been rejected by voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal was rejected
func (p *ProposalStatusResolver) IsRejected(current int64) bool {
	return p.StatusType(current) == governance.StatusRejected
}

// IsExecutable checks if the proposal is in executable status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal can be executed
func (p *ProposalStatusResolver) IsExecutable(current int64) bool {
	return p.StatusType(current) == governance.StatusExecutable
}

// IsExpired checks if the proposal execution window has expired.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has expired
func (p *ProposalStatusResolver) IsExpired(current int64) bool {
	return p.StatusType(current) == governance.StatusExpired
}

// IsExecuted checks if the proposal has been executed.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been executed
func (p *ProposalStatusResolver) IsExecuted(current int64) bool {
	return p.StatusType(current) == governance.StatusExecuted
}

// IsCanceled checks if the proposal has been canceled.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been canceled
func (p *ProposalStatusResolver) IsCanceled(current int64) bool {
	return p.StatusType(current) == governance.StatusCanceled
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
func (p *ProposalStatusResolver) cancel(canceledAt int64, canceledHeight int64, canceledBy address) error {
	return p.actionStatusResolver.cancel(canceledAt, canceledHeight, canceledBy)
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
func (p *ProposalStatusResolver) execute(executedAt int64, executedHeight int64, executedBy address) error {
	return p.actionStatusResolver.Execute(executedAt, executedHeight, executedBy)
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
func (p *ProposalStatusResolver) vote(votedYes bool, weight int64) error {
	if votedYes {
		return p.voteStatusResolver.AddYesVoteWeight(weight)
	}

	return p.voteStatusResolver.AddNoVoteWeight(weight)
}

// NewProposalStatus creates a new proposal status with the specified configuration.
// This initializes all status components with the governance configuration and timing.
//
// Parameters:
//   - config: governance configuration to use
//   - maxVotingWeight: maximum voting weight for this proposal
//   - executable: whether this proposal type can be executed
//   - createdAt: timestamp when proposal was created
//
// Returns:
//   - *ProposalStatus: new proposal status instance
func NewProposalStatus(
	config governance.Config,
	maxVotingWeight int64,
	executable bool,
	createdAt int64,
) *governance.ProposalStatus {
	schedule := NewProposalScheduleStatus(
		config.VotingStartDelay,
		config.VotingPeriod,
		config.ExecutionDelay,
		config.ExecutionWindow,
		createdAt,
	)
	actionStatus := governance.NewProposalActionStatus(executable)

	// Calculate the quorum amount based on the max voting weight and quorum percentage
	quorumAmount := safeMulDiv(maxVotingWeight, config.Quorum, 100)
	voteStatus := governance.NewProposalVoteStatus(maxVotingWeight, quorumAmount)

	return governance.NewProposalStatusBy(schedule, actionStatus, voteStatus)
}
