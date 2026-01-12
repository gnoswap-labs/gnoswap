package v1

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/launchpad"
)

func TestLaunchpadReward_CollectDepositReward(t *testing.T) {
	tests := []struct {
		name          string
		currentTime   int64
		projectID     string
		tier          int64
		depositAmount int64
		setupProject  bool
		setupManager  bool
		expectedError string
	}{
		{
			name:          "FAIL: currentTime is zero",
			currentTime:   0,
			projectID:     "project_1",
			tier:          30,
			depositAmount: 1000,
			setupProject:  false,
			setupManager:  false,
			expectedError: "[GNOSWAP-LAUNCHPAD-028] invalid time || currentTime must be positive",
		},
		{
			name:          "FAIL: project not found",
			currentTime:   100,
			projectID:     "project_not_exist",
			tier:          30,
			depositAmount: 1000,
			setupProject:  false,
			setupManager:  false,
			expectedError: "[GNOSWAP-LAUNCHPAD-003] requested data not found || project(project_not_exist) not found",
		},
		{
			name:          "FAIL: reward manager not found",
			currentTime:   100,
			projectID:     "project_1",
			tier:          30,
			depositAmount: 1000,
			setupProject:  true,
			setupManager:  false,
			expectedError: "[GNOSWAP-LAUNCHPAD-003] requested data not found || reward manager(project_1:30) not found",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			resetTestStore()
			lp := getTestImplementation()
			testing.SetHeight(123)
			setTestProjects(avl.NewTree())
			setTestProjectTierRewardManagers(avl.NewTree())

			// Setup project if needed
			if tt.setupProject {
				projects := getTestProjects()
				project := launchpad.NewProject(tt.projectID, GNS_PATH, 1000000, testutils.TestAddress("recipient"), 100, 1000)
				project.SetID(tt.projectID)

				projectTier := launchpad.NewProjectTier(tt.projectID, tt.tier, 1000000, 100, 200)
				projectTier.SetID(tt.projectID + ":30")
				projectTier.SetTotalDepositAmount(5000)

				tiers := make(map[int64]*launchpad.ProjectTier)
				tiers[tt.tier] = projectTier
				project.SetTiers(tiers)
				projects.Set(tt.projectID, project)
				setTestProjects(projects)
			}

			// Setup reward manager if needed
			if tt.setupManager {
				rewardManagers := getTestProjectTierRewardManagers()
				rewardManager := launchpad.NewRewardManager(1000, 40, 200, 0, 50, 50)
				rewardManager.SetRewards(avl.NewTree())
				rewardManager.SetAccumulatedRewardPerDepositX128(u256.Zero())
				rewardManager.SetDistributeAmountPerSecondX128(u256.NewUintFromInt64(1))
				rewardManagers.Set(tt.projectID+":30", rewardManager)
				setTestProjectTierRewardManagers(rewardManagers)
			}

			// Create deposit
			deposit := launchpad.NewDeposit("deposit_1", tt.projectID, tt.tier, testutils.TestAddress("depositor"), tt.depositAmount, 100, 100, 200)

			// Execute
			_, _, err := lp.collectDepositReward(deposit, runtime.ChainHeight(), tt.currentTime)

			// Verify
			if tt.expectedError != "" {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

func TestLaunchpadReward_CollectDepositReward_ClaimableDuration(t *testing.T) {
	const secondsPerDay = int64(60 * 60 * 24)

	tests := []struct {
		name                 string
		projectID            string
		tier                 int64
		depositAmount        int64
		skipBeforeDeposit    int64
		skipBeforeCollect    int64
		expectedHasPanic     bool
		expectedPanicMessage string
	}{
		{
			name:              "success - 30 tier claimable wait 1 days",
			projectID:         "project_1",
			tier:              30,
			depositAmount:     1000000,
			skipBeforeDeposit: 3 * secondsPerDay, // 3 day
			skipBeforeCollect: secondsPerDay,     // 1 day
			expectedHasPanic:  false,
		},
		{
			name:              "success - 90 tier claimable wait 1 days",
			projectID:         "project_1",
			tier:              90,
			depositAmount:     1000000,
			skipBeforeDeposit: 3 * secondsPerDay, // 3 day
			skipBeforeCollect: secondsPerDay,     // 1 day
			expectedHasPanic:  false,
		},
		{
			name:              "success - 180 tier claimable wait 1 days",
			projectID:         "project_1",
			tier:              180,
			depositAmount:     1000000,
			skipBeforeDeposit: 3 * secondsPerDay, // 3 day
			skipBeforeCollect: secondsPerDay,     // 1 day
			expectedHasPanic:  false,
		},
		{
			name:                 "fail - 30 tier claimable duration not reached",
			projectID:            "project_1",
			tier:                 30,
			depositAmount:        1000000,
			skipBeforeDeposit:    3 * secondsPerDay, // 3 day
			skipBeforeCollect:    0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:                 "fail - 30 tier claimable wait 1 days - 1 second",
			projectID:            "project_1",
			tier:                 30,
			depositAmount:        1000000,
			skipBeforeDeposit:    3 * secondsPerDay, // 3 day
			skipBeforeCollect:    secondsPerDay - 1,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:                 "fail - 90 tier claimable wait 7 days - 1 second",
			projectID:            "project_1",
			tier:                 90,
			depositAmount:        1000000,
			skipBeforeDeposit:    3 * secondsPerDay, // 3 day
			skipBeforeCollect:    secondsPerDay - 1,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:                 "fail - 180 tier claimable wait 14 days - 1 second",
			projectID:            "project_1",
			tier:                 180,
			depositAmount:        1000000,
			skipBeforeDeposit:    3 * secondsPerDay, // 3 day
			skipBeforeCollect:    secondsPerDay - 1,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:              "success - 30 tier claimable wait start time(3 days) + 30 days when ended project",
			projectID:         "project_1",
			tier:              30,
			depositAmount:     1000000,
			skipBeforeDeposit: 3*secondsPerDay + 30*secondsPerDay - 5, // wait start time(3 days) + 30 days - 5 seconds
			skipBeforeCollect: 5,                                      // 5 seconds per block
			expectedHasPanic:  false,
		},
		{
			name:              "success - 90 tier claimable wait start time(3 days) + 90 days when ended project",
			projectID:         "project_1",
			tier:              90,
			depositAmount:     1000000,
			skipBeforeDeposit: 3*secondsPerDay + 90*secondsPerDay - 5, // wait start time(3 days) + 90 days - 5 seconds
			skipBeforeCollect: 5,                                      // 5 seconds per block
			expectedHasPanic:  false,
		},
		{
			name:              "success - 180 tier claimable wait start time(3 days) + 180 days when ended project",
			projectID:         "project_1",
			tier:              180,
			depositAmount:     1000000,
			skipBeforeDeposit: 3*secondsPerDay + 180*secondsPerDay - 5, // wait start time(3 days) + 180 days - 5 seconds
			skipBeforeCollect: 5,                                       // 5 seconds per block
			expectedHasPanic:  false,
		},
		{
			name:                 "fail - 30 tier claimable wait start time(3 days) + 30 days - 5 seconds but not ended project",
			projectID:            "project_1",
			tier:                 30,
			depositAmount:        1000000,
			skipBeforeDeposit:    3*secondsPerDay + 30*secondsPerDay - 5, // wait start time(3 days) + 30 days - 5 seconds
			skipBeforeCollect:    0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:                 "fail - 90 tier claimable wait start time(3 days) + 90 days - 5 seconds but not ended project",
			projectID:            "project_1",
			tier:                 90,
			depositAmount:        1000000,
			skipBeforeDeposit:    3*secondsPerDay + 90*secondsPerDay - 5, // wait start time(3 days) + 90 days - 5 seconds
			skipBeforeCollect:    0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
		{
			name:                 "fail - 180 tier claimable wait start time(3 days) + 180 days - 5 seconds but not ended project",
			projectID:            "project_1",
			tier:                 180,
			depositAmount:        1000000,
			skipBeforeDeposit:    3*secondsPerDay + 180*secondsPerDay - 5, // wait start time(3 days) + 180 days - 5 seconds
			skipBeforeCollect:    0,
			expectedHasPanic:     true,
			expectedPanicMessage: "[GNOSWAP-LAUNCHPAD-019] invalid reward state",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			resetTestStore()

			currentTime := time.Now().Unix()
			secondsOf3Days := 3 * secondsPerDay

			adminAddr := access.MustGetAddress(prbac.ROLE_ADMIN.String())
			testing.SetRealm(testing.NewUserRealm(adminAddr))

			launchpadAddr := access.MustGetAddress(prbac.ROLE_LAUNCHPAD.String())
			gns.Approve(cross, launchpadAddr, math.MaxInt64)

			projectID := createProjectTest(
				t,
				"Test Project",
				GNS_PATH,
				testutils.TestAddress("recipient"),
				1000000,
				33,
				33,
				34,
				currentTime+secondsOf3Days,
			)

			// Skip to start project
			testing.SkipHeights(tt.skipBeforeDeposit / 5) // 5 seconds per block

			// Create deposit
			projectTierID := ufmt.Sprintf("%s:%d", projectID, tt.tier)
			depositID := depositGnsTest(t, projectTierID, tt.depositAmount)

			// Skip to test time
			testing.SkipHeights(tt.skipBeforeCollect / 5) // 5 seconds per block

			// Execute
			if tt.expectedHasPanic {
				uassert.AbortsContains(t, tt.expectedPanicMessage, func() {
					collectRewardTest(t, depositID)
				})
			} else {
				rewardAmount := collectRewardTest(t, depositID)
				uassert.True(t, rewardAmount > 0, "reward amount should be > 0")
			}
		})
	}
}

// TestCollectRewardByDepositId_Success tests successful reward collection scenarios
func TestLaunchpadReward_CollectRewardByDepositId_Success(t *testing.T) {
	tests := []struct {
		name               string
		env                testEnvConfig
		project            testProjectConfig
		depositors         []testDepositConfig
		skipToCollect      int64
		expectRewardRatio  []int64 // expected reward ratios between depositors
		checkBalanceChange bool
	}{
		{
			name: "single depositor collects reward",
			env:  testEnvConfig{initialTime: 1000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv1",
				tier30Pct:       100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "user1", depositAmount: 1000000, tier: 30},
			},
			skipToCollect:      testSkipTier30Claimable,
			checkBalanceChange: true,
		},
		{
			name: "two depositors with equal amounts get equal rewards",
			env:  testEnvConfig{initialTime: 2000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv2",
				tier30Pct:       100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "eqUser1", depositAmount: 1000000, tier: 30},
				{userSuffix: "eqUser2", depositAmount: 1000000, tier: 30},
			},
			skipToCollect:     testSkipTier30Claimable,
			expectRewardRatio: []int64{1, 1},
		},
		{
			name: "depositor with 2x amount gets 2x rewards",
			env:  testEnvConfig{initialTime: 3000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv3",
				tier30Pct:       100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "ratio1", depositAmount: 1000000, tier: 30},
				{userSuffix: "ratio2", depositAmount: 2000000, tier: 30},
			},
			skipToCollect:     testSkipTier30Claimable,
			expectRewardRatio: []int64{1, 2},
		},
		{
			name: "early depositor gets more rewards than late depositor",
			env:  testEnvConfig{initialTime: 4000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv4",
				tier30Pct:       100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "earlyUser", depositAmount: 1000000, tier: 30, depositDelay: 0},
				{userSuffix: "lateUser", depositAmount: 1000000, tier: 30, depositDelay: 100000},
			},
			skipToCollect: testSkipTier30Claimable,
		},
		{
			name: "tier 90 days collection",
			env:  testEnvConfig{initialTime: 5000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv5",
				tier90Pct:       100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "t90User", depositAmount: 1000000, tier: 90},
			},
			skipToCollect:      testSkipTier90Claimable,
			checkBalanceChange: true,
		},
		{
			name: "tier 180 days collection",
			env:  testEnvConfig{initialTime: 6000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv6",
				tier180Pct:      100,
			},
			depositors: []testDepositConfig{
				{userSuffix: "t180User", depositAmount: 1000000, tier: 180},
			},
			skipToCollect:      testSkipTier180Claimable,
			checkBalanceChange: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup environment
			launchpadAddr, adminRealm := setupTestEnvironment(t, tt.env)
			lp := getTestImplementation()

			// Create project
			projectID := createTestProject(t, lp, launchpadAddr, adminRealm, tt.project)

			// Create deposits
			userAddrs, depositIDs := createTestDeposits(t, lp, launchpadAddr, adminRealm, projectID, tt.depositors)

			// Skip to collection time
			testing.SkipHeights(tt.skipToCollect)

			// Collect rewards and verify
			rewards := make([]int64, len(tt.depositors))
			for i, userAddr := range userAddrs {
				balanceBefore := common.BalanceOf(testOblTokenPath, userAddr)
				rewards[i] = collectTestReward(t, lp, userAddr, depositIDs[i])
				balanceAfter := common.BalanceOf(testOblTokenPath, userAddr)

				// Verify reward was collected
				uassert.True(t, rewards[i] > 0, "reward should be > 0")

				// Verify balance change if requested
				if tt.checkBalanceChange {
					uassert.Equal(t, rewards[i], balanceAfter-balanceBefore)
				}
			}

			// Verify reward ratios if specified
			if len(tt.expectRewardRatio) > 0 && len(rewards) >= 2 {
				expectedLeft := rewards[1] * tt.expectRewardRatio[0]
				expectedRight := rewards[0] * tt.expectRewardRatio[1]
				diff := expectedLeft - expectedRight
				if diff < 0 {
					diff = -diff
				}
				// Allow small rounding differences from integer math and per-deposit timing.
				tolerance := expectedRight / 100 // 1%
				if tolerance < 1 {
					tolerance = 1
				}
				uassert.True(t, diff <= tolerance, "reward ratio mismatch")
			}

			// Special case: early vs late depositor
			if len(tt.depositors) == 2 && tt.depositors[1].depositDelay > 0 {
				uassert.True(t, rewards[0] > rewards[1], "early depositor should have more rewards")
			}
		})
	}
}

