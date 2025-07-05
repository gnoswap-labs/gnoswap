package v2

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// Test bit-packing operations for StatusPhase field
func TestProposalStateV2_BitOperations(t *testing.T) {
	ps := &ProposalStateV2{}

	// Test setting and getting status
	tests := []struct {
		name   string
		status ProposalStatus
		phase  ProposalPhase
	}{
		{"Created/Created", StatusCreated, PhaseCreated},
		{"Upcoming/Created", StatusUpcoming, PhaseCreated},
		{"Active/Voting", StatusActive, PhaseVoting},
		{"Passed/VotingEnded", StatusPassed, PhaseVotingEnded},
		{"Rejected/VotingEnded", StatusRejected, PhaseVotingEnded},
		{"Executed/ExecutionEnded", StatusExecuted, PhaseExecutionEnded},
		{"Expired/ExecutionEnded", StatusExpired, PhaseExecutionEnded},
		{"Canceled/Execution", StatusCanceled, PhaseExecution},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ps.SetStatus(tt.status)
			ps.SetPhase(tt.phase)

			gotStatus := ps.Status()
			gotPhase := ps.Phase()

			if tt.status != gotStatus {
				t.Errorf("Status mismatch: expected %s, got %s", tt.status, gotStatus)
			}
			if tt.phase != gotPhase {
				t.Errorf("Phase mismatch: expected %s, got %s", tt.phase, gotPhase)
			}

			// Verify bit-packing
			expectedBits := (uint8(tt.status) << 4) | uint8(tt.phase)
			uassert.Equal(t, expectedBits, ps.StatusPhase, "Bit-packing mismatch")
		})
	}
}

// Test that status and phase don't interfere with each other
func TestProposalStateV2_BitIsolation(t *testing.T) {
	ps := &ProposalStateV2{}

	// Set initial values
	ps.SetStatus(StatusActive)
	ps.SetPhase(PhaseVoting)

	// Change only status
	ps.SetStatus(StatusPassed)
	// uassert.Equal(t, StatusPassed, ps.Status(), "Status should change")
	if ps.Status() != StatusPassed {
		t.Errorf("Status should change")
	}
	// uassert.Equal(t, PhaseVoting, ps.Phase(), "Phase should remain unchanged")
	if ps.Phase() != PhaseVoting {
		t.Errorf("Phase should remain unchanged")
	}

	// Change only phase
	ps.SetPhase(PhaseExecution)
	// uassert.Equal(t, StatusPassed, ps.Status(), "Status should remain unchanged")
	if ps.Status() != StatusPassed {
		t.Errorf("Status should remain unchanged")
	}
	// uassert.Equal(t, PhaseExecution, ps.Phase(), "Phase should change")
	if ps.Phase() != PhaseExecution {
		t.Errorf("Phase should change")
	}
}

// Test timestamp calculations
func TestProposalStateV2_TimestampCalculations(t *testing.T) {
	ps := &ProposalStateV2{}

	// Set timestamps
	createdAt := uint64(1700000000)    // Example timestamp
	votingStartDelay := uint64(86400)  // 1 day
	votingPeriod := uint64(604800)     // 7 days
	executionDelay := uint64(86400)    // 1 day
	executionWindow := uint64(2592000) // 30 days

	ps.SetTimestamps(createdAt, votingStartDelay, votingPeriod, executionDelay, executionWindow)

	// Verify stored values
	uassert.Equal(t, uint32(createdAt), ps.CreatedAt, "CreatedAt mismatch")
	uassert.Equal(t, uint32(votingStartDelay+votingPeriod), ps.VotingEndAt, "VotingEndAt mismatch")
	uassert.Equal(t, uint32(executionDelay+executionWindow), ps.ExecutionEndAt, "ExecutionEndAt mismatch")

	// Test absolute timestamp calculations
	expectedVotingEnd := createdAt + votingStartDelay + votingPeriod
	uassert.Equal(t, expectedVotingEnd, ps.GetAbsoluteVotingEnd(), "Absolute voting end mismatch")

	expectedExecutionEnd := createdAt + votingStartDelay + votingPeriod + executionDelay + executionWindow
	uassert.Equal(t, expectedExecutionEnd, ps.GetAbsoluteExecutionEnd(), "Absolute execution end mismatch")
}

// Test IsTerminated method
func TestProposalStateV2_IsTerminated(t *testing.T) {
	tests := []struct {
		name       string
		status     ProposalStatus
		terminated bool
	}{
		{"Created", StatusCreated, false},
		{"Upcoming", StatusUpcoming, false},
		{"Active", StatusActive, false},
		{"Passed", StatusPassed, false},
		{"Rejected", StatusRejected, true},
		{"Canceled", StatusCanceled, true},
		{"Executed", StatusExecuted, true},
		{"Expired", StatusExpired, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ps := &ProposalStateV2{}
			ps.SetStatus(tt.status)
			uassert.Equal(t, tt.terminated, ps.IsTerminated(), "IsTerminated mismatch")
		})
	}
}

