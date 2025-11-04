package v1

import (
	"chain"
	"chain/banker"
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/governance"
)

var testConfig = governance.Config{
	VotingStartDelay:              86400,         // 1 day
	VotingPeriod:                  604800,        // 7 days
	VotingWeightSmoothingDuration: 86400,         // 1 day
	Quorum:                        50,            // 50%
	ProposalCreationThreshold:     1_000_000_000, // 1 billion
	ExecutionDelay:                86400,         // 1 day
	ExecutionWindow:               2592000,       // 30 days
}

func TestGovernanceExecute_Execute(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalId    int64
		executor      address
		setupProposal *governance.Proposal
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:       "success - execute parameter change proposal",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(), // 10 days ago
					),
					governance.NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				// Mark as passed
				resolver := NewProposalStatusResolver(proposal.Status())
				// proposal.Status().Vote(true, 6_000_000_000) // 60% yes votes
				resolver.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedProposalId: 1,
		},
		{
			name:       "success - execute community pool spend proposal",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					governance.NewProposalMetadata("Community Pool Spend", "Spend from pool"),
					NewProposalCommunityPoolSpendData(
						"gno.land/r/gnoswap/gns",
						testutils.TestAddress("recipient"),
						1_000_000_000,
						"gno.land/r/gnoswap/community_pool",
					),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
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
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					false, // not executable
					time.Now().Add(-time.Hour*24*10).Unix(),
				),
				governance.NewProposalMetadata("Text Proposal", "Text Only"),
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(), // Just created
					),
					governance.NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
		},
		{
			name:       "fail - proposal not passed",
			proposalId: 1,
			executor:   testutils.TestAddress("executor"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Second*86400).Unix(),
					),
					governance.NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
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
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, gov, tt.setupProposal)
			}

			testing.SetRealm(testing.NewUserRealm(tt.executor))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Execute(tt.proposalId)
					}(cross)
				})
				return
			}

			var resultId int64
			func(cur realm) {
				testing.SetRealm(govRealm)

				resultId = gov.Execute(tt.proposalId)
				uassert.Equal(t, tt.expectedProposalId, resultId)
			}(cross)

			proposal, _ := gov.getProposal(tt.proposalId)
			statusResolver := NewProposalStatusResolver(proposal.Status())
			uassert.Equal(t, true, statusResolver.IsExecuted(time.Now().Unix()))
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
		executedBy     address
		setupProposal  *governance.Proposal
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					governance.NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					governance.NewProposalMetadata("Community Pool Spend", "Spend from pool"),
					NewProposalCommunityPoolSpendData(
						"gno.land/r/gnoswap/gns",
						testutils.TestAddress("recipient"),
						1_000_000_000,
						"gno.land/r/gnoswap/community_pool",
					),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
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
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					false,
					time.Now().Unix(),
				),
				governance.NewProposalMetadata("Text Proposal", "Text Only"),
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(), // Just created, not in execution period
					),
					governance.NewProposalMetadata("Parameter Change", "Change Parameters"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
				return proposal
			}(),
			expectedHasError:     true,
			expectedErrorMessage: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, gov, tt.setupProposal)
			}

			// when
			func(cur realm) {
				testing.SetRealm(govRealm)
				proposal, err := gov.executeProposal(
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
					statusResolver := NewProposalStatusResolver(proposal.Status())
					uassert.Equal(t, true, statusResolver.IsExecuted(time.Now().Unix()))
				}
			}(cross)
		})
	}
}

