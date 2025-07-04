package v2

import (
	"gno.land/p/demo/ufmt"
)

// Dual-Dimension State Model for Governance
//
// This system separates proposal state into two independent dimensions:
//
// 1. ProposalStatus: WHAT happened (passed, rejected, canceled)
//    - Based on voting results and governance decisions
//    - Changes when votes are tallied or admin actions occur
//
// 2. ProposalPhase: WHEN it happened (voting period, execution window)
//    - Based on time progression and deadlines
//    - Changes automatically as time passes
//
// Why separate these?
// - Enables complex queries: "proposals that passed but execution expired"
// - Supports type-specific rules: text proposals never expire, param changes do
// - Avoids state explosion: instead of 20+ combined states, we have 8×5=40 combinations
// - Clear separation: vote logic doesn't need to know about time, time logic doesn't need votes
//
// Example combinations:
// - Status=Passed + Phase=Execution -> can execute now
// - Status=Passed + Phase=ExecutionEnded -> missed execution window
// - Status=Active + Phase=VotingEnded -> voting finished, calculating results

// ProposalStatus represents the logical outcome or decision state of a proposal.
// This reflects the result of governance processes (voting, cancellation, etc.)
// and is independent of time-based progression.
type ProposalStatus uint8

const (
	StatusCreated ProposalStatus = iota
	StatusUpcoming
	StatusActive
	StatusPassed
	StatusRejected
	StatusCanceled
	StatusExecuted
	StatusExpired
)

// ProposalPhase represents the temporal progression of a proposal through
// its lifecycle stages. This tracks time-based transitions independent of
// voting outcomes or governance decisions.
type ProposalPhase uint8

const (
	PhaseCreated ProposalPhase = iota
	PhaseVoting
	PhaseVotingEnded
	PhaseExecution
	PhaseExecutionEnded
)

// TODO: remove `V2` suffix after integration with the main `gov/governance` module

// ProposalStateV2 is an optimized structure for tracking proposal state
// Total size: 12 bytes
//
// StatusPhase field uses bit packing to store both Status and Phase in 8 bits:
// +---+---+---+---+---+---+---+---+
// | S | S | S | S | P | P | P | P |
// +---+---+---+---+---+---+---+---+
//
//	^           ^   ^           ^
//	Status      |   Phase       |
//	(4 bits)    |   (4 bits)    |
//	            |               |
//	            |               +-- Lower 4 bits (0x0F)
//	            +-- Upper 4 bits (0xF0)
//
// Example:
// Status = 2 (Active), Phase = 1 (Voting)
// Binary: 0010 0001
// StatusPhase = 0x21
type ProposalStateV2 struct {
	StatusPhase    uint8  // Upper 4 bits: Status, Lower 4 bits: Phase
	CreatedAt      uint32 // Unix timestamp (sufficient until 2106)
	VotingEndAt    uint32 // Relative to CreatedAt (in seconds)
	ExecutionEndAt uint32 // Relative to VotingEndAt (in seconds)
}

// Status returns the proposal status from the packed StatusPhase field
// Extracts upper 4 bits by right-shifting by 4 positions
// Example: StatusPhase = 0x21 (0010 0001)
//
//	StatusPhase >> 4 = 0010 = 2 (Active)
func (ps *ProposalStateV2) Status() ProposalStatus {
	return ProposalStatus(ps.StatusPhase >> 4)
}

// Phase returns the proposal phase from the packed StatusPhase field
// Extracts lower 4 bits using AND with 0x0F (0000 1111)
// Example: StatusPhase = 0x21 (0010 0001)
//
//	StatusPhase & 0x0F = 0001 = 1 (Voting)
func (ps *ProposalStateV2) Phase() ProposalPhase {
	return ProposalPhase(ps.StatusPhase & 0x0F)
}

