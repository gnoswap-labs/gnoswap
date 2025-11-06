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
)

func TestRewardManager_IsInitialized(t *testing.T) {
	tests := []struct {
		name             string
		rewardStates     map[string]*RewardState
		expectedResult   bool
		expectedHasError bool
		expectedError    string
	}{
		{
			name:             "is initialized return false for empty rewards",
			rewardStates:     map[string]*RewardState{},
			expectedResult:   false,
			expectedHasError: false,
		},
		{
			name: "is initialized return true when rewards exist",
			rewardStates: map[string]*RewardState{
				"test": NewRewardState(u256.Zero(), 1000, 100, 200, 0),
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
			manager := &RewardManager{rewards: tree}

			// Execute
			result := manager.IsInitialized()

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
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				distributeStartTime,
				distributeEndTime,
				tt.currentHeight,
				currentTime,
			)

			// Execute
			// Use timestamp based on height offset from start
			rewardTime := now - 1000 + tt.rewardHeight
			err := manager.updateRewardPerDepositX128(tt.totalDistributeAmount, tt.rewardHeight, rewardTime)

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
		deposit               *Deposit
		totalDistributeAmount int64
		distributeStart       int64
		distributeEnd         int64
		existingDeposits      []*Deposit
		collectHeight         int64
		expectedStartTime     int64
		expectedReward        int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name: "add reward state succeed for first deposit",
			deposit: NewDeposit(
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
			existingDeposits:      []*Deposit{},
			collectHeight:         250,
			expectedStartTime:     150,
			expectedReward:        1000,
			expectedHasError:      false,
		},
		{
			name: "add reward state succeed for subsequent deposit",
			deposit: NewDeposit(
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
			existingDeposits: []*Deposit{
				NewDeposit(
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
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStart,
				tt.distributeEnd,
				currentHeight,
				tt.distributeStart,
			)

			totalDepositAmount := int64(0)

			for _, deposit := range tt.existingDeposits {
				totalDepositAmount += int64(deposit.depositAmount)
				// Use timestamp based on deposit height offset
				manager.updateRewardPerDepositX128(totalDepositAmount, deposit.CreatedHeight(), deposit.DepositTime())
				manager.addRewardStateByDeposit(deposit)
			}

			// Execute
			totalDepositAmount += tt.deposit.depositAmount
			// Use timestamp based on deposit height offset
			manager.updateRewardPerDepositX128(totalDepositAmount, tt.deposit.CreatedHeight(), tt.deposit.DepositTime())
			rewardState := manager.addRewardStateByDeposit(tt.deposit)

			// Use timestamp based on collection height offset
			manager.updateRewardPerDepositX128(totalDepositAmount, tt.collectHeight, tt.collectHeight)
			reward, err := manager.collectReward(tt.deposit.ID(), tt.collectHeight)
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
		deposit               *Deposit
		existingDeposits      []*Deposit
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
			deposit: NewDeposit(
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
			existingDeposits: []*Deposit{},
			collectHeight:    200,
			expectedAmount:   1000,
			expectedHasError: false,
		},
		{
			name: "collect reward fail with nonexistent deposit",
			deposit: NewDeposit(
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
			existingDeposits: []*Deposit{},
			expectedAmount:   0,
			expectedHasError: true,
			expectedError:    "[GNOSWAP-LAUNCHPAD-020] not exist deposit",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			// Use current time as base and simulate timing
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
				tt.currentHeight,
				tt.distributeStartTime,
			)

			for _, deposit := range tt.existingDeposits {
				// Use timestamp based on deposit height offset
				manager.updateRewardPerDepositX128(tt.totalDistributeAmount, deposit.CreatedHeight(), deposit.DepositTime())
				manager.addRewardStateByDeposit(deposit)
			}

			// Use timestamp based on deposit height offset
			manager.updateRewardPerDepositX128(tt.totalDistributeAmount, tt.deposit.CreatedHeight(), tt.deposit.DepositTime())
			manager.addRewardStateByDeposit(tt.deposit)

			// Execute
			// Use timestamp based on collection height offset
			manager.updateRewardPerDepositX128(tt.totalDistributeAmount, tt.collectHeight, tt.collectHeight)
			amount, err := manager.collectReward(tt.depositId, tt.collectHeight)

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

func TestNewRewardManager(t *testing.T) {
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
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				distributeStartTime,
				distributeEndTime,
				tt.currentHeight,
				currentTime,
			)

			// Verify
			uassert.NotEqual(t, manager.rewards, nil)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Create two deposits to test reward distribution
	deposit1 := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000, // deposit amount
		1,
		distributeStartTime,
		distributeEndTime,
	)

	deposit2 := NewDeposit(
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
	err := manager.updateRewardPerDepositX128(1000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit1)

	err = manager.updateRewardPerDepositX128(2000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit2)

	// Move time forward by 50 seconds (half way through)
	halfwayTime := distributeStartTime + 50
	err = manager.updateRewardPerDepositX128(2000, halfwayTime, halfwayTime)
	uassert.NoError(t, err)

	// Collect reward for deposit1 after 50 seconds
	reward1, err := manager.collectReward("1", halfwayTime)
	uassert.NoError(t, err)

	// Each deposit should get 250 tokens (50% of 1000 / 2 deposits)
	t.Logf("Deposit1 reward after 50 seconds: %d (expected ~250)", reward1)
	uassert.Equal(t, true, reward1 >= 245 && reward1 <= 255, "reward1 should be ~250")

	// Move to end of distribution period
	err = manager.updateRewardPerDepositX128(2000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect reward for deposit2 after 100 seconds
	reward2, err := manager.collectReward("2", distributeEndTime)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Create first deposit at start
	deposit1 := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)

	err := manager.updateRewardPerDepositX128(1000, distributeStartTime, distributeStartTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit1)

	// Simulate irregular block times:
	// Block 101 comes after 30 seconds (normally would be 1 second)
	time1 := baseTime + 30
	err = manager.updateRewardPerDepositX128(1000, time1, time1)
	uassert.NoError(t, err)

	// Add second deposit
	deposit2 := NewDeposit(
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
	err = manager.updateRewardPerDepositX128(totalDeposits, time1, time1)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit2)

	// Block 105 comes after 80 seconds total (another 50 seconds gap)
	time2 := baseTime + 80
	err = manager.updateRewardPerDepositX128(totalDeposits, time2, time2)
	uassert.NoError(t, err)

	// Check rewards for deposit1 (active for 80 seconds)
	// First 30 seconds: got all rewards (300 tokens)
	// Next 50 seconds: shared with deposit2 (250 tokens)
	// Total: ~550 tokens
	reward1, err := manager.collectReward("1", time2)
	uassert.NoError(t, err)
	uassert.Equal(t, true, reward1 >= 545 && reward1 <= 555)

	// Check rewards for deposit2 (active for 50 seconds, sharing with deposit1)
	// Should get 250 tokens
	reward2, err := manager.collectReward("2", time2)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit)

	// Simulate fast blocks: 50 blocks in 50 seconds (1 block/second)
	midHeight := distributeStartTime + 50
	midTime := distributeStartTime + 50

	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, midHeight, midTime)
	uassert.NoError(t, err)

	// Collect rewards after 50 seconds
	reward, err := manager.collectReward("1", midTime)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit)

	// Simulate slow blocks: only 3 blocks in 60 seconds (20 seconds/block)
	midHeight := distributeStartTime + 3
	midTime := distributeStartTime + 60

	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, midHeight, midTime)
	uassert.NoError(t, err)

	// Collect rewards after 60 seconds
	reward, err := manager.collectReward("1", midTime)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Add deposit at start
	deposit := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit)

	// Simulate irregular blocks over 70 seconds
	irregularHeight := distributeStartTime + 10
	irregularTime := distributeStartTime + 70

	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, irregularHeight, irregularTime)
	uassert.NoError(t, err)

	// Collect rewards after 70 seconds
	reward, err := manager.collectReward("1", irregularTime)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Should have zero distribute amount per second
	uassert.Equal(t, true, manager.distributeAmountPerSecondX128.IsZero(),
		"Zero duration should result in zero distribution rate")
}