func TestGovernanceExecute_Cancel(t *testing.T) {
	executableDelay := int64(0)

	tests := []struct {
		name string
		// given
		proposalId    int64
		canceler      address
		setupProposal *governance.Proposal
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:       "success - cancel proposal by proposer",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-executableDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Description"),
				NewProposalCommunityPoolSpendData(
					"gno.land/r/gnoswap/gns",
					testutils.TestAddress("recipient"),
					1_000_000_000,
					"gno.land/r/gnoswap/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-executableDelay,
				100,
			),
			expectedProposalId: 1,
		},
		{
			name:       "fail - cancel proposal by others when proposer stake below threshold",
			proposalId: 1,
			canceler:   testutils.TestAddress("other"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-executableDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Description"),
				NewProposalCommunityPoolSpendData(
					"gno.land/r/gnoswap/gns",
					testutils.TestAddress("recipient"),
					1_000_000_000,
					"gno.land/r/gnoswap/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-executableDelay,
				100,
			),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-022] not proposer",
		},
		{
			name:             "fail - proposal not found",
			proposalId:       999,
			canceler:         testutils.TestAddress("canceler"),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-020] proposal not found",
		},
		{
			name:       "fail - proposal already executed",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Add(-time.Hour*24*10).Unix(),
					),
					governance.NewProposalMetadata("Test Proposal", "Description"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				// Mark as executed
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.execute(time.Now().Unix(), 1000, testutils.TestAddress("executor"))
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-009] unable to cancel voting proposal",
		},
		{
			name:       "fail - proposal already canceled",
			proposalId: 1,
			canceler:   testutils.TestAddress("proposer"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(
						testConfig,
						10_000_000_000,
						true,
						time.Now().Unix(),
					),
					governance.NewProposalMetadata("Test Proposal", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				// Mark as canceled
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.cancel(time.Now().Unix(), 1000, testutils.TestAddress("canceler"))
				return proposal
			}(),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-008] can not cancel already canceled proposal",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, gov, tt.setupProposal)
			}

			testing.SetRealm(testing.NewUserRealm(tt.canceler))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Cancel(tt.proposalId)
					}(cross)
				})
				return
			}

			var resultId int64
			func(cur realm) {
				testing.SetRealm(govRealm)
				resultId = gov.Cancel(tt.proposalId)
			}(cross)

			// then
			uassert.Equal(t, tt.expectedProposalId, resultId)

			proposal, _ := gov.getProposal(tt.proposalId)
			statusResolver := NewProposalStatusResolver(proposal.Status())
			uassert.Equal(t, true, statusResolver.actionStatusResolver.Canceled())
		})
	}
}

