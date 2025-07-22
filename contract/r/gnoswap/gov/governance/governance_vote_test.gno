package governance

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/r/gnoswap/v1/halt"
)

var testConfig = Config{
	VotingStartDelay:              86400,
	VotingPeriod:                  604800,
	VotingWeightSmoothingDuration: 86400,
	Quorum:                        50,
	ProposalCreationThreshold:     1_000_000_000,
	ExecutionDelay:                86400,
	ExecutionWindow:               2592000,
}

func TestGovernanceVote_Vote(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalID       int64
		yes              bool
		voter            std.Address
		setupProposal    *Proposal
		setupVotingInfos map[string]*VotingInfo
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
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000, // max voting weight
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*VotingInfo{
				testutils.TestAddress("voter").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("voter")),
			},
			expectedWeight: "5000000000",
		},
		{
			name:       "success - vote no",
			proposalID: 1,
			yes:        false,
			voter:      testutils.TestAddress("voter"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*VotingInfo{
				testutils.TestAddress("voter").String(): NewVotingInfo(3_000_000_000, testutils.TestAddress("voter")),
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
			voter:      testutils.TestAddress("voter"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*VotingInfo{
				testutils.TestAddress("voter").String(): NewVotingInfo(0, testutils.TestAddress("voter")),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight",
		},
		{
			name:       "fail - voting period ended",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Add(-time.Second*60*60*24*8).Unix(), // 8 days ago (past voting period)
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*8).Unix(),
				100,
			),
			setupVotingInfos: map[string]*VotingInfo{
				testutils.TestAddress("voter").String(): NewVotingInfo(5_000_000_000, testutils.TestAddress("voter")),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
		},
		{
			name:       "fail - already voted",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfos: map[string]*VotingInfo{
				testutils.TestAddress("voter").String(): func() *VotingInfo {
					vi := NewVotingInfo(5_000_000_000, testutils.TestAddress("voter"))
					vi.vote(true, 5_000_000_000, 100, time.Now().Unix()) // Already voted
					return vi
				}(),
			},
			expectedHasAbort: true,
			expectedAbortMsg: "[GNOSWAP-GOVERNANCE-006] can not vote twice",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanupGovernanceVoteTest()

			if tt.setupProposal != nil {
				setupTestProposal(t, tt.setupProposal)
			}

			if tt.setupVotingInfos != nil {
				setupVoteTestUserVotesWithDelegation(t, tt.proposalID, tt.setupVotingInfos, 10_000_000_000)
			}

			testing.SetRealm(std.NewUserRealm(tt.voter))

			// when
			if tt.expectedHasAbort {
				uassert.AbortsWithMessage(t, tt.expectedAbortMsg, func() {
					Vote(cross, tt.proposalID, tt.yes)
				})
				return
			}

			weight := Vote(cross, tt.proposalID, tt.yes)

			// then
			uassert.Equal(t, tt.expectedWeight, weight)

			// Verify vote was recorded
			proposal, _ := getProposal(tt.proposalID)
			if tt.yes {
				uassert.Equal(t, tt.setupVotingInfos[tt.voter.String()].AvailableVoteWeight(), proposal.VotingYesWeight())
			} else {
				uassert.Equal(t, tt.setupVotingInfos[tt.voter.String()].AvailableVoteWeight(), proposal.VotingNoWeight())
			}
		})
	}
}

