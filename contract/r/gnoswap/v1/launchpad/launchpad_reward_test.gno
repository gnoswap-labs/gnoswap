package launchpad

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestCollectDepositReward(t *testing.T) {
	tests := []struct {
		name           string
		setupFunc      func() (*Deposit, map[string]interface{})
		deposit        *Deposit
		currentTime    int64
		expectedAmount int64
		expectedError  string
	}{
		{
			name: "invalid time returns error",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_1",
					projectID:     "project_1",
					tier:          30,
					depositAmount: 1000,
				}
				return deposit, nil
			},
			deposit:        &Deposit{id: "deposit_1"},
			currentTime:    0,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-028] invalid time || currentTime must be positive",
		},
		{
			name: "project tier not found returns error",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_1",
					projectID:     "project_not_exist",
					tier:          30,
					depositAmount: 1000,
				}

				projects = avl.NewTree()

				return deposit, nil
			},
			deposit:        &Deposit{id: "deposit_1", projectID: "project_not_exist", tier: 30},
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-003] requested data not found || project(project_not_exist) not found",
		},
		{
			name: "reward manager not found returns error",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_1",
					projectID:     "project_1",
					tier:          30,
					depositAmount: 1000,
				}

				// Create project with tier but without reward manager
				project := &Project{
					id:    "project_1",
					tiers: make(map[int64]*ProjectTier),
				}
				projectTier := &ProjectTier{
					id:                 "project_1:30",
					totalDepositAmount: 5000,
				}
				project.tiers[30] = projectTier
				projects.Set("project_1", project)

				projectTierRewardManagers = avl.NewTree()

				return deposit, nil
			},
			deposit:        &Deposit{id: "deposit_1", projectID: "project_1", tier: 30},
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-003] requested data not found || reward manager(project_1:30) not found",
		},
		{
			name: "successful reward collection with zero reward",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_1",
					projectID:     "project_1",
					tier:          30,
					depositAmount: 1000,
					createdAt:     50,
				}

				// Create project with tier
				project := &Project{
					id:    "project_1",
					tiers: make(map[int64]*ProjectTier),
				}
				projectTier := &ProjectTier{
					id:                  "project_1:30",
					totalDepositAmount:  5000,
					totalWithdrawAmount: 0,
				}
				project.tiers[30] = projectTier
				projects.Set("project_1", project)

				// Create reward manager with minimal rewards
				rewardManager := &RewardManager{
					rewards:                         avl.NewTree(),
					accumulatedRewardPerDepositX128: u256.Zero(),
					distributeAmountPerSecondX128:   u256.NewUintFromInt64(1), // Small non-zero value
					accumulatedHeight:               50,
					distributeStartTime:             40,
					distributeEndTime:               200,
					totalDistributeAmount:           1000,
				}

				// Add reward state for the deposit
				rewardState := &RewardState{
					priceDebtX128:       u256.Zero(),
					depositAmount:       1000,
					claimedAmount:       0,
					distributeStartTime: 40,
					distributeEndTime:   200,
					claimableTime:       40,
				}
				rewardManager.rewards.Set("deposit_1", rewardState)

				projectTierRewardManagers.Set("project_1:30", rewardManager)

				return deposit, map[string]interface{}{
					"project":       project,
					"projectTier":   projectTier,
					"rewardManager": rewardManager,
				}
			},
			deposit:        &Deposit{id: "deposit_1", projectID: "project_1", tier: 30},
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "",
		},
		{
			name: "successful reward collection with positive reward",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_2",
					projectID:     "project_1",
					tier:          30,
					depositAmount: 1000,
					createdAt:     100,
					createdHeight: 100,
				}

				// Create project with tier
				project := &Project{
					id:    "project_1",
					tiers: make(map[int64]*ProjectTier),
				}
				projectTier := &ProjectTier{
					id:                  "project_1:30",
					totalDepositAmount:  5000,
					totalWithdrawAmount: 0,
				}
				project.tiers[30] = projectTier
				projects.Set("project_1", project)

				// Create reward manager with rewards
				rewardPerSecond := u256.NewUintFromInt64(100)
				accumulatedReward := u256.NewUintFromInt64(1000)
				accumulatedReward = u256.Zero().Lsh(accumulatedReward, 128) // Convert to Q128

				rewardManager := &RewardManager{
					rewards:                         avl.NewTree(),
					accumulatedRewardPerDepositX128: accumulatedReward,
					distributeAmountPerSecondX128:   rewardPerSecond,
					accumulatedHeight:               90,
					distributeStartTime:             40,
					distributeEndTime:               200,
					totalDistributeAmount:           10000,
					totalClaimedAmount:              0,
				}

				// Add reward state for the deposit with some accumulated rewards
				rewardState := &RewardState{
					priceDebtX128:       u256.Zero(),
					depositAmount:       1000,
					claimedAmount:       0,
					distributeStartTime: 40,
					distributeEndTime:   200,
					claimableTime:       50,
				}
				rewardManager.rewards.Set("deposit_2", rewardState)

				projectTierRewardManagers.Set("project_1:30", rewardManager)

				return deposit, map[string]interface{}{
					"project":        project,
					"projectTier":    projectTier,
					"rewardManager":  rewardManager,
					"expectedReward": int64(1000), // Expected reward based on calculation
				}
			},
			deposit:        &Deposit{id: "deposit_2", projectID: "project_1", tier: 30},
			currentTime:    200,
			expectedAmount: 1000000,
			expectedError:  "",
		},
		{
			name: "reward manager update fails",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				deposit := &Deposit{
					id:            "deposit_3",
					projectID:     "project_1",
					tier:          30,
					depositAmount: 1000,
				}

				// Create project with tier
				project := &Project{
					id:    "project_1",
					tiers: make(map[int64]*ProjectTier),
				}
				projectTier := &ProjectTier{
					id:                  "project_1:30",
					totalDepositAmount:  5000,
					totalWithdrawAmount: 0,
				}
				project.tiers[30] = projectTier
				projects.Set("project_1", project)

				// Create reward manager with invalid state
				rewardManager := &RewardManager{
					rewards:                         avl.NewTree(),
					accumulatedRewardPerDepositX128: u256.Zero(),
					distributeAmountPerSecondX128:   u256.Zero(),
					accumulatedHeight:               150, // Higher than current height
					distributeStartTime:             40,
					distributeEndTime:               200,
				}

				projectTierRewardManagers.Set("project_1:30", rewardManager)

				return deposit, nil
			},
			deposit:        &Deposit{id: "deposit_3", projectID: "project_1", tier: 30},
			currentTime:    100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-001] no left reward || rewardPerSecond(%!d((unhandled)))",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// capture original state
			origProjects := projects
			origProjectTierRewardManagers := projectTierRewardManagers

			projects = avl.NewTree()
			projectTierRewardManagers = avl.NewTree()

			var deposit *Deposit
			if tt.setupFunc != nil {
				deposit, _ = tt.setupFunc()
			} else {
				deposit = tt.deposit
			}

			amount, err := collectDepositReward(deposit, 100, tt.currentTime)

			if tt.expectedError != "" {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, tt.expectedAmount, amount)
			}

			// restore original state
			projects = origProjects
			projectTierRewardManagers = origProjectTierRewardManagers
		})
	}
}

