package launchpad

import (
	"std"
	"testing"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
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
				"test": NewRewardState(u256.Zero(), 1000, 100, 200, &BlockTimeInfo{}),
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
				tt.distributeStartHeight,
				tt.distributeEndHeight,
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
		averageBlockTimeMs    int64
		existingDeposits      []*Deposit
		collectHeight         int64
		expectedStartHeight   int64
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
				&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
				&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
			),
			totalDistributeAmount: 1000,
			distributeStart:       150,
			distributeEnd:         250,
			averageBlockTimeMs:    2000,
			existingDeposits:      []*Deposit{},
			collectHeight:         250,
			expectedStartHeight:   150,
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
				&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
				&BlockTimeInfo{blockTime: 1000, blockHeight: 250},
			),
			totalDistributeAmount: 1000,
			distributeStart:       150,
			distributeEnd:         250,
			averageBlockTimeMs:    2000,
			existingDeposits: []*Deposit{
				NewDeposit(
					"1",
					"existing",
					500,
					"",
					500,
					&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
					&BlockTimeInfo{blockTime: 1000, blockHeight: 250},
				),
			},
			collectHeight:       250,
			expectedStartHeight: 150,
			expectedReward:      666,
			expectedHasError:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup
			currentHeight := std.ChainHeight()

			// Use current time as base and simulate timing
			now := time.Now().Unix()
			distributeStartTime := now - 1000 + tt.distributeStart
			distributeEndTime := now - 1000 + tt.distributeEnd
			currentTime := now
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStart,
				tt.distributeEnd,
				distributeStartTime,
				distributeEndTime,
				currentHeight,
				currentTime,
			)

			totalDepositAmount := int64(0)

			for _, deposit := range tt.existingDeposits {
				totalDepositAmount += int64(deposit.depositAmount)
				// Use timestamp based on deposit height offset
				depositTime := now - 1000 + deposit.DepositHeight()
				manager.updateRewardPerDepositX128(totalDepositAmount, deposit.DepositHeight(), depositTime)
				manager.addRewardStateByDeposit(deposit, tt.averageBlockTimeMs)
			}

			// Execute
			totalDepositAmount += tt.deposit.depositAmount
			// Use timestamp based on deposit height offset
			depositTime := now - 1000 + tt.deposit.DepositHeight()
			manager.updateRewardPerDepositX128(totalDepositAmount, tt.deposit.DepositHeight(), depositTime)
			rewardState := manager.addRewardStateByDeposit(tt.deposit, tt.averageBlockTimeMs)

			// Use timestamp based on collection height offset
			collectTime := now - 1000 + tt.collectHeight
			manager.updateRewardPerDepositX128(totalDepositAmount, tt.collectHeight, collectTime)
			reward, err := manager.collectReward(tt.deposit.ID(), tt.collectHeight)
			if err != nil {
				uassert.NoError(t, err)
			}

			uassert.Equal(t, tt.expectedStartHeight, rewardState.DistributeStartHeight())
			uassert.Equal(t, tt.expectedReward, reward)
		})
	}
}

