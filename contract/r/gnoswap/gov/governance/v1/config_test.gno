package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
	"gno.land/r/gnoswap/halt"
)

// Test for Reconfigure function.
func TestConfig_Reconfigure(t *testing.T) {
	tests := []struct {
		name                          string
		isAdmin                       bool
		isGovernance                  bool
		halted                        bool
		votingStartDelay              int64
		votingPeriod                  int64
		votingWeightSmoothingDuration int64
		quorum                        int64
		proposalCreationThreshold     int64
		executionDelay                int64
		executionWindow               int64
		expectedHasPanic              bool
		expectedPanicMsg              string
	}{
		{
			name:                          "Success by governance",
			isAdmin:                       false,
			isGovernance:                  true,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              false,
		},
		{
			name:                          "Success by admin",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              false,
		},
		{
			name:                          "Fail: not governance",
			isAdmin:                       false,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "unauthorized: caller notgov is not admin or governance",
		},
		{
			name:                          "Fail: halted",
			isAdmin:                       false,
			isGovernance:                  true,
			halted:                        true,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "halted: governance",
		},
		{
			name:                          "Fail: negative voting start delay",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              -1,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingStartDelay cannot be negative",
		},
		{
			name:                          "Fail: negative voting period",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  -1,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingPeriod cannot be negative",
		},
		{
			name:                          "Fail: negative execution delay",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                -1,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || executionDelay cannot be negative",
		},
		{
			name:                          "Fail: negative execution window",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               -1,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || executionWindow cannot be negative",
		},
		{
			name:                          "Fail: negative voting weight smoothing duration",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: -1,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingWeightSmoothingDuration cannot be negative",
		},
		{
			name:                          "Fail: negative proposal creation threshold",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     -1,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || proposalCreationThreshold cannot be negative",
		},
		{
			name:                          "Fail: quorum below 0",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        -1,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || quorum must be between 0 and 100",
		},
		{
			name:                          "Fail: quorum above 100",
			isAdmin:                       true,
			isGovernance:                  false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        101,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || quorum must be between 0 and 100",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given: set realm and halt state
			gs := newMockGovernance()

			testing.SetRealm(adminRealm)
			if tc.halted {
				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
			} else {
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}

			// restore halt state after test to ensure no other tests are affected
			defer func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}()

			testing.SetRealm(testing.NewUserRealm(address("notgov")))

			if tc.isAdmin {
				testing.SetRealm(adminRealm)
			}

			if tc.isGovernance {
				testing.SetRealm(govRealm)
			}

			if tc.expectedHasPanic {
				uassert.AbortsContains(t, tc.expectedPanicMsg, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gs.Reconfigure(
							tc.votingStartDelay,
							tc.votingPeriod,
							tc.votingWeightSmoothingDuration,
							tc.quorum,
							tc.proposalCreationThreshold,
							tc.executionDelay,
							tc.executionWindow,
						)
					}(cross)
				})
			} else {
				func (cur realm) {
					testing.SetRealm(govRealm)
					gs.Reconfigure(
						tc.votingStartDelay,
						tc.votingPeriod,
						tc.votingWeightSmoothingDuration,
						tc.quorum,
						tc.proposalCreationThreshold,
						tc.executionDelay,
						tc.executionWindow,
					)
				}(cross)
				cfg := gs.GetLatestConfig()
				uassert.NotNil(t, cfg)
				uassert.Equal(t, cfg.VotingStartDelay, tc.votingStartDelay)
				uassert.Equal(t, cfg.VotingPeriod, tc.votingPeriod)
				uassert.Equal(t, cfg.VotingWeightSmoothingDuration, tc.votingWeightSmoothingDuration)
				uassert.Equal(t, cfg.Quorum, tc.quorum)
				uassert.Equal(t, cfg.ProposalCreationThreshold, tc.proposalCreationThreshold)
				uassert.Equal(t, cfg.ExecutionDelay, tc.executionDelay)
				uassert.Equal(t, cfg.ExecutionWindow, tc.executionWindow)
			}
		})
	}
}