// Test ProposalStatus.CanTransitionTo
func TestProposalStatus_CanTransitionTo(t *testing.T) {
	tests := []struct {
		from    ProposalStatus
		to      ProposalStatus
		allowed bool
	}{
		// Valid transitions
		{StatusCreated, StatusUpcoming, true},
		{StatusUpcoming, StatusActive, true},
		{StatusUpcoming, StatusCanceled, true},
		{StatusActive, StatusPassed, true},
		{StatusActive, StatusRejected, true},
		{StatusActive, StatusCanceled, true},
		{StatusPassed, StatusExecuted, true},
		{StatusPassed, StatusExpired, true},
		{StatusPassed, StatusCanceled, true},

		// Invalid transitions
		{StatusCreated, StatusActive, false},
		{StatusCreated, StatusPassed, false},
		{StatusUpcoming, StatusExecuted, false},
		{StatusRejected, StatusExecuted, false},
		{StatusExecuted, StatusExpired, false},
		{StatusCanceled, StatusExecuted, false},
		{StatusExpired, StatusCanceled, false},
	}

	for _, tt := range tests {
		name := tt.from.String() + " -> " + tt.to.String()
		t.Run(name, func(t *testing.T) {
			canTransition := tt.from.CanTransitionTo(tt.to)
			uassert.Equal(t, tt.allowed, canTransition, "Transition validity mismatch")
		})
	}
}

// Test ProposalStatus.IsTerminal
func TestProposalStatus_IsTerminal(t *testing.T) {
	tests := []struct {
		status   ProposalStatus
		terminal bool
	}{
		{StatusCreated, false},
		{StatusUpcoming, false},
		{StatusActive, false},
		{StatusPassed, false},
		{StatusRejected, true},
		{StatusCanceled, true},
		{StatusExecuted, true},
		{StatusExpired, true},
	}

	for _, tt := range tests {
		t.Run(tt.status.String(), func(t *testing.T) {
			isTerminal := tt.status.IsTerminal()
			uassert.Equal(t, tt.terminal, isTerminal, "IsTerminal mismatch")
		})
	}
}

// Test NewProposalStateV2 constructor
func TestNewProposalStateV2(t *testing.T) {
	createdAt := uint64(1700000000)
	ps := NewProposalStateV2(createdAt)

	uassert.Equal(t, uint32(createdAt), ps.CreatedAt, "CreatedAt mismatch")
	// uassert.Equal(t, StatusCreated, ps.Status(), "Initial status should be Created")
	if ps.Status() != StatusCreated {
		t.Errorf("Initial status should be Created")
	}
	// uassert.Equal(t, PhaseCreated, ps.Phase(), "Initial phase should be Created")
	if ps.Phase() != PhaseCreated {
		t.Errorf("Initial phase should be Created")
	}
}

// Test edge cases for bit operations
func TestProposalStateV2_BitOperations_EdgeCases(t *testing.T) {
	ps := &ProposalStateV2{}

	// Test maximum valid values (15 = 0x0F for 4 bits)
	maxStatus := ProposalStatus(7) // We have 8 statuses (0-7)
	maxPhase := ProposalPhase(4)   // We have 5 phases (0-4)

	ps.SetStatus(maxStatus)
	ps.SetPhase(maxPhase)

	if ps.Status() != maxStatus {
		t.Errorf("Max status mismatch")
	}
	if ps.Phase() != maxPhase {
		t.Errorf("Max phase mismatch")
	}
}

// Test timestamp overflow protection
func TestProposalStateV2_TimestampOverflow(t *testing.T) {
	ps := &ProposalStateV2{}

	// Test with values that would overflow uint32
	createdAt := uint64(4294967295) // Max uint32
	votingDelay := uint64(1)
	votingPeriod := uint64(1)

	// This should work
	ps.SetTimestamps(createdAt, votingDelay, votingPeriod, 1, 1)
	uassert.Equal(t, uint32(createdAt), ps.CreatedAt, "Max uint32 should work")

	// Test panic on overflow
	defer func() {
		if r := recover(); r == nil {
			t.Errorf("Expected panic on timestamp overflow")
		}
	}()

	// This should panic
	ps.SetTimestamps(createdAt, uint64(^uint32(0))+1, votingPeriod, 1, 1)
}

