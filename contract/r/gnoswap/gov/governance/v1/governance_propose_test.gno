package v1

import (
	"strings"
	"testing"
	"time"

	// "gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gns"
	_ "gno.land/r/gnoswap/halt"
)

func TestGovernancePropose_ProposeText(t *testing.T) {
	tests := []struct {
		name string
		// given
		title               string
		description         string
		callerAddress       address
		setupConfig         *Config
		setupGnsBalance     int64
		setupActiveProposal bool
		setupUserVotes      map[string]*VotingInfo
		maxVotingWeight     int64
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:          "success - create text proposal",
			title:         "Test Text Proposal",
			description:   "This is a test text proposal for governance",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
				testutils.TestAddress("voter1").String():   NewVotingInfo(3_000_000_000, testutils.TestAddress("voter1")),
			},
			maxVotingWeight:    8_000_000_000,
			expectedProposalId: 1,
		},
		{
			name:          "fail - insufficient GNS balance",
			title:         "Test Text Proposal",
			description:   "This is a test text proposal for governance",
			callerAddress: testutils.TestAddress("poor_proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     500_000_000, // Less than threshold
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("poor_proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("poor_proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-004] not enough balance",
		},
		{
			name:          "fail - empty title",
			title:         "",
			description:   "This is a test text proposal for governance",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || title is empty",
		},
		{
			name:          "fail - empty description",
			title:         "Test Text Proposal",
			description:   "",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || description is empty",
		},
		{
			name:          "fail - already has active proposal",
			title:         "Test Text Proposal",
			description:   "This is a test text proposal for governance",
			callerAddress: testutils.TestAddress("active_proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: true,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("active_proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("active_proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-019] already active proposal",
		},
		{
			name:          "fail - not enough voting weight",
			title:         "Test Text Proposal",
			description:   "This is a test text proposal for governance",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes:      map[string]*VotingInfo{}, // Empty voting info
			maxVotingWeight:     0,
			expectedHasAbort:    true,
			expectedAbortMsg:    "[GNOSWAP-GOVERNANCE-007] not enough voting power",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, tt.setupConfig)
			setupTestGnsBalance(t, tt.callerAddress, tt.setupGnsBalance)
			setupTestUserVotesWithDelegation(t, state, tt.setupUserVotes, tt.maxVotingWeight)

			if tt.setupActiveProposal {
				setupTestActiveProposal(t, state, tt.callerAddress)
			}

			testing.SetRealm(testing.NewUserRealm(tt.callerAddress))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsContains(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeText(tt.title, tt.description)
					}(cross)
				})
				return
			}

			var proposalId int64
			func(cur realm) {
				testing.SetRealm(govRealm)
				proposalId = gov.ProposeText(tt.title, tt.description)
			}(cross)

			// then
			uassert.Equal(t, tt.expectedProposalId, proposalId)

			proposal, ok := state.getProposal(proposalId)
			uassert.Equal(t, true, ok)
			uassert.Equal(t, tt.title, proposal.Title())
			uassert.Equal(t, tt.description, proposal.Description())
			uassert.Equal(t, tt.callerAddress, proposal.Proposer())
			uassert.Equal(t, Text.String(), proposal.Type().String())
		})
	}
}

