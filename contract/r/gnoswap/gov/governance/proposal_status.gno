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
