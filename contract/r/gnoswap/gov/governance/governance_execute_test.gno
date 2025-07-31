package governance

import (
	"std"
	"strings"
	"testing"
	"time"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gns"
)

func TestGovernanceExecute_Execute(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalId    int64
		executor      std.Address
		setupProposal *Proposal
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:       "success - execute parameter change proposal",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(), // 10 days ago
					),
					NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				// Mark as passed
				proposal.status.vote(true, 6_000_000_000) // 60% yes votes
				return proposal
			}(),
			expectedProposalId: 1,
		},
		{
			name:       "success - execute community pool spend proposal",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					NewProposalMetadata("Community Pool Spend", "Spend from pool"),
					NewProposalCommunityPoolSpendData(
						"gno.land/r/gnoswap/v1/gns",
						testutils.TestAddress("recipient"),
						1_000_000_000,
						"gno.land/r/gnoswap/v1/community_pool",
					),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedProposalId: 1,
		},
		{
			name:             "fail - proposal not found",
			proposalId:       999,
			executor:         testutils.TestAddress("executor"),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-003] requested data not found",
		},
		{
			name:       "fail - text proposal not executable",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					false, // not executable
					time.Now().Add(-time.Hour*24*10).Unix(),
				),
				NewProposalMetadata("Text Proposal", "Text Only"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*10).Unix(),
				100,
			),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-011] can not execute text proposal",
		},
		{
			name:       "fail - execution period not started",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(), // Just created
					),
					NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
		},
		{
			name:       "fail - proposal not passed",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Second*86400).Unix(),
					),
					NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Second*86400).Unix(),
					100,
				)
				// Don't add votes, so it doesn't pass
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, tt.setupProposal)
			}

			testing.SetRealm(std.NewUserRealm(tt.executor))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					Execute(cross, tt.proposalId)
				})
				return
			}

			resultId := Execute(cross, tt.proposalId)

			// then
			uassert.Equal(t, tt.expectedProposalId, resultId)

			proposal, _ := getProposal(tt.proposalId)
			uassert.Equal(t, true, proposal.status.IsExecuted(time.Now().Unix()))
		})
	}
}

func TestGovernanceExecute_ExecuteProposalPrivate(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalId     int64
		executedAt     int64
		executedHeight int64
		executedBy     std.Address
		setupProposal  *Proposal
		// then
		expectedHasError     bool
		expectedErrorMessage string
	}{
		{
			name:           "success - execute parameter change",
			proposalId:     1,
			executedAt:     time.Now().Unix(),
			executedHeight: 1000,
			executedBy:     testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasError: false,
		},
		{
			name:           "success - execute community pool spend",
			proposalId:     1,
			executedAt:     time.Now().Unix(),
			executedHeight: 1000,
			executedBy:     testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					NewProposalMetadata("Community Pool Spend", "Spend from pool"),
					NewProposalCommunityPoolSpendData(
						"gno.land/r/gnoswap/v1/gns",
						testutils.TestAddress("recipient"),
						1_000_000_000,
						"gno.land/r/gnoswap/v1/community_pool",
					),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasError: false,
		},
		{
			name:                 "fail - proposal not found",
			proposalId:           999,
			executedAt:           time.Now().Unix(),
			executedHeight:       1000,
			executedBy:           testutils.TestAddress("executor"),
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-003] requested data not found",
		},
		{
			name:           "fail - text proposal not executable",
			proposalId:     1,
			executedAt:     time.Now().Unix(),
			executedHeight: 1000,
			executedBy:     testutils.TestAddress("executor"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					false,
					time.Now().Unix(),
				),
				NewProposalMetadata("Text Proposal", "Text Only"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix(),
				100,
			),
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-011] can not execute text proposal",
		},
		{
			name:           "fail - proposal not executable",
			proposalId:     1,
			executedAt:     time.Now().Unix(),
			executedHeight: 1000,
			executedBy:     testutils.TestAddress("executor"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(), // Just created, not in execution period
					),
					NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, tt.setupProposal)
			}

			// when
			proposal, err := executeProposal(
				tt.proposalId,
				tt.executedAt,
				tt.executedHeight,
				tt.executedBy,
			)

			// then
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedErrorMessage)
			} else {
				uassert.NoError(t, err)
				uassert.NotEqual(t, nil, proposal)
				uassert.Equal(t, true, proposal.status.IsExecuted(time.Now().Unix()))
			}
		})
	}
}

