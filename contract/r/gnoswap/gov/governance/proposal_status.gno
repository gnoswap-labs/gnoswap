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

func NewProposalStatusInstance(
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
func (s *ProposalStatus) Schedule() *ProposalScheduleStatus { return s.schedule }
func (s *ProposalStatus) ActionStatus() *ProposalActionStatus { return s.actionStatus }
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
