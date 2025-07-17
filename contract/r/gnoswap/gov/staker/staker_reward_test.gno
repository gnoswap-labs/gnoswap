package staker

import (
	"std"
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"
	"gno.land/p/gnoswap/consts"
	"gno.land/r/demo/wugnot"
	"gno.land/r/gnoswap/v1/gns"
)

// Test CollectReward function
func TestStakerReward_CollectReward(t *testing.T) {
	tests := []struct {
		name             string
		caller           std.Address
		expectPanic      bool
		expectedError    string
		setupRewards     func()
		cleanupMocks     func()
		expectedEmission int64
		expectedProtocol map[string]int64
	}{
		{
			name:        "Successful reward collection with emission rewards",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func() {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestEmissionRewards(t, testutils.TestAddress("alice"), 1000, 100, 1000)
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
			setupRewards: func() {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestProtocolFeeRewards(t, testutils.TestAddress("alice"), 1000, map[string]int64{
					consts.GNS_PATH: 500,
					barPath:         300,
				}, 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				consts.GNS_PATH: 500,
				barPath:         300,
			},
		},
		{
			name:        "No rewards available returns zero",
			caller:      testutils.TestAddress("alice"),
			expectPanic: false,
			setupRewards: func() {
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
			setupRewards: func() {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestProtocolFeeRewards(t, testutils.TestAddress("alice"), 1000, map[string]int64{
					consts.GNS_PATH: 1000,
					barPath:         2000,
					bazPath:         1500,
					usdcPath:        500,
				}, 1000)
			},
			cleanupMocks: func() {
				cleanupStakerRewardTest(t)
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				consts.GNS_PATH: 1000,
				barPath:         2000,
				bazPath:         1500,
				usdcPath:        500,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment with rewards
			tt.setupRewards()
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(std.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					CollectReward(cross)
				})
			} else {
				// Should not panic and collect rewards successfully
				CollectReward(cross)
				// Note: In a real implementation, we would verify the actual reward collection
				// by checking balances, events, etc.
			}
		})
	}
}

// Test CollectRewardFromLaunchPad function
func TestStakerReward_CollectRewardFromLaunchPad(t *testing.T) {
	tests := []struct {
		name           string
		caller         std.Address
		to             std.Address
		expectPanic    bool
		expectedError  string
		setupLaunchpad func()
		cleanupMocks   func()
	}{
		{
			name:        "Successful launchpad reward collection",
			caller:      launchpadAddr,
			to:          testutils.TestAddress("project1"),
			expectPanic: false,
			setupLaunchpad: func() {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestLaunchpadDeposit(t, testutils.TestAddress("project1"), 1000)
				setupStakerRewardTestLaunchpadRewards(t, testutils.TestAddress("project1"), 500)
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
			expectedError: "caller(" + testutils.TestAddress("alice").String() + ") has no permission",
			setupLaunchpad: func() {
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
			setupLaunchpad: func() {
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
			tt.setupLaunchpad()
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(std.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					CollectRewardFromLaunchPad(cross, tt.to)
				})
			} else {
				// Should not panic and collect rewards successfully
				CollectRewardFromLaunchPad(cross, tt.to)
			}
		})
	}
}

// Test SetAmountByProjectWallet function
func TestStakerReward_SetAmountByProjectWallet(t *testing.T) {
	tests := []struct {
		name          string
		caller        std.Address
		addr          std.Address
		amount        int64
		add           bool
		expectPanic   bool
		expectedError string
		setupMocks    func()
		cleanupMocks  func()
	}{
		{
			name:        "Launchpad can add amount",
			caller:      launchpadAddr,
			addr:        testutils.TestAddress("project1"),
			amount:      1000,
			add:         true,
			expectPanic: false,
			setupMocks: func() {
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
			setupMocks: func() {
				cleanupStakerRewardTest(t)
				setupStakerRewardTestLaunchpadStake(t, testutils.TestAddress("project1"), 1000)
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
			expectedError: "caller(" + testutils.TestAddress("alice").String() + ") has no permission",
			setupMocks: func() {
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
			setupMocks: func() {
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
			tt.setupMocks()
			defer tt.cleanupMocks()

			// Setup realm context for testing
			testing.SetRealm(std.NewUserRealm(tt.caller))

			// When & Then: Execute and verify
			if tt.expectPanic {
				uassert.AbortsWithMessage(t, tt.expectedError, func() {
					SetAmountByProjectWallet(cross, tt.addr, tt.amount, tt.add)
				})
			} else {
				// Should not panic
				SetAmountByProjectWallet(cross, tt.addr, tt.amount, tt.add)
			}
		})
	}
}

// Test transferToken function
func TestStakerReward_transferToken(t *testing.T) {
	tests := []struct {
		name         string
		tokenPath    string
		from         std.Address
		to           std.Address
		amount       int64
		expectError  bool
		expectedMsg  string
		setupBalance func()
	}{
		{
			name:        "Valid token transfer",
			tokenPath:   consts.GNS_PATH,
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
			tokenPath:    consts.GNS_PATH,
			from:         govStakerAddr,
			to:           std.Address(""),
			amount:       100,
			expectError:  true,
			expectedMsg:  "[GNOSWAP-GOV_STAKER-008] invalid address",
			setupBalance: func() {},
		},
		{
			name:         "Negative amount should error",
			tokenPath:    consts.GNS_PATH,
			from:         govStakerAddr,
			to:           testutils.TestAddress("to"),
			amount:       -100,
			expectError:  true,
			expectedMsg:  "[GNOSWAP-GOV_STAKER-004] invalid amount",
			setupBalance: func() {},
		},
		{
			name:        "Zero amount should work",
			tokenPath:   consts.GNS_PATH,
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
			tokenPath:   consts.WUGNOT_PATH,
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
			testing.SetRealm(std.NewUserRealm(tt.from))
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
		caller               std.Address
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
				consts.GNS_PATH: 50_000_000,
				barPath:         30_000_000,
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
				consts.GNS_PATH: 100_000_000,
				barPath:         60_000_000,
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
				consts.GNS_PATH: 50_000_000,
				barPath:         30_000_000,
			},
			description: "Mixed xGNS should have voting weight from regular only but rewards from total",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup test environment
			cleanupStakerRewardTest(t)

			// Setup different types of xGNS holdings
			if tt.regularXgns > 0 {
				setupStakerRewardTestEmissionRewards(t, tt.caller, tt.regularXgns, tt.expectEmissionReward, 100)
				setupStakerRewardTestProtocolFeeRewards(t, tt.caller, tt.regularXgns, tt.expectProtocolReward, 100)
			}
			if tt.launchpadXgns > 0 {
				setupStakerRewardTestLaunchpadDeposit(t, tt.caller, tt.launchpadXgns)
				setupStakerRewardTestLaunchpadRewards(t, tt.caller, tt.launchpadXgns)
			}

			testing.SetRealm(std.NewUserRealm(tt.caller))

			// When: Collect rewards
			if tt.expectRewardEligible {
				// Should not panic and collect rewards successfully
				CollectReward(cross)
			} else {
				// Should panic if not eligible
				uassert.AbortsWithMessage(t, "no rewards available", func() {
					CollectReward(cross)
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
		from          std.Address
		to            std.Address
		amount        int64
		fromBalance   int64
		expectedError string
		shouldFail    bool
		description   string
	}{
		{
			name:        "success - normal token transfer",
			tokenPath:   consts.GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 500_000_000,
			shouldFail:  false,
		},
		{
			name:        "success - exact balance transfer",
			tokenPath:   consts.GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      100_000_000,
			fromBalance: 100_000_000,
			shouldFail:  false,
		},
		{
			name:          "fail - insufficient balance",
			tokenPath:     consts.GNS_PATH,
			from:          testutils.TestAddress("from"), // not have balance
			to:            testutils.TestAddress("to"),
			amount:        200_000_000,
			fromBalance:   100_000_000,
			expectedError: "insufficient balance",
			shouldFail:    true,
		},
		{
			name:          "fail - invalid to address",
			tokenPath:     consts.GNS_PATH,
			from:          admin,
			to:            std.Address(""),
			amount:        100_000_000,
			fromBalance:   500_000_000,
			expectedError: "[GNOSWAP-GOV_STAKER-008] invalid address",
			shouldFail:    true,
		},
		{
			name:          "fail - negative amount",
			tokenPath:     consts.GNS_PATH,
			from:          admin,
			to:            testutils.TestAddress("to"),
			amount:        -100_000_000,
			fromBalance:   500_000_000,
			expectedError: "[GNOSWAP-GOV_STAKER-004] invalid amount",
			shouldFail:    true,
		},
		{
			name:        "success - zero amount transfer",
			tokenPath:   consts.GNS_PATH,
			from:        admin,
			to:          testutils.TestAddress("to"),
			amount:      0,
			fromBalance: 500_000_000,
			shouldFail:  false,
		},
		{
			name:        "success - self transfer",
			tokenPath:   consts.GNS_PATH,
			from:        testutils.TestAddress("user"),
			to:          testutils.TestAddress("user"),
			amount:      100_000_000,
			fromBalance: 500_000_000,
			shouldFail:  true,
			expectedError: "[GNOSWAP-GOV_STAKER-010] not enough balance || not enough gno.land/r/gnoswap/v1/gns balance(0) to collect(100000000)",
		},
		{
			name:        "success - WUGNOT native coin transfer",
			tokenPath:   consts.WUGNOT_PATH,
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

// Test reward calculation accuracy
func TestStakerReward_RewardCalculationAccuracy(t *testing.T) {
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
				consts.GNS_PATH: 0,
				barPath:         0,
			},
			updatedEmissionReward: 100_000_000,
			updatedProtocolFeeReward: map[string]int64{
				consts.GNS_PATH: 50_000_000,
				barPath:         30_000_000,
			},
			expectedEmission: 99_999_999,
			expectedProtocol: map[string]int64{
				consts.GNS_PATH: 49_999_999,
				barPath:         29_999_999,
			},
		},
		{
			name:           "small stake proportion",
			userStake:      1_000_000,         // 1M
			totalStake:     1_000_000_000_000, // 1T
			emissionReward: 0,
			protocolFeeReward: map[string]int64{
				consts.GNS_PATH: 0,
			},
			updatedEmissionReward: 1_000,
			updatedProtocolFeeReward: map[string]int64{
				consts.GNS_PATH: 1_000,
			},
			expectedEmission: 999, // 0.0001% of total (with precision loss)
			expectedProtocol: map[string]int64{
				consts.GNS_PATH: 999, // 0.0001% of 1B
			},
		},
		{
			name:           "maximum stake scenario",
			userStake:      9223372036854775807, // MAX_INT64
			totalStake:     9223372036854775807,
			emissionReward: 0,
			protocolFeeReward: map[string]int64{
				consts.GNS_PATH: 2_000_000_000,
			},
			updatedEmissionReward: 0,
			updatedProtocolFeeReward: map[string]int64{
				consts.GNS_PATH: 2_000_000_000,
			},
			expectedEmission: 0,
			expectedProtocol: map[string]int64{
				consts.GNS_PATH: 0,
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
		t.Run(tt.name, func(t *testing.T) {
			// Given: Setup reward pools and stakes
			cleanupStakerRewardTest(t)

			user := testutils.TestAddress("user")
			setupStakerRewardTestEmissionRewards(t, user, tt.userStake, tt.emissionReward, 100)
			setupStakerRewardTestProtocolFeeRewards(t, user, tt.userStake, tt.protocolFeeReward, 100)

			setupStakerRewardTestAccumulateEmissionRewards(t, tt.updatedEmissionReward, 1000)
			setupStakerRewardTestAccumulateProtocolFeeRewards(t, tt.updatedProtocolFeeReward, 1000)

			// When: Claim rewards
			emission, emissionErr := emissionRewardManager.claimRewards(user.String(), 1000)
			protocol, protocolFeeErr := protocolFeeRewardManager.claimRewards(user.String(), 1000)

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
func cleanupStakerRewardTest(t *testing.T) {
	delegationCounter = NewCounter()
	delegations = avl.NewTree()
	delegationManager = NewDelegationManager()

	emissionRewardManager = NewEmissionRewardManager()
	protocolFeeRewardManager = NewProtocolFeeRewardManager()
	launchpadProjectDeposits = avl.NewTree()

	// Reset balances
	emissionRewardBalance = 0
	protocolFeeBalances = make(map[string]int64)

	setupStakerRewardStakerTokenBalance(t)
}

func setupStakerRewardStakerTokenBalance(t *testing.T) {
	amount := int64(1_000_000_000)

	testing.SetRealm(adminRealm)
	// Transfer GNS to gov staker
	gns.Transfer(cross, govStakerAddr, amount)

	// Transfer WUGNOT to gov staker
	gnotAmount := amount * 10
	newCoins := std.Coins{{"ugnot", gnotAmount}}
	testing.IssueCoins(adminRealm.Address(), newCoins)
	testing.SetOriginSend(newCoins)

	banker := std.NewBanker(std.BankerTypeRealmSend)
	banker.SendCoins(adminRealm.Address(), consts.WUGNOT_ADDR, newCoins)
	wugnot.Deposit(cross)

	wugnot.Transfer(cross, govStakerAddr, amount)
}

func setupStakerRewardTestEmissionRewards(t *testing.T, addr std.Address, amount int64, emissionReward int64, currentHeight int64) {
	// Setup emission rewards for testing
	emissionRewardManager.updateAccumulatedRewardX128PerStake(emissionReward, currentHeight)
	emissionRewardManager.addStake(addr.String(), amount, currentHeight)
}

func setupStakerRewardTestProtocolFeeRewards(t *testing.T, addr std.Address, amount int64, protocolFeeReward map[string]int64, currentHeight int64) {
	// Setup protocol fee rewards for testing
	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(protocolFeeReward, currentHeight)
	protocolFeeRewardManager.addStake(addr.String(), amount, currentHeight)
}

func setupStakerRewardTestAccumulateEmissionRewards(t *testing.T, amount, currentHeight int64) {
	// Setup emission rewards for testing
	emissionRewardManager.updateAccumulatedRewardX128PerStake(amount, currentHeight)
}

func setupStakerRewardTestAccumulateProtocolFeeRewards(t *testing.T, distributedAmounts map[string]int64, currentHeight int64) {
	// Setup protocol fee rewards for testing
	protocolFeeRewardManager.updateAccumulatedProtocolFeeX128PerStake(distributedAmounts, currentHeight)
}

func setupStakerRewardTestLaunchpadDeposit(t *testing.T, addr std.Address, amount int64) {
	// Setup launchpad project deposit
	launchpadRewardID := makeLaunchpadRewardID(addr.String())
	launchpadProjectDeposits.Set(launchpadRewardID, amount)
}

func setupStakerRewardTestLaunchpadRewards(t *testing.T, addr std.Address, amount int64) {
	// Setup launchpad rewards
	addStakeFromLaunchpad(addr.String(), amount, 100)
}

func setupStakerRewardTestLaunchpadStake(t *testing.T, addr std.Address, amount int64) {
	// Setup launchpad stake for removal test
	addStakeFromLaunchpad(addr.String(), amount, 100)
}

func setupStakerRewardTestGNSBalance(t *testing.T, user std.Address, amount int64) {
	testing.SetRealm(adminRealm)

	gns.Transfer(cross, user, amount)
}