// Test for reconfigure function (private).
func TestConfig_reconfigure(t *testing.T) {
	tests := []struct {
		name                          string
		votingStartDelay              int64
		votingPeriod                  int64
		votingWeightSmoothingDuration int64
		quorum                        int64
		proposalCreationThreshold     int64
		executionDelay                int64
		executionWindow               int64
	}{
		{
			name:                          "Normal values",
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
		},
		{
			name:                          "Edge: zero values",
			votingStartDelay:              0,
			votingPeriod:                  0,
			votingWeightSmoothingDuration: 0,
			quorum:                        0,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			gs := newMockGovernance()

			func (cur realm) {
				// given: create config directly
				cfg := governance.Config{
					VotingStartDelay:              tc.votingStartDelay,
					VotingPeriod:                  tc.votingPeriod,
					VotingWeightSmoothingDuration: tc.votingWeightSmoothingDuration,
					Quorum:                        tc.quorum,
					ProposalCreationThreshold:     tc.proposalCreationThreshold,
					ExecutionDelay:                tc.executionDelay,
					ExecutionWindow:               tc.executionWindow,
				}

				// when: call reconfigure
				nextVersion := gs.reconfigure(cfg)

				// then: check config state
				uassert.True(t, nextVersion > 0)
				uassert.Equal(t, cfg.VotingStartDelay, tc.votingStartDelay)
				uassert.Equal(t, cfg.VotingPeriod, tc.votingPeriod)
				uassert.Equal(t, cfg.VotingWeightSmoothingDuration, tc.votingWeightSmoothingDuration)
				uassert.Equal(t, cfg.Quorum, tc.quorum)
				uassert.Equal(t, cfg.ProposalCreationThreshold, tc.proposalCreationThreshold)
				uassert.Equal(t, cfg.ExecutionDelay, tc.executionDelay)
				uassert.Equal(t, cfg.ExecutionWindow, tc.executionWindow)
			}(cross)
		})
	}
}

// Test for makeConfig function.
func TestConfig_makeConfig(t *testing.T) {
	tests := []struct {
		name                          string
		votingStartDelay              int64
		votingPeriod                  int64
		votingWeightSmoothingDuration int64
		quorum                        int64
		proposalCreationThreshold     int64
		executionDelay                int64
		executionWindow               int64
		expectedHasPanic              bool
		expectedPanicMsg              string
	}{
		{
			name:                          "Success: normal config",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              false,
		},
		{
			name:                          "Success: zero values",
			votingStartDelay:              0,
			votingPeriod:                  0,
			votingWeightSmoothingDuration: 0,
			quorum:                        0,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
			expectedHasPanic:              false,
		},
		{
			name:                          "Success: max quorum",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        100,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              false,
		},
		{
			name:                          "Fail: negative voting start delay",
			votingStartDelay:              -1,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingStartDelay cannot be negative",
		},
		{
			name:                          "Fail: quorum above 100",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        101,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || quorum must be between 0 and 100",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedHasPanic {
				// when & then
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					makeConfig(
						tc.votingStartDelay,
						tc.votingPeriod,
						tc.votingWeightSmoothingDuration,
						tc.quorum,
						tc.proposalCreationThreshold,
						tc.executionDelay,
						tc.executionWindow,
					)
				})
			} else {
				// when
				cfg := makeConfig(
					tc.votingStartDelay,
					tc.votingPeriod,
					tc.votingWeightSmoothingDuration,
					tc.quorum,
					tc.proposalCreationThreshold,
					tc.executionDelay,
					tc.executionWindow,
				)

				// then
				uassert.Equal(t, cfg.VotingStartDelay, tc.votingStartDelay)
				uassert.Equal(t, cfg.VotingPeriod, tc.votingPeriod)
				uassert.Equal(t, cfg.VotingWeightSmoothingDuration, tc.votingWeightSmoothingDuration)
				uassert.Equal(t, cfg.Quorum, tc.quorum)
				uassert.Equal(t, cfg.ProposalCreationThreshold, tc.proposalCreationThreshold)
				uassert.Equal(t, cfg.ExecutionDelay, tc.executionDelay)
				uassert.Equal(t, cfg.ExecutionWindow, tc.executionWindow)
			}
		})
	}
}
