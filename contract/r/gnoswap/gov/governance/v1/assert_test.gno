package v1

import (
	"math"
	"testing"

	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/gov/governance"
)

// Test for assertIsValidConfigRanges function.
func TestAssert_assertIsValidConfigRanges(t *testing.T) {
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
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					assertIsValidConfigRanges(cfg)
				})
			} else {
				// when & then
				uassert.NotPanics(t, func() {
					assertIsValidConfigRanges(cfg)
				})
			}
		})
	}
}

// Test for assertIsNotOverflowDelay function.
func TestAssert_assertIsNotOverflowDelay(t *testing.T) {
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
			name:                          "Success: max safe values",
			votingStartDelay:              math.MaxInt64 / 10,
			votingPeriod:                  math.MaxInt64 / 10,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                math.MaxInt64 / 10,
			executionWindow:               math.MaxInt64 / 10,
			expectedHasPanic:              false,
		},
		{
			name:                          "Fail: overflow at step 2 (sum + votingPeriod)",
			votingStartDelay:              math.MaxInt64 / 2 + 1,
			votingPeriod:                  math.MaxInt64 / 2 + 1,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                0,
			executionWindow:               0,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
		},
		{
			name:                          "Fail: overflow at step 3 (sum + executionDelay)",
			votingStartDelay:              math.MaxInt64 / 4,
			votingPeriod:                  math.MaxInt64 / 4,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                math.MaxInt64 / 2 + 10,
			executionWindow:               0,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
		},
		{
			name:                          "Fail: overflow at step 4 (sum + executionWindow)",
			votingStartDelay:              math.MaxInt64 / 4,
			votingPeriod:                  math.MaxInt64 / 4,
			votingWeightSmoothingDuration: 0,
			quorum:                        50,
			proposalCreationThreshold:     0,
			executionDelay:                math.MaxInt64 / 4,
			executionWindow:               math.MaxInt64 / 4 + 100,
			expectedHasPanic:              true,
			expectedPanicMsg:              "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
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
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					assertIsNotOverflowDelay(cfg)
				})
			} else {
				// when & then
				uassert.NotPanics(t, func() {
					assertIsNotOverflowDelay(cfg)
				})
			}
		})
	}
}

// Test for assertIsNotOverflowSchedule function.
func TestAssert_assertIsNotOverflowSchedule(t *testing.T) {
	tests := []struct {
		name             string
		currentTime      int64
		totalDelay       int64
		expectedHasPanic bool
		expectedPanicMsg string
	}{
		{
			name:             "Success: normal values",
			currentTime:      1000000,
			totalDelay:       500000,
			expectedHasPanic: false,
		},
		{
			name:             "Success: zero delay",
			currentTime:      1000000,
			totalDelay:       0,
			expectedHasPanic: false,
		},
		{
			name:             "Success: zero current time",
			currentTime:      0,
			totalDelay:       1000000,
			expectedHasPanic: false,
		},
		{
			name:             "Success: max safe values",
			currentTime:      math.MaxInt64 / 2,
			totalDelay:       math.MaxInt64 / 2,
			expectedHasPanic: false,
		},
		{
			name:             "Fail: overflow with max current time",
			currentTime:      math.MaxInt64,
			totalDelay:       1,
			expectedHasPanic: true,
			expectedPanicMsg: "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
		},
		{
			name:             "Fail: overflow with large values",
			currentTime:      math.MaxInt64 / 2 + 1,
			totalDelay:       math.MaxInt64 / 2 + 1,
			expectedHasPanic: true,
			expectedPanicMsg: "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
		},
		{
			name:             "Fail: overflow at boundary",
			currentTime:      math.MaxInt64 - 100,
			totalDelay:       101,
			expectedHasPanic: true,
			expectedPanicMsg: "[GNOSWAP-GOVERNANCE-001] out of range for numeric value || timestamp calculations may cause overflow",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if tc.expectedHasPanic {
				// when & then
				uassert.PanicsWithMessage(t, tc.expectedPanicMsg, func() {
					assertIsNotOverflowSchedule(tc.currentTime, tc.totalDelay)
				})
			} else {
				// when & then
				uassert.NotPanics(t, func() {
					assertIsNotOverflowSchedule(tc.currentTime, tc.totalDelay)
				})
			}
		})
	}
}