func TestGovernancePropose_ProposeCommunityPoolSpend(t *testing.T) {
	tests := []struct {
		name string
		// given
		title               string
		description         string
		to                  address
		tokenPath           string
		amount              int64
		callerAddress       address
		setupConfig         *Config
		setupGnsBalance     int64
		setupActiveProposal bool
		setupUserVotes      map[string]*VotingInfo
		maxVotingWeight     int64
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:          "success - create community pool spend proposal",
			title:         "Community Pool Spend",
			description:   "Spend from community pool for development",
			to:            testutils.TestAddress("recipient"),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        5_000_000_000,
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
				testutils.TestAddress("voter1").String():   NewVotingInfo(3_000_000_000, testutils.TestAddress("voter1")),
			},
			maxVotingWeight:    8_000_000_000,
			expectedProposalId: 1,
		},
		{
			name:          "fail - invalid recipient address",
			title:         "Community Pool Spend",
			description:   "Spend from community pool for development",
			to:            address("invalid"),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        5_000_000_000,
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || to is invalid address",
		},
		{
			name:          "fail - zero amount",
			title:         "Community Pool Spend",
			description:   "Spend from community pool for development",
			to:            testutils.TestAddress("recipient"),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        0,
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || amount is 0",
		},
		{
			name:          "fail - empty token path",
			title:         "Community Pool Spend",
			description:   "Spend from community pool for development",
			to:            testutils.TestAddress("recipient"),
			tokenPath:     "",
			amount:        5_000_000_000,
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || tokenPath is empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, tt.setupConfig)
			setupTestGnsBalance(t, tt.callerAddress, tt.setupGnsBalance)
			setupTestUserVotesWithDelegation(t, state, tt.setupUserVotes, tt.maxVotingWeight)

			if tt.setupActiveProposal {
				setupTestActiveProposal(t, state, tt.callerAddress)
			}

			testing.SetRealm(testing.NewUserRealm(tt.callerAddress))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func (cur realm) {
						gov.ProposeCommunityPoolSpend(tt.title, tt.description, tt.to, tt.tokenPath, tt.amount)
					}(cross)
				})
				return
			}

			var proposalId int64
			func(cur realm) {
				testing.SetRealm(govRealm)
				proposalId = gov.ProposeCommunityPoolSpend(tt.title, tt.description, tt.to, tt.tokenPath, tt.amount)
			}(cross)

			// then
			uassert.Equal(t, tt.expectedProposalId, proposalId)

			proposal, ok := state.getProposal(proposalId)
			uassert.Equal(t, true, ok)
			uassert.Equal(t, CommunityPoolSpend.String(), proposal.Type().String())
			uassert.Equal(t, tt.amount, proposal.data.communityPoolSpend.amount)
			uassert.Equal(t, tt.to, proposal.data.communityPoolSpend.to)
			uassert.Equal(t, tt.tokenPath, proposal.CommunityPoolSpendTokenPath())
		})
	}
}

func TestGovernancePropose_ProposeParameterChange(t *testing.T) {
	tests := []struct {
		name string
		// given
		title               string
		description         string
		numToExecute        int64
		executions          string
		callerAddress       address
		setupConfig         *Config
		setupGnsBalance     int64
		setupActiveProposal bool
		setupUserVotes      map[string]*VotingInfo
		maxVotingWeight     int64
		// then
		expectedProposalId int64
		expectedHasAbort   bool
		expectedAbortMsg   string
	}{
		{
			name:          "success - create parameter change proposal",
			title:         "Parameter Change",
			description:   "Change system parameters",
			numToExecute:  2,
			executions:    "gno.land/r/demo/token*EXE*setParam*EXE*100*GOV*gno.land/r/demo/pool*EXE*setFee*EXE*500",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
				testutils.TestAddress("voter1").String():   NewVotingInfo(3_000_000_000, testutils.TestAddress("voter1")),
			},
			maxVotingWeight:    8_000_000_000,
			expectedProposalId: 1,
		},
		{
			name:          "fail - zero executions",
			title:         "Parameter Change",
			description:   "Change system parameters",
			numToExecute:  0,
			executions:    "",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || numToExecute is less than or equal to 0",
		},
		{
			name:          "fail - invalid execution format",
			title:         "Parameter Change",
			description:   "Change system parameters",
			numToExecute:  1,
			executions:    "invalid_format",
			callerAddress: testutils.TestAddress("proposer"),
			setupConfig: &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			},
			setupGnsBalance:     10_000_000_000,
			setupActiveProposal: false,
			setupUserVotes: map[string]*VotingInfo{
				testutils.TestAddress("proposer").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("proposer")),
			},
			maxVotingWeight:  5_000_000_000,
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-002] invalid input || invalid parameter change info",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, tt.setupConfig)
			setupTestGnsBalance(t, tt.callerAddress, tt.setupGnsBalance)
			setupTestUserVotesWithDelegation(t, state, tt.setupUserVotes, tt.maxVotingWeight)

			if tt.setupActiveProposal {
				setupTestActiveProposal(t, state, tt.callerAddress)
			}

			testing.SetRealm(testing.NewUserRealm(tt.callerAddress))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeParameterChange(tt.title, tt.description, tt.numToExecute, tt.executions)
					}(cross)
				})
				return
			}

			var proposalId int64
			func(cur realm) {
				testing.SetRealm(govRealm)
				proposalId = gov.ProposeParameterChange(tt.title, tt.description, tt.numToExecute, tt.executions)
			}(cross)

			// then
			uassert.Equal(t, tt.expectedProposalId, proposalId)

			proposal, ok := state.getProposal(proposalId)
			uassert.Equal(t, true, ok)
			uassert.Equal(t, ParameterChange.String(), proposal.Type().String())
			uassert.Equal(t, tt.numToExecute, proposal.data.execution.num)
			uassert.Equal(t, tt.executions, strings.Join(proposal.data.execution.msgs, "*GOV*"))
		})
	}
}

