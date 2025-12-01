package v1

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/launchpad"
)

func TestLaunchpadReward_CollectDepositReward(t *testing.T) {
	tests := []struct {
		name           string
		setupFunc      func() (*launchpad.Deposit, map[string]interface{})
		deposit        *launchpad.Deposit
		currentTime    int64
		expectedAmount int64
		expectedError  string
	}{
		{
			name: "invalid time returns error",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_1", "project_1", 30, testutils.TestAddress("depositor"), 1000, 100, 100, 200)
				return deposit, nil
			},
			deposit:        launchpad.NewDeposit("deposit_1", "", 0, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    0,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-028] invalid time || currentTime must be positive",
		},
		{
			name: "project tier not found returns error",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_1", "project_not_exist", 30, testutils.TestAddress("depositor"), 1000, 100, 100, 200)

				setTestProjects(avl.NewTree())

				return deposit, nil
			},
			deposit:        launchpad.NewDeposit("deposit_1", "project_not_exist", 30, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-003] requested data not found || project(project_not_exist) not found",
		},
		{
			name: "reward manager not found returns error",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_1", "project_1", 30, testutils.TestAddress("depositor"), 1000, 100, 100, 200)

				// Create project with tier but without reward manager
				projects := getTestProjects()
				project := launchpad.NewProject("project_1", "gno.land/r/test/token", 1000000, testutils.TestAddress("recipient"), 100, 1000)
				project.SetID("project_1")

				projectTier := launchpad.NewProjectTier("project_1", 30, 1000000, 100, 200)
				projectTier.SetID("project_1:30")
				projectTier.SetTotalDepositAmount(5000)

				tiers := make(map[int64]*launchpad.ProjectTier)
				tiers[30] = projectTier
				project.SetTiers(tiers)
				projects.Set("project_1", project)
				setTestProjects(projects)

				setTestProjectTierRewardManagers(avl.NewTree())

				return deposit, nil
			},
			deposit:        launchpad.NewDeposit("deposit_1", "project_1", 30, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-003] requested data not found || reward manager(project_1:30) not found",
		},
		{
			name: "successful reward collection with zero reward",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_1", "project_1", 30, testutils.TestAddress("depositor"), 1000, 50, 50, 200)

				// Create project with tier
				projects := getTestProjects()
				project := launchpad.NewProject("project_1", GNS_PATH, 1000000, testutils.TestAddress("recipient"), 100, 1000)
				project.SetID("project_1")

				projectTier := launchpad.NewProjectTier("project_1", 30, 1000000, 100, 200)
				projectTier.SetID("project_1:30")
				projectTier.SetTotalDepositAmount(5000)
				projectTier.SetTotalWithdrawAmount(0)

				tiers := make(map[int64]*launchpad.ProjectTier)
				tiers[30] = projectTier
				project.SetTiers(tiers)
				projects.Set("project_1", project)
				setTestProjects(projects)

				// Create reward manager with minimal rewards
				rewardManagers := getTestProjectTierRewardManagers()
				rewardManager := launchpad.NewRewardManager(1000, 40, 200, 50, 50)
				rewardManager.SetRewards(avl.NewTree())
				rewardManager.SetAccumulatedRewardPerDepositX128(u256.Zero())
				rewardManager.SetDistributeAmountPerSecondX128(u256.NewUintFromInt64(1)) // Small non-zero value
				rewardManager.SetAccumulatedHeight(50)

				// Add reward state for the deposit
				rewardState := launchpad.NewRewardState(u256.Zero(), 1000, 40, 200, 40)
				rewardState.SetClaimedAmount(0)
				rewardManager.Rewards().Set("deposit_1", rewardState)

				rewardManagers.Set("project_1:30", rewardManager)
				setTestProjectTierRewardManagers(rewardManagers)

				return deposit, map[string]interface{}{
					"project":       project,
					"projectTier":   projectTier,
					"rewardManager": rewardManager,
				}
			},
			deposit:        launchpad.NewDeposit("deposit_1", "project_1", 30, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "",
		},
		{
			name: "successful reward collection with positive reward",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_2", "project_1", 30, testutils.TestAddress("depositor"), 1000, 100, 100, 200)

				// Create project with tier
				projects := getTestProjects()
				project := launchpad.NewProject("project_1", GNS_PATH, 1000000, testutils.TestAddress("recipient"), 100, 1000)
				project.SetID("project_1")

				projectTier := launchpad.NewProjectTier("project_1", 30, 1000000, 100, 200)
				projectTier.SetID("project_1:30")
				projectTier.SetTotalDepositAmount(5000)
				projectTier.SetTotalWithdrawAmount(0)

				tiers := make(map[int64]*launchpad.ProjectTier)
				tiers[30] = projectTier
				project.SetTiers(tiers)
				projects.Set("project_1", project)
				setTestProjects(projects)

				// Create reward manager with rewards
				rewardPerSecond := u256.NewUintFromInt64(100)
				accumulatedReward := u256.NewUintFromInt64(1000)
				accumulatedReward = u256.Zero().Lsh(accumulatedReward, 128) // Convert to Q128

				rewardManagers := getTestProjectTierRewardManagers()
				rewardManager := launchpad.NewRewardManager(10000, 40, 200, 90, 100)
				rewardManager.SetRewards(avl.NewTree())
				rewardManager.SetAccumulatedRewardPerDepositX128(accumulatedReward)
				rewardManager.SetDistributeAmountPerSecondX128(rewardPerSecond)
				rewardManager.SetAccumulatedHeight(90)
				rewardManager.SetTotalClaimedAmount(0)

				// Add reward state for the deposit with some accumulated rewards
				rewardState := launchpad.NewRewardState(u256.Zero(), 1000, 40, 200, 50)
				rewardState.SetClaimedAmount(0)
				rewardManager.Rewards().Set("deposit_2", rewardState)

				rewardManagers.Set("project_1:30", rewardManager)
				setTestProjectTierRewardManagers(rewardManagers)

				return deposit, map[string]interface{}{
					"project":        project,
					"projectTier":    projectTier,
					"rewardManager":  rewardManager,
					"expectedReward": int64(1000), // Expected reward based on calculation
				}
			},
			deposit:        launchpad.NewDeposit("deposit_2", "project_1", 30, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    200,
			expectedAmount: 1000000,
			expectedError:  "",
		},
		{
			name: "reward manager update fails",
			setupFunc: func() (*launchpad.Deposit, map[string]interface{}) {
				deposit := launchpad.NewDeposit("deposit_3", "project_1", 30, testutils.TestAddress("depositor"), 1000, 100, 100, 200)

				// Create project with tier
				projects := getTestProjects()
				project := launchpad.NewProject("project_1", "gno.land/r/test/token", 1000000, testutils.TestAddress("recipient"), 100, 1000)
				project.SetID("project_1")
				projectTier := launchpad.NewProjectTier("project_1", 30, 1000000, 100, 200)
				projectTier.SetID("project_1:30")
				projectTier.SetTotalDepositAmount(5000)
				projectTier.SetTotalWithdrawAmount(0)

				tiers := make(map[int64]*launchpad.ProjectTier)
				tiers[30] = projectTier
				project.SetTiers(tiers)
				projects.Set("project_1", project)
				setTestProjects(projects)

				// Create reward manager with invalid state
				rewardManagers := getTestProjectTierRewardManagers()
				rewardManager := launchpad.NewRewardManager(0, 40, 200, 150, 100)
				rewardManager.SetRewards(avl.NewTree())
				rewardManager.SetAccumulatedRewardPerDepositX128(u256.Zero())
				rewardManager.SetDistributeAmountPerSecondX128(u256.Zero())
				rewardManager.SetAccumulatedHeight(150) // Higher than current height

				rewardManagers.Set("project_1:30", rewardManager)
				setTestProjectTierRewardManagers(rewardManagers)

				return deposit, nil
			},
			deposit:        launchpad.NewDeposit("deposit_3", "project_1", 30, testutils.TestAddress(""), 0, 0, 0, 0),
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-001] no left reward || rewardPerSecond(%!d((unhandled)))",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset test store
			resetTestStore()
			lp := getTestImplementation()
			testing.SetHeight(123)

			setTestProjects(avl.NewTree())
			setTestProjectTierRewardManagers(avl.NewTree())

			var deposit *launchpad.Deposit
			if tt.setupFunc != nil {
				deposit, _ = tt.setupFunc()
			} else {
				deposit = tt.deposit
			}

			rewardTokenPath, amount, err := lp.collectDepositReward(deposit, runtime.ChainHeight(), tt.currentTime)

			if tt.expectedError != "" {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedAmount, amount)
				uassert.Equal(t, GNS_PATH, rewardTokenPath)
			}
		})
	}
}

