package governance

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/halt"
)

// Test for ReconfigureByAdmin function.
func TestConfig_ReconfigureByAdmin(t *testing.T) {
	tests := []struct {
		name                          string
		isAdmin                       bool
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
			name:                          "Success by admin",
			isAdmin:                       true,
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
			name:                          "Fail: not admin",
			isAdmin:                       false,
			halted:                        false,
			votingStartDelay:              10,
			votingPeriod:                  100,
			votingWeightSmoothingDuration: 20,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                30,
			executionWindow:               60,
			expectedHasPanic:              true,
			expectedPanicMsg:              "unauthorized: caller notadmin is not admin",
		},
		{
			name:                          "Fail: halted",
			isAdmin:                       true,
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
			name:                          "Edge: zero values",
			isAdmin:                       true,
			halted:                        false,
			votingStartDelay:              0,
			votingPeriod:                  0,
			votingWeightSmoothingDuration: 0,
			quorum:                        0,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
			expectedHasPanic:              false,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			defer func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}()

			// given: set realm and halt state
			testing.SetRealm(adminRealm)
			if tc.halted {
				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
			} else {
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}

			if tc.isAdmin {
				testing.SetRealm(adminRealm)
			} else {
				testing.SetRealm(std.NewUserRealm(std.Address("notadmin")))
			}

			if tc.expectedHasPanic {
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					ReconfigureByAdmin(
						cross,
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
				ReconfigureByAdmin(
					cross,
					tc.votingStartDelay,
					tc.votingPeriod,
					tc.votingWeightSmoothingDuration,
					tc.quorum,
					tc.proposalCreationThreshold,
					tc.executionDelay,
					tc.executionWindow,
				)
				cfg, ok := getCurrentConfig()
				uassert.True(t, ok)
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

// Test for ReconfigureByGovernance function.
func TestConfig_ReconfigureByGovernance(t *testing.T) {
	tests := []struct {
		name                          string
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
			name:                          "Fail: not governance",
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
			expectedPanicMsg:              "unauthorized: caller notgov is not governance",
		},
		{
			name:                          "Fail: halted",
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
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given: set realm and halt state
			testing.SetRealm(adminRealm)
			if tc.halted {
				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
			} else {
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}

			if tc.isGovernance {
				testing.SetRealm(govRealm)
			} else {
				testing.SetRealm(std.NewUserRealm(std.Address("notgov")))
			}

			if tc.expectedHasPanic {
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					ReconfigureByGovernance(
						cross,
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
				ReconfigureByGovernance(
					cross,
					tc.votingStartDelay,
					tc.votingPeriod,
					tc.votingWeightSmoothingDuration,
					tc.quorum,
					tc.proposalCreationThreshold,
					tc.executionDelay,
					tc.executionWindow,
				)
				cfg, ok := getCurrentConfig()
				uassert.True(t, ok)
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
			// when: call reconfigure
			nextVersion, cfg := reconfigure(
				tc.votingStartDelay,
				tc.votingPeriod,
				tc.votingWeightSmoothingDuration,
				tc.quorum,
				tc.proposalCreationThreshold,
				tc.executionDelay,
				tc.executionWindow,
			)

			// then: check config state
			uassert.True(t, nextVersion > 0)
			uassert.Equal(t, cfg.VotingStartDelay, tc.votingStartDelay)
			uassert.Equal(t, cfg.VotingPeriod, tc.votingPeriod)
			uassert.Equal(t, cfg.VotingWeightSmoothingDuration, tc.votingWeightSmoothingDuration)
			uassert.Equal(t, cfg.Quorum, tc.quorum)
			uassert.Equal(t, cfg.ProposalCreationThreshold, tc.proposalCreationThreshold)
			uassert.Equal(t, cfg.ExecutionDelay, tc.executionDelay)
			uassert.Equal(t, cfg.ExecutionWindow, tc.executionWindow)
		})
	}
}