// Test comprehensive input validation for text proposals
func TestGovernancePropose_ProposeTextInputValidation(t *testing.T) {
	tests := []struct {
		name          string
		title         string
		description   string
		expectedError string
		shouldFail    bool
	}{
		{
			name:        "success - title 254 characters",
			title:       strings.Repeat("a", 254),
			description: "Valid description",
			shouldFail:  false,
		},
		{
			name:        "success - title 255 characters",
			title:       strings.Repeat("a", 255),
			description: "Valid description",
			shouldFail:  false,
		},
		{
			name:          "fail - title 256 characters",
			title:         strings.Repeat("a", 256),
			description:   "Valid description",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || title is too long, max length is 255",
			shouldFail:    true,
		},
		{
			name:        "success - description 9999 characters",
			title:       "Valid title",
			description: strings.Repeat("a", 9999),
			shouldFail:  false,
		},
		{
			name:        "success - description 10000 characters",
			title:       "Valid title",
			description: strings.Repeat("a", 10000),
			shouldFail:  false,
		},
		{
			name:          "fail - description 10001 characters",
			title:         "Valid title",
			description:   strings.Repeat("a", 10001),
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || description is too long, max length is 10000",
			shouldFail:    true,
		},
		{
			name:        "success - special characters and emojis",
			title:       "Special chars: !@#$%^&*()_+ 🚀🌟",
			description: "Description with markdown **bold** *italic* and emojis 🎉📊",
			shouldFail:  false,
		},
		{
			name:        "success - unicode characters",
			title:       "한글 제목 测试 テスト العربية",
			description: "Unicode description: 한국어 中文 日本語 العربية русский",
			shouldFail:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			})

			caller := testutils.TestAddress("proposer")
			setupTestGnsBalance(t, caller, 10_000_000_000)
			setupTestUserVotesWithDelegation(t, state, map[string]*VotingInfo{
				caller.String(): NewVotingInfo(5_000_000_000, caller),
			}, 5_000_000_000)

			testing.SetRealm(testing.NewUserRealm(caller))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeText(tt.title, tt.description)
					}(cross)
				})
			} else {
				var proposalId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					proposalId = gov.ProposeText(tt.title, tt.description)
				}(cross)

				uassert.Equal(t, int64(1), proposalId)

				proposal, ok := state.getProposal(proposalId)
				uassert.Equal(t, true, ok)
				uassert.Equal(t, tt.title, proposal.Title())
				uassert.Equal(t, tt.description, proposal.Description())
			}
		})
	}
}

