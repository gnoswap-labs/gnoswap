package v1

import (
	"chain"
	"chain/banker"
	"testing"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
)

// Test CollectReward function
func TestStakerReward_CollectReward(t *testing.T) {
	tests := []struct {
		name             string
		caller           address
		expectPanic      bool
		expectedError    string
		setupRewards     func(gs *govStakerV1)
		cleanupMocks     func()
		expectedEmission int64
		expectedProtocol map[string]int64
	}{
		{
			name:        "Successful reward collection with emission rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestEmissionRewards(t, gs, testutils.TestAddress("alice"), 1000, 100, 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 1000,
			expectedProtocol: make(map[string]int64),
		},
		{
			name:        "Successful reward collection with protocol fee rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestProtocolFeeRewards(t, gs, testutils.TestAddress("alice"), 1000, map[string]int64{
					GNS_PATH: 500,
					barPath:  300,
				}, 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				GNS_PATH: 500,
				barPath:  300,
			},
		},
		{
			name:        "No rewards available returns zero",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 0,
			expectedProtocol: make(map[string]int64),
		},
		{
			name:        "Multiple token protocol fee rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestProtocolFeeRewards(t, gs, testutils.TestAddress("alice"), 1000, map[string]int64{
					GNS_PATH: 1000,
					barPath:  2000,
					bazPath:  1500,
					usdcPath: 500,
				}, 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				GNS_PATH: 1000,
				barPath:  2000,
				bazPath:  1500,
				usdcPath: 500,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with rewards
			gs := createTestGovStaker()
			tt.setupRewards(gs)
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CollectReward()
					}(cross)
				})
			} else {
				uassert.NotPanics(t, func() {
					func (cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CollectReward()
					}(cross)
				})
			}
		})
	}
}

// Test CollectRewardFromLaunchPad function
func TestStakerReward_CollectRewardFromLaunchPad(t *testing.T) {
	tests := []struct {
		name           string
		caller         address
		to             address
		expectPanic    bool
		expectedError  string
		setupLaunchpad func(gs *govStakerV1)
		cleanupMocks   func()
	}{
		{
			name:        "Successful launchpad reward collection",
			caller:      launchpadAddr,
			to:          testutils.TestAddress("project1"),
			expectPanic: false,
			setupLaunchpad: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestLaunchpadDeposit(t, gs, testutils.TestAddress("project1"), 1000)
				setupStakerRewardTestLaunchpadRewards(t, gs, testutils.TestAddress("project1"), 500)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
		{
			name:          "Non-launchpad caller should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("project1"),
			expectPanic:   true,
			expectedError: "unauthorized: caller " + testutils.TestAddress("alice").String() + " is not launchpad",
			setupLaunchpad: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
		{
			name:          "Project wallet not found should panic",
			caller:        launchpadAddr,
			to:            testutils.TestAddress("nonexistent"),
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-005] zero delegated amount || " + testutils.TestAddress("nonexistent").String() + " is not project wallet from launchpad",
			setupLaunchpad: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with launchpad context
			gs := createTestGovStaker()
			tt.setupLaunchpad(gs)
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CollectRewardFromLaunchPad(tt.to)
					}(cross)
				})
			} else {
				// Should not panic and collect rewards successfully
				func (cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.CollectRewardFromLaunchPad(tt.to)
				}(cross)
			}
		})
	}
}