// TestCollectDepositReward_TimeBoundaries tests edge cases around time boundaries
func TestLaunchpadReward_CollectDepositRewardTimeBoundaries(t *testing.T) {
	tests := []struct {
		name           string
		currentTime    int64
		startTime      int64
		endTime        int64
		expectedReward int64
		expectedError  string
		description    string
	}{
		{
			name:           "before distribution start",
			currentTime:    90,
			startTime:      100,
			endTime:        200,
			expectedReward: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-019] invalid reward state || currentTime 90 is less than claimableTime 100",
			description:    "No rewards before distribution starts",
		},
		{
			name:           "exactly at start",
			currentTime:    100,
			startTime:      100,
			endTime:        200,
			expectedReward: 0,
			description:    "No rewards at exact start time",
		},
		{
			name:           "exactly at end",
			currentTime:    200,
			startTime:      100,
			endTime:        200,
			expectedReward: 1000,
			description:    "Full rewards at end time",
		},
		{
			name:           "after distribution end",
			currentTime:    300,
			startTime:      100,
			endTime:        200,
			expectedReward: 1000,
			description:    "Full rewards after end time",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset test store
			resetTestStore()
			lp := getTestImplementation()
			testing.SetHeight(123)

			setTestProjects(avl.NewTree())
			setTestProjectTierRewardManagers(avl.NewTree())

			// Setup project
			projects := getTestProjects()
			project := launchpad.NewProject("boundary_test", "gno.land/r/onbloc/obl", 1000000, testutils.TestAddress("recipient"), 100, 1000)
			project.SetID("boundary_test")

			tier30 := launchpad.NewProjectTier("boundary_test", 30, 1000, 100, 200)
			tier30.SetID("boundary_test:30")

			tiers := map[int64]*launchpad.ProjectTier{
				30: tier30,
			}
			project.SetTiers(tiers)
			projects.Set(project.ID(), project)
			setTestProjects(projects)

			// Setup reward manager
			rewardManager := newRewardManager(
				1000, // total amount
				tt.startTime,
				tt.endTime,
				100,          // current height
				tt.startTime, // initial time
			)

			// Add deposit reward state
			deposit := launchpad.NewDeposit("boundary_deposit", "boundary_test", 30, testutils.TestAddress("depositor"), 0, 0, 0, 0)

			rewardState := launchpad.NewRewardState(u256.Zero(), 1000000, 100, 200, 100)
			rewardState.SetAccumulatedHeight(100)
			rewards := rewardManager.Rewards()
			rewards.Set(deposit.ID(), rewardState)

			// Update to current time
			if tt.currentTime > tt.startTime {
				updateRewardPerDepositX128(rewardManager, 1000000, 150, tt.currentTime)
			}

			rewardManagers := getTestProjectTierRewardManagers()
			rewardManagers.Set("boundary_test:30", rewardManager)
			setTestProjectTierRewardManagers(rewardManagers)

			// Collect reward
			rewardTokenPath, amount, err := lp.collectDepositReward(deposit, 150, tt.currentTime)
			if tt.expectedError != "" {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
				return
			}

			uassert.NoError(t, err)
			uassert.Equal(t, "gno.land/r/onbloc/obl", rewardTokenPath)
			// Verify reward
			if amount < (tt.expectedReward-5) || amount > (tt.expectedReward+5) {
				t.Errorf("%s: expected ~%d, got %d", tt.description, tt.expectedReward, amount)
			}
		})
	}
}
