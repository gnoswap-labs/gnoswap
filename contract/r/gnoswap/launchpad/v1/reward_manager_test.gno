package v1

import (
	"chain/runtime"
	"math"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	"gno.land/r/gnoswap/launchpad"
)

func TestRewardManager_IsInitialized(t *testing.T) {
	tests := []struct {
		name             string
		rewardStates     map[string]*launchpad.RewardState
		expectedResult   bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "is initialized return false for empty rewards",
			rewardStates:     map[string]*launchpad.RewardState{},
			expectedResult:   false,
			expectedHasError: false,
		},
		{
			name: "is initialized return true when rewards exist",
			rewardStates: map[string]*launchpad.RewardState{
				"test": newRewardState(u256.Zero(), 1000, 100, 200, 0),
			},
			expectedResult:   true,
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			tree := avl.NewTree()
			for k, v := range tt.rewardStates {
				tree.Set(k, v)
			}
			manager := newRewardManager(1000000, 100, 200, 0, 100, 100)
			manager.SetRewards(tree)

			// Execute
			result := isRewardManagerInitialized(manager)

			// Verify
			uassert.Equal(t, result, tt.expectedResult)
		})
	}
}

func TestRewardManager_UpdateRewardPerDepositX128(t *testing.T) {
	tests := []struct {
		name                                string
		totalDistributeAmount               int64
		distributeStartHeight               int64
		distributeEndHeight                 int64
		currentHeight                       int64
		rewardHeight                        int64
		expectedAccumulatedRewardPerDeposit string
		expectedHasError                    bool
		expectedError                       string
	}{
		{
			name:                                "update reward per deposit succeed with valid height",
			totalDistributeAmount:               1000,
			distributeStartHeight:               100,
			distributeEndHeight:                 200,
			currentHeight:                       150,
			rewardHeight:                        100,
			expectedAccumulatedRewardPerDeposit: "0",
			expectedHasError:                    false,
		},
		{
			name:                                "update reward per deposit fail with invalid height",
			totalDistributeAmount:               1000,
			distributeStartHeight:               100,
			distributeEndHeight:                 200,
			currentHeight:                       50,
			rewardHeight:                        0,
			expectedAccumulatedRewardPerDeposit: "0",
			expectedHasError:                    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			// Use current time as base and simulate 1 second per block
			now := time.Now().Unix()
			distributeStartTime := now - 1000 + tt.distributeStartHeight // Start in the past
			distributeEndTime := now - 1000 + tt.distributeEndHeight
			currentTime := now - 1000 + tt.currentHeight
			manager := newRewardManager(
				tt.totalDistributeAmount,
				distributeStartTime,
				distributeEndTime,
				0,
				tt.currentHeight,
				currentTime,
			)

			// Execute
			// Use timestamp based on height offset from start
			rewardTime := now - 1000 + tt.rewardHeight
			err := updateRewardPerDepositX128(manager, tt.totalDistributeAmount, tt.rewardHeight, rewardTime)

			// Verify
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.Equal(t, tt.expectedAccumulatedRewardPerDeposit, manager.AccumulatedRewardPerDepositX128().ToString())
			}
		})
	}
}

func TestRewardManager_AddRewardStateByDeposit(t *testing.T) {
	tests := []struct {
		name                  string
		deposit               *launchpad.Deposit
		totalDistributeAmount int64
		distributeStart       int64
		distributeEnd         int64
		existingDeposits      []*launchpad.Deposit
		collectHeight         int64
		expectedStartTime     int64
		expectedReward        int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name: "add reward state succeed for first deposit",
			deposit: launchpad.NewDeposit(
				"1",
				"test",
				30,
				"",
				1000,
				1000,
				150,
				250,
			),
			totalDistributeAmount: 1000,
			distributeStart:       150,
			distributeEnd:         250,
			existingDeposits:      []*launchpad.Deposit{},
			collectHeight:         250,
			expectedStartTime:     150,
			expectedReward:        1000,
			expectedHasError:      false,
		},
		{
			name: "add reward state succeed for subsequent deposit",
			deposit: launchpad.NewDeposit(
				"1",
				"test",
				30,
				"",
				1000,
				1000,
				150,
				250,
			),
			totalDistributeAmount: 1000,
			distributeStart:       150,
			distributeEnd:         250,
			existingDeposits: []*launchpad.Deposit{
				launchpad.NewDeposit(
					"1",
					"existing",
					500,
					"",
					500,
					1000,
					150,
					250,
				),
			},
			collectHeight:     250,
			expectedStartTime: 150,
			expectedReward:    666,
			expectedHasError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			currentHeight := runtime.ChainHeight()

			// Use current time as base and simulate timing
			manager := newRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStart,
				tt.distributeEnd,
				0,
				currentHeight,
				tt.distributeStart,
			)

			totalDepositAmount := int64(0)

			for _, deposit := range tt.existingDeposits {
				totalDepositAmount += int64(deposit.DepositAmount())
				// Use timestamp based on deposit height offset
				updateRewardPerDepositX128(manager, totalDepositAmount, deposit.CreatedHeight(), deposit.CreatedAt())
				addRewardStateByDeposit(manager, deposit)
			}

			// Execute
			totalDepositAmount += tt.deposit.DepositAmount()
			// Use timestamp based on deposit height offset
			updateRewardPerDepositX128(manager, totalDepositAmount, tt.deposit.CreatedHeight(), tt.deposit.CreatedAt())
			rewardState := addRewardStateByDeposit(manager, tt.deposit)

			// Use timestamp based on collection height offset
			updateRewardPerDepositX128(manager, totalDepositAmount, tt.collectHeight, tt.collectHeight)
			reward, err := collectReward(manager, tt.deposit.ID(), tt.collectHeight)
			if err != nil {
				uassert.NoError(t, err)
			}

			uassert.Equal(t, tt.expectedStartTime, rewardState.DistributeStartTime())
			uassert.Equal(t, tt.expectedReward, reward)
		})
	}
}

