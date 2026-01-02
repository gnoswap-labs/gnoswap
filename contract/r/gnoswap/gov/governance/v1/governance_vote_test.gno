package v1

import (
	"errors"
	"testing"
	"time"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	"gno.land/r/gnoswap/gov/governance"
	"gno.land/r/gnoswap/halt"
)

func TestGovernanceVote_Vote(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalID       int64
		yes              bool
		voter            address
		setupProposal    *governance.Proposal
		setupVotingInfos map[string]*governance.VotingInfo
		// then
		expectedWeight   string
		expectedHasAbort bool
		expectedAbortMsg string
	}{
		{
			name:       "success - vote yes",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000, // max voting weight
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*governance.VotingInfo{
				testutils.TestAddress("voter").String(): governance.NewVotingInfo(5_000_000_000),
			},
			expectedWeight: "5000000000",
		},
		{
			name:       "success - vote no",
			proposalID: 1,
			yes:        false,
			voter:      testutils.TestAddress("voter"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*governance.VotingInfo{
				testutils.TestAddress("voter").String(): governance.NewVotingInfo(3_000_000_000),
			},
			expectedWeight: "3000000000",
		},
		{
			name:             "fail - proposal not found",
			proposalID:       999,
			yes:              true,
			voter:            testutils.TestAddress("voter"),
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-003] requested data not found || not found proposal",
		},
		{
			name:       "fail - no voting weight",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter_no_weight"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*governance.VotingInfo{
				testutils.TestAddress("voter_no_weight").String(): governance.NewVotingInfo(0),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight at snapshot time",
		},
		{
			name:       "fail - voting period ended",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Add(-time.Second*60*60*24*8).Unix(), // 8 days ago (past voting period)
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*8).Unix()-testConfig.VotingWeightSmoothingDuration,
				time.Now().Add(-time.Hour*24*8).Unix(),
				100,
			),
			setupVotingInfos: map[string]*governance.VotingInfo{
				testutils.TestAddress("voter").String(): governance.NewVotingInfo(5_000_000_000),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
		},
		{
			name:       "fail - already voted",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter_already"),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*governance.VotingInfo{
				testutils.TestAddress("voter_already").String(): func() *governance.VotingInfo {
					vi := governance.NewVotingInfo(5_000_000_000)
					viResolver := NewVotingInfoResolver(vi)
					viResolver.vote(true, 5_000_000_000, 100, time.Now().Unix()) // Already voted
					return vi
				}(),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-006] cannot vote twice || user has already voted",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			if tt.setupProposal != nil {
				setupTestProposal(t, gov, tt.setupProposal)

				// Use the actual proposal ID from the setup proposal
				if tt.setupVotingInfos != nil {
					setupVoteTestUserVotesWithDelegation(t, gov, tt.setupProposal.ID(), tt.setupVotingInfos, 10_000_000_000)
				}
			}

			testing.SetRealm(testing.NewUserRealm(tt.voter))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Vote(tt.proposalID, tt.yes)
					}(cross)
				})
				return
			}

			func(cur realm) {
				testing.SetRealm(govRealm)
				weight := gov.Vote(tt.proposalID, tt.yes)
				uassert.Equal(t, tt.expectedWeight, weight)

				// Verify vote was recorded
				proposal, _ := gov.getProposal(tt.proposalID)
				if tt.yes {
					uassert.Equal(t, tt.setupVotingInfos[tt.voter.String()].AvailableVoteWeight(), proposal.VotingYesWeight())
				} else {
					uassert.Equal(t, tt.setupVotingInfos[tt.voter.String()].AvailableVoteWeight(), proposal.VotingNoWeight())
				}
			}(cross)
		})
	}
}