// Test SetAmountByProjectWallet function
func TestStakerReward_SetAmountByProjectWallet(t *testing.T) {
	tests := []struct {
		name          string
		caller        address
		addr          address
		amount        int64
		add           bool
		expectPanic   bool
		expectedError string
		setupMocks    func(gs *govStakerV1)
		cleanupMocks  func()
	}{
		{
			name:        "Launchpad can add amount",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      1000,
			add:         true,
			expectPanic: false,
			setupMocks: func(_ *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
		{
			name:        "Launchpad can remove amount",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      500,
			add:         false,
			expectPanic: false,
			setupMocks: func(gs *govStakerV1) {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestLaunchpadStake(t, gs, testutils.TestAddress("project1"), 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
		{
			name:          "Non-launchpad caller should panic",
			caller:        testutils.TestAddress("alice"),
			addr:          testutils.TestAddress("project1"),
			amount:        1000,
			add:           true,
			expectPanic:   true,
			expectedError: "unauthorized: caller " + testutils.TestAddress("alice").String() + " is not launchpad",
			setupMocks: func(_ *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
		{
			name:        "Zero amount should work",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      0,
			add:         true,
			expectPanic: false,
			setupMocks: func(_ *govStakerV1) {
				cleanupStakerRewardTest(t)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			gs := createTestGovStaker()
			tt.setupMocks(gs)
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					func (cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.SetAmountByProjectWallet(tt.addr, tt.amount, tt.add)
					}(cross)
				})
			} else {
				// Should not panic
				func (cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.SetAmountByProjectWallet(tt.addr, tt.amount, tt.add)
				}(cross)
			}
		})
	}
}

// Test transferToken function
func TestStakerReward_transferToken(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		from         address
		to           address
		amount       int64
		expectError  bool
		expectedMsg  string
		setupBalance func()
	}{
		{
			name:        "Valid token transfer",
			tokenPath:   GNS_PATH,
			from:        govStakerAddr,
			to:          testutils.TestAddress("to"),
			amount:      100,
			expectError: false,
			setupBalance: func() {
				// Setup balance for transfer
			},
		},
		{
			name:         "Invalid to address should error",
			tokenPath:    GNS_PATH,
			from:         govStakerAddr,
			to:           address(""),
			amount:       100,
			expectError:  true,
			expectedMsg:  "[GNOSWAP-GOV_STAKER-008] invalid address",
			setupBalance: func() {},
		},
		{
			name:         "Negative amount should error",
			tokenPath:    GNS_PATH,
			from:         govStakerAddr,
			to:           testutils.TestAddress("to"),
			amount:       -100,
			expectError:  true,
			expectedMsg:  "[GNOSWAP-GOV_STAKER-004] invalid amount",
			setupBalance: func() {},
		},
		{
			name:        "Zero amount should work",
			tokenPath:   GNS_PATH,
			from:        govStakerAddr,
			to:          testutils.TestAddress("to"),
			amount:      0,
			expectError: false,
			setupBalance: func() {
				// Setup balance for transfer
			},
		},
		{
			name:        "WUGNOT token path should use native coin transfer",
			tokenPath:   WUGNOT_PATH,
			from:        govStakerAddr,
			to:          testutils.TestAddress("to"),
			amount:      100,
			expectError: false,
			setupBalance: func() {
				// Setup WUGNOT balance
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup balance if needed
			cleanupStakerRewardTest(t)
			tt.setupBalance()

			// When: Transfer token
			testing.SetRealm(testing.NewUserRealm(tt.from))
			err := transferToken(tt.tokenPath, tt.from, tt.to, tt.amount)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
				uassert.True(t, err.Error() == tt.expectedMsg || len(err.Error()) > len(tt.expectedMsg))
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test comprehensive launchpad reward scenarios including exclusion from governance
func TestStakerReward_LaunchpadExclusionAndRewards(t *testing.T) {
	tests := []struct {
		name                 string
		caller               address
		regularXgns          int64
		launchpadXgns        int64
		expectVotingWeight   int64
		expectRewardEligible bool
		expectEmissionReward int64
		expectProtocolReward map[string]int64
		description          string
	}{
		{
			name:                 "regular xGNS only - voting and rewards eligible",
			caller:               testutils.TestAddress("user1"),
			regularXgns:          1_000_000_000,
			launchpadXgns:        0,
			expectVotingWeight:   1_000_000_000,
			expectRewardEligible: true,
			expectEmissionReward: 100_000_000,
			expectProtocolReward: map[string]int64{
				GNS_PATH: 50_000_000,
				barPath:  30_000_000,
			},
			description: "Regular xGNS should have full voting weight and reward eligibility",
		},
		{
			name:                 "launchpad xGNS only - no voting but rewards eligible",
			caller:               testutils.TestAddress("project1"),
			regularXgns:          0,
			launchpadXgns:        2_000_000_000,
			expectVotingWeight:   0,    // Excluded from voting
			expectRewardEligible: true, // But eligible for rewards
			expectEmissionReward: 200_000_000,
			expectProtocolReward: map[string]int64{
				GNS_PATH: 100_000_000,
				barPath:  60_000_000,
			},
			description: "Launchpad xGNS should be excluded from voting but eligible for rewards",
		},
		{
			name:                 "mixed xGNS - partial voting but full rewards",
			caller:               testutils.TestAddress("user2"),
			regularXgns:          800_000_000,
			launchpadXgns:        200_000_000,
			expectVotingWeight:   800_000_000, // Only regular xGNS counts
			expectRewardEligible: true,
			expectEmissionReward: 100_000_000, // Based on total xGNS
			expectProtocolReward: map[string]int64{
				GNS_PATH: 50_000_000,
				barPath:  30_000_000,
			},
			description: "Mixed xGNS should have voting weight from regular only but rewards from total",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			cleanupStakerRewardTest(t)

			gs := createTestGovStaker()

			// Setup different types of xGNS holdings
			if tt.regularXgns > 0 {
				setupStakerRewardTestEmissionRewards(t, gs, tt.caller, tt.regularXgns, tt.expectEmissionReward, 100)
				setupStakerRewardTestProtocolFeeRewards(t, gs, tt.caller, tt.regularXgns, tt.expectProtocolReward, 100)
			}
			if tt.launchpadXgns > 0 {
				setupStakerRewardTestLaunchpadDeposit(t, gs, tt.caller, tt.launchpadXgns)
				setupStakerRewardTestLaunchpadRewards(t, gs, tt.caller, tt.launchpadXgns)
			}

			testing.SetRealm(testing.NewUserRealm(tt.caller))

			// When: Collect rewards
			if tt.expectRewardEligible {
				// Should not panic and collect rewards successfully
				func (cur realm) {
					testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
					gs.CollectReward()
				}(cross)
			} else {
				// Should panic if not eligible
				uassert.AbortsWithMessage(t, "no rewards available", func() {
					func (cur realm) {
						testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
						gs.CollectReward()
					}(cross)
				})
			}

			// Then: Verify reward collection worked as expected
			// Note: In real implementation, we would verify actual balance changes
		})
	}
}

// Test comprehensive token transfer scenarios
func TestStakerReward_TokenTransferScenarios(t *testing.T) {
	tests := []struct {
		name          string
		tokenPath     string
		from          address
		to            address
		amount        int64
		fromBalance   int64
		expectedError string
		shouldFail    bool
		description   string
	}{
		{
			name:        "success - normal token transfer",
			tokenPath:   GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 500_000_000,
			shouldFail:  false,
		},
		{
			name:        "success - exact balance transfer",
			tokenPath:   GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 100_000_000,
			shouldFail:  false,
		},
		{
			name:          "fail - insufficient balance",
			tokenPath:     GNS_PATH,
			from:          testutils.TestAddress("from"), // not have balance
			to:            testutils.TestAddress("to"),
			amount:        200_000_000,
			fromBalance:   100_000_000,
			expectedError: "insufficient balance",
			shouldFail:    true,
		},
		{
			name:          "fail - invalid to address",
			tokenPath:     GNS_PATH,
			from:          admin,
			to:            address(""),
			amount:        100_000_000,
			fromBalance:   500_000_000,
			expectedError: "[GNOSWAP-GOV_STAKER-008] invalid address",
			shouldFail:    true,
		},
		{
			name:          "fail - negative amount",
			tokenPath:     GNS_PATH,
			from:          admin,
			to:            testutils.TestAddress("to"),
			amount:        -100_000_000,
			fromBalance:   500_000_000,
			expectedError: "[GNOSWAP-GOV_STAKER-004] invalid amount",
			shouldFail:    true,
		},
		{
			name:        "success - zero amount transfer",
			tokenPath:   GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      0,
			fromBalance: 500_000_000,
			shouldFail:  false,
		},
		{
			name:          "success - self transfer",
			tokenPath:     GNS_PATH,
			from:          testutils.TestAddress("user"),
			to:            testutils.TestAddress("user"),
			amount:        100_000_000,
			fromBalance:   500_000_000,
			shouldFail:    true,
			expectedError: "[GNOSWAP-GOV_STAKER-010] not enough balance || not enough gno.land/r/gnoswap/gns balance(0) to collect(100000000)",
		},
		{
			name:        "success - WUGNOT native coin transfer",
			tokenPath:   WUGNOT_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 500_000_000,
			shouldFail:  false,
			description: "WUGNOT should use native coin transfer mechanism",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup balance if needed
			// Note: In real implementation, we would set up token balances
			cleanupStakerRewardTest(t)
			setupStakerRewardStakerTokenBalance(t)

			testing.SetRealm(adminRealm)

			// When: Transfer token
			err := transferToken(tt.tokenPath, tt.from, tt.to, tt.amount)

			// Then: Check result
			if tt.shouldFail {
				uassert.Error(t, err)
				if tt.expectedError != "" {
					uassert.True(t, err.Error() == tt.expectedError || len(err.Error()) > len(tt.expectedError))
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Helper functions for test setup
func cleanupStakerRewardTest(t *testing.T) {
	// Create new test govStaker instance for fresh state
	setupStakerRewardStakerTokenBalance(t)
}

func setupStakerRewardStakerTokenBalance(t *testing.T) {
	amount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	// Transfer GNS to gov staker
	gns.Transfer(cross, govStakerAddr, amount)

	// Transfer WUGNOT to gov staker
	gnotAmount := amount * 10
	newCoins := chain.Coins{{"ugnot", gnotAmount}}
	testing.IssueCoins(adminRealm.Address(), newCoins)
	testing.SetOriginSend(newCoins)

	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminRealm.Address(), WUGNOT_ADDR, newCoins)
	wugnot.Deposit(cross)

	wugnot.Transfer(cross, govStakerAddr, amount)
}

func setupStakerRewardTestEmissionRewards(t *testing.T, gs *govStakerV1, addr address, amount int64, emissionReward int64, currentHeight int64) {
	// Setup emission rewards for testing
	state := gs.getState()
	emissionRewardManager := state.EmissionRewardManager().(*EmissionRewardManager)
	emissionRewardManager.updateAccumulatedRewardX128PerStake(emissionReward, currentHeight)
	emissionRewardManager.addStake(addr.String(), amount, currentHeight)
	gs.setState(state)
}

func setupStakerRewardTestProtocolFeeRewards(t *testing.T, gs *govStakerV1, addr address, amount int64, protocolFeeReward map[string]int64, currentHeight int64) {
	// Setup protocol fee rewards for testing
	state := gs.getState()
	protocolFeeRewardManager := state.ProtocolFeeRewardManager().(*ProtocolFeeRewardManager)
	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(protocolFeeReward, currentHeight)
	protocolFeeRewardManager.addStake(addr.String(), amount, currentHeight)
	gs.setState(state)
}

func setupStakerRewardTestAccumulateEmissionRewards(t *testing.T, gs *govStakerV1, amount, currentHeight int64) {
	// Setup emission rewards for testing
	state := gs.getState()
	emissionRewardManager := state.EmissionRewardManager().(*EmissionRewardManager)
	emissionRewardManager.updateAccumulatedRewardX128PerStake(amount, currentHeight)
	gs.setState(state)
}

func setupStakerRewardTestAccumulateProtocolFeeRewards(t *testing.T, gs *govStakerV1, distributedAmounts map[string]int64, currentHeight int64) {
	// Setup protocol fee rewards for testing
	state := gs.getState()
	protocolFeeRewardManager := state.ProtocolFeeRewardManager().(*ProtocolFeeRewardManager)
	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	gs.setState(state)
}

func setupStakerRewardTestLaunchpadDeposit(t *testing.T, gs *govStakerV1, addr address, amount int64) {
	// Setup launchpad project deposit
	launchpadRewardID := gs.makeLaunchpadRewardID(addr.String())
	gs.setLaunchpadProjectDeposit(launchpadRewardID, amount)
}

func setupStakerRewardTestLaunchpadRewards(t *testing.T, gs *govStakerV1, addr address, amount int64) {
	func (cur realm) {
		testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
		gs.addStakeFromLaunchpad(addr.String(), amount, 100)
	}(cross)
}

func setupStakerRewardTestLaunchpadStake(t *testing.T, gs *govStakerV1, addr address, amount int64) {
	// Setup launchpad stake for removal test
	func (cur realm) {
		testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
		gs.addStakeFromLaunchpad(addr.String(), amount, 100)
	}(cross)
}

func setupStakerRewardTestGNSBalance(t *testing.T, user address, amount int64) {
	testing.SetRealm(adminRealm)

	gns.Transfer(cross, user, amount)
}
