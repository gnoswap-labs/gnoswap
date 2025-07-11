package governance

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func createTestProposal(t *testing.T, createdAt uint64) *ProposalInfo {
	t.Helper()
	testConfig := createTestConfig()
	schedule := createProposalSchedule(testConfig, createdAt)
	return &ProposalInfo{
		// Do not use Text type when testing expiration
		// because it will not be expired
		Data: ProposalData{
			ProposalType: CommunityPoolSpend,
		},
		Voting: VotingInfo{
			QuorumAmount: 100,
			Yea:          u256.NewUint(0),
			Nay:          u256.NewUint(0),
		},
		Status: ProposalStatus{
			Schedule:    schedule,
			ActionState: ActionState{},
		},
		ConfigVersion: 1,
	}
}

func createTestConfig() Config {
	return Config{
		VotingStartDelay: 100,  // 100 seconds delay
		VotingPeriod:     1000, // 1000 seconds voting period
		ExecutionDelay:   200,  // 200 seconds delay after voting
		ExecutionWindow:  500,  // 500 seconds execution window
	}
}

func TestProposalStatus_String(t *testing.T) {
	tests := []struct {
		status   ProposalStatusEnum
		expected string
	}{
		{StatusUpcoming, "upcoming"},
		{StatusActive, "active"},
		{StatusPassed, "passed"},
		{StatusRejected, "rejected"},
		{StatusExecuted, "executed"},
		{StatusExpired, "expired"},
		{StatusCanceled, "canceled"},
		{ProposalStatusEnum(99), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			if got := tt.status.String(); got != tt.expected {
				t.Errorf("ProposalStatusEnum.String() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestProposalStatus_IsTerminated(t *testing.T) {
	tests := []struct {
		status     ProposalStatusEnum
		terminated bool
	}{
		{StatusUpcoming, false},
		{StatusActive, false},
		{StatusPassed, false},
		{StatusRejected, true},
		{StatusExecuted, true},
		{StatusExpired, true},
		{StatusCanceled, true},
	}

	for _, tt := range tests {
		t.Run(tt.status.String(), func(t *testing.T) {
			if got := tt.status.IsTerminated(); got != tt.terminated {
				t.Errorf("ProposalStatusEnum.IsTerminated() = %v, want %v", got, tt.terminated)
			}
		})
	}
}

func TestProposalStatus_CanTransitionTo(t *testing.T) {
	tests := []struct {
		from     ProposalStatusEnum
		to       ProposalStatusEnum
		expected bool
	}{
		// Valid transitions
		{StatusUpcoming, StatusActive, true},
		{StatusUpcoming, StatusCanceled, true},
		{StatusActive, StatusPassed, true},
		{StatusActive, StatusRejected, true},
		{StatusActive, StatusCanceled, true},
		{StatusPassed, StatusExecuted, true},
		{StatusPassed, StatusExpired, true},
		{StatusPassed, StatusCanceled, true},

		// Invalid transitions
		{StatusUpcoming, StatusPassed, false},
		{StatusUpcoming, StatusExecuted, false},
		{StatusActive, StatusUpcoming, false},
		{StatusActive, StatusExecuted, false},
		{StatusPassed, StatusActive, false},
		{StatusPassed, StatusRejected, false},

		// Terminal states cannot transition
		{StatusRejected, StatusActive, false},
		{StatusExecuted, StatusPassed, false},
		{StatusExpired, StatusExecuted, false},
		{StatusCanceled, StatusActive, false},

		// Invalid status values
		{ProposalStatusEnum(99), StatusActive, false},
		{StatusActive, ProposalStatusEnum(99), false},
	}

	for _, tt := range tests {
		t.Run(tt.from.String()+"_to_"+tt.to.String(), func(t *testing.T) {
			if got := tt.from.CanTransitionTo(tt.to); got != tt.expected {
				t.Errorf("ProposalStatusEnum.CanTransitionTo() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestProposalStateUpdater_GetCurrentPhase(t *testing.T) {
	createdAt := uint64(1000)

	// Test timeline:
	// Created: 1000
	// Voting starts: 1000 + 100 = 1100
	// Voting ends: 1100 + 1000 = 2100
	// Execution starts: 2100 + 200 = 2300
	// Execution ends: 2300 + 500 = 2800

	tests := []struct {
		name     string
		now      uint64
		expected ProposalPhase
	}{
		{"before_voting", 1050, PhaseCreated},
		{"voting_start", 1100, PhaseVoting},
		{"during_voting", 1500, PhaseVoting},
		{"voting_end", 2100, PhaseVoting},
		{"after_voting", 2200, PhaseVotingEnded},
		{"execution_start", 2300, PhaseExecution},
		{"during_execution", 2500, PhaseExecution},
		{"execution_end", 2800, PhaseExecution},
		{"after_execution", 3000, PhaseExecutionEnded},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Save original state and create test state
			originalState := governanceState
			testConfig := createTestConfig()
			testState := NewGovernanceState(testConfig)

			// Temporarily replace global state
			governanceState = testState

			// Restore original state after test
			defer func() {
				governanceState = originalState
			}()

			proposal := createTestProposal(t, createdAt)
			updater := newProposalStateUpdater(proposal, tt.now)

			got := updater.getCurrentPhase()
			if got != tt.expected {
				votingStart, votingEnd := updater.getVotingPeriod()
				execStart, execEnd := updater.getExecutionPeriod()

				t.Logf("Debug - Now: %d, VotingStart: %d, VotingEnd: %d, ExecStart: %d, ExecEnd: %d",
					tt.now, votingStart, votingEnd, execStart, execEnd)

				t.Errorf("getCurrentPhase() = %v (%d), want %v (%d)",
					got, int(got), tt.expected, int(tt.expected))
			}
		})
	}
}
