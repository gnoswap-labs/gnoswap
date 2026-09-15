package governance

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
//   - string: lowercase status name, or "unknown" for an unrecognized value
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

// NewProposalStatusBy combines schedule, action, and vote state into a proposal status.
//
// Parameters:
//   - schedule: time-based lifecycle schedule for the proposal
//   - actionStatus: execution and cancellation state for the proposal
//   - voteStatus: vote tallies and voting requirements for the proposal
//
// Returns:
//   - *ProposalStatus: status object containing the supplied lifecycle components
func NewProposalStatusBy(
	schedule *ProposalScheduleStatus,
	actionStatus *ProposalActionStatus,
	voteStatus *ProposalVoteStatus,
) *ProposalStatus {
	return &ProposalStatus{
		schedule:     schedule,
		actionStatus: actionStatus,
		voteStatus:   voteStatus,
	}
}

/* Getter methods */
// Schedule returns the proposal's time-based scheduling state.
//
// Returns:
//   - *ProposalScheduleStatus: schedule containing proposal lifecycle timestamps
func (s *ProposalStatus) Schedule() *ProposalScheduleStatus { return s.schedule }

// ActionStatus returns the proposal's execution and cancellation state.
//
// Returns:
//   - *ProposalActionStatus: action state associated with the proposal
func (s *ProposalStatus) ActionStatus() *ProposalActionStatus { return s.actionStatus }

// VoteStatus returns the proposal's vote tallies and voting requirements.
//
// Returns:
//   - *ProposalVoteStatus: vote state associated with the proposal
func (s *ProposalStatus) VoteStatus() *ProposalVoteStatus { return s.voteStatus }

/* Delegation getters for vote data */

// YesWeight returns the total weight of "yes" votes.
//
// Returns:
//   - int64: total "yes" vote weight
func (s *ProposalStatus) YesWeight() int64 {
	return s.voteStatus.YesWeight()
}

// NoWeight returns the total weight of "no" votes.
//
// Returns:
//   - int64: total "no" vote weight
func (s *ProposalStatus) NoWeight() int64 {
	return s.voteStatus.NoWeight()
}

// Clone creates a deep copy of the ProposalStatus, or nil when the
// receiver is nil.
//
// Returns:
//   - *ProposalStatus: independent copy of the status, or nil for a nil receiver
func (s *ProposalStatus) Clone() *ProposalStatus {
	if s == nil {
		return nil
	}

	return &ProposalStatus{
		schedule:     s.schedule.Clone(),
		actionStatus: s.actionStatus.Clone(),
		voteStatus:   s.voteStatus.Clone(),
	}
}