// Test proposal state validation
func TestGovernancePropose_ProposalStateValidation(t *testing.T) {
	tests := []struct {
		name                string
		setupActiveProposal func() *Proposal
		expectedError       string
		shouldFail          bool
		description         string
	}{
		{
			name: "fail - upcoming proposal exists",
			setupActiveProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Active", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			expectedError: "[GNOSWAP-GOVERNANCE-019] already active proposal",
			shouldFail:    true,
			description:   "Upcoming status blocks new proposal",
		},
		{
			name: "fail - active proposal exists",
			setupActiveProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*25).Unix()),
					NewProposalMetadata("Active", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*25).Unix(),
					100,
				)
			},
			expectedError: "[GNOSWAP-GOVERNANCE-019] already active proposal",
			shouldFail:    true,
			description:   "Active status blocks new proposal",
		},
		{
			name: "fail - passed proposal exists",
			setupActiveProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					NewProposalMetadata("Passed", "Description"),
					NewProposalExecutionData(1, "test*EXE*func*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-019] already active proposal",
			shouldFail:    true,
			description:   "Passed status blocks new proposal",
		},
		{
			name: "fail - executable proposal exists",
			setupActiveProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*12).Unix()),
					NewProposalMetadata("Executable", "Description"),
					NewProposalExecutionData(1, "test*EXE*func*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*12).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-019] already active proposal",
			shouldFail:    true,
			description:   "Executable status blocks new proposal",
		},
		{
			name: "success - executed proposal exists",
			setupActiveProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*20).Unix()),
					NewProposalMetadata("Executed", "Description"),
					NewProposalExecutionData(1, "test*EXE*func*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*20).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				proposal.status.execute(time.Now().Unix(), 100, testutils.TestAddress("executor"))
				return proposal
			},
			shouldFail:  false,
			description: "Executed status allows new proposal",
		},
		{
			name: "success - canceled proposal exists",
			setupActiveProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Canceled", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				proposal.status.cancel(time.Now().Unix(), 100, testutils.TestAddress("proposer"))
				return proposal
			},
			shouldFail:  false,
			description: "Canceled status allows new proposal",
		},
		{
			name: "success - expired proposal exists",
			setupActiveProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*40).Unix()),
					NewProposalMetadata("Expired", "Description"),
					NewProposalExecutionData(1, "test*EXE*func*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*40).Unix(),
					100,
				)
			},
			shouldFail:  false,
			description: "Expired status allows new proposal",
		},
		{
			name: "success - rejected proposal exists",
			setupActiveProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					NewProposalMetadata("Rejected", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(false, 6_000_000_000) // Majority no votes
				return proposal
			},
			shouldFail:  false,
			description: "Rejected status allows new proposal",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			})

			caller := testutils.TestAddress("proposer")
			setupTestGnsBalance(t, caller, 10_000_000_000)
			setupTestUserVotesWithDelegation(t, state, map[string]*VotingInfo{
				caller.String(): NewVotingInfo(5_000_000_000, caller),
			}, 5_000_000_000)

			if tt.setupActiveProposal != nil {
				state.addProposal(tt.setupActiveProposal())
			}

			testing.SetRealm(testing.NewUserRealm(caller))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeText("New Proposal", "New Description")
					}(cross)
				})
			} else {
				func(cur realm) {
					testing.SetRealm(govRealm)
					proposalID := gov.ProposeText("New Proposal", "New Description")
					uassert.Equal(t, proposalID, state.getCurrentProposalID())
				}(cross)
			}
		})
	}
}

// Test comprehensive community pool spend validation
func TestGovernancePropose_CommunityPoolSpendValidation(t *testing.T) {
	tests := []struct {
		name          string
		to            address
		tokenPath     string
		amount        int64
		expectedError string
		shouldFail    bool
	}{
		{
			name:       "success - valid parameters",
			to:         testutils.TestAddress("recipient"),
			tokenPath:  "gno.land/r/demo/gns",
			amount:     1_000_000_000,
			shouldFail: false,
		},
		{
			name:          "fail - empty recipient address",
			to:            address(""),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        1_000_000_000,
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || to is invalid address",
			shouldFail:    true,
		},
		{
			name:          "fail - invalid recipient address format",
			to:            address("invalid_address_format"),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        1_000_000_000,
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || to is invalid address",
			shouldFail:    true,
		},
		{
			name:          "fail - zero amount",
			to:            testutils.TestAddress("recipient"),
			tokenPath:     "gno.land/r/demo/gns",
			amount:        0,
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || amount is 0",
			shouldFail:    true,
		},
		{
			name:       "success - max int64 amount",
			to:         testutils.TestAddress("recipient"),
			tokenPath:  "gno.land/r/demo/gns",
			amount:     9223372036854775807, // MAX_INT64
			shouldFail: false,
		},
		{
			name:          "fail - empty token path",
			to:            testutils.TestAddress("recipient"),
			tokenPath:     "",
			amount:        1_000_000_000,
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || tokenPath is empty",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			})

			caller := testutils.TestAddress("proposer")
			setupTestGnsBalance(t, caller, 10_000_000_000)
			setupTestUserVotesWithDelegation(t, state, map[string]*VotingInfo{
				caller.String(): NewVotingInfo(5_000_000_000, caller),
			}, 5_000_000_000)

			testing.SetRealm(testing.NewUserRealm(caller))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeCommunityPoolSpend("Community Pool Spend", "Description", tt.to, tt.tokenPath, tt.amount)
					}(cross)
				})
			} else {
				var proposalId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					proposalId = gov.ProposeCommunityPoolSpend("Community Pool Spend", "Description", tt.to, tt.tokenPath, tt.amount)
				}(cross)
				uassert.Equal(t, proposalId, state.getCurrentProposalID())

				proposal, ok := state.getProposal(proposalId)
				uassert.Equal(t, true, ok)
				uassert.Equal(t, CommunityPoolSpend.String(), proposal.Type().String())
			}
		})
	}
}