// TestRewardManager_EdgeCase_TimeGoesBackward tests that time cannot go backward
func TestRewardManager_EdgeCase_TimeGoesBackward(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Add deposit
	deposit := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit)

	// First update at time 1500
	err := manager.updateRewardPerDepositX128(1000000, 150, 1500)
	uassert.NoError(t, err)

	// Try to update with earlier time (should not affect accumulated time)
	manager.addRewardPerDepositX128(u256.Zero(), 140, 1400)

	// Accumulated time should still be 1500
	uassert.Equal(t, int64(1500), manager.accumulatedTime,
		"Time should not go backward")
}

// TestRewardManager_EdgeCase_RewardAfterEnd tests reward collection after distribution end
func TestRewardManager_EdgeCase_RewardAfterEnd(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Add deposit
	deposit := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit)

	// Update past end time
	err := manager.updateRewardPerDepositX128(1000000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect rewards
	reward, err := manager.collectReward("1", distributeEndTime)
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

	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartTime,
		distributeEndTime,
		currentHeight,
		currentTime,
	)

	// Deposit 1: Joins at start
	deposit1 := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		distributeStartTime,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit1)

	// Update after 250 seconds (deposit1 alone)
	timeAfter250s := distributeStartTime + 250
	err := manager.updateRewardPerDepositX128(1000000, timeAfter250s, timeAfter250s)
	uassert.NoError(t, err)

	// Deposit 2: Joins after 250 seconds
	deposit2 := NewDeposit(
		"2",
		"test",
		30,
		"",
		1000000,
		currentHeight,
		timeAfter250s,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit2)

	// Update after 500 seconds total (250 seconds shared)
	timeAfter500s := distributeStartTime + 500
	err = manager.updateRewardPerDepositX128(2000000, timeAfter500s, timeAfter500s)
	uassert.NoError(t, err)

	// Deposit 3: Joins after 500 seconds
	deposit3 := NewDeposit(
		"3",
		"test",
		30,
		"",
		2000000, // Double amount
		currentHeight,
		timeAfter500s,
		distributeEndTime,
	)
	manager.addRewardStateByDeposit(deposit3)

	// Final update at end (500 seconds with 3 deposits)
	err = manager.updateRewardPerDepositX128(4000000, distributeEndTime, distributeEndTime)
	uassert.NoError(t, err)

	// Collect all rewards
	reward1, err := manager.collectReward("1", distributeEndTime)
	uassert.NoError(t, err)
	reward2, err := manager.collectReward("2", distributeEndTime)
	uassert.NoError(t, err)
	reward3, err := manager.collectReward("3", distributeEndTime)
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
// Tests: claimableTime := deposit.DepositTime() + r.rewardClaimableDuration
func TestRewardManager_ClaimableTimeOverflow(t *testing.T) {
	tests := []struct {
		name              string
		depositTime       int64
		claimableDuration int64
		expectedResult    int64
		description       string
	}{
		{
			name:              "normal case",
			depositTime:       1000,
			claimableDuration: 500,
			expectedResult:    1500,
			description:       "Normal addition",
		},
		{
			name:              "boundary - exactly MaxInt64",
			depositTime:       math.MaxInt64 - 1000,
			claimableDuration: 1000,
			expectedResult:    math.MaxInt64,
			description:       "Should handle boundary at MaxInt64",
		},
		// TODO: Add overflow test case after implementing overflow check in main code
		// Currently, MaxInt64 + 1 would wrap to negative (Go behavior)
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := NewRewardManager(
				1000000,
				time.Now().Unix(),
				time.Now().Unix()+1000,
				100,
				time.Now().Unix(),
			)
			manager.rewardClaimableDuration = tt.claimableDuration

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				tt.depositTime,
				tt.depositTime+1000,
			)

			// when
			rewardState := manager.addRewardStateByDeposit(deposit)
			claimableTime := rewardState.ClaimableTime()

			// then
			uassert.Equal(t, tt.expectedResult, claimableTime,
				"claimableTime should match expected result")
		})
	}
}

