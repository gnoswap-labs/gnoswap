package governance

import (
	"std"
)

// ProposalStatusType represents the current status of a proposal in its lifecycle.
// These statuses determine what actions are available for a proposal.
type ProposalStatusType int

const (
	_                ProposalStatusType = iota
	StatusUpcoming                      // Proposal created but voting hasn't started yet
	StatusActive                        // Proposal is in voting period
	StatusPassed                        // Proposal has passed but hasn't been executed (or is text proposal)
	StatusRejected                      // Proposal failed to meet voting requirements
	StatusExecutable                    // Proposal can be executed (passed and in execution window)
	StatusExecuted                      // Proposal has been successfully executed
	StatusExpired                       // Proposal execution window has passed
	StatusCanceled                      // Proposal has been canceled
)

// String returns the string representation of ProposalStatusType for display purposes.
//
// Returns:
//   - string: human-readable status name
func (s ProposalStatusType) String() string {
	switch s {
	case StatusUpcoming:
		return "upcoming"
	case StatusActive:
		return "active"
	case StatusPassed:
		return "passed"
	case StatusRejected:
		return "rejected"
	case StatusExecutable:
		return "executable"
	case StatusExecuted:
		return "executed"
	case StatusExpired:
		return "expired"
	case StatusCanceled:
		return "canceled"
	default:
		return "unknown"
	}
}

// ProposalStatus manages the complete status of a proposal including scheduling, voting, and actions.
// This is the central status tracking structure that coordinates different aspects of proposal state.
type ProposalStatus struct {
	schedule     *ProposalScheduleStatus // Time-based scheduling information
	actionStatus *ProposalActionStatus   // Execution and cancellation status
	voteStatus   *ProposalVoteStatus     // Voting tallies and requirements
}

// StatusType determines the current status of the proposal based on timing, voting, and actions.
// This is the main status calculation method that considers all factors.
//
// Parameters:
//   - current: current timestamp to evaluate status at
//
// Returns:
//   - ProposalStatusType: current status of the proposal
func (p *ProposalStatus) StatusType(current int64) ProposalStatusType {
	// Check action-based statuses first (these override time-based statuses)
	if p.actionStatus.IsExecuted() {
		return StatusExecuted
	}

	if p.actionStatus.IsCanceled() {
		return StatusCanceled
	}

	// Check time-based statuses
	if !p.schedule.IsPassedActiveAt(current) {
		return StatusUpcoming
	}

	if !p.schedule.IsPassedVotingEndedAt(current) {
		return StatusActive
	}

	// Check voting outcome
	if p.voteStatus.IsRejected() {
		return StatusRejected
	}

	// For passed proposals, check execution status
	if !p.actionStatus.IsExecutable() || !p.schedule.IsPassedExecutableAt(current) {
		return StatusPassed
	}

	if !p.schedule.IsPassedExpiredAt(current) {
		return StatusExecutable
	}

	return StatusExpired
}

// IsUpcoming checks if the proposal is in upcoming status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal is upcoming
func (p *ProposalStatus) IsUpcoming(current int64) bool {
	return p.StatusType(current) == StatusUpcoming
}

// IsActive checks if the proposal is in active voting status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal is active (voting period)
func (p *ProposalStatus) IsActive(current int64) bool {
	return p.StatusType(current) == StatusActive
}

// IsPassed checks if the proposal has passed voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has passed
func (p *ProposalStatus) IsPassed(current int64) bool {
	return p.StatusType(current) == StatusPassed
}

// IsRejected checks if the proposal has been rejected by voting.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal was rejected
func (p *ProposalStatus) IsRejected(current int64) bool {
	return p.StatusType(current) == StatusRejected
}

// IsExecutable checks if the proposal is in executable status.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal can be executed
func (p *ProposalStatus) IsExecutable(current int64) bool {
	return p.StatusType(current) == StatusExecutable
}

// IsExpired checks if the proposal execution window has expired.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has expired
func (p *ProposalStatus) IsExpired(current int64) bool {
	return p.StatusType(current) == StatusExpired
}

// IsExecuted checks if the proposal has been executed.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been executed
func (p *ProposalStatus) IsExecuted(current int64) bool {
	return p.StatusType(current) == StatusExecuted
}

// IsCanceled checks if the proposal has been canceled.
//
// Parameters:
//   - current: timestamp to check status at
//
// Returns:
//   - bool: true if proposal has been canceled
func (p *ProposalStatus) IsCanceled(current int64) bool {
	return p.StatusType(current) == StatusCanceled
}

// YesWeight returns the total weight of "yes" votes.
//
// Returns:
//   - int64: total "yes" vote weight
func (p *ProposalStatus) YesWeight() int64 {
	return p.voteStatus.YesWeight()
}

// NoWeight returns the total weight of "no" votes.
//
// Returns:
//   - int64: total "no" vote weight
func (p *ProposalStatus) NoWeight() int64 {
	return p.voteStatus.NoWeight()
}

// TotalVoteWeight returns the total weight of all votes cast.
//
// Returns:
//   - int64: total vote weight
func (p *ProposalStatus) TotalVoteWeight() int64 {
	return p.voteStatus.TotalVoteWeight()
}

// DiffVoteWeight returns the absolute difference between yes and no votes.
//
// Returns:
//   - int64: absolute difference in vote weights
func (p *ProposalStatus) DiffVoteWeight() int64 {
	return p.voteStatus.DiffVoteWeight()
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
func (p *ProposalStatus) cancel(canceledAt int64, canceledHeight int64, canceledBy std.Address) error {
	return p.actionStatus.cancel(canceledAt, canceledHeight, canceledBy)
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
func (p *ProposalStatus) execute(executedAt int64, executedHeight int64, executedBy std.Address) error {
	return p.actionStatus.execute(executedAt, executedHeight, executedBy)
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
func (p *ProposalStatus) vote(votedYes bool, weight int64) error {
	if votedYes {
		return p.voteStatus.addYesVoteWeight(weight)
	}

	return p.voteStatus.addNoVoteWeight(weight)
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
func (p *ProposalStatus) updateVoteStatus(maxVotingWeight, quorum int64) error {
	return p.voteStatus.updateVoteStatus(maxVotingWeight, quorum)
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
	config Config,
	maxVotingWeight int64,
	executable bool,
	createdAt int64,
) *ProposalStatus {
	return &ProposalStatus{
		// Initialize time-based scheduling
		schedule: NewProposalScheduleStatus(
			config.VotingStartDelay,
			config.VotingPeriod,
			config.ExecutionDelay,
			config.ExecutionWindow,
			createdAt,
		),
		// Initialize action status (execution/cancellation tracking)
		actionStatus: NewProposalActionStatus(executable),
		// Initialize vote status with voting requirements
		voteStatus: NewProposalVoteStatus(
			maxVotingWeight,
			config.Quorum,
		),
	}
}
