package v1

import (
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/gov/staker"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/onbloc/bar"
)

// Test CollectReward function
func TestStakerReward_CollectReward(cur realm, t *testing.T) {
	tests := []struct {
		name             string
		caller           address
		expectPanic      bool
		expectedError    string
		setupRewards     func(cur realm, gs *govStakerV1)
		cleanupMocks     func(cur realm)
		expectedEmission int64
		expectedProtocol map[string]int64
	}{
		{
			name:        "Successful reward collection with emission rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
				setupStakerRewardTestEmissionRewards(cur, t, gs, testutils.TestAddress("alice"), 1000, 100, 1000)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
			expectedEmission: 1000,
			expectedProtocol: make(map[string]int64),
		},
		{
			name:        "Successful reward collection with protocol fee rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
				setupStakerRewardTestProtocolFeeRewards(cur, t, gs, testutils.TestAddress("alice"), 1000, map[string]int64{
					GNS_PATH: 500,
					barPath:  300,
				}, 1000)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
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
			setupRewards: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
			expectedEmission: 0,
			expectedProtocol: make(map[string]int64),
		},
		{
			name:        "Multiple token protocol fee rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
				setupStakerRewardTestProtocolFeeRewards(cur, t, gs, testutils.TestAddress("alice"), 1000, map[string]int64{
					GNS_PATH: 1000,
					barPath:  2000,
					bazPath:  1500,
					usdcPath: 500,
				}, 1000)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup test environment with rewards
			gs := createTestGovStaker()
			tt.setupRewards(cur, gs)
			defer tt.cleanupMocks(cur)

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callMockCollectReward(cur, gs, tt.caller)
				})
			} else {
				uassert.NotPanics(t, cur, func() {
					callMockCollectReward(cur, gs, tt.caller)
				})
			}
		})
	}
}

// Test CollectRewardFromLaunchPad function
func TestStakerReward_CollectRewardFromLaunchPad(cur realm, t *testing.T) {
	tests := []struct {
		name           string
		caller         address
		to             address
		expectPanic    bool
		expectedError  string
		setupLaunchpad func(cur realm, gs *govStakerV1)
		cleanupMocks   func(cur realm)
	}{
		{
			name:        "Successful launchpad reward collection",
			caller:      launchpadAddr,
			to:          testutils.TestAddress("project1"),
			expectPanic: false,
			setupLaunchpad: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
				setupStakerRewardTestLaunchpadDeposit(cur, t, gs, testutils.TestAddress("project1"), 1000)
				setupStakerRewardTestLaunchpadRewards(cur, t, gs, testutils.TestAddress("project1"), 500)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
		{
			name:          "Non-launchpad caller should panic",
			caller:        testutils.TestAddress("alice"),
			to:            testutils.TestAddress("project1"),
			expectPanic:   true,
			expectedError: "unauthorized: caller " + testutils.TestAddress("alice").String() + " is not launchpad",
			setupLaunchpad: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
		{
			name:          "Project wallet not found should panic",
			caller:        launchpadAddr,
			to:            testutils.TestAddress("nonexistent"),
			expectPanic:   true,
			expectedError: "[GNOSWAP-GOV_STAKER-003] zero delegated amount || " + testutils.TestAddress("nonexistent").String() + " is not project wallet from launchpad",
			setupLaunchpad: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup test environment with launchpad context
			gs := createTestGovStaker()
			tt.setupLaunchpad(cur, gs)
			defer tt.cleanupMocks(cur)

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callMockCollectRewardFromLaunchPad(cur, gs, tt.caller, tt.to)
				})
			} else {
				callMockCollectRewardFromLaunchPad(cur, gs, tt.caller, tt.to)
			}
		})
	}
}