func TestGovernanceExecute_Cancel(t *testing.T) {
	executableDelay := int64(0)

	tests := []struct {
		name string
		// given
		proposalId    int64
		canceler      std.Address
		setupProposal *Proposal
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:       "success - cancel proposal by proposer",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-executableDelay,
				),
				NewProposalMetadata("Test Proposal", "Description"),
				NewProposalCommunityPoolSpendData(
					"gno.land/r/gnoswap/v1/gns",
					testutils.TestAddress("recipient"),
					1_000_000_000,
					"gno.land/r/gnoswap/v1/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-executableDelay,
				100,
			),
			expectedProposalId: 1,
		},
		{
			name:       "success - cancel proposal by others when proposer stake below threshold",
			proposalId: 1,
			canceler:   testutils.TestAddress("other"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-executableDelay,
				),
				NewProposalMetadata("Test Proposal", "Description"),
				NewProposalCommunityPoolSpendData(
					"gno.land/r/gnoswap/v1/gns",
					testutils.TestAddress("recipient"),
					1_000_000_000,
					"gno.land/r/gnoswap/v1/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-executableDelay,
				100,
			),
			expectedProposalId: 1,
		},
		{
			name:             "fail - proposal not found",
			proposalId:       999,
			canceler:         testutils.TestAddress("canceler"),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-003] requested data not found",
		},
		{
			name:       "fail - proposal already executed",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					NewProposalMetadata("Test Proposal", "Description"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				// Mark as executed
				proposal.status.execute(time.Now().Unix(), 1000, testutils.TestAddress("executor"))
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-009] unable to cancel voting proposal",
		},
		{
			name:       "fail - proposal already canceled",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(),
					),
					NewProposalMetadata("Test Proposal", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				// Mark as canceled
				proposal.status.cancel(time.Now().Unix(), 1000, testutils.TestAddress("canceler"))
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-008] can not cancel already canceled proposal",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, tt.setupProposal)
			}

			testing.SetRealm(std.NewUserRealm(tt.canceler))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					Cancel(cross, tt.proposalId)
				})
				return
			}

			resultId := Cancel(cross, tt.proposalId)

			// then
			uassert.Equal(t, tt.expectedProposalId, resultId)

			proposal, _ := getProposal(tt.proposalId)
			uassert.Equal(t, true, proposal.status.IsCanceled(time.Now().Unix()))
		})
	}
}

// Test comprehensive execution validation
func TestGovernanceExecute_ExecutionValidation(t *testing.T) {
	tests := []struct {
		name          string
		proposalId    int64
		setupProposal func() *Proposal
		expectedError string
		shouldFail    bool
	}{
		{
			name:          "fail - negative proposal ID",
			proposalId:    -1,
			expectedError: "[GNOSWAP-GOVERNANCE-003] requested data not found",
			shouldFail:    true,
		},
		{
			name:          "fail - zero proposal ID",
			proposalId:    0,
			expectedError: "[GNOSWAP-GOVERNANCE-003] requested data not found",
			shouldFail:    true,
		},
		{
			name:       "fail - text proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, false, time.Now().Add(-time.Hour*24*10).Unix()),
					NewProposalMetadata("Text Proposal", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-011] can not execute text proposal",
			shouldFail:    true,
		},
		{
			name:       "fail - upcoming proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - active proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*25).Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*25).Unix(),
					100,
				)
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - rejected proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(false, 6_000_000_000) // Majority no votes
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - already executed proposal",
			proposalId: 1,
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*15).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				proposal.status.execute(time.Now().Unix(), 100, testutils.TestAddress("executor"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - expired proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*40).Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*40).Unix(),
					100,
				)
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - canceled proposal execution",
			proposalId: 1,
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				proposal.status.cancel(time.Now().Unix(), 100, testutils.TestAddress("proposer"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, tt.setupProposal())
			}

			testing.SetRealm(std.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Execute(cross, tt.proposalId)
				})
			} else {
				resultId := Execute(cross, tt.proposalId)
				uassert.Equal(t, tt.proposalId, resultId)
			}
		})
	}
}