func TestRewardManager_CollectReward(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		distributeStartTime   int64
		distributeEndTime     int64
		currentHeight         int64
		depositId             string
		deposit               *launchpad.Deposit
		existingDeposits      []*launchpad.Deposit
		collectHeight         int64
		expectedAmount        int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "collect reward succeed with valid deposit",
			totalDistributeAmount: 1000,
			distributeStartTime:   100,
			distributeEndTime:     200,
			currentHeight:         150,
			deposit: launchpad.NewDeposit(
				"1",
				"test",
				30,
				"",
				1000,
				1000,
				100,
				200,
			),
			depositId:        "1",
			existingDeposits: []*launchpad.Deposit{},
			collectHeight:    200,
			expectedAmount:   1000,
			expectedHasError: false,
		},
		{
			name: "collect reward fail with nonexistent deposit",
			deposit: launchpad.NewDeposit(
				"1",
				"test",
				30,
				"",
				100,
				1000,
				1000,
				1000,
			),
			depositId:        "nonexistent",
			collectHeight:    150,
			existingDeposits: []*launchpad.Deposit{},
			expectedAmount:   0,
			expectedHasError: true,
			expectedError:    "[GNOSWAP-LAUNCHPAD-020] not exist deposit",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			// Use current time as base and simulate timing
			manager := newRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
				0,
				tt.currentHeight,
				tt.distributeStartTime,
			)

			for _, deposit := range tt.existingDeposits {
				// Use timestamp based on deposit height offset
				updateRewardPerDepositX128(manager, tt.totalDistributeAmount, deposit.CreatedHeight(), deposit.CreatedAt())
				addRewardStateByDeposit(manager, deposit)
			}

			// Use timestamp based on deposit height offset
			updateRewardPerDepositX128(manager, tt.totalDistributeAmount, tt.deposit.CreatedHeight(), tt.deposit.CreatedAt())
			addRewardStateByDeposit(manager, tt.deposit)

			// Execute
			// Use timestamp based on collection height offset
			updateRewardPerDepositX128(manager, tt.totalDistributeAmount, tt.collectHeight, tt.collectHeight)
			amount, err := collectReward(manager, tt.depositId, tt.collectHeight)

			// Verify
			if tt.expectedHasError {
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, amount, tt.expectedAmount)
			}
		})
	}
}

func TestnewRewardManager(t *testing.T) {
	tests := []struct {
		name                          string
		totalDistributeAmount         int64
		distributeStartTime           int64
		distributeEndTime             int64
		distributeAmountPerSecondX128 *u256.Uint
		currentHeight                 int64
		expectedHasError              bool
		expectedError                 string
	}{
		{
			name:                          "new reward manager create valid manager with correct values",
			totalDistributeAmount:         1000,
			distributeStartTime:           100,
			distributeEndTime:             200,
			distributeAmountPerSecondX128: u256.NewUintFromInt64(100),
			currentHeight:                 100,
			expectedHasError:              false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			// Use current time as base and simulate timing
			now := time.Now().Unix()
			distributeStartTime := now - 1000 + tt.distributeStartTime
			distributeEndTime := now - 1000 + tt.distributeEndTime
			currentTime := now - 1000 + tt.currentHeight
			manager := newRewardManager(
				tt.totalDistributeAmount,
				distributeStartTime,
				distributeEndTime,
				0,
				tt.currentHeight,
				currentTime,
			)

			// Verify
			uassert.NotEqual(t, manager.Rewards(), nil)
		})
	}
}