func TestRewardManager_CollectReward(t *testing.T) {
	tests := []struct {
		name                  string
		totalDistributeAmount int64
		distributeStartHeight int64
		distributeEndHeight   int64
		currentHeight         int64
		depositId             string
		deposit               *Deposit
		averageBlockTimeMs    int64
		existingDeposits      []*Deposit
		collectHeight         int64
		expectedAmount        int64
		expectedHasError      bool
		expectedError         string
	}{
		{
			name:                  "collect reward succeed with valid deposit",
			totalDistributeAmount: 1000,
			distributeStartHeight: 100,
			distributeEndHeight:   200,
			currentHeight:         150,
			deposit: NewDeposit(
				"1",
				"test",
				30,
				"",
				1000,
				&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
				&BlockTimeInfo{blockTime: 1000, blockHeight: 200},
			),
			depositId:          "1",
			averageBlockTimeMs: 2000,
			existingDeposits:   []*Deposit{},
			collectHeight:      200,
			expectedAmount:     1000,
			expectedHasError:   false,
		},
		{
			name: "collect reward fail with nonexistent deposit",
			deposit: NewDeposit(
				"1",
				"test",
				30,
				"",
				1000,
				&BlockTimeInfo{blockTime: 1000, blockHeight: 150},
				&BlockTimeInfo{blockTime: 1000, blockHeight: 250},
			),
			depositId:          "nonexistent",
			collectHeight:      150,
			averageBlockTimeMs: 2000,
			existingDeposits:   []*Deposit{},
			expectedAmount:     0,
			expectedHasError:   true,
			expectedError:      "[GNOSWAP-LAUNCHPAD-020] not exist deposit",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetHeight(123)

			// Setup
			// Use current time as base and simulate timing
			now := time.Now().Unix()
			distributeStartTime := now - 1000 + tt.distributeStartHeight
			distributeEndTime := now - 1000 + tt.distributeEndHeight
			currentTime := now - 1000 + tt.currentHeight
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartHeight,
				tt.distributeEndHeight,
				distributeStartTime,
				distributeEndTime,
				tt.currentHeight,
				currentTime,
			)

			for _, deposit := range tt.existingDeposits {
				// Use timestamp based on deposit height offset
				depositTime := now - 1000 + deposit.DepositHeight()
				manager.updateRewardPerDepositX128(tt.totalDistributeAmount, deposit.DepositHeight(), depositTime)
				manager.addRewardStateByDeposit(deposit, tt.averageBlockTimeMs)
			}

			// Use timestamp based on deposit height offset
			depositTime := now - 1000 + tt.deposit.DepositHeight()
			manager.updateRewardPerDepositX128(tt.totalDistributeAmount, tt.deposit.DepositHeight(), depositTime)
			manager.addRewardStateByDeposit(tt.deposit, tt.averageBlockTimeMs)

			// Execute
			// Use timestamp based on collection height offset
			collectTime := now - 1000 + tt.collectHeight
			manager.updateRewardPerDepositX128(tt.totalDistributeAmount, tt.collectHeight, collectTime)
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
		name                         string
		totalDistributeAmount        int64
		distributeStartHeight        int64
		distributeEndHeight          int64
		distributeAmountPerSecondX128 *u256.Uint
		currentHeight                int64
		expectedHasError             bool
		expectedError                string
	}{
		{
			name:                         "new reward manager create valid manager with correct values",
			totalDistributeAmount:        1000,
			distributeStartHeight:        100,
			distributeEndHeight:          200,
			distributeAmountPerSecondX128: u256.NewUintFromInt64(100),
			currentHeight:                100,
			expectedHasError:             false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Execute
			// Use current time as base and simulate timing
			now := time.Now().Unix()
			distributeStartTime := now - 1000 + tt.distributeStartHeight
			distributeEndTime := now - 1000 + tt.distributeEndHeight
			currentTime := now - 1000 + tt.currentHeight
			manager := NewRewardManager(
				tt.totalDistributeAmount,
				tt.distributeStartHeight,
				tt.distributeEndHeight,
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(200)
	
	// Set up timestamps: 100 seconds duration
	baseTime := time.Now().Unix()
	distributeStartTime := baseTime
	distributeEndTime := baseTime + 100 // 100 seconds later
	currentTime := baseTime
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
		distributeStartTime,
		distributeEndTime,
		distributeStartHeight,
		currentTime,
	)
	
	// Create two deposits to test reward distribution
	deposit1 := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000, // deposit amount
		&BlockTimeInfo{blockTime: baseTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	
	deposit2 := NewDeposit(
		"2",
		"test",
		30,
		"",
		1000, // deposit amount
		&BlockTimeInfo{blockTime: baseTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	
	// Add both deposits at start time
	err := manager.updateRewardPerDepositX128(1000, distributeStartHeight, baseTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit1, 2000)
	
	err = manager.updateRewardPerDepositX128(2000, distributeStartHeight, baseTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit2, 2000)
	
	// Move time forward by 50 seconds (half way through)
	halfwayTime := baseTime + 50
	err = manager.updateRewardPerDepositX128(2000, distributeStartHeight + 25, halfwayTime)
	uassert.NoError(t, err)
	
	// Collect reward for deposit1 after 50 seconds
	reward1, err := manager.collectReward("1", distributeStartHeight + 25)
	uassert.NoError(t, err)
	
	// Each deposit should get 250 tokens (50% of 1000 / 2 deposits)
	t.Logf("Deposit1 reward after 50 seconds: %d (expected ~250)", reward1)
	uassert.Equal(t, true, reward1 >= 245 && reward1 <= 255, "reward1 should be ~250")
	
	// Move to end of distribution period
	err = manager.updateRewardPerDepositX128(2000, distributeEndHeight, distributeEndTime)
	uassert.NoError(t, err)
	
	// Collect reward for deposit2 after 100 seconds
	reward2, err := manager.collectReward("2", distributeEndHeight)
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(110) // Only 10 blocks but 100 seconds
	
	// Set up timestamps: blocks at irregular intervals
	baseTime := time.Now().Unix()
	distributeStartTime := baseTime
	distributeEndTime := baseTime + 100 // 100 seconds for just 10 blocks
	currentTime := baseTime
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
		distributeStartTime,
		distributeEndTime,
		distributeStartHeight,
		currentTime,
	)
	
	// Create first deposit at start
	deposit1 := NewDeposit(
		"1",
		"test",
		30,
		"",
		1000,
		&BlockTimeInfo{blockTime: baseTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	
	err := manager.updateRewardPerDepositX128(1000, distributeStartHeight, baseTime)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit1, 2000)
	
	// Simulate irregular block times:
	// Block 101 comes after 30 seconds (normally would be 1 second)
	time1 := baseTime + 30
	err = manager.updateRewardPerDepositX128(1000, distributeStartHeight + 1, time1)
	uassert.NoError(t, err)
	
	// Add second deposit
	deposit2 := NewDeposit(
		"2",
		"test",
		30,
		"",
		1000,
		&BlockTimeInfo{blockTime: time1, blockHeight: distributeStartHeight + 1},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	
	totalDeposits := int64(2000)
	err = manager.updateRewardPerDepositX128(totalDeposits, distributeStartHeight + 1, time1)
	uassert.NoError(t, err)
	manager.addRewardStateByDeposit(deposit2, 2000)
	
	// Block 105 comes after 80 seconds total (another 50 seconds gap)
	time2 := baseTime + 80
	err = manager.updateRewardPerDepositX128(totalDeposits, distributeStartHeight + 5, time2)
	uassert.NoError(t, err)
	
	// Check rewards for deposit1 (active for 80 seconds)
	// First 30 seconds: got all rewards (300 tokens)
	// Next 50 seconds: shared with deposit2 (250 tokens)
	// Total: ~550 tokens
	reward1, err := manager.collectReward("1", distributeStartHeight + 5)
	uassert.NoError(t, err)
	uassert.Equal(t, true, reward1 >= 545 && reward1 <= 555)
	
	// Check rewards for deposit2 (active for 50 seconds, sharing with deposit1)
	// Should get 250 tokens
	reward2, err := manager.collectReward("2", distributeStartHeight + 5)
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(200) // 100 blocks
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	manager.addRewardStateByDeposit(deposit, 5000)
	
	// Simulate fast blocks: 50 blocks in 50 seconds (1 block/second)
	midHeight := distributeStartHeight + 50
	midTime := distributeStartTime + 50
	
	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, midHeight, midTime)
	uassert.NoError(t, err)
	
	// Collect rewards after 50 seconds
	reward, err := manager.collectReward("1", midHeight)
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(105) // Only 5 blocks
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	manager.addRewardStateByDeposit(deposit, 5000)
	
	// Simulate slow blocks: only 3 blocks in 60 seconds (20 seconds/block)
	midHeight := distributeStartHeight + 3
	midTime := distributeStartTime + 60
	
	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, midHeight, midTime)
	uassert.NoError(t, err)
	
	// Collect rewards after 60 seconds
	reward, err := manager.collectReward("1", midHeight)
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(110) 
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1100) // 100 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	manager.addRewardStateByDeposit(deposit, 5000)
	
	// Simulate irregular blocks over 70 seconds
	irregularHeight := distributeStartHeight + 10
	irregularTime := distributeStartTime + 70
	
	// Update reward state
	err := manager.updateRewardPerDepositX128(1000000, irregularHeight, irregularTime)
	uassert.NoError(t, err)
	
	// Collect rewards after 70 seconds
	reward, err := manager.collectReward("1", irregularHeight)
	uassert.NoError(t, err)
	
	// Should get ~700 tokens (70% of time elapsed)
	uassert.Equal(t, true, reward >= 695 && reward <= 705, 
		"Irregular blocks should not affect time-based rewards")
}

// TestRewardManager_EdgeCase_ZeroDuration tests edge case with zero duration
func TestRewardManager_EdgeCase_ZeroDuration(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(100) // Same as start
	distributeStartTime := int64(1000)
	distributeEndTime := int64(1000) // Same as start (zero duration)
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(200)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	manager.addRewardStateByDeposit(deposit, 5000)
	
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
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(200)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000)
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: distributeStartHeight},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: distributeEndHeight},
	)
	manager.addRewardStateByDeposit(deposit, 5000)
	
	// Update past end time
	err := manager.updateRewardPerDepositX128(1000000, 300, 3000)
	uassert.NoError(t, err)
	
	// Collect rewards
	reward, err := manager.collectReward("1", 300)
	uassert.NoError(t, err)
	
	// Should get all 1000 tokens (100% distributed)
	uassert.Equal(t, true, reward >= 995 && reward <= 1005,
		"Should receive all rewards when collecting after end time")
}