// Test comprehensive execution validation
func TestGovernanceExecute_ExecutionValidation(t *testing.T) {
	tests := []struct {
		name          string
		proposalId    int64
		setupProposal func() *governance.Proposal
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, false, time.Now().Add(-time.Hour*24*10).Unix()),
					governance.NewProposalMetadata("Text Proposal", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)

				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-011] can not execute text proposal",
			shouldFail:    true,
		},
		{
			name:       "fail - upcoming proposal execution",
			proposalId: 1,
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
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
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*25).Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(false, 6_000_000_000) // Majority no votes
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - already executed proposal",
			proposalId: 1,
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*15).Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.vote(true, 6_000_000_000)
				statusResolver.execute(time.Now().Unix(), 100, testutils.TestAddress("executor"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
		{
			name:       "fail - expired proposal execution",
			proposalId: 1,
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*40).Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
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
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Parameter Change", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				statusResolver.cancel(time.Now().Unix(), 100, testutils.TestAddress("proposer"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-021] proposal not executable",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			if tt.setupProposal != nil {
				setupExecuteTestProposal(t, gov, tt.setupProposal())
			}

			testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Execute(tt.proposalId)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(govRealm)
					resultId := gov.Execute(tt.proposalId)
					uassert.Equal(t, tt.proposalId, resultId)
				}(cross)
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
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := governance.NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, tt.proposalTime.Unix()),
				governance.NewProposalMetadata("Parameter Change", "Description"),
				NewProposalCommunityPoolSpendData("gno.land/r/gnoswap/gns", testutils.TestAddress("recipient"), 100, "gno.land/r/gnoswap/community_pool"),
				testutils.TestAddress("proposer"),
				1,
				tt.proposalTime.Unix(),
				100,
			)
			statusResolver := NewProposalStatusResolver(proposal.Status())
			statusResolver.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, gov, proposal)

			testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Execute(1)
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(govRealm)
					resultId := gov.Execute(1)
					uassert.Equal(t, int64(1), resultId)
				}(cross)
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
		recipientAddress     address
		communityPoolBalance int64
		expectedError        string
		expectedHasAbort     bool
		description          string
	}{
		{
			name:                 "success - sufficient balance",
			tokenPath:            "gno.land/r/gnoswap/gns",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 5_000_000_000,
			expectedHasAbort:     false,
		},
		{
			name:                 "success - exact balance",
			tokenPath:            "gno.land/r/gnoswap/gns",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 1_000_000_000,
			expectedHasAbort:     false,
		},
		{
			name:                 "fail - insufficient balance",
			tokenPath:            "gno.land/r/gnoswap/gns",
			amount:               2_000_000_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 1_000_000_000,
			expectedError:        "insufficient balance",
			expectedHasAbort:     true,
		},
		{
			name:                 "success - WUGNOT transfer",
			tokenPath:            "gno.land/r/gnoland/wugnot",
			amount:               1_000_000_000,
			recipientAddress:     testutils.TestAddress("recipient"),
			communityPoolBalance: 5_000_000_000,
			expectedHasAbort:     false,
			description:          "WUGNOT should be converted to ugnot",
		},
		{
			name:                 "success - large amount transfer",
			tokenPath:            "gno.land/r/gnoswap/gns",
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
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := governance.NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
				governance.NewProposalMetadata("Community Pool Spend", "Description"),
				NewProposalCommunityPoolSpendData(
					tt.tokenPath,
					tt.recipientAddress,
					tt.amount,
					"gno.land/r/gnoswap/community_pool",
				),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*15).Unix(),
				100,
			)
			statusResolver := NewProposalStatusResolver(proposal.Status())
			statusResolver.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, gov, proposal)

			// Mock community pool balance setup would go here

			testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Execute(1)
					}(cross)
				})
			} else {
				var resultId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					resultId = gov.Execute(1)
				}(cross)
				uassert.Equal(t, int64(1), resultId)

				// Verify execution state
				proposal, _ := gov.getProposal(resultId)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				uassert.Equal(t, true, statusResolver.IsExecuted(time.Now().Unix()))
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
			executions:       "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
			expectedHasAbort: false,
		},
		{
			name:         "success - multiple parameter changes",
			numToExecute: 2,
			executions: "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0*GOV*" +
				"gno.land/r/gnoswap/pool*EXE*SetWithdrawalFee*EXE*0",
			expectedHasAbort: false,
		},
		{
			name:         "success - maximum executions",
			numToExecute: 10,
			executions: strings.Join([]string{
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
				"gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*0",
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
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := governance.NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
				governance.NewProposalMetadata("Parameter Change", "Description"),
				NewProposalExecutionData(tt.numToExecute, tt.executions),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*15).Unix(),
				100,
			)
			statusResolver := NewProposalStatusResolver(proposal.Status())
			statusResolver.vote(true, 6_000_000_000)
			setupExecuteTestProposal(t, gov, proposal)

			testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("executor")))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Execute(1)
					}(cross)
				})
			} else {
				var resultId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					resultId = gov.Execute(1)
				}(cross)
				uassert.Equal(t, int64(1), resultId)

				// Verify execution state
				proposal, _ := gov.getProposal(resultId)
				statusResolver := NewProposalStatusResolver(proposal.Status())
				uassert.Equal(t, true, statusResolver.IsExecuted(time.Now().Unix()))
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
		canceler           address
		proposer           address
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
			expectedError:      "[GNOSWAP-GOVERNANCE-020] proposal not found",
			expectedHasAbort:   true,
			description:        "Test with proposalId 999 (nonexistent)",
		},
		{
			name:               "fail - cancel proposal by others when proposer stake below threshold",
			proposalTime:       now,
			cancellationTime:   now.Add(-time.Second * time.Duration(testConfig.VotingStartDelay+testConfig.VotingPeriod+testConfig.ExecutionDelay)),
			canceler:           testutils.TestAddress("other"),
			proposer:           testutils.TestAddress("proposer"),
			proposerThreshold:  1_000_000_000,
			proposerCurrentGns: 2_000_000_000,
			expectedError:      "[GNOSWAP-GOVERNANCE-022] not proposer",
			expectedHasAbort:   true,
			description:        "Test with proposalId 1 (existent)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			setupGovernanceExecuteTestCommunityPoolBalance(t)

			proposalId := int64(1)
			if tt.description == "Test with proposalId 999 (nonexistent)" {
				proposalId = 999
			} else {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, tt.cancellationTime.Unix()),
					governance.NewProposalMetadata("Test Proposal", "Description"),
					NewProposalCommunityPoolSpendData("gno.land/r/gnoswap/gns", tt.proposer, 100, "gno.land/r/gnoswap/community_pool"),
					tt.proposer,
					1,
					tt.cancellationTime.Unix(),
					100,
				)
				setupExecuteTestProposal(t, gov, proposal)
			}

			testing.SetRealm(testing.NewUserRealm(tt.canceler))

			// when & then
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Cancel(proposalId)
					}(cross)
				})
			} else {
				var resultId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					resultId = gov.Cancel(proposalId)
				}(cross)
				uassert.Equal(t, proposalId, resultId)

				// Verify cancellation state
				proposal, _ := gov.getProposal(proposalId)
				resolver := NewProposalStatusResolver(proposal.Status())
				uassert.Equal(t, true, resolver.actionStatusResolver.Canceled())
			}
		})
	}
}