func TestTimestampBasedRewardCalculation_ConstantTime(t *testing.T) {
	// Test that rewards are calculated based on time duration, not block count
	// Scenario: 100 seconds duration should distribute rewards evenly per second

	totalDistributeAmount := int64(1000)
	currentHeight := int64(100)

	// Set up timestamps: 100 seconds duration
	baseTime := time.Now().Unix()
	distributeStartTime := baseTime + 100
	distributeEndTime := baseTime + 200 // 100 seconds later
	currentTime := baseTime

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Create two deposits to test reward distribution
	deposit1 := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000, // deposit amount
		1,
		distributeStartTime,
		distributeEndTime,
	)

	deposit2 := launchpad.NewDeposit(
		"2",
		"test",
		30,
		"",
		1000, // deposit amount
		1,
		distributeStartTime,
		distributeEndTime,
	)

	// Add both deposits at start time
	err := updateRewardPerDepositX128(manager, 1000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	addRewardStateByDeposit(manager, deposit1)

	err = updateRewardPerDepositX128(manager, 2000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	addRewardStateByDeposit(manager, deposit2)

	// Move time forward by 50 seconds (half way through)
	halfwayTime := distributeStartTime + 50
	err = updateRewardPerDepositX128(manager, 2000, halfwayTime, halfwayTime)
	uassert.NoError(t, err)

	// Collect reward for deposit1 after 50 seconds
	reward1, err := collectReward(manager, "1", halfwayTime)
	uassert.NoError(t, err)

	// Each deposit should get 250 tokens (50% of 1000 / 2 deposits)
	t.Logf("Deposit1 reward after 50 seconds: %d (expected ~250)", reward1)
	uassert.Equal(t, true, reward1 >= 245 && reward1 <= 255, "reward1 should be ~250")

	// Move to end of distribution period
	err = updateRewardPerDepositX128(manager, 2000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect reward for deposit2 after 100 seconds
	reward2, err := collectReward(manager, "2", distributeEndTime)
	uassert.NoError(t, err)

	// Deposit2 should get 500 tokens (100% of 1000 / 2 deposits)
	t.Logf("Deposit2 reward after 100 seconds: %d (expected ~500)", reward2)
	uassert.Equal(t, true, reward2 >= 495 && reward2 <= 505, "reward2 should be ~500")

	// Total distributed should be ~750 (deposit1: 250, deposit2: 500)
	totalDistributed := reward1 + reward2
	t.Logf("Total distributed: %d (expected ~750)", totalDistributed)
	uassert.Equal(t, true, totalDistributed >= 745 && totalDistributed <= 755)
}

func TestTimestampBasedRewardCalculation_VariableBlockTime(t *testing.T) {
	// Test that rewards work correctly even with variable block times
	// Scenario: Blocks come at irregular intervals, but rewards should still be time-based

	totalDistributeAmount := int64(1000)

	// Set up timestamps: blocks at irregular intervals
	baseTime := time.Now().Unix()
	currentHeight := int64(1)
	distributeStartTime := baseTime
	distributeEndTime := baseTime + 100 // 100 seconds for just 10 blocks
	currentTime := baseTime

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Create first deposit at start
	deposit1 := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)

	err := updateRewardPerDepositX128(manager, 1000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	addRewardStateByDeposit(manager, deposit1)

	// Simulate irregular block times:
	// Block 101 comes after 30 seconds (normally would be 1 second)
	time1 := baseTime + 30
	err = updateRewardPerDepositX128(manager, 1000, time1, time1)
	uassert.NoError(t, err)

	// Add second deposit
	deposit2 := launchpad.NewDeposit(
		"2",
		"test",
		30,
		"",
		1000,
		currentHeight,
		time1,
		distributeEndTime,
	)

	totalDeposits := int64(2000)
	err = updateRewardPerDepositX128(manager, totalDeposits, time1, time1)
	uassert.NoError(t, err)
	addRewardStateByDeposit(manager, deposit2)

	// Block 105 comes after 80 seconds total (another 50 seconds gap)
	time2 := baseTime + 80
	err = updateRewardPerDepositX128(manager, totalDeposits, time2, time2)
	uassert.NoError(t, err)

	// Check rewards for deposit1 (active for 80 seconds)
	// First 30 seconds: got all rewards (300 tokens)
	// Next 50 seconds: shared with deposit2 (250 tokens)
	// Total: ~550 tokens
	reward1, err := collectReward(manager, "1", time2)
	uassert.NoError(t, err)
	uassert.Equal(t, true, reward1 >= 545 && reward1 <= 555)

	// Check rewards for deposit2 (active for 50 seconds, sharing with deposit1)
	// Should get 250 tokens
	reward2, err := collectReward(manager, "2", time2)
	uassert.NoError(t, err)
	uassert.Equal(t, true, reward2 >= 245 && reward2 <= 255)

	// Verify total distributed is approximately 800 tokens (80% of 1000 over 80 seconds)
	totalDistributed := reward1 + reward2
	uassert.Equal(t, true, totalDistributed >= 795 && totalDistributed <= 805)
}

// TestRewardManager_VaryingBlockTime_FastBlocks tests reward distribution with very fast block times
func TestRewardManager_VaryingBlockTime_FastBlocks(t *testing.T) {
	// Scenario: Blocks coming every 1 second instead of 5 seconds
	// This should NOT affect time-based rewards

	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit)

	// Simulate fast blocks: 50 blocks in 50 seconds (1 block/second)
	midHeight := distributeStartTime + 50
	midTime := distributeStartTime + 50

	// Update reward state
	err := updateRewardPerDepositX128(manager, 1000000, midHeight, midTime)
	uassert.NoError(t, err)

	// Collect rewards after 50 seconds
	reward, err := collectReward(manager, "1", midTime)
	uassert.NoError(t, err)

	// Should get ~500 tokens (50% of time elapsed)
	uassert.Equal(t, true, reward >= 495 && reward <= 505,
		"Fast blocks should not affect time-based rewards")
}

// TestRewardManager_VaryingBlockTime_SlowBlocks tests reward distribution with very slow block times
func TestRewardManager_VaryingBlockTime_SlowBlocks(t *testing.T) {
	// Scenario: Blocks coming every 20 seconds instead of 5 seconds
	// This should NOT affect time-based rewards

	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit)

	// Simulate slow blocks: only 3 blocks in 60 seconds (20 seconds/block)
	midHeight := distributeStartTime + 3
	midTime := distributeStartTime + 60

	// Update reward state
	err := updateRewardPerDepositX128(manager, 1000000, midHeight, midTime)
	uassert.NoError(t, err)

	// Collect rewards after 60 seconds
	reward, err := collectReward(manager, "1", midTime)
	uassert.NoError(t, err)

	// Should get ~600 tokens (60% of time elapsed)
	uassert.Equal(t, true, reward >= 595 && reward <= 605,
		"Slow blocks should not affect time-based rewards")
}

// TestRewardManager_VaryingBlockTime_IrregularBlocks tests reward distribution with irregular block times
func TestRewardManager_VaryingBlockTime_IrregularBlocks(t *testing.T) {
	// Scenario: Blocks come at irregular intervals
	// Block pattern: 1s, 1s, 1s, 30s, 1s, 1s, 30s, 1s, 1s, 1s (total 70s for 10 blocks)

	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit)

	// Simulate irregular blocks over 70 seconds
	irregularHeight := distributeStartTime + 10
	irregularTime := distributeStartTime + 70

	// Update reward state
	err := updateRewardPerDepositX128(manager, 1000000, irregularHeight, irregularTime)
	uassert.NoError(t, err)

	// Collect rewards after 70 seconds
	reward, err := collectReward(manager, "1", irregularTime)
	uassert.NoError(t, err)

	// Should get ~700 tokens (70% of time elapsed)
	uassert.Equal(t, true, reward >= 695 && reward <= 705,
		"Irregular blocks should not affect time-based rewards")
}

// TestRewardManager_EdgeCase_ZeroDuration tests edge case with zero duration
func TestRewardManager_EdgeCase_ZeroDuration(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1000) // Same as start (zero duration)
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Should have zero distribute amount per second
	uassert.Equal(t, true, manager.DistributeAmountPerSecondX128().IsZero(),
		"Zero duration should result in zero distribution rate")
}