// TestRewardManager_MultipleDeposits_DifferentTimings tests multiple deposits joining at different times
func TestRewardManager_MultipleDeposits_DifferentTimings(t *testing.T) {
	totalDistributeAmount := int64(1000)
	distributeStartHeight := int64(100)
	distributeEndHeight := int64(200)
	distributeStartTime := int64(1000)
	distributeEndTime := int64(2000) // 1000 seconds duration
	currentHeight := int64(100)
	currentTime := int64(1000)
	
	manager := NewRewardManager(
		totalDistributeAmount,
		distributeStartHeight,
		distributeEndHeight,
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
		&BlockTimeInfo{blockTime: distributeStartTime, blockHeight: 100},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: 200},
	)
	manager.addRewardStateByDeposit(deposit1, 5000)
	
	// Update after 250 seconds (deposit1 alone)
	err := manager.updateRewardPerDepositX128(1000000, 125, 1250)
	uassert.NoError(t, err)
	
	// Deposit 2: Joins after 250 seconds
	deposit2 := NewDeposit(
		"2",
		"test",
		30,
		"",
		1000000,
		&BlockTimeInfo{blockTime: 1250, blockHeight: 125},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: 200},
	)
	manager.addRewardStateByDeposit(deposit2, 5000)
	
	// Update after 500 seconds total (250 seconds shared)
	err = manager.updateRewardPerDepositX128(2000000, 150, 1500)
	uassert.NoError(t, err)
	
	// Deposit 3: Joins after 500 seconds
	deposit3 := NewDeposit(
		"3",
		"test",
		30,
		"",
		2000000, // Double amount
		&BlockTimeInfo{blockTime: 1500, blockHeight: 150},
		&BlockTimeInfo{blockTime: distributeEndTime, blockHeight: 200},
	)
	manager.addRewardStateByDeposit(deposit3, 5000)
	
	// Final update at end (500 seconds with 3 deposits)
	err = manager.updateRewardPerDepositX128(4000000, 200, 2000)
	uassert.NoError(t, err)
	
	// Collect all rewards
	reward1, err := manager.collectReward("1", 200)
	uassert.NoError(t, err)
	reward2, err := manager.collectReward("2", 200)
	uassert.NoError(t, err)
	reward3, err := manager.collectReward("3", 200)
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