// Test re-execution prevention
func TestGovernanceExecute_ReExecutionPrevention(t *testing.T) {
	t.Run("prevent double execution", func(t *testing.T) {
		// given
		gov := newMockGovernance()

		setupGovernanceExecuteTestCommunityPoolBalance(t)
		proposal := governance.NewProposal(
			1,
			NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*15).Unix()),
			governance.NewProposalMetadata("Parameter Change", "Description"),
			NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*-1"),
			testutils.TestAddress("proposer"),
			1,
			time.Now().Add(-time.Hour*24*15).Unix(),
			100,
		)
		resolver := NewProposalStatusResolver(proposal.Status())
		resolver.vote(true, 6_000_000_000)
		setupExecuteTestProposal(t, gov, proposal)

		testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("executor")))

		// when - first execution
		errInvalidRangeMsg := "[GNOSWAP-STAKER-008] invalid unstaking fee || fee(-1) must be in range 0 ~ 1000"
		uassert.AbortsContains(t, errInvalidRangeMsg, func() {
			func(cur realm) {
				testing.SetRealm(govRealm)
				gov.Execute(1)
			}(cross)
		})

		// then - second execution should fail
		errNotExecutableMsg := "[GNOSWAP-GOVERNANCE-021] proposal not executable"
		uassert.AbortsContains(t, errNotExecutableMsg, func() {
			func(cur realm) {
				testing.SetRealm(govRealm)
				gov.Execute(1)
			}(cross)
		})
	})
}