// TestCollectDepositReward_TimeBoundaries tests edge cases around time boundaries
func TestCollectDepositReward_TimeBoundaries(t *testing.T) {
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
			// Reset state
			projects = avl.NewTree()
			projectTierRewardManagers = avl.NewTree()

			// Setup project
			project := &Project{
				id:        "boundary_test",
				tokenPath: "gno.land/r/onbloc/obl",
				tiers: map[int64]*ProjectTier{
					30: {
						id:                    "boundary_test:30",
						totalDistributeAmount: 1000,
					},
				},
			}
			projects.Set(project.ID(), project)

			// Setup reward manager
			rewardManager := NewRewardManager(
				1000, // total amount
				tt.startTime,
				tt.endTime,
				100,          // current height
				tt.startTime, // initial time
			)

			// Add deposit reward state
			deposit := &Deposit{
				id:        "boundary_deposit",
				projectID: "boundary_test",
				tier:      30,
			}

			rewardState := &RewardState{
				depositAmount:       1000000,
				distributeStartTime: 100,
				distributeEndTime:   200,
				accumulatedHeight:   100,
				priceDebtX128:       u256.Zero(),
				claimableTime:       100,
			}
			rewardManager.rewards.Set(deposit.ID(), rewardState)

			// Update to current time
			if tt.currentTime > tt.startTime {
				rewardManager.updateRewardPerDepositX128(1000000, 150, tt.currentTime)
			}

			projectTierRewardManagers.Set("boundary_test:30", rewardManager)

			// Collect reward
			amount, err := collectDepositReward(deposit, 150, tt.currentTime)
			if tt.expectedError != "" {
				uassert.Error(t, err)
				uassert.Equal(t, tt.expectedError, err.Error())
				return
			}

			uassert.NoError(t, err)

			// Verify reward
			if amount < (tt.expectedReward-5) || amount > (tt.expectedReward+5) {
				t.Errorf("%s: expected ~%d, got %d", tt.description, tt.expectedReward, amount)
			}
		})
	}
}