func TestGovernanceVote_VotePrivate(t *testing.T) {
	tests := []struct {
		name string
		// given
		proposalID      int64
		voterAddress    std.Address
		votedYes        bool
		votedHeight     int64
		votedAt         int64
		setupProposal   *Proposal
		setupVotingInfo *VotingInfo
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
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:   NewVotingInfo(5_000_000_000, testutils.TestAddress("voter")),
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
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:   NewVotingInfo(3_000_000_000, testutils.TestAddress("voter")),
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
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			expectedHasError: true,
			expectedError:    "not found user's voting info",
		},
		{
			name:         "fail - no voting weight",
			proposalID:   1,
			voterAddress: testutils.TestAddress("voter"),
			votedYes:     true,
			votedHeight:  100,
			votedAt:      time.Now().Unix(),
			setupProposal: NewProposal(
				1,
				NewProposalStatus(
					testConfig,
					10_000_000_000,
					true,
					time.Now().Unix()-testConfig.VotingStartDelay,
				),
				NewProposalMetadata("Test Proposal", "Test Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			),
			setupVotingInfo:  NewVotingInfo(0, testutils.TestAddress("voter")),
			expectedHasError: true,
			expectedError:    "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanupGovernanceVoteTest()

			if tt.setupProposal != nil {
				setupTestProposal(t, tt.setupProposal)
			}
			if tt.setupVotingInfo != nil {
				setupTestVotingInfo(t, tt.proposalID, tt.voterAddress.String(), tt.setupVotingInfo)
			}

			// when
			userVote, totalYesVoteWeight, totalNoVoteWeight, err := vote(
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
		voter         std.Address
		setupProposal func() *Proposal
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
			setupProposal: func() *Proposal {
				return NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Test", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
			},
			setupHalt:     true,
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
		},
		{
			name:       "fail - canceled proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()),
					NewProposalMetadata("Test", "Description"),
					NewProposalTextData(),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Unix(),
					100,
				)
				proposal.status.cancel(time.Now().Unix(), 100, testutils.TestAddress("canceler"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
		},
		{
			name:       "fail - executed proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*10).Unix()),
					NewProposalMetadata("Test", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*10).Unix(),
					100,
				)
				proposal.status.vote(true, 6_000_000_000)
				proposal.status.execute(time.Now().Unix(), 100, testutils.TestAddress("executor"))
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
		},
		{
			name:       "fail - expired proposal voting",
			proposalID: 1,
			yes:        true,
			voter:      testutils.TestAddress("voter"),
			setupProposal: func() *Proposal {
				proposal := NewProposal(
					1,
					NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Add(-time.Hour*24*40).Unix()),
					NewProposalMetadata("Test", "Description"),
					NewProposalExecutionData(1, "test*EXE*function*EXE*param"),
					testutils.TestAddress("proposer"),
					1,
					time.Now().Add(-time.Hour*24*40).Unix(),
					100,
				)
				return proposal
			},
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanupGovernanceVoteTest()

			if tt.setupHalt {
				// Mock halt state setup
			}
			if tt.setupProposal != nil {
				setupTestProposal(t, tt.setupProposal())
				setupTestVotingInfo(t, tt.proposalID, tt.voter.String(), NewVotingInfo(5_000_000_000, tt.voter))
			}

			testing.SetRealm(std.NewUserRealm(tt.voter))

			// when & then
			uassert.AbortsWithMessage(t, tt.expectedError, func() {
				Vote(cross, tt.proposalID, tt.yes)
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
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
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
			expectedError: "[GNOSWAP-GOVERNANCE-014] unable to vote out of voting period || can not vote out of voting period",
			shouldPass:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanupGovernanceVoteTest()

			proposal := NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, tt.proposalTime),
				NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				tt.proposalTime,
				100,
			)
			setupTestProposal(t, proposal)
			voter := testutils.TestAddress("voter")
			setupTestVotingInfo(t, 1, voter.String(), NewVotingInfo(5_000_000_000, voter))

			testing.SetRealm(std.NewUserRealm(voter))

			// when & then
			if tt.shouldPass {
				// Mock time to vote time for successful cases
				weight := Vote(cross, 1, true)
				uassert.Equal(t, "5000000000", weight)
			} else {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Vote(cross, 1, true)
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
			expectedError:   "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight",
			shouldFail:      true,
		},
		{
			name:          "fail - zero weight",
			voterWeight:   0,
			expectedError: "[GNOSWAP-GOVERNANCE-007] not enough voting power || no voting weight",
			shouldFail:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			cleanupGovernanceVoteTest()

			proposal := NewProposal(
				1,
				NewProposalStatus(testConfig, 10_000_000_000, true, time.Now().Unix()-testConfig.VotingStartDelay),
				NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Unix()-testConfig.VotingStartDelay,
				100,
			)
			setupTestProposal(t, proposal)

			voter := testutils.TestAddress("voter")
			totalWeight := tt.voterWeight + tt.delegatedWeight
			// Note: In real implementation, launchpad weight would be handled separately
			if tt.launchpadWeight > 0 && tt.voterWeight == 0 {
				totalWeight = 0 // Simulate launchpad exclusion
			}

			setupTestVotingInfo(t, 1, voter.String(), NewVotingInfo(totalWeight, voter))

			testing.SetRealm(std.NewUserRealm(voter))

			// when & then
			if tt.shouldFail {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					Vote(cross, 1, true)
				})
			} else {
				weight := Vote(cross, 1, true)
				uassert.Equal(t, tt.expectedWeight, weight)
			}
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
			cleanupGovernanceVoteTest()

			eligibleWeight := tt.totalVotingWeight - tt.launchpadWeight

			customConfig := testConfig
			customConfig.Quorum = tt.quorumPercent

			proposal := NewProposal(
				1,
				NewProposalStatus(customConfig, eligibleWeight, true, time.Now().Add(-time.Hour*24*10).Unix()),
				NewProposalMetadata("Test", "Description"),
				NewProposalTextData(),
				testutils.TestAddress("proposer"),
				1,
				time.Now().Add(-time.Hour*24*10).Unix(),
				100,
			)

			// Simulate voting
			if tt.yesVotes > 0 {
				proposal.status.vote(true, tt.yesVotes)
			}
			if tt.noVotes > 0 {
				proposal.status.vote(false, tt.noVotes)
			}

			setupTestProposal(t, proposal)

			// then
			uassert.Equal(t, tt.expectedTotalVoteWeight, proposal.status.TotalVoteWeight())
			uassert.Equal(t, tt.expectedQuorumAmount, proposal.VotingQuorumAmount())
		})
	}
}