// Test comprehensive parameter change validation
func TestGovernancePropose_ParameterChangeValidation(t *testing.T) {
	tests := []struct {
		name          string
		numToExecute  int64
		executions    string
		expectedError string
		shouldFail    bool
	}{
		{
			name:         "success - single execution",
			numToExecute: 1,
			executions:   "gno.land/r/demo/token*EXE*setParam*EXE*100",
			shouldFail:   false,
		},
		{
			name:         "success - 10 executions (maximum)",
			numToExecute: 10,
			executions: "gno.land/r/demo/token1*EXE*setParam*EXE*100*GOV*" +
				"gno.land/r/demo/token2*EXE*setParam*EXE*200*GOV*" +
				"gno.land/r/demo/token3*EXE*setParam*EXE*300*GOV*" +
				"gno.land/r/demo/token4*EXE*setParam*EXE*400*GOV*" +
				"gno.land/r/demo/token5*EXE*setParam*EXE*500*GOV*" +
				"gno.land/r/demo/token6*EXE*setParam*EXE*600*GOV*" +
				"gno.land/r/demo/token7*EXE*setParam*EXE*700*GOV*" +
				"gno.land/r/demo/token8*EXE*setParam*EXE*800*GOV*" +
				"gno.land/r/demo/token9*EXE*setParam*EXE*900*GOV*" +
				"gno.land/r/demo/token10*EXE*setParam*EXE*1000",
			shouldFail: false,
		},
		{
			name:          "fail - zero executions",
			numToExecute:  0,
			executions:    "",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || numToExecute is less than or equal to 0",
			shouldFail:    true,
		},
		{
			name:          "fail - negative executions",
			numToExecute:  -1,
			executions:    "gno.land/r/demo/token*EXE*setParam*EXE*100",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || numToExecute is less than or equal to 0",
			shouldFail:    true,
		},
		{
			name:          "fail - 11 executions (over maximum)",
			numToExecute:  11,
			executions:    strings.Repeat("gno.land/r/demo/token*EXE*setParam*EXE*100*GOV*", 10) + "gno.land/r/demo/token11*EXE*setParam*EXE*1100",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || numToExecute is greater than 10",
			shouldFail:    true,
		},
		{
			name:          "fail - empty executions string",
			numToExecute:  1,
			executions:    "",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || invalid parameter change info",
			shouldFail:    true,
		},
		{
			name:          "fail - missing *GOV* separator",
			numToExecute:  2,
			executions:    "gno.land/r/demo/token1*EXE*setParam*EXE*100gno.land/r/demo/token2*EXE*setParam*EXE*200",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || executions is not equal to numToExecute",
			shouldFail:    true,
		},
		{
			name:          "fail - missing *EXE* separator",
			numToExecute:  1,
			executions:    "gno.land/r/demo/tokensetParam100",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || invalid parameter change info",
			shouldFail:    true,
		},
		{
			name:          "fail - insufficient *EXE* separators",
			numToExecute:  1,
			executions:    "gno.land/r/demo/token*EXE*setParam",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || invalid parameter change info",
			shouldFail:    true,
		},
		{
			name:          "fail - numToExecute mismatch with actual count",
			numToExecute:  2,
			executions:    "gno.land/r/demo/token*EXE*setParam*EXE*100",
			expectedError: "[GNOSWAP-GOVERNANCE-002] invalid input || executions is not equal to numToExecute",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()
			state := gov.GetGovernanceState()

			setupTestConfig(t, state, &Config{
				VotingStartDelay:              86400,
				VotingPeriod:                  604800,
				VotingWeightSmoothingDuration: 86400,
				Quorum:                        50,
				ProposalCreationThreshold:     1_000_000_000,
				ExecutionDelay:                86400,
				ExecutionWindow:               2592000,
			})

			caller := testutils.TestAddress("proposer")
			setupTestGnsBalance(t, caller, 10_000_000_000)
			setupTestUserVotesWithDelegation(t, state, map[string]*VotingInfo{
				caller.String(): NewVotingInfo(5_000_000_000, caller),
			}, 5_000_000_000)

			testing.SetRealm(testing.NewUserRealm(caller))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(govRealm)
						gov.ProposeParameterChange("Parameter Change", "Description", tt.numToExecute, tt.executions)
					}(cross)
				})
			} else {
				var proposalId int64
				func(cur realm) {
					testing.SetRealm(govRealm)
					proposalId = gov.ProposeParameterChange("Parameter Change", "Description", tt.numToExecute, tt.executions)
					uassert.Equal(t, proposalId, state.getCurrentProposalID())
				}(cross)

				proposal, ok := state.getProposal(proposalId)
				uassert.Equal(t, true, ok)
				uassert.Equal(t, ParameterChange.String(), proposal.Type().String())
			}
		})
	}
}