// TestRewardManager_ClaimedAmountOverflow tests potential overflow in claimedAmount update (line 268)  
// Tests: rewardState.setClaimedAmount(rewardState.ClaimedAmount() + claimableReward)
func TestRewardManager_ClaimedAmountOverflow(t *testing.T) {
	tests := []struct {
		name             string
		initialClaimed   int64
		claimableReward  int64
		expectedResult   int64
		description      string
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

			manager := NewRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				100,
				currentTime,
			)
			manager.rewardClaimableDuration = 100

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			rewardState := manager.addRewardStateByDeposit(deposit)
			
			// Setup: Set initial claimed amount
			rewardState.setClaimedAmount(tt.initialClaimed)
			manager.rewards.Set(deposit.ID(), rewardState)

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
			manager.accumulatedRewardPerDepositX128 = accumX128

			// when
			_, _ = manager.collectReward(deposit.ID(), currentTime+200)
			
			// then
			updatedState, _ := manager.getDepositRewardState(deposit.ID())
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
		name             string
		initialTotal     int64
		claimableReward  int64
		expectedResult   int64
		description      string
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

			manager := NewRewardManager(
				10000000,
				distributeStart,
				distributeEnd,
				100,
				currentTime,
			)
			manager.rewardClaimableDuration = 100
			manager.totalClaimedAmount = tt.initialTotal

			deposit := NewDeposit(
				"test_deposit",
				"test_project:100",
				30,
				testutils.TestAddress("depositor"),
				1000000,
				100,
				currentTime-500,
				distributeEnd,
			)

			rewardState := manager.addRewardStateByDeposit(deposit)
			
			// Setup: Configure accumulated reward to generate exact claimableReward
			priceDebtX128 := rewardState.PriceDebtX128()
			totalReward := tt.claimableReward
			depositAmount := deposit.DepositAmount()
			
			actualRewardX128 := u256.NewUint(uint64(totalReward))
			actualRewardX128 = u256.Zero().Lsh(actualRewardX128, 128)
			actualRewardX128 = u256.Zero().Div(actualRewardX128, u256.NewUint(uint64(depositAmount)))
			
			accumX128 := u256.Zero().Add(actualRewardX128, priceDebtX128)
			manager.accumulatedRewardPerDepositX128 = accumX128

			// when
			_, _ = manager.collectReward(deposit.ID(), currentTime+200)

			// then
			newTotal := manager.totalClaimedAmount
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
		name                   string
		setupManager           func() *RewardManager
		rewardPerSecondX128    *u256.Uint
		totalStaked            int64
		currentTime            int64
		expectedResultIsZero   bool
		expectedHasError       bool
		expectedErrorContains  string
		validateResult         func(t *testing.T, result *u256.Uint)
	}{
		{
			name: "normal calculation - valid time range",
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     800,  // before distributeStartTime
					distributeStartTime: 1000, // should use this as accumulatedTime
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     2100, // after distributeEndTime
					distributeStartTime: 1000,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     2000, // exactly at distributeEndTime
					distributeStartTime: 1000,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   1500,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   1500,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   math.MaxInt64,
				}
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
			setupManager: func() *RewardManager {
				manager := &RewardManager{
					accumulatedTime:     1000,
					distributeStartTime: 900,
					distributeEndTime:   2000,
				}
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
			result, err := manager.calculateRewardPerDepositX128(
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
		name                   string
		totalDistributeAmount  int64
		distributeStartTime    int64
		distributeEndTime      int64
		expectedAmountPerSecond string
		expectedStartTime      int64
		expectedEndTime        int64
		expectNoUpdate         bool
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
			manager := &RewardManager{
				distributeAmountPerSecondX128: u256.Zero(),
				distributeStartTime:           0,
				distributeEndTime:             0,
			}

			// Store initial state
			initialAmount := manager.distributeAmountPerSecondX128.ToString()
			initialStart := manager.distributeStartTime
			initialEnd := manager.distributeEndTime

			// when
			manager.updateDistributeAmountPerSecondX128(
				tt.totalDistributeAmount,
				tt.distributeStartTime,
				tt.distributeEndTime,
			)

			// then
			if tt.expectNoUpdate {
				// Verify no update occurred
				uassert.Equal(t, initialAmount, manager.distributeAmountPerSecondX128.ToString())
				uassert.Equal(t, initialStart, manager.distributeStartTime)
				uassert.Equal(t, initialEnd, manager.distributeEndTime)
			} else {
				// Verify update occurred with correct values
				uassert.Equal(t, tt.expectedAmountPerSecond, manager.distributeAmountPerSecondX128.ToString())
				uassert.Equal(t, tt.expectedStartTime, manager.distributeStartTime)
				uassert.Equal(t, tt.expectedEndTime, manager.distributeEndTime)
			}
		})
	}
}