// TestGovernanceExecute_executeCommunityPoolSpend tests the private executeCommunityPoolSpend function
func TestGovernanceExecute_executeCommunityPoolSpend(t *testing.T) {
	tests := []struct {
		name             string
		setupProposal    func() *governance.Proposal
		setupRegistry    func() *ParameterRegistry
		executedAt       int64
		executedHeight   int64
		executedBy       address
		expectedError    string
		expectedHasError bool
	}{
		{
			name: "success - valid community pool spend",
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Community Pool Spend", "Test proposal"),
					NewProposalCommunityPoolSpendData(
						"gno.land/r/gnoswap/gns",
						testutils.TestAddress("recipient"),
						1_000_000,
						"gno.land/r/gnoswap/community_pool",
					),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			setupRegistry: func() *ParameterRegistry {
				return CreateParameterHandlers()
			},
			executedAt:       time.Now().Unix(),
			executedHeight:   200,
			executedBy:       testutils.TestAddress("executor"),
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			setupGovernanceExecuteTestCommunityPoolBalance(t)
			proposal := tt.setupProposal()
			registry := tt.setupRegistry()

			// when
			var err error
			func(cur realm) {
				testing.SetRealm(govRealm)
				err = executeCommunityPoolSpend(
					proposal,
					registry,
					tt.executedAt,
					tt.executedHeight,
					tt.executedBy,
				)
			}(cross)

			// then
			if tt.expectedHasError {
				uassert.NotNil(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				uassert.Nil(t, err)
			}
		})
	}
}

// TestGovernanceExecute_executeParameterChange tests the private executeParameterChange function
func TestGovernanceExecute_executeParameterChange(t *testing.T) {
	tests := []struct {
		name             string
		setupProposal    func() *governance.Proposal
		setupRegistry    func() *ParameterRegistry
		executedAt       int64
		executedHeight   int64
		executedBy       address
		expectedError    string
		expectedHasError bool
	}{
		{
			name: "success - single parameter change",
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Parameter Change", "Test proposal"),
					NewProposalExecutionData(1, "gno.land/r/gnoswap/staker*EXE*SetUnStakingFee*EXE*100"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			setupRegistry: func() *ParameterRegistry {
				return CreateParameterHandlers()
			},
			executedAt:       time.Now().Unix(),
			executedHeight:   200,
			executedBy:       testutils.TestAddress("executor"),
			expectedHasError: false,
		},
		{
			name: "success - no parameter changes",
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Parameter Change", "Test proposal"),
					NewProposalExecutionData(0, ""),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			setupRegistry: func() *ParameterRegistry {
				return NewParameterRegistry()
			},
			executedAt:       time.Now().Unix(),
			executedHeight:   200,
			executedBy:       testutils.TestAddress("executor"),
			expectedHasError: false,
		},
		{
			name: "fail - handler not found",
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Parameter Change", "Test proposal"),
					NewProposalExecutionData(1, "gno.land/r/nonexistent/package*EXE*NonExistentFunction*EXE*123"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			setupRegistry: func() *ParameterRegistry {
				return NewParameterRegistry()
			},
			executedAt:       time.Now().Unix(),
			executedHeight:   200,
			executedBy:       testutils.TestAddress("executor"),
			expectedError:    "handler not found",
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			proposal := tt.setupProposal()
			registry := tt.setupRegistry()

			// when
			var err error
			func(cur realm) {
				testing.SetRealm(govRealm)
				err = executeParameterChange(
					proposal,
					registry,
					tt.executedAt,
					tt.executedHeight,
					tt.executedBy,
				)
			}(cross)

			// then
			if tt.expectedHasError {
				uassert.NotNil(t, err)
				if !strings.Contains(err.Error(), tt.expectedError) {
					t.Errorf("expected error to contain '%s', got '%s'", tt.expectedError, err.Error())
				}
			} else {
				uassert.Nil(t, err)
			}
		})
	}
}

// Helper functions for execute tests
func setupExecuteTestProposal(t *testing.T, gov *governanceV1, proposal *governance.Proposal) {
	gov.addProposal(proposal)
}

func setupGovernanceExecuteTestCommunityPoolBalance(t *testing.T) {
	amount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross, communityPoolAddr, amount)

	gnotAmount := amount * 10
	newCoins := chain.Coins{{"ugnot", gnotAmount}}
	testing.IssueCoins(adminRealm.Address(), newCoins)
	testing.SetOriginSend(newCoins)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminRealm.Address(), wugnotAddr, newCoins)
	wugnot.Deposit(cross)

	wugnot.Transfer(cross, communityPoolAddr, gnotAmount)
}
