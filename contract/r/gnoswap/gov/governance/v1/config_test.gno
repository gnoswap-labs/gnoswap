package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	// "gno.land/r/gnoswap/halt"
)

// Test for Reconfigure function.
// func TestConfig_Reconfigure(t *testing.T) {
// 	tests := []struct {
// 		name                          string
// 		isAdmin                       bool
// 		isGovernance                  bool
// 		halted                        bool
// 		votingStartDelay              int64
// 		votingPeriod                  int64
// 		votingWeightSmoothingDuration int64
// 		quorum                        int64
// 		proposalCreationThreshold     int64
// 		executionDelay                int64
// 		executionWindow               int64
// 		expectedHasPanic              bool
// 		expectedPanicMsg              string
// 	}{
// 		{
// 			name:                          "Success by governance",
// 			isAdmin:                       false,
// 			isGovernance:                  true,
// 			halted:                        false,
// 			votingStartDelay:              10,
// 			votingPeriod:                  100,
// 			votingWeightSmoothingDuration: 20,
// 			quorum:                        50,
// 			proposalCreationThreshold:     1000,
// 			executionDelay:                30,
// 			executionWindow:               60,
// 			expectedHasPanic:              false,
// 		},
// 		{
// 			name:                          "Success by admin",
// 			isAdmin:                       true,
// 			isGovernance:                  false,
// 			halted:                        false,
// 			votingStartDelay:              10,
// 			votingPeriod:                  100,
// 			votingWeightSmoothingDuration: 20,
// 			quorum:                        50,
// 			proposalCreationThreshold:     1000,
// 			executionDelay:                30,
// 			executionWindow:               60,
// 			expectedHasPanic:              false,
// 		},
// 		{
// 			name:                          "Fail: not governance",
// 			isAdmin:                       false,
// 			isGovernance:                  false,
// 			halted:                        false,
// 			votingStartDelay:              10,
// 			votingPeriod:                  100,
// 			votingWeightSmoothingDuration: 20,
// 			quorum:                        50,
// 			proposalCreationThreshold:     1000,
// 			executionDelay:                30,
// 			executionWindow:               60,
// 			expectedHasPanic:              true,
// 			expectedPanicMsg:              "unauthorized: caller notgov is not admin or governance",
// 		},
// 		{
// 			name:                          "Fail: halted",
// 			isAdmin:                       false,
// 			isGovernance:                  true,
// 			halted:                        true,
// 			votingStartDelay:              10,
// 			votingPeriod:                  100,
// 			votingWeightSmoothingDuration: 20,
// 			quorum:                        50,
// 			proposalCreationThreshold:     1000,
// 			executionDelay:                30,
// 			executionWindow:               60,
// 			expectedHasPanic:              true,
// 			expectedPanicMsg:              "halted: governance",
// 		},
// 	}

// 	for _, tc := range tests {
// 		t.Run(tc.name, func(t *testing.T) {
// 			// given: set realm and halt state
// 			gs := newMockGovernance()
// 			state := gs.GetGovernanceState()

// 			testing.SetRealm(adminRealm)
// 			if tc.halted {
// 				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
// 			} else {
// 				halt.SetHaltLevel(cross, halt.HaltLevelNone)
// 			}

// 			testing.SetRealm(testing.NewUserRealm(address("notgov")))

// 			if tc.isAdmin {
// 				testing.SetRealm(adminRealm)
// 			}

// 			if tc.isGovernance {
// 				testing.SetRealm(govRealm)
// 			}

// 			if tc.expectedHasPanic {
// 				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
// 					func (cur realm) {
// 						testing.SetRealm(govRealm)
// 						gs.Reconfigure(
// 							tc.votingStartDelay,
// 							tc.votingPeriod,
// 							tc.votingWeightSmoothingDuration,
// 							tc.quorum,
// 							tc.proposalCreationThreshold,
// 							tc.executionDelay,
// 							tc.executionWindow,
// 						)
// 					}(cross)
// 				})
// 			} else {
// 				func (cur realm) {
// 					testing.SetRealm(govRealm)
// 					gs.Reconfigure(
// 						tc.votingStartDelay,
// 						tc.votingPeriod,
// 						tc.votingWeightSmoothingDuration,
// 						tc.quorum,
// 						tc.proposalCreationThreshold,
// 						tc.executionDelay,
// 						tc.executionWindow,
// 					)
// 				}(cross)
// 				cfg, ok := state.getCurrentConfig()
// 				uassert.True(t, ok)
// 				uassert.Equal(t, cfg.VotingStartDelay, tc.votingStartDelay)
// 				uassert.Equal(t, cfg.VotingPeriod, tc.votingPeriod)
// 				uassert.Equal(t, cfg.VotingWeightSmoothingDuration, tc.votingWeightSmoothingDuration)
// 				uassert.Equal(t, cfg.Quorum, tc.quorum)
// 				uassert.Equal(t, cfg.ProposalCreationThreshold, tc.proposalCreationThreshold)
// 				uassert.Equal(t, cfg.ExecutionDelay, tc.executionDelay)
// 				uassert.Equal(t, cfg.ExecutionWindow, tc.executionWindow)
// 			}
// 		})
// 	}
// }

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
				// when: call reconfigure
				nextVersion, cfg := gs.reconfigure(
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
			}(cross)
		})
	}
}