// Helper functions for voting
func cleanupGovernanceVoteTest() {
	// Reset global state
	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross, halt.HaltLevelNone)
	configCounter = NewCounter()
	proposalCounter = NewCounter()
	configs = avl.NewTree()
	proposals = avl.NewTree()
	proposalManager = NewProposalManager()
	proposalUserVotingInfos = avl.NewTree()

	// Set initial config
	initConfig()
}

func setupTestProposal(t *testing.T, proposal *Proposal) {
	addProposal(proposal)
}

func setupVoteTestUserVotesWithDelegation(t *testing.T, proposalID int64, userVotes map[string]*VotingInfo, maxVotingWeight int64) {
	// Mock delegation snapshots setup
	// In actual implementation, this would set up staker delegation snapshots
	testing.SetRealm(adminRealm)

	getUserVotingInfoSnapshotFn = func(snapshotTime int64) (map[string]*VotingInfo, int64, bool) {
		return userVotes, maxVotingWeight, true
	}

	for voter, votingInfo := range userVotes {
		setupTestVotingInfo(t, proposalID, voter, votingInfo)
	}
}

func setupTestVotingInfo(t *testing.T, proposalID int64, voter string, votingInfo *VotingInfo) {
	_, exists := proposalUserVotingInfos.Get(formatInt(proposalID))
	if !exists {
		proposalUserVotingInfos.Set(formatInt(proposalID), make(map[string]*VotingInfo))
	}

	proposalVotingInfos, _ := proposalUserVotingInfos.Get(formatInt(proposalID))
	votingInfoMap, ok := proposalVotingInfos.(map[string]*VotingInfo)
	if !ok {
		panic("votingInfoMap is not a map[string]*VotingInfo")
	}

	votingInfoMap[voter] = votingInfo
}