// TestCollectRewardByDepositId_UpdatesTotalCollectedAmount ensures collected rewards are reflected in project stats.
func TestLaunchpadReward_CollectRewardByDepositId_UpdatesTotalCollectedAmount(t *testing.T) {
	env := testEnvConfig{initialTime: 15000000}
	project := testProjectConfig{
		rewardAmount:    10000000,
		recipientSuffix: "recv14",
		tier30Pct:       100,
	}
	depositor := testDepositConfig{userSuffix: "statUser1", depositAmount: 1000000, tier: 30}

	launchpadAddr, adminRealm := setupTestEnvironment(t, env)
	lp := getTestImplementation()

	projectID := createTestProject(t, lp, launchpadAddr, adminRealm, project)
	userAddr, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, depositor)

	testing.SkipHeights(testSkipTier30Claimable)
	reward := collectTestReward(t, lp, userAddr, depositID)

	storedProject, err := lp.getProject(projectID)
	uassert.NoError(t, err)

	// Calculate total collected amount from tiers
	totalCollectedAmount := int64(0)
	remainingAmount := int64(0)
	for _, tier := range storedProject.Tiers() {
		totalCollectedAmount += tier.TotalCollectedAmount()
		remainingAmount += tier.TotalDistributeAmount() - tier.TotalCollectedAmount()
	}
	uassert.Equal(t, reward, totalCollectedAmount)
	uassert.Equal(t, safeSubInt64(storedProject.DepositAmount(), reward), remainingAmount)
}