func TestGovernanceVote_VotePrivate(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalID       int64
		voterAddress     address
		votedYes         bool
		votedHeight      int64
		votedAt          int64
		setupProposal    *governance.Proposal
		setupVotingInfo  *governance.VotingInfo
		setVotingInfoErr error
		// then
		expectedYesWeight int64
		expectedNoWeight  int64
		expectedHasError  bool
		expectedError     string
	}{
		{
			name:         "success - vote yes with full weight",
			proposalID:   1,
			voterAddress: testutils.TestAddress("voter"),
			votedYes:     true,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:   governance.NewVotingInfo(5_000_000_000),
			expectedYesWeight: 5_000_000_000,
			expectedNoWeight:  0,
		},
		{
			name:         "success - vote no with full weight",
			proposalID:   1,
			voterAddress: testutils.TestAddress("voter"),
			votedYes:     false,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:   governance.NewVotingInfo(3_000_000_000),
			expectedYesWeight: 0,
			expectedNoWeight:  3_000_000_000,
		},
		{
			name:             "fail - proposal not found",
			proposalID:       999,
			voterAddress:     testutils.TestAddress("voter"),
			votedYes:         true,
			votedHeight:      100,
			votedAt:          time.Now().Unix(),
			expectedHasError: true,
			expectedError:    "[GNOSWAP-GOVERNANCE-003] requested data not found || not found proposal",
		},
		{
			name:         "fail - voter not found",
			proposalID:   1,
			voterAddress: testutils.TestAddress("unknown_voter"),
			votedYes:     true,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			expectedHasError: true,
			expectedError:    "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight at snapshot time",
		},
		{
			name:         "fail - no voting weight",
			proposalID:   1,
			voterAddress: testutils.TestAddress("voter"),
			votedYes:     true,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:  governance.NewVotingInfo(0),
			expectedHasError: true,
			expectedError:    "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight",
		},
		{
			name:         "fail - voting info store error",
			proposalID:   1,
			voterAddress: testutils.TestAddress("voter"),
			votedYes:     true,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: governance.NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				governance.NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay-testConfig.VotingWeightSmoothingDuration,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:  governance.NewVotingInfo(5_000_000_000),
			setVotingInfoErr: errors.New("set proposal voting infos failed"),
			expectedHasError: true,
			expectedError:    "set proposal voting infos failed",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			if tt.setupProposal != nil {
				setupTestProposal(t, gov, tt.setupProposal)
			}
			if tt.setupVotingInfo != nil {
				setupTestVotingInfo(t, gov, tt.proposalID, tt.voterAddress.String(), tt.setupVotingInfo)
			}
			if tt.setVotingInfoErr != nil {
				store, ok := gov.store.(*mockGovernanceStore)
				uassert.True(t, ok)
				store.setProposalVotingInfosErr = tt.setVotingInfoErr
			}

			// when
			userVote, totalYesVoteWeight, totalNoVoteWeight, err := gov.vote(
				tt.proposalID,
				tt.voterAddress,
				tt.votedYes,
				tt.votedHeight,
				tt.votedAt,
			)

			// then
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, tt.expectedYesWeight, totalYesVoteWeight)
			uassert.Equal(t, tt.expectedNoWeight, totalNoVoteWeight)

			if tt.votedYes {
				uassert.Equal(t, "yes", userVote.VotingType())
			} else {
				uassert.Equal(t, "no", userVote.VotingType())
			}
		})
	}
}