// Test validation functions
func TestValidateProposalStatus(t *testing.T) {
	// Valid statuses
	validStatuses := []ProposalStatus{
		StatusCreated, StatusUpcoming, StatusActive, StatusPassed,
		StatusRejected, StatusCanceled, StatusExecuted, StatusExpired,
	}

	for _, status := range validStatuses {
		err := ValidateProposalStatus(status)
		uassert.NoError(t, err, "Valid status should not return error: "+status.String())
	}

	// Invalid status
	invalidStatus := ProposalStatus(99)
	err := ValidateProposalStatus(invalidStatus)
	uassert.Error(t, err, "Invalid status should return error")
}

func TestValidateProposalPhase(t *testing.T) {
	// Valid phases
	validPhases := []ProposalPhase{
		PhaseCreated, PhaseVoting, PhaseVotingEnded,
		PhaseExecution, PhaseExecutionEnded,
	}

	for _, phase := range validPhases {
		err := ValidateProposalPhase(phase)
		uassert.NoError(t, err, "Valid phase should not return error: "+phase.String())
	}

	// Invalid phase
	invalidPhase := ProposalPhase(99)
	err := ValidateProposalPhase(invalidPhase)
	uassert.Error(t, err, "Invalid phase should return error")
}

func TestValidateStatusPhaseTransition(t *testing.T) {
	tests := []struct {
		name   string
		status ProposalStatus
		phase  ProposalPhase
		valid  bool
	}{
		// Valid combinations
		{"Created-Created", StatusCreated, PhaseCreated, true},
		{"Upcoming-Created", StatusUpcoming, PhaseCreated, true},
		{"Active-Voting", StatusActive, PhaseVoting, true},
		{"Passed-VotingEnded", StatusPassed, PhaseVotingEnded, true},
		{"Passed-Execution", StatusPassed, PhaseExecution, true},
		{"Passed-ExecutionEnded", StatusPassed, PhaseExecutionEnded, true},
		{"Rejected-VotingEnded", StatusRejected, PhaseVotingEnded, true},
		{"Executed-Execution", StatusExecuted, PhaseExecution, true},
		{"Executed-ExecutionEnded", StatusExecuted, PhaseExecutionEnded, true},
		{"Expired-ExecutionEnded", StatusExpired, PhaseExecutionEnded, true},
		{"Canceled-Created", StatusCanceled, PhaseCreated, true},
		{"Canceled-Voting", StatusCanceled, PhaseVoting, true},
		{"Canceled-VotingEnded", StatusCanceled, PhaseVotingEnded, true},
		{"Canceled-Execution", StatusCanceled, PhaseExecution, true},

		// Invalid combinations
		{"Created-Voting", StatusCreated, PhaseVoting, false},
		{"Created-Execution", StatusCreated, PhaseExecution, false},
		{"Active-Created", StatusActive, PhaseCreated, false},
		{"Active-Execution", StatusActive, PhaseExecution, false},
		{"Passed-Created", StatusPassed, PhaseCreated, false},
		{"Passed-Voting", StatusPassed, PhaseVoting, false},
		{"Executed-Created", StatusExecuted, PhaseCreated, false},
		{"Executed-Voting", StatusExecuted, PhaseVoting, false},
		{"Expired-Created", StatusExpired, PhaseCreated, false},
		{"Expired-Voting", StatusExpired, PhaseVoting, false},
		{"Expired-Execution", StatusExpired, PhaseExecution, false},
		{"Canceled-ExecutionEnded", StatusCanceled, PhaseExecutionEnded, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateStatusPhaseTransition(tt.status, tt.phase)
			if tt.valid {
				uassert.NoError(t, err, "Valid combination should not return error")
			} else {
				uassert.Error(t, err, "Invalid combination should return error")
			}
		})
	}
}

// Test ProposalType String method
func TestProposalType_String(t *testing.T) {
	tests := []struct {
		proposalType ProposalType
		expected     string
	}{
		{ProposalText, "text"},
		{ProposalParamChange, "parameter_change"},
		{ProposalCommunitySpend, "community_pool_spend"},
		{ProposalRoleChange, "role_change"},
		{ProposalType(99), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			result := tt.proposalType.String()
			uassert.Equal(t, tt.expected, result, "ProposalType.String() mismatch")
		})
	}
}

// Test ValidateProposalType function
func TestValidateProposalType(t *testing.T) {
	// Valid proposal types
	validTypes := []ProposalType{
		ProposalText,
		ProposalParamChange,
		ProposalCommunitySpend,
		ProposalRoleChange,
	}

	for _, proposalType := range validTypes {
		err := ValidateProposalType(proposalType)
		uassert.NoError(t, err, "Valid proposal type should not return error: "+proposalType.String())
	}

	// Invalid proposal types
	invalidTypes := []ProposalType{
		ProposalType(4),
		ProposalType(99),
		ProposalType(255),
	}

	for _, proposalType := range invalidTypes {
		err := ValidateProposalType(proposalType)
		uassert.Error(t, err, "Invalid proposal type should return error")
	}
}