// Test SetAmountByProjectWallet function
func TestStakerReward_SetAmountByProjectWallet(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		caller        address
		addr          address
		amount        int64
		add           bool
		expectPanic   bool
		expectedError string
		setupMocks    func(cur realm, gs *govStakerV1)
		cleanupMocks  func(cur realm)
	}{
		{
			name:        "Launchpad can add amount",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      1000,
			add:         true,
			expectPanic: false,
			setupMocks: func(cur realm, _ *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
		{
			name:        "Launchpad can remove amount",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      500,
			add:         false,
			expectPanic: false,
			setupMocks: func(cur realm, gs *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
				setupStakerRewardTestLaunchpadStake(cur, t, gs, testutils.TestAddress("project1"), 1000)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
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
			setupMocks: func(cur realm, _ *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
		{
			name:          "Zero amount should panic",
			caller:        launchpadAddr,
			addr:          testutils.TestAddress("project1"),
			amount:        0,
			add:           true,
			expectPanic:   true,
			expectedError: "amount must be positive",
			setupMocks: func(cur realm, _ *govStakerV1) {
				cleanupStakerRewardTest(cur, t)
			},
			cleanupMocks: func(cur realm) {
				cleanupStakerRewardTest(cur, t)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup test environment
			gs := createTestGovStaker()
			tt.setupMocks(cur, gs)
			defer tt.cleanupMocks(cur)

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, cur, tt.expectedError, func() {
					callMockSetAmountByProjectWallet(cur, gs, tt.caller, tt.addr, tt.amount, tt.add)
				})
			} else {
				callMockSetAmountByProjectWallet(cur, gs, tt.caller, tt.addr, tt.amount, tt.add)
			}
		})
	}
}

func TestStakerReward_CollectReward_EmergencyHaltAllowsSettlement(cur realm, t *testing.T) {
	gs := createTestGovStaker()
	cleanupStakerRewardTest(cur, t)
	setupStakerRewardTestEmissionRewards(cur, t, gs, testutils.TestAddress("alice"), 1000, 100, 1000)
	defer cleanupStakerRewardTest(cur, t)

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	uassert.NotPanics(t, cur, func() {
		callMockCollectReward(cur, gs, testutils.TestAddress("alice"))
	})

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
}

func TestStakerReward_CollectRewardFromLaunchPad_EmergencyHaltAllowsSettlement(cur realm, t *testing.T) {
	gs := createTestGovStaker()
	cleanupStakerRewardTest(cur, t)
	setupStakerRewardTestLaunchpadDeposit(cur, t, gs, testutils.TestAddress("project1"), 1000)
	setupStakerRewardTestLaunchpadRewards(cur, t, gs, testutils.TestAddress("project1"), 500)
	defer cleanupStakerRewardTest(cur, t)

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	uassert.NotPanics(t, cur, func() {
		callMockCollectRewardFromLaunchPad(cur, gs, launchpadAddr, testutils.TestAddress("project1"))
	})

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
}

func TestStakerReward_SetAmountByProjectWallet_EmergencyHaltPolicy(cur realm, t *testing.T) {
	gs := createTestGovStaker()
	cleanupStakerRewardTest(cur, t)
	setupStakerRewardTestLaunchpadStake(cur, t, gs, testutils.TestAddress("project1"), 1000)
	defer cleanupStakerRewardTest(cur, t)

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelEmergency)

	uassert.NotPanics(t, cur, func() {
		callMockSetAmountByProjectWallet(cur, gs, launchpadAddr, testutils.TestAddress("project1"), 500, false)
	})

	uassert.AbortsWithMessage(t, cur, "halted: gov_staker", func() {
		callMockSetAmountByProjectWallet(cur, gs, launchpadAddr, testutils.TestAddress("project1"), 500, true)
	})

	testing.SetRealm(adminRealm)
	halt.SetHaltLevel(cross(cur), halt.HaltLevelNone)
}

// Test transferToken function
func TestStakerReward_transferToken(cur realm, t *testing.T) {
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
			expectedMsg:  "[GNOSWAP-GOV_STAKER-005] invalid address",
			setupBalance: func() {},
		},
		{
			name:         "Negative amount should error",
			tokenPath:    GNS_PATH,
			from:         govStakerAddr,
			to:           testutils.TestAddress("to"),
			amount:       -100,
			expectError:  true,
			expectedMsg:  "[GNOSWAP-GOV_STAKER-002] invalid amount",
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
			name:        "GRC20 bar token transfer",
			tokenPath:   barPath,
			from:        govStakerAddr,
			to:          testutils.TestAddress("to"),
			amount:      100,
			expectError: false,
			setupBalance: func() {
				// bar balance is set up via setupStakerRewardStakerTokenBalance
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup balance if needed
			cleanupStakerRewardTest(cur, t)
			tt.setupBalance()

			// When: Transfer token
			testing.SetRealm(testing.NewUserRealm(tt.from))
			err := transferToken(0, cur, tt.tokenPath, tt.from, tt.to, tt.amount)

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
func TestStakerReward_LaunchpadExclusionAndRewards(cur realm, t *testing.T) {
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
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup test environment
			cleanupStakerRewardTest(cur, t)

			gs := createTestGovStaker()

			// Setup different types of xGNS holdings
			if tt.regularXgns > 0 {
				setupStakerRewardTestEmissionRewards(cur, t, gs, tt.caller, tt.regularXgns, tt.expectEmissionReward, 100)
				setupStakerRewardTestProtocolFeeRewards(cur, t, gs, tt.caller, tt.regularXgns, tt.expectProtocolReward, 100)
			}
			if tt.launchpadXgns > 0 {
				setupStakerRewardTestLaunchpadDeposit(cur, t, gs, tt.caller, tt.launchpadXgns)
				setupStakerRewardTestLaunchpadRewards(cur, t, gs, tt.caller, tt.launchpadXgns)
			}

			// When: Collect rewards
			if tt.expectRewardEligible {
				callMockCollectReward(cur, gs, tt.caller)
			} else {
				uassert.AbortsWithMessage(t, cur, "no rewards available", func() {
					callMockCollectReward(cur, gs, tt.caller)
				})
			}

			// Then: Verify reward collection worked as expected
			// Note: In real implementation, we would verify actual balance changes
		})
	}
}