// TestCollectRewardByDepositId_Failure tests error scenarios
func TestLaunchpadReward_CollectRewardByDepositId_Failure(t *testing.T) {
	tests := []struct {
		name             string
		env              testEnvConfig
		project          testProjectConfig
		setupDeposit     bool
		depositOwner     string
		caller           string
		depositIDToUse   string // override deposit ID if set
		haltLevel        halt.HaltLevel
		expectedErrorMsg string
	}{
		{
			name: "FAIL: non-owner cannot collect",
			env:  testEnvConfig{initialTime: 7000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv7",
				tier30Pct:       100,
			},
			setupDeposit:     true,
			depositOwner:     "owner1",
			caller:           "nonOwner1",
			expectedErrorMsg: "[GNOSWAP-LAUNCHPAD-026] invalid owner",
		},
		{
			name:             "FAIL: deposit does not exist",
			env:              testEnvConfig{initialTime: 8000000},
			setupDeposit:     false,
			caller:           "anyUser",
			depositIDToUse:   "nonexistent_dep",
			expectedErrorMsg: "[GNOSWAP-LAUNCHPAD-020] not exist deposit",
		},
		{
			name: "FAIL: emergency halt",
			env:  testEnvConfig{initialTime: 9000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv8",
				tier30Pct:       100,
			},
			setupDeposit:     true,
			depositOwner:     "haltOwner1",
			caller:           "haltOwner1",
			haltLevel:        halt.HaltLevelEmergency,
			expectedErrorMsg: "halted: launchpad",
		},
		{
			name: "FAIL: complete halt",
			env:  testEnvConfig{initialTime: 10000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv9",
				tier30Pct:       100,
			},
			setupDeposit:     true,
			depositOwner:     "haltOwner2",
			caller:           "haltOwner2",
			haltLevel:        halt.HaltLevelComplete,
			expectedErrorMsg: "halted: launchpad",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup environment
			launchpadAddr, adminRealm := setupTestEnvironment(t, tt.env)
			lp := getTestImplementation()

			var depositID string

			if tt.setupDeposit {
				// Create project
				projectID := createTestProject(t, lp, launchpadAddr, adminRealm, tt.project)

				// Create deposit
				_, depositID = createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID,
					testDepositConfig{userSuffix: tt.depositOwner, depositAmount: 1000000, tier: 30})

				testing.SkipHeights(testSkipTier30Claimable)
			}

			// Override deposit ID if specified
			if tt.depositIDToUse != "" {
				depositID = tt.depositIDToUse
			}

			// Set halt level if specified
			if tt.haltLevel != "" {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, tt.haltLevel)
			}

			// Execute and verify error
			callerAddr := testutils.TestAddress(tt.caller)
			testing.SetRealm(testing.NewUserRealm(callerAddr))

			uassert.AbortsContains(t, tt.expectedErrorMsg, func() {
				func(cur realm) {
					testing.SetRealm(testing.NewCodeRealm(testLaunchpadPkgPath))
					lp.CollectRewardByDepositId(depositID)
				}(cross)
			})

			// Cleanup halt
			if tt.haltLevel != "" {
				testing.SetRealm(adminRealm)
				halt.SetHaltLevel(cross, halt.HaltLevelNone)
			}
		})
	}
}