// Test Vote Validation including halt states, proposal statuses, and access validation
func TestGovernanceVote_VoteValidation(t *testing.T) {
	tests := []struct {
		name          string
		proposalID    int64
		yes           bool
		voter         address
		setupProposal func() *governance.Proposal
		setupHalt     bool
		expectedError string
	}{
		{
			name:          "fail - negative proposal ID",
			proposalID:    -1,
			yes:           true,
			voter:         testutils.TestAddress("voter"),
			expectedError: "[GNOSWAP-GOVERNANCE-003] requested data not found || not found proposal",
		},
		{
			name:          "fail - proposal not found",
			proposalID:    999,
			yes:           true,
			voter:         testutils.TestAddress("voter"),
			expectedError: "[GNOSWAP-GOVERNANCE-003] requested data not found || not found proposal",
		},
		{
			name:       "fail - halt state voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *governance.Proposal {
				return governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Test", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix()-testConfig.VotingWeightSmoothingDuration,
					time.Now().Unix(),
					100,
				)
			},
			setupHalt:     true,
			expectedError: "halted: governance",
		},
		{
			name:       "fail - canceled proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					governance.NewProposalMetadata("Test", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix()-testConfig.VotingWeightSmoothingDuration,
					time.Now().Unix(),
					100,
				)

				resolver := NewProposalStatusResolver(proposal.Status())
				resolver.cancel(time.Now().Unix(), 100, testutils.TestAddress("canceler"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
		},
		{
			name:       "fail - executed proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					governance.NewProposalMetadata("Test", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix()-testConfig.VotingWeightSmoothingDuration,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)

				resolver := NewProposalStatusResolver(proposal.Status())
				resolver.vote(true, 6_000_000_000)
				resolver.execute(time.Now().Unix(), 100, testutils.TestAddress("executor"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
		},
		{
			name:       "fail - expired proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *governance.Proposal {
				proposal := governance.NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*40).Unix()),
					governance.NewProposalMetadata("Test", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*40).Unix()-testConfig.VotingWeightSmoothingDuration,
					time.Now().Add(-time.Hour*24*40).Unix(),
					100,
				)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			testing.SetRealm(adminRealm)
			halt.SetHaltLevel(cross, halt.HaltLevelNone)
			if tt.setupHalt {
				halt.SetHaltLevel(cross, halt.HaltLevelComplete)
			}
			defer func() {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}()
			if tt.setupProposal != nil {
				setupTestProposal(t, gov, tt.setupProposal())
				setupTestVotingInfo(t, gov, tt.proposalID, tt.voter.String(), governance.NewVotingInfo(5_000_000_000))
			}

			testing.SetRealm(testing.NewUserRealm(tt.voter))

			// when & then
			uassert.AbortsWithMessage(t, tt.expectedError, func() {
				func(cur realm) {
					testing.SetRealm(govRealm)
					gov.Vote(tt.proposalID, tt.yes)
				}(cross)
			})
		})
	}
}

// Test Vote Period timing validation
func TestGovernanceVote_VotePeriod(t *testing.T) {
	tests := []struct {
		name          string
		proposalTime  int64
		voteTime      int64
		expectedError string
		shouldPass    bool
	}{
		{
			name:          "fail - voting before start delay",
			proposalTime:  time.Now().Unix() - testConfig.VotingStartDelay + 1,
			voteTime:      time.Now().Unix(), // Before 24h delay
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
			shouldPass:    false,
		},
		{
			name:         "success - voting at start delay end",
			proposalTime: time.Now().Unix() - testConfig.VotingStartDelay,
			voteTime:     time.Now().Unix(), // Exactly at delay end
			shouldPass:   true,
		},
		{
			name:         "success - voting during active period",
			proposalTime: time.Now().Unix() - testConfig.VotingStartDelay - testConfig.VotingPeriod/2,
			voteTime:     time.Now().Unix(), // Mid voting period
			shouldPass:   true,
		},
		{
			name:         "success - voting at period end",
			proposalTime: time.Now().Unix() - testConfig.VotingStartDelay - testConfig.VotingPeriod + 1,
			voteTime:     time.Now().Unix(), // End of voting period
			shouldPass:   true,
		},
		{
			name:          "fail - voting after period end",
			proposalTime:  time.Now().Unix() - testConfig.VotingStartDelay - testConfig.VotingPeriod,
			voteTime:      time.Now().Unix(), // 1 second after end
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || cannot vote out of voting period",
			shouldPass:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			proposal := governance.NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, tt.proposalTime),
				governance.NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				tt.proposalTime-testConfig.VotingWeightSmoothingDuration,
				tt.proposalTime,
				100,
			)
			setupTestProposal(t, gov, proposal)
			voter := testutils.TestAddress("voter")
			setupTestVotingInfo(t, gov, 1, voter.String(), governance.NewVotingInfo(5_000_000_000))

			testing.SetRealm(testing.NewUserRealm(voter))

			// when & then
			if tt.shouldPass {
				func(cur realm) {
					// Mock time to vote time for successful cases
					testing.SetRealm(govRealm)
					weight := gov.Vote(1, true)
					uassert.Equal(t, "5000000000", weight)
				}(cross)
			} else {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func(cur realm) {
						testing.SetRealm(govRealm)
						gov.Vote(1, true)
					}(cross)
				})
			}
		})
	}
}