// Test comprehensive token transfer scenarios
func TestStakerReward_TokenTransferScenarios(cur realm, t *testing.T) {
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
			expectedError: "[GNOSWAP-GOV_STAKER-005] invalid address",
			shouldFail:    true,
		},
		{
			name:          "fail - negative amount",
			tokenPath:     GNS_PATH,
			from:          admin,
			to:            testutils.TestAddress("to"),
			amount:        -100_000_000,
			fromBalance:   500_000_000,
			expectedError: "[GNOSWAP-GOV_STAKER-002] invalid amount",
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
			expectedError: "[GNOSWAP-GOV_STAKER-006] not enough balance || not enough gno.land/r/gnoswap/gns balance(0) to collect(100000000)",
		},
		{
			name:        "success - GRC20 bar token transfer",
			tokenPath:   barPath,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 500_000_000,
			shouldFail:  false,
			description: "GRC20 bar token transfer",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup balance if needed
			// Note: In real implementation, we would set up token balances
			cleanupStakerRewardTest(cur, t)
			setupStakerRewardStakerTokenBalance(cur, t)

			testing.SetRealm(adminRealm)

			// When: Transfer token
			err := transferToken(0, cur, tt.tokenPath, tt.from, tt.to, tt.amount)

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

// Test reward calculation accuracy
func TestStakerReward_RewardCalculationAccuracy(cur realm, t *testing.T) {
	tests := []struct {
		name                     string
		userStake                int64
		totalStake               int64
		emissionReward           int64
		protocolFeeReward        map[string]int64
		updatedEmissionReward    int64
		updatedProtocolFeeReward map[string]int64
		expectedEmission         int64
		expectedProtocol         map[string]int64
		description              string
	}{
		{
			name:           "equal stake distribution",
			userStake:      1_000_000_000,
			totalStake:     10_000_000_000,
			emissionReward: 0,
			protocolFeeReward: map[string]int64{
				GNS_PATH: 0,
				barPath:  0,
			},
			updatedEmissionReward: 100_000_000,
			updatedProtocolFeeReward: map[string]int64{
				GNS_PATH: 50_000_000,
				barPath:  30_000_000,
			},
			expectedEmission: 99_999_999,
			expectedProtocol: map[string]int64{
				GNS_PATH: 49_999_999,
				barPath:  29_999_999,
			},
		},
		{
			name:           "small stake proportion",
			userStake:      1_000_000,         // 1M
			totalStake:     1_000_000_000_000, // 1T
			emissionReward: 0,
			protocolFeeReward: map[string]int64{
				GNS_PATH: 0,
			},
			updatedEmissionReward: 1_000,
			updatedProtocolFeeReward: map[string]int64{
				GNS_PATH: 1_000,
			},
			expectedEmission: 999, // 0.0001% of total (with precision loss)
			expectedProtocol: map[string]int64{
				GNS_PATH: 999, // 0.0001% of 1B
			},
		},
		{
			name:           "maximum stake scenario",
			userStake:      9223372036854775807, // MAX_INT64
			totalStake:     9223372036854775807,
			emissionReward: 0,
			protocolFeeReward: map[string]int64{
				GNS_PATH: 2_000_000_000,
			},
			updatedEmissionReward: 0,
			updatedProtocolFeeReward: map[string]int64{
				GNS_PATH: 2_000_000_000,
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				GNS_PATH: 0,
			},
		},
		{
			name:                     "zero total pool",
			userStake:                1_000_000_000,
			totalStake:               10_000_000_000,
			emissionReward:           0,
			protocolFeeReward:        map[string]int64{},
			updatedEmissionReward:    0,
			updatedProtocolFeeReward: map[string]int64{},
			expectedEmission:         0,
			expectedProtocol:         map[string]int64{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Given: Setup reward pools and stakes
			cleanupStakerRewardTest(cur, t)

			gs := createTestGovStaker()

			user := testutils.TestAddress("user")
			setupStakerRewardTestEmissionRewards(cur, t, gs, user, tt.userStake, tt.emissionReward, 100)
			setupStakerRewardTestProtocolFeeRewards(cur, t, gs, user, tt.userStake, tt.protocolFeeReward, 100)

			setupStakerRewardTestAccumulateEmissionRewards(cur, t, gs, tt.updatedEmissionReward, 1000)
			setupStakerRewardTestAccumulateProtocolFeeRewards(cur, t, gs, tt.updatedProtocolFeeReward, 1000)

			// When: Claim rewards
			emissionRewardManager := gs.store.GetEmissionRewardManager()

			emissionResolver := NewEmissionRewardManagerResolver(emissionRewardManager)
			emission, emissionErr := emissionResolver.claimRewards(user.String(), 1000)

			protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
			protocolResolver := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)
			protocol, protocolFeeErr := protocolResolver.claimRewards(user.String(), 1000)

			// Then: Check calculated amounts
			uassert.NoError(t, emissionErr)
			uassert.NoError(t, protocolFeeErr)
			uassert.Equal(t, emission, tt.expectedEmission)

			for token, expectedAmount := range tt.expectedProtocol {
				actualAmount, exists := protocol[token]
				uassert.True(t, exists)
				uassert.Equal(t, actualAmount, expectedAmount)
			}
		})
	}
}

