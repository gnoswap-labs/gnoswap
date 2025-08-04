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
					distributeAmountPerSecondX128:   u256.NewUintFromInt64(1), // Small non-zero value
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
				rewardPerSecond := u256.NewUintFromInt64(100)
				accumulatedReward := u256.NewUintFromInt64(1000)
				accumulatedReward = u256.Zero().Lsh(accumulatedReward, 128) // Convert to Q128

				rewardManager := &RewardManager{
					rewards:                         avl.NewTree(),
					accumulatedRewardPerDepositX128: accumulatedReward,
					distributeAmountPerSecondX128:   rewardPerSecond,
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
					distributeAmountPerSecondX128:   u256.Zero(),
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

// TestCollectDepositReward_VaryingBlockTimes tests reward collection with varying block times
func TestCollectDepositReward_VaryingBlockTimes(t *testing.T) {
	// These tests ensure rewards are calculated based on time elapsed, not blocks elapsed
	
	tests := []struct {
		name           string
		scenario       string
		blockPattern   string // "fast", "slow", "irregular"
		expectedReward int64
		tolerance      int64
	}{
		{
			name:           "fast blocks - 1 second per block",
			scenario:       "100 blocks in 100 seconds",
			blockPattern:   "fast",
			expectedReward: 500, // 50% of time elapsed
			tolerance:      5,
		},
		{
			name:           "slow blocks - 20 seconds per block",
			scenario:       "5 blocks in 100 seconds",
			blockPattern:   "slow",
			expectedReward: 500, // 50% of time elapsed
			tolerance:      5,
		},
		{
			name:           "irregular blocks - mixed timing",
			scenario:       "blocks at 1s, 30s, 1s, 40s, 1s intervals",
			blockPattern:   "irregular",
			expectedReward: 365, // ~73 seconds elapsed = 73% of 500
			tolerance:      5,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Reset state
			projects = avl.NewTree()
			projectTierRewardManagers = avl.NewTree()
			
			// Setup project
			project := &Project{
				id:        "test_project",
				tokenPath: "gno.land/r/onbloc/obl",
				tiers: map[int64]*ProjectTier{
					30: &ProjectTier{
						id:                    "test_project:30",
						totalDistributeAmount: 1000,
						startBlockTimeInfo:    &BlockTimeInfo{blockTime: 1000, blockHeight: 100},
						endBlockTimeInfo:      &BlockTimeInfo{blockTime: 1200, blockHeight: 300}, // 200 seconds duration
					},
				},
			}
			projects.Set(project.ID(), project)
			
			// Setup reward manager based on block pattern
			var rewardManager *RewardManager
			
			switch tt.blockPattern {
			case "fast":
				// 100 blocks in 100 seconds (1 block/second)
				rewardManager = NewRewardManager(
					1000,  // total amount
					100,   // start height
					200,   // end height (100 blocks)
					1000,  // start time
					1200,  // end time (200 seconds)
					150,   // current height (50 blocks)
					1100,  // current time (100 seconds elapsed)
				)
				// Update to simulate 50% time elapsed
				rewardManager.updateRewardPerDepositX128(1000000, 150, 1100)
				
			case "slow":
				// 5 blocks in 100 seconds (20 seconds/block)
				rewardManager = NewRewardManager(
					1000,  // total amount
					100,   // start height
					110,   // end height (10 blocks total)
					1000,  // start time
					1200,  // end time (200 seconds)
					105,   // current height (5 blocks)
					1100,  // current time (100 seconds elapsed)
				)
				// Update to simulate 50% time elapsed
				rewardManager.updateRewardPerDepositX128(1000000, 105, 1100)
				
			case "irregular":
				// Irregular block pattern
				rewardManager = NewRewardManager(
					1000,  // total amount
					100,   // start height
					110,   // end height
					1000,  // start time
					1200,  // end time (200 seconds)
					100,   // current height
					1000,  // current time
				)
				// Simulate irregular updates:
				// Block 101 at +1 second
				rewardManager.updateRewardPerDepositX128(1000000, 101, 1001)
				// Block 102 at +31 seconds
				rewardManager.updateRewardPerDepositX128(1000000, 102, 1031)
				// Block 103 at +32 seconds
				rewardManager.updateRewardPerDepositX128(1000000, 103, 1032)
				// Block 104 at +72 seconds
				rewardManager.updateRewardPerDepositX128(1000000, 104, 1072)
				// Block 105 at +73 seconds
				rewardManager.updateRewardPerDepositX128(1000000, 105, 1073)
			}
			
			// Add reward state for deposit
			deposit := &Deposit{
				id:        "test_deposit",
				projectID: "test_project",
				tier:      30,
			}
			
			// Create reward state
			rewardState := &RewardState{
				depositAmount:              1000000,
				distributeStartHeight:      100,
				distributeEndHeight:        300,
				accumulatedHeight:          100,
				priceDebtX128:              u256.Zero(),
				claimableBlockTimeInfo:     &BlockTimeInfo{blockTime: 1000, blockHeight: 100},
			}
			rewardManager.rewards.Set(deposit.ID(), rewardState)
			
			projectTierRewardManagers.Set("test_project:30", rewardManager)
			
			// Collect reward
			amount, err := collectDepositReward(deposit, 200)
			uassert.NoError(t, err)
			
			// Verify reward is within expected range
			if amount < (tt.expectedReward-tt.tolerance) || amount > (tt.expectedReward+tt.tolerance) {
				t.Errorf("Reward should be based on time elapsed, not blocks. Expected ~%d, got %d", 
					tt.expectedReward, amount)
			}
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
		description    string
	}{
		{
			name:           "before distribution start",
			currentTime:    900,
			startTime:      1000,
			endTime:        2000,
			expectedReward: 0,
			description:    "No rewards before distribution starts",
		},
		{
			name:           "exactly at start",
			currentTime:    1000,
			startTime:      1000,
			endTime:        2000,
			expectedReward: 0,
			description:    "No rewards at exact start time",
		},
		{
			name:           "exactly at end",
			currentTime:    2000,
			startTime:      1000,
			endTime:        2000,
			expectedReward: 1000,
			description:    "Full rewards at end time",
		},
		{
			name:           "after distribution end",
			currentTime:    3000,
			startTime:      1000,
			endTime:        2000,
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
					30: &ProjectTier{
						id:                    "boundary_test:30",
						totalDistributeAmount: 1000,
					},
				},
			}
			projects.Set(project.ID(), project)
			
			// Setup reward manager
			rewardManager := NewRewardManager(
				1000,      // total amount
				100,       // start height
				200,       // end height
				tt.startTime,
				tt.endTime,
				100,       // current height
				tt.startTime, // initial time
			)
			
			// Add deposit reward state
			deposit := &Deposit{
				id:        "boundary_deposit",
				projectID: "boundary_test",
				tier:      30,
			}
			
			rewardState := &RewardState{
				depositAmount:         1000000,
				distributeStartHeight: 100,
				distributeEndHeight:   200,
				accumulatedHeight:     100,
				priceDebtX128:         u256.Zero(),
				claimableBlockTimeInfo: &BlockTimeInfo{blockTime: tt.startTime, blockHeight: 100},
			}
			rewardManager.rewards.Set(deposit.ID(), rewardState)
			
			// Update to current time
			if tt.currentTime > tt.startTime {
				rewardManager.updateRewardPerDepositX128(1000000, 150, tt.currentTime)
			}
			
			projectTierRewardManagers.Set("boundary_test:30", rewardManager)
			
			// Collect reward
			amount, err := collectDepositReward(deposit, 150)
			uassert.NoError(t, err)
			
			// Verify reward
			if amount < (tt.expectedReward-5) || amount > (tt.expectedReward+5) {
				t.Errorf("%s: expected ~%d, got %d", tt.description, tt.expectedReward, amount)
			}
		})
	}
}
