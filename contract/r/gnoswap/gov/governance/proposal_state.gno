package governance

// ProposalStatusEnum represents the current status of a proposal
type ProposalStatusEnum int

const (
	_ ProposalStatusEnum = iota
	StatusUpcoming
	StatusActive
	StatusPassed
	StatusRejected
	StatusExecuted
	StatusExpired
	StatusCanceled
)

// String returns the string representation of ProposalStatusEnum
func (s ProposalStatusEnum) String() string {
	switch s {
	case StatusUpcoming:
		return "upcoming"
	case StatusActive:
		return "active"
	case StatusPassed:
		return "passed"
	case StatusRejected:
		return "rejected"
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

// IsTerminated returns true if the proposal is in a terminated state
func (s ProposalStatusEnum) IsTerminated() bool {
	switch s {
	case StatusExecuted, StatusRejected, StatusCanceled, StatusExpired:
		return true
	default:
		return false
	}
}

// CanTransitionTo checks if transition to target status is allowed
func (s ProposalStatusEnum) CanTransitionTo(target ProposalStatusEnum) bool {
	validTransitions := map[ProposalStatusEnum][]ProposalStatusEnum{
		StatusUpcoming: {StatusActive, StatusCanceled},
		StatusActive:   {StatusPassed, StatusRejected, StatusCanceled},
		StatusPassed:   {StatusExecuted, StatusExpired, StatusCanceled},
		StatusRejected: {}, // Terminal state
		StatusExecuted: {}, // Terminal state
		StatusExpired:  {}, // Terminal state
		StatusCanceled: {}, // Terminal state
	}

	allowedTargets := validTransitions[s]
	for _, allowed := range allowedTargets {
		if allowed == target {
			return true
		}
	}
	return false
}

// ProposalPhase represents the current phase of a proposal lifecycle
type ProposalPhase int

const (
	PhaseCreated ProposalPhase = iota
	PhaseVoting
	PhaseVotingEnded
	PhaseExecution
	PhaseExecutionEnded
)

// proposalStateUpdater handles the state transitions of a proposal.
type proposalStateUpdater struct {
	proposal *ProposalInfo
	config   Config
	now      uint64
}

// StateTransition represents a single state transition with its conditions and actions
type StateTransition struct {
	name      string
	from      ProposalStatusEnum
	to        ProposalStatusEnum
	condition func() bool
	action    func()
}

// newProposalStateUpdater creates a new proposalStateUpdater.
func newProposalStateUpdater(proposal *ProposalInfo, now uint64) *proposalStateUpdater {
	return &proposalStateUpdater{
		proposal: proposal,
		config:   GetConfigVersion(proposal.ConfigVersion),
		now:      now,
	}
}

// getCurrentStatus returns the current status based on the proposal state
func (u *proposalStateUpdater) getCurrentStatus() ProposalStatusEnum {
	// Priority 1: Check Status field if available
	if u.proposal.Status.Schedule.CreateTime != 0 {
		// Check action-based terminal states first (highest priority)
		if u.proposal.Status.ActionState.IsExecuted() {
			return StatusExecuted
		}
		if u.proposal.Status.ActionState.IsCanceled() {
			return StatusCanceled
		}

		// Then check time-based states using Schedule and votes
		phase := u.getCurrentPhase()
		
		// Check if expired (only for non-text proposals after execution window)
		if u.proposal.ProposalType != Text && phase == PhaseExecutionEnded {
			return StatusExpired
		}

		// Check voting results
		if phase >= PhaseVotingEnded {
			yeaVotes := u.proposal.Yea.Uint64()
			nayVotes := u.proposal.Nay.Uint64()
			if u.isVotingPassed(yeaVotes, nayVotes) {
				return StatusPassed
			} else {
				return StatusRejected
			}
		}

		// Check active voting
		if phase == PhaseVoting {
			return StatusActive
		}

		// Before voting starts
		if phase == PhaseCreated {
			return StatusUpcoming
		}

		return StatusUpcoming
	}

	// Fallback: Use legacy State and ActionState fields
	state := u.proposal.State
	actionState := u.proposal.ActionState

	// Check action-based terminal states first (highest priority)
	if actionState.IsExecuted() {
		return StatusExecuted
	}
	if actionState.IsCanceled() {
		return StatusCanceled
	}

	// Then check time-based terminal states
	if state.Expired {
		return StatusExpired
	}
	if state.Rejected {
		return StatusRejected
	}

	// Check active states
	if state.Passed {
		return StatusPassed
	}
	if state.Active {
		return StatusActive
	}
	if state.Upcoming {
		return StatusUpcoming
	}

	// Fallback (shouldn't happen with proper state management)
	return StatusUpcoming
}

// getCurrentPhase returns the current phase based on time
func (u *proposalStateUpdater) getCurrentPhase() ProposalPhase {
	votingStart, votingEnd := u.getVotingPeriod()
	executionStart, executionEnd := u.getExecutionPeriod()

	switch {
	case u.now < votingStart:
		return PhaseCreated
	case u.now >= votingStart && u.now <= votingEnd:
		return PhaseVoting
	case u.now > votingEnd && u.now < executionStart:
		return PhaseVotingEnded
	case u.now >= executionStart && u.now <= executionEnd:
		return PhaseExecution
	default:
		return PhaseExecutionEnded
	}
}

// shouldUpdate determines if the proposal state should be updated.
func (u *proposalStateUpdater) shouldUpdate() bool {
	currentStatus := u.getCurrentStatus()
	return !currentStatus.IsTerminated()
}

// Time period calculations
func (u *proposalStateUpdater) getVotingPeriod() (start, end uint64) {
	// Use Status.Schedule
	if u.proposal.Status.Schedule.CreateTime != 0 {
		return u.proposal.Status.Schedule.ActiveTime, u.proposal.Status.Schedule.VotingEndTime
	}
	// Fallback to Schedule field for backward compatibility
	if u.proposal.Schedule.CreateTime != 0 {
		return u.proposal.Schedule.ActiveTime, u.proposal.Schedule.VotingEndTime
	}
	// Fallback to calculation for backward compatibility
	start = u.proposal.State.CreatedAt + u.config.VotingStartDelay
	end = start + u.config.VotingPeriod
	return
}

func (u *proposalStateUpdater) getExecutionPeriod() (start, end uint64) {
	// Use Status.Schedule
	if u.proposal.Status.Schedule.CreateTime != 0 {
		return u.proposal.Status.Schedule.ExecutableTime, u.proposal.Status.Schedule.ExpiredTime
	}
	// Fallback to Schedule field for backward compatibility
	if u.proposal.Schedule.CreateTime != 0 {
		return u.proposal.Schedule.ExecutableTime, u.proposal.Schedule.ExpiredTime
	}
	// Fallback to calculation for backward compatibility
	_, votingEnd := u.getVotingPeriod()
	start = votingEnd + u.config.ExecutionDelay
	end = start + u.config.ExecutionWindow
	return
}

// Phase-based condition checks (safer than boolean logic)
func (u *proposalStateUpdater) isVotingPhase() bool {
	return u.getCurrentPhase() == PhaseVoting
}

func (u *proposalStateUpdater) isVotingEndedAndPassed() bool {
	phase := u.getCurrentPhase()
	if phase != PhaseVotingEnded && phase != PhaseExecution && phase != PhaseExecutionEnded {
		return false
	}

	yeaVotes := u.proposal.Yea.Uint64()
	nayVotes := u.proposal.Nay.Uint64()
	return u.isVotingPassed(yeaVotes, nayVotes)
}

func (u *proposalStateUpdater) isVotingEndedAndRejected() bool {
	phase := u.getCurrentPhase()
	if phase != PhaseVotingEnded && phase != PhaseExecution && phase != PhaseExecutionEnded {
		return false
	}

	yeaVotes := u.proposal.Yea.Uint64()
	nayVotes := u.proposal.Nay.Uint64()
	return !u.isVotingPassed(yeaVotes, nayVotes)
}

func (u *proposalStateUpdater) isExecutionExpired() bool {
	// Only non-text proposals can expire
	if u.proposal.ProposalType == Text {
		return false
	}

	return u.getCurrentPhase() == PhaseExecutionEnded
}

// State transition actions
// NOTE: These methods are now empty as state is calculated dynamically from Status.
// They are kept for backward compatibility but will be removed in future versions.
func (u *proposalStateUpdater) startVoting() {
	// State is now calculated dynamically from Status.Schedule
	// No need to update legacy State fields
}

func (u *proposalStateUpdater) markAsPassed() {
	// State is now calculated dynamically from Status.Schedule and votes
	// No need to update legacy State fields
}

func (u *proposalStateUpdater) markAsRejected() {
	// State is now calculated dynamically from Status.Schedule and votes
	// No need to update legacy State fields
}

func (u *proposalStateUpdater) markAsExpired() {
	// State is now calculated dynamically from Status.Schedule
	// No need to update legacy State fields
}

// Helper methods
func (u *proposalStateUpdater) isVotingPassed(yeaVotes, nayVotes uint64) bool {
	return yeaVotes >= u.proposal.QuorumAmount && yeaVotes > nayVotes
}

// isProposalTerminated checks if a proposal is in a terminated state (legacy compatibility)
func isProposalTerminated(proposal ProposalInfo) bool {
	// Priority 1: Check Status.ActionState if available
	if proposal.Status.Schedule.CreateTime != 0 && proposal.Status.ActionState.IsActionTaken() {
		return true
	}
	// Priority 2: Check ActionState field
	if proposal.ActionState.IsActionTaken() {
		return true
	}
	// Then check ProposalStatusEnum
	updater := &proposalStateUpdater{proposal: &proposal}
	return updater.getCurrentStatus().IsTerminated()
}

// createProposalSchedule creates a pre-calculated schedule for a proposal
func createProposalSchedule(config Config, now uint64) ProposalSchedule {
	activeTime := now + config.VotingStartDelay
	votingEndTime := activeTime + config.VotingPeriod
	executableTime := votingEndTime + config.ExecutionDelay
	expiredTime := executableTime + config.ExecutionWindow

	return ProposalSchedule{
		CreateTime:     now,
		ActiveTime:     activeTime,
		VotingEndTime:  votingEndTime,
		ExecutableTime: executableTime,
		ExpiredTime:    expiredTime,
	}
}
