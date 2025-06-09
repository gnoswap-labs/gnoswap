package governance

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
)

func createTestProposal(t *testing.T, createdAt uint64) *ProposalInfo {
	t.Helper()
	return &ProposalInfo{
		// Do not use ProposalType::Text when testing expiration
		// because it will not be expired
		ProposalType: CommunityPoolSpend,
		QuorumAmount: 100,
		Yea:          u256.NewUint(0),
		Nay:          u256.NewUint(0),
		State: ProposalState{
			CreatedAt: createdAt,
			Upcoming:  true,
			Active:    false,
			Passed:    false,
			Rejected:  false,
			Executed:  false,
			Expired:   false,
			Canceled:  false,
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
		status   ProposalStatus
		expected string
	}{
		{StatusUpcoming, "upcoming"},
		{StatusActive, "active"},
		{StatusPassed, "passed"},
		{StatusRejected, "rejected"},
		{StatusExecuted, "executed"},
		{StatusExpired, "expired"},
		{StatusCanceled, "canceled"},
		{ProposalStatus(99), "unknown"},
	}

	for _, tt := range tests {
		t.Run(tt.expected, func(t *testing.T) {
			if got := tt.status.String(); got != tt.expected {
				t.Errorf("ProposalStatus.String() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestProposalStatus_IsTerminated(t *testing.T) {
	tests := []struct {
		status     ProposalStatus
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
				t.Errorf("ProposalStatus.IsTerminated() = %v, want %v", got, tt.terminated)
			}
		})
	}
}

func TestProposalStatus_CanTransitionTo(t *testing.T) {
	tests := []struct {
		from     ProposalStatus
		to       ProposalStatus
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
		{ProposalStatus(99), StatusActive, false},
		{StatusActive, ProposalStatus(99), false},
	}

	for _, tt := range tests {
		t.Run(tt.from.String()+"_to_"+tt.to.String(), func(t *testing.T) {
			if got := tt.from.CanTransitionTo(tt.to); got != tt.expected {
				t.Errorf("ProposalStatus.CanTransitionTo() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestProposalStatus_GetValidTransitions(t *testing.T) {
	tests := []struct {
		status   ProposalStatus
		expected []ProposalStatus
	}{
		{StatusUpcoming, []ProposalStatus{StatusActive, StatusCanceled}},
		{StatusActive, []ProposalStatus{StatusPassed, StatusRejected, StatusCanceled}},
		{StatusPassed, []ProposalStatus{StatusExecuted, StatusExpired, StatusCanceled}},
		{StatusRejected, []ProposalStatus{}},
		{StatusExecuted, []ProposalStatus{}},
		{StatusExpired, []ProposalStatus{}},
		{StatusCanceled, []ProposalStatus{}},
	}

	for _, tt := range tests {
		t.Run(tt.status.String(), func(t *testing.T) {
			got := tt.status.GetValidTransitions()
			if len(got) != len(tt.expected) {
				t.Errorf("ProposalStatus.GetValidTransitions() length = %v, want %v", len(got), len(tt.expected))
				return
			}

			// Convert to sets for comparison
			gotSet := make(map[ProposalStatus]bool)
			expectedSet := make(map[ProposalStatus]bool)

			for _, status := range got {
				gotSet[status] = true
			}
			for _, status := range tt.expected {
				expectedSet[status] = true
			}

			for status := range expectedSet {
				if !gotSet[status] {
					t.Errorf("ProposalStatus.GetValidTransitions() missing %v", status)
				}
			}

			for status := range gotSet {
				if !expectedSet[status] {
					t.Errorf("ProposalStatus.GetValidTransitions() unexpected %v", status)
				}
			}
		})
	}
}

// Test proposalStateUpdater methods
func TestProposalStateUpdater_GetCurrentStatus(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *ProposalInfo
		expected ProposalStatus
	}{
		{
			name: "upcoming_proposal",
			setup: func() *ProposalInfo {
				return createTestProposal(t, 1000)
			},
			expected: StatusUpcoming,
		},
		{
			name: "active_proposal",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = true
				return p
			},
			expected: StatusActive,
		},
		{
			name: "passed_proposal",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Passed = true
				return p
			},
			expected: StatusPassed,
		},
		{
			name: "executed_proposal",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Passed = true
				p.State.Executed = true
				return p
			},
			expected: StatusExecuted,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			proposal := tt.setup()
			updater := newProposalStateUpdater(proposal, 2000)

			if got := updater.getCurrentStatus(); got != tt.expected {
				t.Errorf("getCurrentStatus() = %v, want %v", got, tt.expected)
			}
		})
	}
}

func TestProposalStateUpdater_GetCurrentPhase(t *testing.T) {
	createdAt := uint64(1000)

	// Test timeline:
	// Created: 1000
	// Voting starts: 1000 + 86400 = 87400
	// Voting ends: 87400 + 604800 = 692200
	// Execution starts: 692200 + 86400 = 778600
	// Execution ends: 778600 + 2592000 = 3370600

	tests := []struct {
		name     string
		now      uint64
		expected ProposalPhase
	}{
		{"before_voting", 50000, PhaseCreated},
		{"voting_start", 87400, PhaseVoting},
		{"during_voting", 300000, PhaseVoting},
		{"voting_end", 692200, PhaseVoting},
		{"after_voting", 700000, PhaseVotingEnded},
		{"execution_start", 778600, PhaseExecution},
		{"during_execution", 2000000, PhaseExecution},
		{"execution_end", 3370600, PhaseExecution},
		{"after_execution", 4000000, PhaseExecutionEnded},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
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

func TestProposalStateUpdater_StateTransitions(t *testing.T) {
	createdAt := uint64(1000)

	// Voting starts: 87400, Voting ends: 692200
	// Execution starts: 778600, Execution ends: 3370600

	tests := []struct {
		name           string
		now            uint64
		initialState   func() *ProposalInfo
		expectedStatus ProposalStatus
		expectChange   bool
	}{
		{
			name: "upcoming_to_active",
			now:  300000, // during voting (87400 < 300000 < 692200)
			initialState: func() *ProposalInfo {
				return createTestProposal(t, createdAt)
			},
			expectedStatus: StatusActive,
			expectChange:   true,
		},
		{
			name: "active_to_passed",
			now:  700000, // after voting (692200 < 700000 < 778600)
			initialState: func() *ProposalInfo {
				p := createTestProposal(t, createdAt)
				p.State.Upcoming = false
				p.State.Active = true
				p.Yea = u256.NewUint(150) // Above quorum (100) and more than nay
				p.Nay = u256.NewUint(50)
				return p
			},
			expectedStatus: StatusPassed,
			expectChange:   true,
		},
		{
			name: "active_to_rejected",
			now:  700000, // after voting
			initialState: func() *ProposalInfo {
				p := createTestProposal(t, createdAt)
				p.State.Upcoming = false
				p.State.Active = true
				p.Yea = u256.NewUint(50) // Below quorum
				p.Nay = u256.NewUint(30)
				return p
			},
			expectedStatus: StatusRejected,
			expectChange:   true,
		},
		{
			name: "passed_to_expired",
			now:  4000000, // after execution (3370600 < 4000000)
			initialState: func() *ProposalInfo {
				p := createTestProposal(t, createdAt)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Passed = true
				p.State.PassedAt = 700000
				return p
			},
			expectedStatus: StatusExpired,
			expectChange:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			proposal := tt.initialState()
			updater := newProposalStateUpdater(proposal, tt.now)

			originalStatus := updater.getCurrentStatus()

			t.Logf("Debug - Original status: %s", originalStatus.String())
			t.Logf("Debug - Should update: %v", updater.shouldUpdate())
			t.Logf("Debug - Current phase: %v", updater.getCurrentPhase())

			if updater.shouldUpdate() {
				transitions := updater.getStateTransitions()
				for _, transition := range transitions {
					if transition.from == originalStatus {
						conditionMet := transition.condition()
						t.Logf("Debug - Transition %s: condition = %v", transition.name, conditionMet)
						if conditionMet {
							t.Logf("Debug - Executing transition: %s", transition.name)
						}
					}
				}

				updater.update()
			}

			newStatus := updater.getCurrentStatus()
			t.Logf("Debug - New status: %s", newStatus.String())

			if tt.expectChange {
				if newStatus == originalStatus {
					t.Errorf("Expected status change from %v, but status remained %v",
						originalStatus, newStatus)
				}
				if newStatus != tt.expectedStatus {
					t.Errorf("Expected status %v, got %v", tt.expectedStatus, newStatus)
				}
			} else {
				if newStatus != originalStatus {
					t.Errorf("Expected no status change, but status changed from %v to %v",
						originalStatus, newStatus)
				}
			}
		})
	}
}

func TestProposalStateUpdater_ShouldUpdate(t *testing.T) {
	tests := []struct {
		name     string
		setup    func() *ProposalInfo
		expected bool
	}{
		{
			name: "upcoming_should_update",
			setup: func() *ProposalInfo {
				return createTestProposal(t, 1000)
			},
			expected: true,
		},
		{
			name: "active_should_update",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = true
				return p
			},
			expected: true,
		},
		{
			name: "passed_should_update",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Passed = true
				return p
			},
			expected: true,
		},
		{
			name: "executed_should_not_update",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Passed = true
				p.State.Executed = true
				return p
			},
			expected: false,
		},
		{
			name: "rejected_should_not_update",
			setup: func() *ProposalInfo {
				p := createTestProposal(t, 1000)
				p.State.Upcoming = false
				p.State.Active = false
				p.State.Rejected = true
				return p
			},
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			proposal := tt.setup()
			updater := newProposalStateUpdater(proposal, 2000)

			if got := updater.shouldUpdate(); got != tt.expected {
				t.Errorf("shouldUpdate() = %v, want %v", got, tt.expected)
			}
		})
	}
}