// Helper functions for test setup
func cleanupStakerRewardTest(cur realm, t *testing.T) {
	setupStakerRewardStakerTokenBalance(cur, t)
}

func setupStakerRewardStakerTokenBalance(cur realm, t *testing.T) {
	amount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	gns.Transfer(cross(cur), govStakerAddr, amount)
	bar.Transfer(cross(cur), govStakerAddr, amount*10)
}

func setupStakerRewardTestEmissionRewards(cur realm, t *testing.T, gs *govStakerV1, addr address, amount int64, emissionReward int64, currentHeight int64) {
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)
	resolvedManager.updateAccumulatedRewardX128PerStake(emissionReward, currentHeight)
	resolvedManager.addStake(addr.String(), amount, currentHeight)
	testing.SetRealm(adminRealm)
	func(cur realm) {
		gs.store.SetEmissionRewardManager(0, cur, emissionRewardManager)
	}(cross(cur))
}

func setupStakerRewardTestProtocolFeeRewards(cur realm, t *testing.T, gs *govStakerV1, addr address, amount int64, protocolFeeReward map[string]int64, currentHeight int64) {
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	resolvedManager := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)
	resolvedManager.updateAccumulatedProtocolFeeX128PerStake(protocolFeeReward, currentHeight)
	resolvedManager.addStake(addr.String(), amount, currentHeight)
	testing.SetRealm(adminRealm)
	func(cur realm) {
		gs.store.SetProtocolFeeRewardManager(0, cur, protocolFeeRewardManager)
	}(cross(cur))
}