// SetStatus updates the status in the packed StatusPhase field
// Preserves existing phase by masking with 0x0F, then ORs with shifted status
// Example: Current StatusPhase = 0x21 (Status=2, Phase=1)
//
//	Setting Status = 3 (Passed)
//	uint8(3) << 4 = 0011 0000
//	StatusPhase & 0x0F = 0000 0001
//	Result: 0011 0001 = 0x31
func (ps *ProposalStateV2) SetStatus(status ProposalStatus) {
	if status > 15 { // 4 bits max value
		panic("ProposalStatus exceeds 4-bit limit")
	}
	ps.StatusPhase = (uint8(status) << 4) | (ps.StatusPhase & 0x0F)
}

// SetPhase updates the phase in the packed StatusPhase field
// Preserves existing status by masking with 0xF0, then ORs with new phase
// Example: Current StatusPhase = 0x21 (Status=2, Phase=1)
//
//	Setting Phase = 2 (VotingEnded)
//	StatusPhase & 0xF0 = 0010 0000
//	uint8(2) = 0000 0010
//	Result: 0010 0010 = 0x22
func (ps *ProposalStateV2) SetPhase(phase ProposalPhase) {
	if phase > 15 { // 4 bits max value
		panic("ProposalPhase exceeds 4-bit limit")
	}
	ps.StatusPhase = (ps.StatusPhase & 0xF0) | uint8(phase)
}

// GetAbsoluteVotingEnd returns the absolute timestamp when voting ends
func (ps *ProposalStateV2) GetAbsoluteVotingEnd() uint64 {
	return uint64(ps.CreatedAt) + uint64(ps.VotingEndAt)
}

// GetAbsoluteExecutionEnd returns the absolute timestamp when execution window ends
func (ps *ProposalStateV2) GetAbsoluteExecutionEnd() uint64 {
	return uint64(ps.CreatedAt) + uint64(ps.VotingEndAt) + uint64(ps.ExecutionEndAt)
}

// SetTimestamps sets the timestamps based on config parameters
func (ps *ProposalStateV2) SetTimestamps(createdAt uint64, votingStartDelay, votingPeriod, executionDelay, executionWindow uint64) {
	ps.CreatedAt = uint32(createdAt)

	// Calculate relative timestamps
	votingEnd := votingStartDelay + votingPeriod
	executionEnd := executionDelay + executionWindow

	// Ensure values fit in uint32
	if votingEnd > uint64(^uint32(0)) {
		panic("VotingEndAt exceeds uint32 limit")
	}
	if executionEnd > uint64(^uint32(0)) {
		panic("ExecutionEndAt exceeds uint32 limit")
	}

	ps.VotingEndAt = uint32(votingEnd)
	ps.ExecutionEndAt = uint32(executionEnd)
}

// IsTerminated returns true if the proposal is in a terminal state
func (ps *ProposalStateV2) IsTerminated() bool {
	status := ps.Status()
	switch status {
	case StatusExecuted, StatusRejected, StatusCanceled, StatusExpired:
		return true
	default:
		return false
	}
}

// String returns a human-readable representation of the proposal state
func (ps *ProposalStateV2) String() string {
	return ufmt.Sprintf("Status: %s, Phase: %s, CreatedAt: %d, VotingEndAt: +%ds, ExecutionEndAt: +%ds",
		ps.Status().String(),
		ps.Phase().String(),
		ps.CreatedAt,
		ps.VotingEndAt,
		ps.ExecutionEndAt,
	)
}

// String returns the string representation of ProposalStatus
func (s ProposalStatus) String() string {
	switch s {
	case StatusCreated:
		return "created"
	case StatusUpcoming:
		return "upcoming"
	case StatusActive:
		return "active"
	case StatusPassed:
		return "passed"
	case StatusRejected:
		return "rejected"
	case StatusCanceled:
		return "canceled"
	case StatusExecuted:
		return "executed"
	case StatusExpired:
		return "expired"
	default:
		return "unknown"
	}
}