// Test execution timing validation
func TestGovernanceExecute_ExecutionTiming(t *testing.T) {
	tests := []struct {
		name             string
		proposalTime     time.Time
		executionTime    time.Time
		expectedError    string
		expectedHasAbort bool
		description      string
	}{
		{
			name:             "fail - execute before execution delay",
			proposalTime:     time.Now().Add(-time.Second * time.Duration(testConfig.VotingStartDelay+testConfig.VotingPeriod+testConfig.ExecutionDelay-1)), // execution window end
			executionTime:    time.Now(),
			expectedError:    "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			expectedHasAbort: true,
			description:      "Execution before delay should fail",
		},
		{
			name:             "success - execute exactly at execution delay",
			proposalTime:     time.Now().Add(-time.Hour * 24 * 11), // 11 days ago
			executionTime:    time.Now(),                           // Exactly at delay end
			expectedHasAbort: false,
			description:      "Execution at delay end should succeed",
		},
		{
			name:             "success - execute during execution window",
			proposalTime:     time.Now().Add(-time.Hour * 24 * 15), // 15 days ago
			executionTime:    time.Now(),                           // Within execution window
			expectedHasAbort: false,
			description:      "Execution within window should succeed",
		},
		{
			name:             "success - execute at window end",
			proposalTime:     time.Now().Add(-time.Second * time.Duration(testConfig.VotingStartDelay+testConfig.VotingPeriod+testConfig.ExecutionDelay)), // execution window end
			executionTime:    time.Now(),
			expectedHasAbort: false,
			description:      "Execution at window end should succeed",
		},
		{
			name:             "fail - execute after window expires",
			proposalTime:     time.Now().Add(-time.Second * time.Duration(testConfig.VotingStartDelay+testConfig.VotingPeriod+testConfig.ExecutionDelay+testConfig.ExecutionWindow)), // execution window end
			executionTime:    time.Now(),
			expectedError:    "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			expectedHasAbort: true,
			description:      "Execution after window expiry should fail",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, tt.proposalTime.Unix()),
				NewProposalMetadata("Parameter Change", "Description"),
				NewProposalCommunityPoolSpendData("gno.land/r/gnoswap/v1/gns", testutils.TestAddress("recipient"), 100, "gno.land/r/gnoswap/v1/community_pool"),
				testutils.TestAddress("proposer"),
				1,
				tt.proposalTime.Unix(),
				100,
			)
			proposal.status.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, proposal)

			testing.SetRealm(std.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Execute(cross, 1)
				})
			} else {
				resultId := Execute(cross, 1)
				uassert.Equal(t, int64(1), resultId)
			}
		})
	}
}

// Test community pool spend execution scenarios
func TestGovernanceExecute_CommunityPoolSpendExecution(t *testing.T) {
	tests := []struct {
		name                 string
		tokenPath            string
		amount               int64
		recipientAddress     std.Address
		communityPoolBalance int64
		expectedError        string
		expectedHasAbort     bool
		description          string
	}{
		{
			name:                 "success - sufficient balance",
			tokenPath:            "gno.land/r/gnoswap/v1/gns",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 5_000_000_000,
			expectedHasAbort:     false,
		},
		{
			name:                 "success - exact balance",
			tokenPath:            "gno.land/r/gnoswap/v1/gns",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 1_000_000_000,
			expectedHasAbort:     false,
		},
		{
			name:                 "fail - insufficient balance",
			tokenPath:            "gno.land/r/gnoswap/v1/gns",
			amount:               2_000_000_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 1_000_000_000,
			expectedError:        "insufficient balance",
			expectedHasAbort:     true,
		},
		{
			name:                 "success - WUGNOT transfer",
			tokenPath:            "gno.land/r/demo/wugnot",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 5_000_000_000,
			expectedHasAbort:     false,
			description:          "WUGNOT should be converted to ugnot",
		},
		{
			name:                 "success - large amount transfer",
			tokenPath:            "gno.land/r/gnoswap/v1/gns",
			amount:               9223372036854775807, // MAX_INT64
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 9223372036854775807,
			expectedHasAbort:     true,
			expectedError:        "insufficient balance",
			description:          "Large amount transfer should fail",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
				NewProposalMetadata("Community Pool Spend", "Description"),
				NewProposalCommunityPoolSpendData(
					tt.tokenPath,
					tt.recipientAddress,
					tt.amount,
					"gno.land/r/gnoswap/v1/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*15).Unix(),
				100,
			)
			proposal.status.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, proposal)

			// Mock community pool balance setup would go here

			testing.SetRealm(std.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Execute(cross, 1)
				})
			} else {
				resultId := Execute(cross, 1)
				uassert.Equal(t, int64(1), resultId)

				// Verify execution state
				proposal, _ := getProposal(1)
				uassert.Equal(t, true, proposal.status.IsExecuted(time.Now().Unix()))
			}
		})
	}
}