// TestRewardManager_EdgeCase_TimeGoesBackward tests that time cannot go backward
func TestRewardManager_EdgeCase_TimeGoesBackward(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Add deposit
	deposit := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit)

	// First update at time 1500
	err := updateRewardPerDepositX128(manager, 1000000, 150, 1500)
	uassert.NoError(t, err)

	// Try to update with earlier time (should not affect accumulated time)
	addRewardPerDepositX128(manager, u256.Zero(), 140, 1400)

	// Accumulated time should still be 1500
	uassert.Equal(t, int64(1500), manager.AccumulatedTime(),
		"Time should not go backward")
}

// TestRewardManager_EdgeCase_RewardAfterEnd tests reward collection after distribution end
func TestRewardManager_EdgeCase_RewardAfterEnd(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Add deposit
	deposit := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit)

	// Update past end time
	err := updateRewardPerDepositX128(manager, 1000000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect rewards
	reward, err := collectReward(manager, "1", distributeEndTime)
	uassert.NoError(t, err)

	// Should get all 1000 tokens (100% distributed)
	uassert.Equal(t, true, reward >= 995 && reward <= 1005,
		"Should receive all rewards when collecting after end time")
}

// TestRewardManager_MultipleDeposits_DifferentTimings tests multiple deposits joining at different times
func TestRewardManager_MultipleDeposits_DifferentTimings(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000) // 1000 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := newRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		0,
		currentHeight,
		currentTime,
	)

	// Deposit 1: Joins at start
	deposit1 := launchpad.NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit1)

	// Update after 250 seconds (deposit1 alone)
	timeAfter250s := distributeStartTime + 250
	err := updateRewardPerDepositX128(manager, 1000000, timeAfter250s, timeAfter250s)
	uassert.NoError(t, err)

	// Deposit 2: Joins after 250 seconds
	deposit2 := launchpad.NewDeposit(
		"2",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		timeAfter250s,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit2)

	// Update after 500 seconds total (250 seconds shared)
	timeAfter500s := distributeStartTime + 500
	err = updateRewardPerDepositX128(manager, 2000000, timeAfter500s, timeAfter500s)
	uassert.NoError(t, err)

	// Deposit 3: Joins after 500 seconds
	deposit3 := launchpad.NewDeposit(
		"3",
		"test",
		30,
		"",
		2000000, // Double amount
		currentHeight,
		timeAfter500s,
		distributeEndTime,
	)
	addRewardStateByDeposit(manager, deposit3)

	// Final update at end (500 seconds with 3 deposits)
	err = updateRewardPerDepositX128(manager, 4000000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect all rewards
	reward1, err := collectReward(manager, "1", distributeEndTime)
	uassert.NoError(t, err)
	reward2, err := collectReward(manager, "2", distributeEndTime)
	uassert.NoError(t, err)
	reward3, err := collectReward(manager, "3", distributeEndTime)
	uassert.NoError(t, err)

	// Expected rewards:
	// Deposit1: 250 alone (250) + 250 with deposit2 (125) + 500 with all (125) = 500
	// Deposit2: 250 with deposit1 (125) + 500 with all (125) = 250
	// Deposit3: 500 with all (250) = 250

	uassert.Equal(t, true, reward1 >= 495 && reward1 <= 505, "Deposit1 should get ~500 tokens")
	uassert.Equal(t, true, reward2 >= 245 && reward2 <= 255, "Deposit2 should get ~250 tokens")
	uassert.Equal(t, true, reward3 >= 245 && reward3 <= 255, "Deposit3 should get ~250 tokens")

	totalDistributed := reward1 + reward2 + reward3
	uassert.Equal(t, true, totalDistributed >= 995 && totalDistributed <= 1005,
		"Total distributed should equal total amount")
}

// TestRewardManager_ClaimableTimeOverflow tests potential overflow in claimableTime calculation (line 120)
// Tests: claimableTime := deposit.CreatedAt() + r.rewardClaimableDuration
func TestRewardManager_ClaimableTimeOverflow(t *testing.T) {
	tests := []struct {
		name              string
		createdAt         int64
		distributeEndTime int64
		claimableDuration int64
		expectedResult    int64
		description       string
	}{
		{
			name:              "normal case",
			createdAt:         1000,
			distributeEndTime: 2000,
			claimableDuration: 500,
			expectedResult:    1500,
			description:       "Normal addition",
		},
		{
			name:              "boundary - exactly MaxInt64",
			createdAt:         math.MaxInt64 - 1000,
			distributeEndTime: math.MaxInt64,
			claimableDuration: 1000,
			expectedResult:    math.MaxInt64,
			description:       "Should handle boundary at MaxInt64",
		},
		{
			name:              "boundary - claimableTime > distributeEndTime",
			createdAt:         1000,
			distributeEndTime: 2000,
			claimableDuration: 1001,
			expectedResult:    2000,
			description:       "Should handle claimableTime > distributeEndTime",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := newRewardManager(
				1000000,
				time.Now().Unix(),
				tt.distributeEndTime,
				0,
				100,
				time.Now().Unix(),
			)
			manager.SetRewardClaimableDuration(tt.claimableDuration)

			deposit := launchpad.NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				tt.createdAt,
				tt.createdAt+1000,
			)

			// when
			rewardState := addRewardStateByDeposit(manager, deposit)
			claimableTime := rewardState.ClaimableTime()

			// then
			uassert.Equal(t, tt.expectedResult, claimableTime,
				"claimableTime should match expected result")
		})
	}
}

