package launchpad

import (
	"testing"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestCollectDepositReward(t *testing.T) {
	tests := []struct {
		name           string
		setupFunc      func() (*Deposit, map[string]interface{})
		deposit        *Deposit
		currentHeight  int64
		expectedAmount int64
		expectedError  string
	}{
		{
			name: "nil deposit returns error",
			setupFunc: func() (*Deposit, map[string]interface{}) {
				return nil, nil
			},
			deposit:        nil,
			currentHeight:  100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-020] not exist deposit || deposit is nil",
		},
		{
			name: "invalid height returns error",
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
			currentHeight:  0,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-028] invalid height || currentHeight must be positive",
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
			currentHeight:  100,
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
			currentHeight:  100,
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
					createdBlockTimeInfo: &BlockTimeInfo{
						blockTime:   1000,
						blockHeight: 50,
					},
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
					distributeAmountPerBlockX128:    u256.NewUintFromInt64(1), // Small non-zero value
					accumulatedHeight:               50,
					distributeStartHeight:           40,
					distributeEndHeight:             200,
					totalDistributeAmount:           1000,
				}

				// Add reward state for the deposit
				rewardState := &RewardState{
					priceDebtX128:         u256.Zero(),
					depositAmount:         1000,
					claimedAmount:         0,
					distributeStartHeight: 40,
					distributeEndHeight:   200,
					claimableBlockTimeInfo: &BlockTimeInfo{
						blockTime:   1000,
						blockHeight: 50,
					},
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
			currentHeight:  100,
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
					createdBlockTimeInfo: &BlockTimeInfo{
						blockTime:   1000,
						blockHeight: 50,
					},
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
				rewardPerBlock := u256.NewUintFromInt64(100)
				accumulatedReward := u256.NewUintFromInt64(1000)
				accumulatedReward = u256.Zero().Lsh(accumulatedReward, 128) // Convert to Q128

				rewardManager := &RewardManager{
					rewards:                         avl.NewTree(),
					accumulatedRewardPerDepositX128: accumulatedReward,
					distributeAmountPerBlockX128:    rewardPerBlock,
					accumulatedHeight:               90,
					distributeStartHeight:           40,
					distributeEndHeight:             200,
					totalDistributeAmount:           10000,
					totalClaimedAmount:              0,
				}

				// Add reward state for the deposit with some accumulated rewards
				rewardState := &RewardState{
					priceDebtX128:         u256.Zero(),
					depositAmount:         1000,
					claimedAmount:         0,
					distributeStartHeight: 40,
					distributeEndHeight:   200,
					claimableBlockTimeInfo: &BlockTimeInfo{
						blockTime:   1000,
						blockHeight: 50,
					},
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
			currentHeight:  100,
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
					distributeAmountPerBlockX128:    u256.Zero(),
					accumulatedHeight:               150, // Higher than current height
					distributeStartHeight:           40,
					distributeEndHeight:             200,
				}

				projectTierRewardManagers.Set("project_1:30", rewardManager)

				return deposit, nil
			},
			deposit:        &Deposit{id: "deposit_3", projectID: "project_1", tier: 30},
			currentHeight:  100,
			expectedAmount: 0,
			expectedError:  "[GNOSWAP-LAUNCHPAD-019] invalid reward state || currentHeight 100 is less than AccumulatedHeight 150",
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

			amount, err := collectDepositReward(deposit, tt.currentHeight)

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