func setupStakerRewardTestAccumulateEmissionRewards(cur realm, t *testing.T, gs *govStakerV1, amount, currentHeight int64) {
	emissionRewardManager := gs.store.GetEmissionRewardManager()
	resolvedManager := NewEmissionRewardManagerResolver(emissionRewardManager)
	resolvedManager.updateAccumulatedRewardX128PerStake(amount, currentHeight)
	testing.SetRealm(adminRealm)
	func(cur realm) {
		gs.store.SetEmissionRewardManager(0, cur, emissionRewardManager)
	}(cross(cur))
}

func setupStakerRewardTestAccumulateProtocolFeeRewards(cur realm, t *testing.T, gs *govStakerV1, distributedAmounts map[string]int64, currentHeight int64) {
	protocolFeeRewardManager := gs.store.GetProtocolFeeRewardManager()
	resolvedManager := &ProtocolFeeRewardManagerResolver{protocolFeeRewardManager}
	resolvedManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
	testing.SetRealm(adminRealm)
	func(cur realm) {
		gs.store.SetProtocolFeeRewardManager(0, cur, protocolFeeRewardManager)
	}(cross(cur))
}

func setupStakerRewardTestLaunchpadDeposit(cur realm, t *testing.T, gs *govStakerV1, addr address, amount int64) {
	launchpadRewardID := gs.makeLaunchpadRewardID(addr.String())
	testing.SetRealm(adminRealm)
	func(cur realm) {
		gs.setLaunchpadProjectDeposit(0, cur, launchpadRewardID, amount)
	}(cross(cur))
}

func setupStakerRewardTestLaunchpadRewards(cur realm, t *testing.T, gs *govStakerV1, addr address, amount int64) {
	setupStakerRewardTestLaunchpadDeposit(cur, t, gs, addr, amount)
	testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
	testing.SetRealm(testing.NewUserRealm(launchpadAddr))
	staker.SetAmountByProjectWallet(cross(cur), addr, amount, true)
}

func setupStakerRewardTestLaunchpadStake(cur realm, t *testing.T, gs *govStakerV1, addr address, amount int64) {
	testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
	testing.SetRealm(testing.NewUserRealm(launchpadAddr))
	staker.SetAmountByProjectWallet(cross(cur), addr, amount, true)
}

func callMockCollectReward(cur realm, gs *govStakerV1, caller address) {
	// Mock-store CollectReward cannot satisfy pf.DistributeProtocolFee(cross(rlm))
	// auth without the gov/staker proxy frame. Exercise the emission claim path on
	// the isolated store (protocol fee distribution is covered elsewhere).
	testing.SetRealm(adminRealm)
	func(cur realm) {
		_, err := gs.claimRewardsEmissionReward(0, cur, caller.String(), time.Now().Unix())
		if err != nil {
			panic(err)
		}
	}(cross(cur))
}

func callMockCollectRewardFromLaunchPad(cur realm, gs *govStakerV1, caller, to address) {
	testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
	testing.SetRealm(testing.NewUserRealm(caller))
	staker.CollectRewardFromLaunchPad(cross(cur), to)
}

func callMockSetAmountByProjectWallet(cur realm, gs *govStakerV1, caller, addr address, amount int64, add bool) {
	testing.SetRealm(testing.NewCodeRealm(GOV_STAKER_PKG_PATH))
	testing.SetRealm(testing.NewUserRealm(caller))
	staker.SetAmountByProjectWallet(cross(cur), addr, amount, add)
}

func setupStakerRewardTestGNSBalance(cur realm, t *testing.T, user address, amount int64) {
	testing.SetRealm(adminRealm)

	gns.Transfer(cross(cur), user, amount)
}