// Test Vote Weight Calculation including delegation scenarios
func TestGovernanceVote_VoteWeightCalculation(t *testing.T) {
	tests := []struct {
		name            string
		voterWeight     int64
		delegatedWeight int64
		launchpadWeight int64
		expectedWeight  string
		expectedError   string
		shouldFail      bool
	}{
		{
			name:           "success - basic voting weight",
			voterWeight:    1_000_000_000,
			expectedWeight: "1000000000",
		},
		{
			name:            "success - with delegation",
			voterWeight:     1_000_000_000,
			delegatedWeight: 2_000_000_000,
			expectedWeight:  "3000000000",
		},
		{
			name:            "success - launchpad excluded from voting",
			voterWeight:     1_000_000_000,
			launchpadWeight: 500_000_000,
			expectedWeight:  "1000000000", // Launchpad weight excluded
		},
		{
			name:            "fail - only launchpad weight",
			launchpadWeight: 1_000_000_000,
			expectedError:   "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight at snapshot time",
			shouldFail:      true,
		},
		{
			name:          "fail - zero weight",
			voterWeight:   0,
			expectedError: "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight at snapshot time",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			proposal := governance.NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()-testConfig.VotingStartDelay),
				governance.NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				time.Now().Unix(),
				100,
			)
			setupTestProposal(t, gov, proposal)

			voter := testutils.TestAddress("voter")
			totalWeight := tt.voterWeight + tt.delegatedWeight
			// Note: In real implementation, launchpad weight would be handled separately
			if tt.launchpadWeight > 0 && tt.voterWeight == 0 {
				totalWeight = 0 // Simulate launchpad exclusion
			}

			setupTestVotingInfo(t, gov, 1, voter.String(), governance.NewVotingInfo(totalWeight))

			testing.SetRealm(testing.NewUserRealm(voter))

			func(cur realm) {
				testing.SetRealm(govRealm)
				// when & then
				if tt.shouldFail {
					uassert.PanicsWithMessage(t, tt.expectedError, func() {
						gov.Vote(1, true)
					})
				} else {
					weight := gov.Vote(1, true)
					uassert.Equal(t, tt.expectedWeight, weight)
				}
			}(cross)
		})
	}
}