// Test proposal ID generation and active proposal limits
func TestGovernancePropose_ProposalIDGeneration(t *testing.T) {
	t.Run("sequential ID generation", func(t *testing.T) {
		// given
		gov := newMockGovernance()
		state := gov.GetGovernanceState()

		setupTestConfig(t, state, &Config{
			VotingStartDelay:              86400,
			VotingPeriod:                  604800,
			VotingWeightSmoothingDuration: 86400,
			Quorum:                        50,
			ProposalCreationThreshold:     1_000_000_000,
			ExecutionDelay:                86400,
			ExecutionWindow:               2592000,
		})

		caller1 := testutils.TestAddress("proposer1")
		caller2 := testutils.TestAddress("proposer2")
		caller3 := testutils.TestAddress("proposer3")

		setupTestGnsBalance(t, caller1, 10_000_000_000)
		setupTestGnsBalance(t, caller2, 10_000_000_000)
		setupTestGnsBalance(t, caller3, 10_000_000_000)
		setupTestUserVotesWithDelegation(t, state, map[string]*VotingInfo{
			caller1.String(): NewVotingInfo(5_000_000_000, caller1),
			caller2.String(): NewVotingInfo(5_000_000_000, caller2),
		}, 10_000_000_000)

		var proposalId1 int64
		var proposalId2 int64
		var proposalId3 int64

		// when - create first proposal
		testing.SetRealm(testing.NewUserRealm(caller1))

		func(cur realm) {
			testing.SetRealm(govRealm)
			proposalId1 = gov.ProposeText("Proposal 1", "Description 1")
		}(cross)

		// when - create second proposal from same user
		testing.SetRealm(testing.NewUserRealm(caller2))
		func(cur realm) {
			testing.SetRealm(govRealm)
			proposalId2 = gov.ProposeText("Proposal 2", "Description 2")
		}(cross)

		// when - create third proposal from different user
		testing.SetRealm(testing.NewUserRealm(caller3))
		func(cur realm) {
			testing.SetRealm(govRealm)
			proposalId3 = gov.ProposeText("Proposal 3", "Description 3")
		}(cross)

		// then
		uassert.Equal(t, proposalId1, int64(1))
		uassert.Equal(t, proposalId2, int64(2))
		uassert.Equal(t, proposalId3, int64(3))
	})
}

func setupTestConfig(t *testing.T, state *governanceState, config *Config) {
	if config == nil {
		return
	}
	nextVersion := state.nextConfigVersion()
	state.setConfig(nextVersion, *config)
}

func setupTestGnsBalance(t *testing.T, address address, balance int64) {
	// Mock GNS balance setup
	// In actual implementation, this would set up the GNS token balance
	testing.SetRealm(adminRealm)

	gns.Transfer(cross, address, balance)
}

func setupTestUserVotesWithDelegation(t *testing.T, state *governanceState, userVotes map[string]*VotingInfo, maxVotingWeight int64) {
	// Mock delegation snapshots setup
	// In actual implementation, this would set up staker delegation snapshots
	testing.SetRealm(adminRealm)

	state.getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*VotingInfo, int64, bool) {
		return userVotes, maxVotingWeight, true
	}
}

func setupTestActiveProposal(t *testing.T, state *governanceState, proposerAddress address) {
	// Create an active proposal for the proposer
	config, ok := state.getCurrentConfig()
	if !ok {
		panic("config not found")
	}

	proposal := NewProposal(
		state.nextProposalID(),
		NewProposalStatus(
			config,
			1_000_000_000,
			false,
			time.Now().Unix(),
		),
		NewProposalMetadata("Active Proposal", "Description"),
		NewProposalTextData(),
		proposerAddress,
		state.getCurrentConfigVersion(),
		time.Now().Unix(),
		100,
	)

	state.addProposal(proposal)
}