// Test parameter change execution scenarios
func TestGovernanceExecute_ParameterChangeExecution(t *testing.T) {
	tests := []struct {
		name             string
		numToExecute     int64
		executions       string
		expectedError    string
		expectedHasAbort bool
		description      string
	}{
		{
			name:             "success - single parameter change",
			numToExecute:     1,
			executions:       "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
			expectedHasAbort: false,
		},
		{
			name:         "success - multiple parameter changes",
			numToExecute: 2,
			executions: "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0*GOV*" +
				"gno.land/r/gnoswap/v1/pool*EXE*SetWithdrawalFee*EXE*0",
			expectedHasAbort: false,
		},
		{
			name:         "success - maximum executions",
			numToExecute: 10,
			executions: strings.Join([]string{
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*0",
			}, "*GOV*"),
			expectedHasAbort: false,
		},
		{
			name:             "fail - nonexistent function",
			numToExecute:     1,
			executions:       "gno.land/r/demo/config*EXE*nonexistentFunction*EXE*value",
			expectedError:    "handler not found for gno.land/r/demo/config:nonexistentFunction",
			expectedHasAbort: true,
		},
		{
			name:             "fail - invalid parameter type",
			numToExecute:     1,
			executions:       "gno.land/r/demo/config*EXE*setParam*EXE*invalidType",
			expectedError:    "handler not found for gno.land/r/demo/config:setParam",
			expectedHasAbort: true,
		},
		{
			name:             "fail - unauthorized contract",
			numToExecute:     1,
			executions:       "gno.land/r/unauthorized/contract*EXE*setParam*EXE*value",
			expectedError:    "handler not found for gno.land/r/unauthorized/contract:setParam",
			expectedHasAbort: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
				NewProposalMetadata("Parameter Change", "Description"),
				NewProposalExecutionData(tt.numToExecute, tt.executions),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*15).Unix(),
				100,
			)
			proposal.status.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, proposal)

			testing.SetRealm(std.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Execute(cross, 1)
				})
			} else {
				resultId := Execute(cross, 1)
				uassert.Equal(t, int64(1), resultId)

				// Verify execution state
				proposal, _ := getProposal(1)
				uassert.Equal(t, true, proposal.status.IsExecuted(time.Now().Unix()))
			}
		})
	}
}