// String returns the string representation of ProposalPhase
func (p ProposalPhase) String() string {
	switch p {
	case PhaseCreated:
		return "created"
	case PhaseVoting:
		return "voting"
	case PhaseVotingEnded:
		return "voting_ended"
	case PhaseExecution:
		return "execution"
	case PhaseExecutionEnded:
		return "execution_ended"
	default:
		return "unknown"
	}
}

// CanTransitionTo checks if the current status can transition to the target status
func (s ProposalStatus) CanTransitionTo(target ProposalStatus) bool {
	validTransitions := map[ProposalStatus][]ProposalStatus{
		StatusCreated:  {StatusUpcoming},
		StatusUpcoming: {StatusActive, StatusCanceled},
		StatusActive:   {StatusPassed, StatusRejected, StatusCanceled},
		StatusPassed:   {StatusExecuted, StatusExpired, StatusCanceled},
		StatusRejected: {}, /* Terminal State */
		StatusExecuted: {}, /* Terminal State */
		StatusExpired:  {}, /* Terminal State */
		StatusCanceled: {}, /* Terminal State */
	}

	allowedTargets := validTransitions[s]
	for _, allowed := range allowedTargets {
		if allowed == target {
			return true
		}
	}
	return false
}

// IsTerminal returns true if this is a terminal status
func (s ProposalStatus) IsTerminal() bool {
	switch s {
	case StatusExecuted, StatusRejected, StatusCanceled, StatusExpired:
		return true
	default:
		return false
	}
}

// NewProposalStateV2 creates a new proposal state with initial values
func NewProposalStateV2(createdAt uint64) *ProposalStateV2 {
	ps := &ProposalStateV2{
		CreatedAt: uint32(createdAt),
	}
	ps.SetStatus(StatusCreated)
	ps.SetPhase(PhaseCreated)
	return ps
}

// ValidateProposalStatus checks if a ProposalStatus value is valid
func ValidateProposalStatus(status ProposalStatus) error {
	switch status {
	case StatusCreated, StatusUpcoming, StatusActive, StatusPassed,
		StatusRejected, StatusCanceled, StatusExecuted, StatusExpired:
		return nil
	default:
		return ufmt.Errorf("invalid ProposalStatus: %d", status)
	}
}

// ValidateProposalPhase checks if a ProposalPhase value is valid
func ValidateProposalPhase(phase ProposalPhase) error {
	switch phase {
	case PhaseCreated, PhaseVoting, PhaseVotingEnded,
		PhaseExecution, PhaseExecutionEnded:
		return nil
	default:
		return ufmt.Errorf("invalid ProposalPhase: %d", phase)
	}
}

// ValidateStatusPhaseTransition validates if a status-phase combination is valid
func ValidateStatusPhaseTransition(status ProposalStatus, phase ProposalPhase) error {
	// Define valid status-phase combinations
	validCombinations := map[ProposalStatus][]ProposalPhase{
		StatusCreated:  {PhaseCreated},
		StatusUpcoming: {PhaseCreated},
		StatusActive:   {PhaseVoting},
		StatusPassed:   {PhaseVotingEnded, PhaseExecution, PhaseExecutionEnded},
		StatusRejected: {PhaseVotingEnded, PhaseExecution, PhaseExecutionEnded},
		StatusCanceled: {PhaseCreated, PhaseVoting, PhaseVotingEnded, PhaseExecution},
		StatusExecuted: {PhaseExecution, PhaseExecutionEnded},
		StatusExpired:  {PhaseExecutionEnded},
	}

	validPhases, exists := validCombinations[status]
	if !exists {
		return ufmt.Errorf("invalid status: %s", status.String())
	}

	for _, validPhase := range validPhases {
		if phase == validPhase {
			return nil
		}
	}

	return ufmt.Errorf("invalid status-phase combination: %s-%s", status.String(), phase.String())
}