// TestRewardManager_ClaimedAmountOverflow tests potential overflow in claimedAmount update (line 268)
// Tests: rewardState.SetClaimedAmount(rewardState.ClaimedAmount() + claimableReward)
func TestRewardManager_ClaimedAmountOverflow(t *testing.T) {
	tests := []struct {
		name            string
		initialClaimed  int64
		claimableReward int64
		expectedResult  int64
		description     string
	}{
		{
			name:            "normal case",
			initialClaimed:  1000,
			claimableReward: 500,
			expectedResult:  1500,
			description:     "Normal addition",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialClaimed:  math.MaxInt64 - 1000,
			claimableReward: 1000,
			expectedResult:  math.MaxInt64,
			description:     "Should handle boundary at MaxInt64",
		},
		// TODO: Add overflow test case after implementing overflow check in main code
		// Currently, MaxInt64 + 1 would wrap to negative (Go behavior)
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			currentTime := time.Now().Unix()
			distributeStart := currentTime - 1000
			distributeEnd := currentTime + 1000

			manager := newRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				0,
				100,
				currentTime,
			)
			manager.SetRewardClaimableDuration(100)

			deposit := launchpad.NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			rewardState := addRewardStateByDeposit(manager, deposit)

			// Setup: Set initial claimed amount
			rewardState.SetClaimedAmount(tt.initialClaimed)
			manager.Rewards().Set(deposit.ID(), rewardState)

			// Setup: Configure accumulated reward to generate exact claimableReward
			// Using priceDebtX128 for precise calculation
			priceDebtX128 := rewardState.PriceDebtX128()
			totalReward := tt.initialClaimed + tt.claimableReward
			depositAmount := deposit.DepositAmount()

			// actualRewardPerDepositX128 = (totalReward << 128) / depositAmount
			actualRewardX128 := u256.NewUint(uint64(totalReward))
			actualRewardX128 = u256.Zero().Lsh(actualRewardX128, 128)
			actualRewardX128 = u256.Zero().Div(actualRewardX128, u256.NewUint(uint64(depositAmount)))

			// accumRewardPerDepositX128 = actualRewardPerDepositX128 + priceDebtX128
			accumX128 := u256.Zero().Add(actualRewardX128, priceDebtX128)
			manager.SetAccumulatedRewardPerDepositX128(accumX128)

			// when
			_, _ = collectReward(manager, deposit.ID(), currentTime+200)

			// then
			updatedState, _ := getDepositRewardState(manager, deposit.ID())
			newClaimedAmount := updatedState.ClaimedAmount()

			// Allow precision loss of 1 due to uint256 division truncation
			diff := tt.expectedResult - newClaimedAmount
			uassert.True(t, diff >= 0 && diff <= 1,
				"claimedAmount should match expected result (allowing precision loss of 1)")
		})
	}
}

// TestRewardManager_TotalClaimedAmountOverflow tests potential overflow in totalClaimedAmount (line 270)
// Tests: r.totalClaimedAmount += claimableReward
func TestRewardManager_TotalClaimedAmountOverflow(t *testing.T) {
	tests := []struct {
		name            string
		initialTotal    int64
		claimableReward int64
		expectedResult  int64
		description     string
	}{
		{
			name:            "normal case",
			initialTotal:    1000,
			claimableReward: 500,
			expectedResult:  1500,
			description:     "Normal addition",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialTotal:    math.MaxInt64 - 500,
			claimableReward: 500,
			expectedResult:  math.MaxInt64,
			description:     "Should handle boundary at MaxInt64",
		},
		// TODO: Add overflow test case after implementing overflow check in main code
		// Currently, MaxInt64 + 1 would wrap to negative (Go behavior)
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			currentTime := time.Now().Unix()
			distributeStart := currentTime - 1000
			distributeEnd := currentTime + 1000

			manager := newRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				0,
				100,
				currentTime,
			)
			manager.SetRewardClaimableDuration(100)
			manager.SetTotalClaimedAmount(tt.initialTotal)

			deposit := newDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			rewardState := addRewardStateByDeposit(manager, deposit)

			// Setup: Configure accumulated reward to generate exact claimableReward
			priceDebtX128 := rewardState.PriceDebtX128()
			totalReward := tt.claimableReward
			depositAmount := deposit.DepositAmount()

			actualRewardX128 := u256.NewUint(uint64(totalReward))
			actualRewardX128 = u256.Zero().Lsh(actualRewardX128, 128)
			actualRewardX128 = u256.Zero().Div(actualRewardX128, u256.NewUint(uint64(depositAmount)))

			accumX128 := u256.Zero().Add(actualRewardX128, priceDebtX128)
			manager.SetAccumulatedRewardPerDepositX128(accumX128)

			// when
			_, _ = collectReward(manager, deposit.ID(), currentTime+200)

			// then
			newTotal := manager.TotalClaimedAmount()
			// Allow precision loss of 1 due to uint256 division truncation
			diff := tt.expectedResult - newTotal
			uassert.True(t, diff >= 0 && diff <= 1,
				"totalClaimedAmount should match expected result (allowing precision loss of 1)")
		})
	}
}