// Test comprehensive cancellation scenarios
func TestGovernanceExecute_CancellationScenarios(t *testing.T) {
	now := time.Now()

	tests := []struct {
		name               string
		proposalTime       time.Time
		cancellationTime   time.Time
		canceler           std.Address
		proposer           std.Address
		proposerThreshold  int64
		proposerCurrentGns int64
		expectedError      string
		expectedHasAbort   bool
		description        string
	}{
		{
			name:               "success - proposer cancels upcoming proposal",
			proposalTime:       now,
			cancellationTime:   now,
			canceler:           testutils.TestAddress("proposer"),
			proposer:           testutils.TestAddress("proposer"),
			proposerThreshold:  1_000_000_000,
			proposerCurrentGns: 2_000_000_000,
			expectedHasAbort:   false,
			expectedError:      "",
		},
		{
			name:               "fail - proposer tries to cancel active proposal",
			proposalTime:       now,
			cancellationTime:   now.Add(-time.Second * time.Duration(testConfig.VotingStartDelay)),
			canceler:           testutils.TestAddress("proposer"),
			proposer:           testutils.TestAddress("proposer"),
			proposerThreshold:  1_000_000_000,
			proposerCurrentGns: 2_000_000_000,
			expectedError:      "[GNOSWAP-GOVERNANCE-009] unable to cancel voting proposal",
			expectedHasAbort:   true,
		},
		{
			name:               "fail - cancel nonexistent proposal",
			proposalTime:       now,
			cancellationTime:   now.Add(-time.Second * time.Duration(testConfig.VotingStartDelay+testConfig.VotingPeriod+testConfig.ExecutionDelay)),
			canceler:           testutils.TestAddress("proposer"),
			proposer:           testutils.TestAddress("proposer"),
			proposerThreshold:  1_000_000_000,
			proposerCurrentGns: 2_000_000_000,
			expectedError:      "[GNOSWAP-GOVERNANCE-003] requested data not found",
			expectedHasAbort:   true,
			description:        "Test with proposalId 999 (nonexistent)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanup()
			setupGovernanceExecuteTestCommunityPoolBalance(t)

			proposalId := int64(1)
			if tt.description == "Test with proposalId 999 (nonexistent)" {
				proposalId = 999
			} else {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, tt.cancellationTime.Unix()),
					NewProposalMetadata("Test Proposal", "Description"),
					NewProposalCommunityPoolSpendData("gno.land/r/gnoswap/v1/gns", tt.proposer, 100, "gno.land/r/gnoswap/v1/community_pool"),
					tt.proposer,
					1,
					tt.cancellationTime.Unix(),
					100,
				)
				setupExecuteTestProposal(t, proposal)
			}

			testing.SetRealm(std.NewUserRealm(tt.canceler))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Cancel(cross, proposalId)
				})
			} else {
				resultId := Cancel(cross, proposalId)
				uassert.Equal(t, proposalId, resultId)

				// Verify cancellation state
				proposal, _ := getProposal(proposalId)
				uassert.Equal(t, true, proposal.status.IsCanceled(time.Now().Unix()))
			}
		})
	}
}

// Test re-execution prevention
func TestGovernanceExecute_ReExecutionPrevention(t *testing.T) {
	t.Run("prevent double execution", func(t *testing.T) {
		// given
		cleanup()
		setupGovernanceExecuteTestCommunityPoolBalance(t)
		proposal := NewProposal(
			1,
			NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
			NewProposalMetadata("Parameter Change", "Description"),
			NewProposalExecutionData(1, "gno.land/r/gnoswap/v1/staker*EXE*SetUnStakingFee*EXE*-1"),
			testutils.TestAddress("proposer"),
			1,
			time.Now().Add(-time.Hour*24*15).Unix(),
			100,
		)
		proposal.status.vote(true, 6_000_000_000)
		setupExecuteTestProposal(t, proposal)

		testing.SetRealm(std.NewUserRealm(testutils.TestAddress("executor")))

		// when - first execution
		errInvalidRangeMsg := "[GNOSWAP-STAKER-008] invalid unstaking fee || fee(-1) must be in range 0 ~ 10000"
		uassert.AbortsWithMessage(t, errInvalidRangeMsg, func() {
			Execute(cross, 1)
		})

		// then - second execution should fail
		errNotExecutableMsg := "[GNOSWAP-GOVERNANCE-021] proposal not executable"
		uassert.AbortsWithMessage(t, errNotExecutableMsg, func() {
			Execute(cross, 1)
		})
	})
}

// Helper functions for execute tests
func setupExecuteTestProposal(t *testing.T, proposal *Proposal) {
	addProposal(proposal)
}

func setupGovernanceExecuteTestCommunityPoolBalance(t *testing.T) {
	amount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, communityPoolAddr, amount)

	gnotAmount := amount * 10
	newCoins := std.Coins{{"ugnot", gnotAmount}}
	testing.IssueCoins(adminRealm.Address(), newCoins)
	testing.SetOriginSend(newCoins)

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminRealm.Address(), wugnotAddr, newCoins)
	wugnot.Deposit(cross)

	wugnot.Transfer(cross, communityPoolAddr, gnotAmount)
}