// TestCollectRewardByDepositId_ConsecutiveCollections tests multiple collections
func TestLaunchpadReward_CollectRewardByDepositId_ConsecutiveCollections(t *testing.T) {
	tests := []struct {
		name                string
		env                 testEnvConfig
		project             testProjectConfig
		depositor           testDepositConfig
		skipToFirstCollect  int64
		skipBetweenCollects int64
		expectSecondReward  bool // false means second reward should be 0
	}{
		{
			name: "consecutive collections accumulate rewards",
			env:  testEnvConfig{initialTime: 11000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv10",
				tier30Pct:       100,
			},
			depositor:           testDepositConfig{userSuffix: "multiUser", depositAmount: 1000000, tier: 30},
			skipToFirstCollect:  testSkipTier30Claimable,
			skipBetweenCollects: 100000,
			expectSecondReward:  true,
		},
		{
			name: "immediate second collection returns zero",
			env:  testEnvConfig{initialTime: 12000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv11",
				tier30Pct:       100,
			},
			depositor:           testDepositConfig{userSuffix: "zeroUser", depositAmount: 1000000, tier: 30},
			skipToFirstCollect:  testSkipTier30Claimable,
			skipBetweenCollects: 0,
			expectSecondReward:  false,
		},
		{
			name: "collection after distribution ends returns zero",
			env:  testEnvConfig{initialTime: 13000000},
			project: testProjectConfig{
				rewardAmount:    10000000,
				recipientSuffix: "recv12",
				tier30Pct:       100,
			},
			depositor:           testDepositConfig{userSuffix: "endUser", depositAmount: 1000000, tier: 30},
			skipToFirstCollect:  testSkipTier30End,
			skipBetweenCollects: 1000,
			expectSecondReward:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup environment
			launchpadAddr, adminRealm := setupTestEnvironment(t, tt.env)
			lp := getTestImplementation()

			// Create project and depositor
			projectID := createTestProject(t, lp, launchpadAddr, adminRealm, tt.project)
			userAddr, depositID := createTestDeposit(t, lp, launchpadAddr, adminRealm, projectID, tt.depositor)

			// First collection
			testing.SkipHeights(tt.skipToFirstCollect)
			balanceBefore1 := common.BalanceOf(testOblTokenPath, userAddr)
			reward1 := collectTestReward(t, lp, userAddr, depositID)
			balanceAfter1 := common.BalanceOf(testOblTokenPath, userAddr)

			uassert.True(t, reward1 > 0, "first reward should be > 0")
			uassert.Equal(t, reward1, balanceAfter1-balanceBefore1)

			// Second collection
			testing.SkipHeights(tt.skipBetweenCollects)
			balanceBefore2 := common.BalanceOf(testOblTokenPath, userAddr)
			reward2 := collectTestReward(t, lp, userAddr, depositID)
			balanceAfter2 := common.BalanceOf(testOblTokenPath, userAddr)

			uassert.Equal(t, reward2, balanceAfter2-balanceBefore2)

			if tt.expectSecondReward {
				uassert.True(t, reward2 > 0, "second reward should be > 0")
			} else {
				uassert.True(t, reward2 <= reward1/100, "second reward should be minimal or zero")
			}
		})
	}
}