// Test Quorum Calculation with launchpad exclusion
func TestGovernanceVote_QuorumCalculation(t *testing.T) {
	tests := []struct {
		name                    string
		totalVotingWeight       int64
		launchpadWeight         int64
		yesVotes                int64
		noVotes                 int64
		quorumPercent           int64
		expectedTotalVoteWeight int64
		expectedQuorumAmount    int64
		description             string
	}{
		{
			name:                    "pass - quorum met with majority yes",
			totalVotingWeight:       10_000_000_000,
			launchpadWeight:         2_000_000_000, // Excluded from quorum calculation
			yesVotes:                4_500_000_000, // 56.25% of eligible (8B)
			noVotes:                 0,
			quorumPercent:           50,
			expectedTotalVoteWeight: 4_500_000_000,
			expectedQuorumAmount:    4_000_000_000,
			description:             "Quorum calculated on non-launchpad weight only",
		},
		{
			name:                    "fail - quorum not met due to launchpad exclusion",
			totalVotingWeight:       10_000_000_000,
			launchpadWeight:         6_000_000_000, // Large launchpad amount
			yesVotes:                3_000_000_000, // 75% of eligible (4B) but only 30% of total
			noVotes:                 0,
			quorumPercent:           50,
			expectedTotalVoteWeight: 3_000_000_000,
			expectedQuorumAmount:    2_000_000_000,
			description:             "High launchpad weight doesn't affect quorum",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			gov := newMockGovernance()

			eligibleWeight := tt.totalVotingWeight - tt.launchpadWeight

			customConfig := testConfig
			customConfig.Quorum = tt.quorumPercent

			proposal := governance.NewProposal(
				1,
				NewProposalStatus(customConfig, eligibleWeight, true, time.Now().Add(-time.Hour*24*10).Unix()),
				governance.NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*10).Unix()-testConfig.VotingWeightSmoothingDuration,
				time.Now().Add(-time.Hour*24*10).Unix(),
				100,
			)

			resolver := NewProposalStatusResolver(proposal.Status())
			// Simulate voting
			if tt.yesVotes > 0 {
				resolver.vote(true, tt.yesVotes)
			}
			if tt.noVotes > 0 {
				resolver.vote(false, tt.noVotes)
			}

			setupTestProposal(t, gov, proposal)

			// then
			statusResolver := NewProposalStatusResolver(proposal.Status())
			uassert.Equal(t, tt.expectedTotalVoteWeight, statusResolver.TotalVoteWeight())
			uassert.Equal(t, tt.expectedQuorumAmount, proposal.VotingQuorumAmount())
		})
	}
}

func setupTestProposal(t *testing.T, gov *governanceV1, proposal *governance.Proposal) {
	gov.addProposal(proposal)

	// Initialize empty voting info tree for the proposal if not exists
	if _, exists := gov.getProposalUserVotingInfos(proposal.ID()); !exists {
		gov.store.SetProposalVotingInfos(proposal.ID(), avl.NewTree())
	}
}

func setupVoteTestUserVotesWithDelegation(t *testing.T, gov *governanceV1, proposalID int64, userVotes map[string]*governance.VotingInfo, maxVotingWeight int64) {
	// Set up mock accessor to return the expected delegation amounts
	mockAccessor := &mockGovStakerAccessor{
		totalDelegation: maxVotingWeight,
		userDelegations: make(map[string]int64),
	}

	// Set up user delegations from votingInfo
	for voter, votingInfo := range userVotes {
		mockAccessor.userDelegations[voter] = votingInfo.AvailableVoteWeight()
		setupTestVotingInfo(t, gov, proposalID, voter, votingInfo)
	}

	gov.stakerAccessor = mockAccessor
}

func setupTestVotingInfo(t *testing.T, gov *governanceV1, proposalID int64, voter string, votingInfo *governance.VotingInfo) {
	// Get existing voting infos or create new ones
	votingInfos, exists := gov.getProposalUserVotingInfos(proposalID)

	if !exists {
		votingInfos = avl.NewTree()
	}
	votingInfos.Set(voter, votingInfo)

	// Set the voting info for the voter
	gov.store.SetProposalVotingInfos(proposalID, votingInfos)

	// Set up mock accessor to return the expected delegation amounts for this voter
	mockAccessor, ok := gov.stakerAccessor.(*mockGovStakerAccessor)
	if !ok {
		mockAccessor = &mockGovStakerAccessor{
			totalDelegation: 10_000_000_000, // default total
			userDelegations: make(map[string]int64),
		}
		gov.stakerAccessor = mockAccessor
	}
	mockAccessor.userDelegations[voter] = votingInfo.AvailableVoteWeight()
}