// TestRewardManager_calculateRewardPerDepositX128 tests the private function calculateRewardPerDepositX128
// This function calculates reward per deposit based on time duration and staking amount
func TestRewardManager_calculateRewardPerDepositX128(t *testing.T) {
	tests := []struct {
		name                  string
		setupManager          func() *launchpad.RewardManager
		rewardPerSecondX128   *u256.Uint
		totalStaked           int64
		currentTime           int64
		expectedResultIsZero  bool
		expectedHasError      bool
		expectedErrorContains string
		validateResult        func(t *testing.T, result *u256.Uint)
	}{
		{
			name: "normal calculation - valid time range",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"), // 1 << 128 (1.0)
			totalStaked:          1000,
			currentTime:          1100, // 100 seconds elapsed
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// (currentTime - accumulatedTime) * rewardPerSecondX128 / totalStaked
				// = (1100 - 1000) * (1 << 128) / 1000
				// = 100 * (1 << 128) / 1000
				expected := u256.MulDiv(
					u256.NewUint(100),
					u256.MustFromDecimal("1000000000000000000000000000000000000"),
					u256.NewUint(1000),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "accumulated time adjusted to distribute start time",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)

				manager.SetAccumulatedTime(800)
				manager.SetDistributeStartTime(1000)
				manager.SetDistributeEndTime(2000)

				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          500,
			currentTime:          1200,
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// Should use distributeStartTime (1000) instead of accumulatedTime (800)
				// = (1200 - 1000) * (1 << 128) / 500
				expected := u256.MulDiv(
					u256.NewUint(200),
					u256.MustFromDecimal("1000000000000000000000000000000000000"),
					u256.NewUint(500),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "current time before accumulated time - not started yet",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          900, // before accumulatedTime
			expectedResultIsZero: true,
			expectedHasError:     false,
		},
		{
			name: "current time equals accumulated time - boundary",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          1000, // exactly at accumulatedTime
			expectedResultIsZero: true, // timeDuration = 0
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// timeDuration = 0, so result should be zero
				uassert.True(t, result.IsZero())
			},
		},
		{
			name: "accumulated time past distribute end time",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(2100)
				manager.SetDistributeStartTime(1000)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          2200,
			expectedResultIsZero: true,
			expectedHasError:     false,
		},
		{
			name: "accumulated time equals distribute end time - boundary",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(2000)
				manager.SetDistributeStartTime(1000)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          2100,
			expectedResultIsZero: true,
			expectedHasError:     false,
		},
		{
			name: "current time past distribute end time - capped to end time",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(1500)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          2000, // past distributeEndTime, should be capped to 1500
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// Should cap currentTime to distributeEndTime (1500)
				// = (1500 - 1000) * (1 << 128) / 1000
				expected := u256.MulDiv(
					u256.NewUint(500),
					u256.MustFromDecimal("1000000000000000000000000000000000000"),
					u256.NewUint(1000),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "current time equals distribute end time - boundary",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(1500)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1000,
			currentTime:          1500, // exactly at distributeEndTime
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// = (1500 - 1000) * (1 << 128) / 1000
				expected := u256.MulDiv(
					u256.NewUint(500),
					u256.MustFromDecimal("1000000000000000000000000000000000000"),
					u256.NewUint(1000),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "reward per second is zero - error case",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:   u256.Zero(),
			totalStaked:           1000,
			currentTime:           1100,
			expectedHasError:      true,
			expectedErrorContains: "no left reward",
		},
		{
			name: "total staked is zero - returns zero",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          0,
			currentTime:          1100,
			expectedResultIsZero: true,
			expectedHasError:     false,
		},
		{
			name: "total staked boundary - exactly 1",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.MustFromDecimal("1000000000000000000000000000000000000"),
			totalStaked:          1, // minimum positive value
			currentTime:          1100,
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// = (1100 - 1000) * (1 << 128) / 1
				expected := u256.MulDiv(
					u256.NewUint(100),
					u256.MustFromDecimal("1000000000000000000000000000000000000"),
					u256.NewUint(1),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "very large time duration",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(math.MaxInt64)
				return manager
			},
			rewardPerSecondX128:  u256.NewUint(1000),
			totalStaked:          1000000,
			currentTime:          1000000000, // very large
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// Should calculate without overflow
				// = (1000000000 - 1000) * 1000 / 1000000
				expected := u256.MulDiv(
					u256.NewUint(999999000),
					u256.NewUint(1000),
					u256.NewUint(1000000),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
		{
			name: "very small reward per second",
			setupManager: func() *launchpad.RewardManager {
				manager := newRewardManager(
					10000000,
					1000,
					2000,
					0,
					100,
					1000,
				)
				manager.SetAccumulatedTime(1000)
				manager.SetDistributeStartTime(900)
				manager.SetDistributeEndTime(2000)
				return manager
			},
			rewardPerSecondX128:  u256.NewUint(1), // very small
			totalStaked:          1000000,
			currentTime:          1100,
			expectedResultIsZero: false,
			expectedHasError:     false,
			validateResult: func(t *testing.T, result *u256.Uint) {
				// = (1100 - 1000) * 1 / 1000000 = 100 / 1000000 = 0 (truncated)
				expected := u256.MulDiv(
					u256.NewUint(100),
					u256.NewUint(1),
					u256.NewUint(1000000),
				)
				uassert.Equal(t, expected.ToString(), result.ToString())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := tt.setupManager()

			// when
			result, err := calculateRewardPerDepositX128(
				manager,
				tt.rewardPerSecondX128,
				tt.totalStaked,
				tt.currentTime,
			)

			// then
			if tt.expectedHasError {
				uassert.NotNil(t, err)
				if tt.expectedErrorContains != "" {
					uassert.ErrorContains(t, err, tt.expectedErrorContains)
				}
			} else {
				uassert.Nil(t, err)
				if tt.expectedResultIsZero {
					uassert.True(t, result.IsZero())
				}
				if tt.validateResult != nil {
					tt.validateResult(t, result)
				}
			}
		})
	}
}

// TestRewardManager_updateDistributeAmountPerSecondX128 tests the private function updateDistributeAmountPerSecondX128
// This function calculates and sets the distribute amount per second in X128 format
func TestRewardManager_updateDistributeAmountPerSecondX128(t *testing.T) {
	tests := []struct {
		name                    string
		totalDistributeAmount   int64
		distributeStartTime     int64
		distributeEndTime       int64
		expectedAmountPerSecond string
		expectedStartTime       int64
		expectedEndTime         int64
		expectNoUpdate          bool
	}{
		{
			name:                  "normal calculation - 100 seconds duration",
			totalDistributeAmount: 1000,
			distributeStartTime:   1000,
			distributeEndTime:     1100,
			expectedAmountPerSecond: func() string {
				// 1000 << 128 / 100 = 10 << 128
				result := u256.Zero().Lsh(u256.NewUint(1000), 128)
				result = u256.Zero().Div(result, u256.NewUint(100))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   1100,
			expectNoUpdate:    false,
		},
		{
			name:                  "time duration is exactly 1 second - boundary",
			totalDistributeAmount: 1000,
			distributeStartTime:   1000,
			distributeEndTime:     1001,
			expectedAmountPerSecond: func() string {
				// 1000 << 128 / 1 = 1000 << 128
				result := u256.Zero().Lsh(u256.NewUint(1000), 128)
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   1001,
			expectNoUpdate:    false,
		},
		{
			name:                  "time duration is zero - no update",
			totalDistributeAmount: 1000,
			distributeStartTime:   1000,
			distributeEndTime:     1000,
			expectNoUpdate:        true,
		},
		{
			name:                  "time duration is negative - no update",
			totalDistributeAmount: 1000,
			distributeStartTime:   2000,
			distributeEndTime:     1000,
			expectNoUpdate:        true,
		},
		{
			name:                  "time duration is -1 - boundary",
			totalDistributeAmount: 1000,
			distributeStartTime:   1001,
			distributeEndTime:     1000,
			expectNoUpdate:        true,
		},
		{
			name:                  "very large duration",
			totalDistributeAmount: 1000000,
			distributeStartTime:   1000,
			distributeEndTime:     1000000000,
			expectedAmountPerSecond: func() string {
				// 1000000 << 128 / 999999000
				result := u256.Zero().Lsh(u256.NewUint(1000000), 128)
				result = u256.Zero().Div(result, u256.NewUint(999999000))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   1000000000,
			expectNoUpdate:    false,
		},
		{
			name:                  "very small total distribute amount",
			totalDistributeAmount: 1,
			distributeStartTime:   1000,
			distributeEndTime:     2000,
			expectedAmountPerSecond: func() string {
				// 1 << 128 / 1000
				result := u256.Zero().Lsh(u256.NewUint(1), 128)
				result = u256.Zero().Div(result, u256.NewUint(1000))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   2000,
			expectNoUpdate:    false,
		},
		{
			name:                  "zero total distribute amount",
			totalDistributeAmount: 0,
			distributeStartTime:   1000,
			distributeEndTime:     2000,
			expectedAmountPerSecond: func() string {
				// 0 << 128 / 1000 = 0
				return u256.Zero().ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   2000,
			expectNoUpdate:    false,
		},
		{
			name:                  "large total distribute amount",
			totalDistributeAmount: math.MaxInt64 / 2,
			distributeStartTime:   1000,
			distributeEndTime:     2000,
			expectedAmountPerSecond: func() string {
				// (MaxInt64/2) << 128 / 1000
				result := u256.Zero().Lsh(u256.NewUint(uint64(math.MaxInt64/2)), 128)
				result = u256.Zero().Div(result, u256.NewUint(1000))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   2000,
			expectNoUpdate:    false,
		},
		{
			name:                  "amount equals duration - 1:1 ratio",
			totalDistributeAmount: 1000,
			distributeStartTime:   1000,
			distributeEndTime:     2000,
			expectedAmountPerSecond: func() string {
				// 1000 << 128 / 1000 = 1 << 128
				result := u256.Zero().Lsh(u256.NewUint(1), 128)
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   2000,
			expectNoUpdate:    false,
		},
		{
			name:                  "duration much larger than amount",
			totalDistributeAmount: 100,
			distributeStartTime:   1000,
			distributeEndTime:     1000000,
			expectedAmountPerSecond: func() string {
				// 100 << 128 / 999000 (very small per second)
				result := u256.Zero().Lsh(u256.NewUint(100), 128)
				result = u256.Zero().Div(result, u256.NewUint(999000))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   1000000,
			expectNoUpdate:    false,
		},
		{
			name:                  "amount much larger than duration",
			totalDistributeAmount: 1000000,
			distributeStartTime:   1000,
			distributeEndTime:     1100,
			expectedAmountPerSecond: func() string {
				// 1000000 << 128 / 100 (very large per second)
				result := u256.Zero().Lsh(u256.NewUint(1000000), 128)
				result = u256.Zero().Div(result, u256.NewUint(100))
				return result.ToString()
			}(),
			expectedStartTime: 1000,
			expectedEndTime:   1100,
			expectNoUpdate:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := newRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
				0,
				100,
				1000,
			)

			// Store initial state
			initialAmount := manager.DistributeAmountPerSecondX128().ToString()
			initialStart := manager.DistributeStartTime()
			initialEnd := manager.DistributeEndTime()

			// when
			updateDistributeAmountPerSecondX128(
				manager,
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
			)

			// then
			if tt.expectNoUpdate {
				// Verify no update occurred
				uassert.Equal(t, initialAmount, manager.DistributeAmountPerSecondX128().ToString())
				uassert.Equal(t, initialStart, manager.DistributeStartTime())
				uassert.Equal(t, initialEnd, manager.DistributeEndTime())
			} else {
				// Verify update occurred with correct values
				uassert.Equal(t, tt.expectedAmountPerSecond, manager.DistributeAmountPerSecondX128().ToString())
				uassert.Equal(t, tt.expectedStartTime, manager.DistributeStartTime())
				uassert.Equal(t, tt.expectedEndTime, manager.DistributeEndTime())
			}
		})
	}
}

// TestRewardManager_addRewardPerDepositX128 tests the private function addRewardPerDepositX128
// This function accumulates reward per deposit and updates manager state
func TestRewardManager_addRewardPerDepositX128(t *testing.T) {
	// Define the manager values type for test cases
	type managerTestValues struct {
		accumulatedRewardPerDepositX128 *u256.Uint
		accumulatedHeight               int64
		accumulatedTime                 int64
		distributeStartTime             int64
		distributeEndTime               int64
	}

	tests := []struct {
		name                      string
		managerValues             managerTestValues
		rewardPerDepositX128      *u256.Uint
		currentHeight             int64
		currentTime               int64
		expectedAccumulatedReward string
		expectedAccumulatedHeight int64
		expectedAccumulatedTime   int64
		expectNoUpdate            bool
	}{
		{
			name: "normal addition - first reward",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.Zero(),
				accumulatedHeight:               0,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(1000),
			currentHeight:             150,
			currentTime:               1100,
			expectedAccumulatedReward: "1000",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "normal addition - accumulating rewards",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(3000),
			currentHeight:             150,
			currentTime:               1100,
			expectedAccumulatedReward: "8000",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "reward is zero - no update",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128: u256.Zero(),
			currentHeight:        150,
			currentTime:          1100,
			expectNoUpdate:       true,
		},
		{
			name: "accumulated time greater than current time - no update",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1200,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128: u256.NewUint(1000),
			currentHeight:        150,
			currentTime:          1100,
			expectNoUpdate:       true,
		},
		{
			name: "accumulated time equals current time - boundary",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1100,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(1000),
			currentHeight:             150,
			currentTime:               1100,
			expectedAccumulatedReward: "6000",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "distribute start time greater than current time - no update",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 900,
				distributeStartTime:             1200,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128: u256.NewUint(1000),
			currentHeight:        150,
			currentTime:          1100,
			expectNoUpdate:       true,
		},
		{
			name: "distribute start time equals current time - boundary",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 900,
				distributeStartTime:             1100,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(1000),
			currentHeight:             150,
			currentTime:               1100,
			expectedAccumulatedReward: "6000",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "current time past distribute end time - capped",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               1500,
			},
			rewardPerDepositX128:      u256.NewUint(1000),
			currentHeight:             200,
			currentTime:               2000,
			expectedAccumulatedReward: "6000",
			expectedAccumulatedHeight: 200,
			expectedAccumulatedTime:   1500,
			expectNoUpdate:            false,
		},
		{
			name: "current time equals distribute end time - boundary",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(5000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               1500,
			},
			rewardPerDepositX128:      u256.NewUint(1000),
			currentHeight:             150,
			currentTime:               1500,
			expectedAccumulatedReward: "6000",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1500,
			expectNoUpdate:            false,
		},
		{
			name: "very large accumulated reward",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.Zero().Sub(u256.MustFromDecimal("340282366920938463463374607431768211455"), u256.NewUint(1000)),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128: u256.NewUint(500),
			currentHeight:        150,
			currentTime:          1100,
			expectedAccumulatedReward: func() string {
				maxUint128 := u256.MustFromDecimal("340282366920938463463374607431768211455")
				result := u256.Zero().Sub(maxUint128, u256.NewUint(500))
				return result.ToString()
			}(),
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "very small reward addition",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(1000000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             900,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(1),
			currentHeight:             150,
			currentTime:               1100,
			expectedAccumulatedReward: "1000001",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1100,
			expectNoUpdate:            false,
		},
		{
			name: "multiple conditions - both time checks pass",
			managerValues: managerTestValues{
				accumulatedRewardPerDepositX128: u256.NewUint(1000),
				accumulatedHeight:               100,
				accumulatedTime:                 1000,
				distributeStartTime:             1000,
				distributeEndTime:               2000,
			},
			rewardPerDepositX128:      u256.NewUint(500),
			currentHeight:             150,
			currentTime:               1500,
			expectedAccumulatedReward: "1500",
			expectedAccumulatedHeight: 150,
			expectedAccumulatedTime:   1500,
			expectNoUpdate:            false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := launchpad.NewRewardManager(0, 0, 0, 0, 0, 0)
			manager.SetAccumulatedRewardPerDepositX128(tt.managerValues.accumulatedRewardPerDepositX128)
			manager.SetAccumulatedHeight(tt.managerValues.accumulatedHeight)
			manager.SetAccumulatedTime(tt.managerValues.accumulatedTime)
			manager.SetDistributeStartTime(tt.managerValues.distributeStartTime)
			manager.SetDistributeEndTime(tt.managerValues.distributeEndTime)

			// Store initial state
			initialReward := manager.AccumulatedRewardPerDepositX128().ToString()
			initialHeight := manager.AccumulatedHeight()
			initialTime := manager.AccumulatedTime()

			// when
			err := addRewardPerDepositX128(
				manager,
				tt.rewardPerDepositX128,
				tt.currentHeight,
				tt.currentTime,
			)

			// then
			uassert.Nil(t, err)

			if tt.expectNoUpdate {
				// Verify no update occurred
				uassert.Equal(t, initialReward, manager.AccumulatedRewardPerDepositX128().ToString())
				uassert.Equal(t, initialHeight, manager.AccumulatedHeight())
				uassert.Equal(t, initialTime, manager.AccumulatedTime())
			} else {
				// Verify update occurred with correct values
				uassert.Equal(t, tt.expectedAccumulatedReward, manager.AccumulatedRewardPerDepositX128().ToString())
				uassert.Equal(t, tt.expectedAccumulatedHeight, manager.AccumulatedHeight())
				uassert.Equal(t, tt.expectedAccumulatedTime, manager.AccumulatedTime())
			}
		})
	}
}

// TestRewardManager_addRewardState tests the private function addRewardState
// This function sets reward state for a deposit and returns it
func TestRewardManager_addRewardState(t *testing.T) {
	tests := []struct {
		name         string
		depositId    string
		rewardAmount int64
	}{
		{
			name:         "add first reward state",
			depositId:    "deposit1",
			rewardAmount: 1000,
		},
		{
			name:         "add second reward state",
			depositId:    "deposit2",
			rewardAmount: 2000,
		},
		{
			name:         "add reward state with zero amount",
			depositId:    "deposit3",
			rewardAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := newRewardManager(
				1000,
				900,
				2000,
				0,
				100,
				1000,
			)

			deposit := launchpad.NewDeposit(
				tt.depositId,
				"project:tier",
				30,
				testutils.TestAddress("depositor"),
				tt.rewardAmount,
				100,
				1000,
				2000,
			)

			rewardState := newRewardState(
				u256.NewUint(1000),
				tt.rewardAmount,
				1000,
				2000,
				1030,
			)

			// when
			result := addRewardState(manager, deposit, rewardState)

			// then
			uassert.NotNil(t, result)

			// Verify it was stored in the tree
			stored, exists := manager.Rewards().Get(tt.depositId)
			uassert.True(t, exists)
			uassert.NotNil(t, stored)

			// Verify the stored state has correct deposit amount
			storedState, ok := stored.(*launchpad.RewardState)
			uassert.True(t, ok)
			uassert.Equal(t, tt.rewardAmount, storedState.DepositAmount())
		})
	}
}