// TestCollectRewardByDepositId_BalanceIntegrity tests that total rewards distributed match balance changes
func TestLaunchpadReward_CollectRewardByDepositId_BalanceIntegrity(t *testing.T) {
	env := testEnvConfig{initialTime: 14000000}
	project := testProjectConfig{
		rewardAmount:    10000000,
		recipientSuffix: "recv13",
		tier30Pct:       100,
	}
	depositors := []testDepositConfig{
		{userSuffix: "intUser1", depositAmount: 1000000, tier: 30},
		{userSuffix: "intUser2", depositAmount: 1000000, tier: 30},
		{userSuffix: "intUser3", depositAmount: 1000000, tier: 30},
	}

	// Setup environment
	launchpadAddr, adminRealm := setupTestEnvironment(t, env)
	lp := getTestImplementation()

	// Create project
	projectID := createTestProject(t, lp, launchpadAddr, adminRealm, project)
	launchpadBalanceAfterCreate := common.BalanceOf(testOblTokenPath, launchpadAddr)

	// Create all deposits
	userAddrs, depositIDs := createTestDeposits(t, lp, launchpadAddr, adminRealm, projectID, depositors)

	// Skip to collection time
	testing.SkipHeights(testSkipTier30Claimable)

	// Collect all rewards
	rewards := make([]int64, len(depositors))
	for i, userAddr := range userAddrs {
		rewards[i] = collectTestReward(t, lp, userAddr, depositIDs[i])
	}

	// Verify total distributed
	totalDistributed := int64(0)
	for _, r := range rewards {
		totalDistributed += r
	}

	launchpadBalanceAfterCollect := common.BalanceOf(testOblTokenPath, launchpadAddr)
	launchpadBalanceDecrease := launchpadBalanceAfterCreate - launchpadBalanceAfterCollect

	uassert.Equal(t, totalDistributed, launchpadBalanceDecrease)

	// Verify each user received their reward
	for i, userAddr := range userAddrs {
		userBalance := common.BalanceOf(testOblTokenPath, userAddr)
		uassert.Equal(t, rewards[i], userBalance)
	}
}
