package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// Test for assertIsValidConfig function.
func TestAssert_assertIsValidConfig(t *testing.T) {
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
			name:                          "Success: quorum at 100",
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
			name:                          "Fail: negative voting period",
			votingStartDelay:              100,
			votingPeriod:                  -1,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingPeriod cannot be negative",
		},
		{
			name:                          "Fail: negative execution delay",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                -1,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || executionDelay cannot be negative",
		},
		{
			name:                          "Fail: negative execution window",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               -1,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || executionWindow cannot be negative",
		},
		{
			name:                          "Fail: negative voting weight smoothing duration",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: -1,
			quorum:                        50,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingWeightSmoothingDuration cannot be negative",
		},
		{
			name:                          "Fail: negative proposal creation threshold",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        50,
			proposalCreationThreshold:     -1,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || proposalCreationThreshold cannot be negative",
		},
		{
			name:                          "Fail: quorum below 0",
			votingStartDelay:              100,
			votingPeriod:                  200,
			votingWeightSmoothingDuration: 50,
			quorum:                        -1,
			proposalCreationThreshold:     1000,
			executionDelay:                100,
			executionWindow:               200,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || quorum must be between 0 and 100",
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
		{
			name:                          "Fail: overflow at step 1 (currentTime + votingStartDelay)",
			votingStartDelay:              math.MaxInt64,
			votingPeriod:                  0,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || currentTime + votingStartDelay exceeds MaxInt64",
		},
		{
			name:                          "Fail: overflow at step 2 (activeTime + votingPeriod)",
			votingStartDelay:              math.MaxInt64 / 2,
			votingPeriod:                  math.MaxInt64 / 2,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || activeTime + votingPeriod exceeds MaxInt64",
		},
		{
			name:                          "Fail: overflow at step 3 (votingEndTime + executionDelay)",
			votingStartDelay:              math.MaxInt64 / 3,
			votingPeriod:                  math.MaxInt64 / 3,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                math.MaxInt64 / 3,
			executionWindow:               0,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || votingEndTime + executionDelay exceeds MaxInt64",
		},
		{
			name:                          "Fail: overflow at step 4 (executableTime + executionWindow)",
			votingStartDelay:              math.MaxInt64 / 4,
			votingPeriod:                  math.MaxInt64 / 4,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                math.MaxInt64 / 4,
			executionWindow:               math.MaxInt64 / 4,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || executableTime + executionWindow exceeds MaxInt64",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			cfg := governance.Config{
				VotingStartDelay:              tc.votingStartDelay,
				VotingPeriod:                  tc.votingPeriod,
				VotingWeightSmoothingDuration: tc.votingWeightSmoothingDuration,
				Quorum:                        tc.quorum,
				ProposalCreationThreshold:     tc.proposalCreationThreshold,
				ExecutionDelay:                tc.executionDelay,
				ExecutionWindow:               tc.executionWindow,
			}

			if tc.expectedHasPanic {
				// when & then
				uassert.AbortsWithMessage(t, tc.expectedPanicMsg, func() {
					func(cur realm) {
						assertIsValidConfig(cfg)
					}(cross)
				})
			} else {
				// when & then
				func(cur realm) {
					assertIsValidConfig(cfg)
				}(cross)
			}
		})
	}
}
