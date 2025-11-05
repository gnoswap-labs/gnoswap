package v1

import (
	"math"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestRewardManager_addRewardStateByDeposit tests overflow in claimableTime calculation
func TestRewardManager_addRewardStateByDeposit(t *testing.T) {
	tests := []struct {
		name              string
		depositTime       int64
		claimableDuration int64
		shouldOverflow    bool
		description       string
	}{
		{
			name:              "normal - no overflow",
			depositTime:       1000,
			claimableDuration: 500,
			shouldOverflow:    false,
			description:       "Normal addition without overflow",
		},
		{
			name:              "boundary - MaxInt64 depositTime with duration 0",
			depositTime:       math.MaxInt64,
			claimableDuration: 0,
			shouldOverflow:    false,
			description:       "MaxInt64 + 0 should not overflow",
		},
		{
			name:              "overflow - MaxInt64 depositTime with duration 1",
			depositTime:       math.MaxInt64,
			claimableDuration: 1,
			shouldOverflow:    true,
			description:       "MaxInt64 + 1 should overflow",
		},
		{
			name:              "overflow - near MaxInt64",
			depositTime:       math.MaxInt64 - 100,
			claimableDuration: 200,
			shouldOverflow:    true,
			description:       "(MaxInt64 - 100) + 200 should overflow",
		},
		{
			name:              "boundary - exactly MaxInt64",
			depositTime:       math.MaxInt64 - 1000,
			claimableDuration: 1000,
			shouldOverflow:    false,
			description:       "Exactly reaching MaxInt64 should not overflow",
		},
		{
			name:              "overflow - large values",
			depositTime:       math.MaxInt64 / 2,
			claimableDuration: math.MaxInt64/2 + 1,
			shouldOverflow:    true,
			description:       "Half MaxInt64 + Half MaxInt64 + 1 should overflow",
		},
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

			// when & then
			if tt.shouldOverflow {
				rewardState := manager.addRewardStateByDeposit(deposit)
				claimableTime := rewardState.ClaimableTime()

				uassert.True(t, claimableTime < 0 || claimableTime < tt.depositTime,
					"Overflow should result in negative or smaller value")
			} else {
				rewardState := manager.addRewardStateByDeposit(deposit)
				claimableTime := rewardState.ClaimableTime()

				uassert.True(t, claimableTime >= tt.depositTime,
					"No overflow - claimableTime should be >= depositTime")
			}
		})
	}
}

// TestRewardManager_collectReward tests overflow in claimed amount update
func TestRewardManager_collectReward(t *testing.T) {
	tests := []struct {
		name             string
		initialClaimed   int64
		claimableReward  int64
		shouldOverflow   bool
		description      string
	}{
		{
			name:            "normal - no overflow",
			initialClaimed:  1000,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Normal accumulation without overflow",
		},
		{
			name:            "boundary - MaxInt64 with 0 reward",
			initialClaimed:  math.MaxInt64,
			claimableReward: 0,
			shouldOverflow:  false,
			description:     "MaxInt64 + 0 should not overflow",
		},
		{
			name:            "overflow - MaxInt64 with 1 reward",
			initialClaimed:  math.MaxInt64,
			claimableReward: 1,
			shouldOverflow:  true,
			description:     "MaxInt64 + 1 should overflow",
		},
		{
			name:            "overflow - near MaxInt64",
			initialClaimed:  math.MaxInt64 - 100,
			claimableReward: 200,
			shouldOverflow:  true,
			description:     "(MaxInt64 - 100) + 200 should overflow",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialClaimed:  math.MaxInt64 - 1000,
			claimableReward: 1000,
			shouldOverflow:  false,
			description:     "Exactly reaching MaxInt64 should not overflow",
		},
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
			rewardState.setClaimedAmount(tt.initialClaimed)

			if tt.claimableReward > 0 {
				// accumulatedRewardPerDepositX128 needs to be set so that
				// (accumulated - priceDebt) * depositAmount / 2^128 = claimableReward
				targetReward := tt.claimableReward + tt.initialClaimed

				// Calculate required accumulated per deposit
				depositAmount := deposit.DepositAmount()
				requiredAccumX128 := u256.NewUintFromInt64(targetReward)
				requiredAccumX128 = u256.Zero().Lsh(requiredAccumX128, 128)
				requiredAccumX128 = u256.Zero().Div(requiredAccumX128, u256.NewUintFromInt64(depositAmount))

				manager.accumulatedRewardPerDepositX128 = requiredAccumX128
			}

			// when
			resultAmount, _ := manager.collectReward(deposit.ID(), currentTime)

			// then
			if tt.shouldOverflow {
				newClaimedAmount := rewardState.ClaimedAmount()
				expected := tt.initialClaimed + tt.claimableReward
				if expected < 0 {
					uassert.True(t, newClaimedAmount < tt.initialClaimed || newClaimedAmount < 0,
						"Overflow should result in wraparound")
				}
			} else {
				if tt.claimableReward > 0 {
					uassert.Equal(t, resultAmount, tt.claimableReward,
						"Should collect exact claimable reward")
				}
			}
		})
	}
}

// TestRewardManager_collectReward_TotalClaimedAmountOverflow tests overflow in total claimed amount
func TestRewardManager_collectReward_TotalClaimedAmountOverflow(t *testing.T) {
	tests := []struct {
		name              string
		initialTotal      int64
		claimableReward   int64
		shouldOverflow    bool
		description       string
	}{
		{
			name:            "normal - no overflow",
			initialTotal:    1000,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Normal accumulation without overflow",
		},
		{
			name:            "boundary - MaxInt64 with 0 reward",
			initialTotal:    math.MaxInt64,
			claimableReward: 0,
			shouldOverflow:  false,
			description:     "MaxInt64 + 0 should not overflow",
		},
		{
			name:            "overflow - MaxInt64 with 1 reward",
			initialTotal:    math.MaxInt64,
			claimableReward: 1,
			shouldOverflow:  true,
			description:     "MaxInt64 + 1 should overflow",
		},
		{
			name:            "overflow - near MaxInt64",
			initialTotal:    math.MaxInt64 - 50,
			claimableReward: 100,
			shouldOverflow:  true,
			description:     "(MaxInt64 - 50) + 100 should overflow",
		},
		{
			name:            "boundary - exactly MaxInt64",
			initialTotal:    math.MaxInt64 - 500,
			claimableReward: 500,
			shouldOverflow:  false,
			description:     "Exactly reaching MaxInt64 should not overflow",
		},
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

			// Set initial total claimed amount
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

			// Add reward state
			_ = manager.addRewardStateByDeposit(deposit)

			// Set up rewards to get desired claimableReward
			if tt.claimableReward > 0 {
				depositAmount := deposit.DepositAmount()
				requiredAccumX128 := u256.NewUintFromInt64(tt.claimableReward)
				requiredAccumX128 = u256.Zero().Lsh(requiredAccumX128, 128)
				requiredAccumX128 = u256.Zero().Div(requiredAccumX128, u256.NewUintFromInt64(depositAmount))

				manager.accumulatedRewardPerDepositX128 = requiredAccumX128
			}

			initialTotal := manager.totalClaimedAmount

			// when
			_, _ = manager.collectReward(deposit.ID(), currentTime)

			// then
			newTotal := manager.totalClaimedAmount

			if tt.shouldOverflow {
				// If overflow occurred, totalClaimedAmount would wrap around
				expected := initialTotal + tt.claimableReward
				if expected < 0 {
					// Overflow occurred
					uassert.True(t, newTotal < initialTotal || newTotal < 0,
						"Overflow should result in wraparound to negative or smaller value")
				}
			} else {
				// No overflow - total should increase correctly
				if tt.claimableReward > 0 {
					uassert.Equal(t, newTotal, initialTotal+tt.claimableReward,
						"Total claimed should increase by claimable reward")
				}
			}
		})
	}
}

// TestRewardManager_calculateRewardPerDepositX128 tests the core reward calculation logic
func TestRewardManager_calculateRewardPerDepositX128(t *testing.T) {
	tests := []struct {
		name                 string
		setupManager         func() *RewardManager
		rewardPerSecondX128  *u256.Uint
		totalStaked          int64
		currentTime          int64
		expectedReward       *u256.Uint
		expectedHasError     bool
		expectedError        string
	}{
		{
			name: "normal - calculate correct reward per deposit",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         150,
			expectedReward:      u256.NewUintFromInt64(5000), // (150-100) * 100 / 1000 = 5
			expectedHasError:    false,
		},
		{
			name: "edge case - currentTime before accumulatedTime (not started yet)",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         50, // before start
			expectedReward:      u256.Zero(),
			expectedHasError:    false,
		},
		{
			name: "edge case - accumulatedTime after distributeEndTime (past end)",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					250, // past end
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         300,
			expectedReward:      u256.Zero(),
			expectedHasError:    false,
		},
		{
			name: "edge case - currentTime after distributeEndTime caps to end",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         300, // past end, should cap to 200
			expectedReward:      u256.NewUintFromInt64(10000), // (200-100) * 100 / 1000 = 10
			expectedHasError:    false,
		},
		{
			name: "edge case - rewardPerSecondX128 is zero returns error",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.Zero(),
			totalStaked:         1000,
			currentTime:         150,
			expectedHasError:    true,
			expectedError:       "GNOSWAP-LAUNCHPAD-013",
		},
		{
			name: "edge case - totalStaked is zero returns zero",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         0,
			currentTime:         150,
			expectedReward:      u256.Zero(),
			expectedHasError:    false,
		},
		{
			name: "edge case - accumulatedTime before distributeStartTime uses startTime",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					50, // before start
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         150,
			expectedReward:      u256.NewUintFromInt64(5000), // (150-100) * 100 / 1000 = 5
			expectedHasError:    false,
		},
		{
			name: "boundary - currentTime equals accumulatedTime (zero duration)",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					150,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         150, // same as accumulatedTime
			expectedReward:      u256.Zero(),
			expectedHasError:    false,
		},
		{
			name: "boundary - timeDuration = 1 second",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(100),
			totalStaked:         1000,
			currentTime:         101, // 1 second duration
			expectedReward:      u256.NewUintFromInt64(100), // 1 * 100 / 1000 = 0.1
			expectedHasError:    false,
		},
		{
			name: "boundary - large totalStaked",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(1000000),
			totalStaked:         9223372036854775807, // MaxInt64
			currentTime:         150,
			expectedReward:      u256.NewUintFromInt64(0), // small result due to large divisor
			expectedHasError:    false,
		},
		{
			name: "boundary - large rewardPerSecond",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				return manager
			},
			rewardPerSecondX128: u256.NewUintFromInt64(9223372036854775807), // MaxInt64
			totalStaked:         1000,
			currentTime:         150,
			expectedReward:      u256.NewUintFromInt64(461168601842738790), // (150-100) * MaxInt64 / 1000
			expectedHasError:    false,
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
				uassert.ErrorContains(t, err, tt.expectedError)
			} else {
				uassert.Nil(t, err)
				uassert.True(t, result.Eq(tt.expectedReward),
					"Expected reward mismatch")
			}
		})
	}
}

// TestRewardManager_updateDistributeAmountPerSecondX128 tests the per-second distribution calculation
func TestRewardManager_updateDistributeAmountPerSecondX128(t *testing.T) {
	tests := []struct {
		name                string
		totalDistribute     int64
		distributeStart     int64
		distributeEnd       int64
		expectedUpdated     bool
		checkAmountPerSec   bool
	}{
		{
			name:            "normal - calculate correct amount per second",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "edge case - distributeStart equals distributeEnd (timeDuration = 0)",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   100,
			expectedUpdated: false,
		},
		{
			name:            "edge case - distributeStart greater than distributeEnd (negative duration)",
			totalDistribute: 1000000,
			distributeStart: 200,
			distributeEnd:   100,
			expectedUpdated: false,
		},
		{
			name:            "edge case - totalDistributeAmount is zero",
			totalDistribute: 0,
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - very small timeDuration (1 second)",
			totalDistribute: 1000000,
			distributeStart: 100,
			distributeEnd:   101,
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - very large timeDuration",
			totalDistribute: 1000000,
			distributeStart: 0,
			distributeEnd:   31536000, // 1 year in seconds
			expectedUpdated: true,
			checkAmountPerSec: true,
		},
		{
			name:            "boundary - large totalDistribute",
			totalDistribute: 9223372036854775807, // MaxInt64
			distributeStart: 100,
			distributeEnd:   200,
			expectedUpdated: true,
			checkAmountPerSec: true,
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
			initialAmountPerSec := manager.distributeAmountPerSecondX128.Clone()

			// when
			manager.updateDistributeAmountPerSecondX128(
				tt.totalDistribute,
				tt.distributeStart,
				tt.distributeEnd,
			)

			// then
			if tt.expectedUpdated {
				if tt.distributeEnd <= tt.distributeStart {
					// Should not update if duration invalid
					uassert.True(t, manager.distributeAmountPerSecondX128.Eq(initialAmountPerSec),
						"Should not update with invalid duration")
				} else {
					// Verify times were set
					uassert.Equal(t, manager.distributeStartTime, tt.distributeStart)
					uassert.Equal(t, manager.distributeEndTime, tt.distributeEnd)

					if tt.checkAmountPerSec {
						// Verify amountPerSecond is not zero (unless totalDistribute is zero)
						if tt.totalDistribute == 0 {
							uassert.True(t, manager.distributeAmountPerSecondX128.IsZero(),
								"Amount per second should be zero when total is zero")
						} else {
							uassert.False(t, manager.distributeAmountPerSecondX128.IsZero(),
								"Amount per second should not be zero")
						}
					}
				}
			} else {
				// Should not update
				uassert.True(t, manager.distributeAmountPerSecondX128.Eq(initialAmountPerSec),
					"Should not update amount per second")
			}
		})
	}
}

// TestRewardManager_addRewardState tests adding reward state for a deposit
func TestRewardManager_addRewardState(t *testing.T) {
	tests := []struct {
		name          string
		setupDeposit  func() *Deposit
		setupReward   func() *RewardState
		verifyAdded   bool
	}{
		{
			name: "normal - add state successfully",
			setupDeposit: func() *Deposit {
				return NewDeposit(
					"deposit_1",
					"project:100",
					30,
					testutils.TestAddress("user"),
					1000000,
					100,
					time.Now().Unix(),
					time.Now().Unix()+1000,
				)
			},
			setupReward: func() *RewardState {
				return NewRewardState(
					u256.NewUintFromInt64(100),
					1000000,
					100,
					200,
					150,
				)
			},
			verifyAdded: true,
		},
		{
			name: "edge case - deposit ID already exists (overwrite)",
			setupDeposit: func() *Deposit {
				return NewDeposit(
					"duplicate_deposit",
					"project:100",
					30,
					testutils.TestAddress("user"),
					1000000,
					100,
					time.Now().Unix(),
					time.Now().Unix()+1000,
				)
			},
			setupReward: func() *RewardState {
				return NewRewardState(
					u256.NewUintFromInt64(200),
					2000000,
					100,
					200,
					150,
				)
			},
			verifyAdded: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := NewRewardManager(
				1000000,
				100,
				200,
				100,
				time.Now().Unix(),
			)
			deposit := tt.setupDeposit()
			rewardState := tt.setupReward()

			// For overwrite test, add initial state first
			if tt.name == "edge case - deposit ID already exists (overwrite)" {
				initialState := NewRewardState(
					u256.NewUintFromInt64(50),
					500000,
					100,
					200,
					150,
				)
				manager.addRewardState(deposit, initialState)
			}

			// when
			result := manager.addRewardState(deposit, rewardState)

			// then
			if tt.verifyAdded {
				uassert.NotNil(t, result)
				uassert.Equal(t, result, rewardState)

				// Verify it was stored
				retrievedI, exists := manager.rewards.Get(deposit.ID())
				uassert.True(t, exists, "State should be stored")
				retrieved := retrievedI.(*RewardState)
				uassert.Equal(t, retrieved, rewardState)
			}
		})
	}
}

// TestRewardManager_addRewardPerDepositX128 tests adding reward per deposit with various conditions
func TestRewardManager_addRewardPerDepositX128(t *testing.T) {
	tests := []struct {
		name                    string
		setupManager            func() *RewardManager
		rewardPerDepositX128    *u256.Uint
		currentHeight           int64
		currentTime             int64
		expectedError           bool
		shouldUpdate            bool
		checkAccumulatedHeight  bool
		expectedAccumulatedHeight int64
		checkAccumulatedTime    bool
		expectedAccumulatedTime int64
	}{
		{
			name: "normal - add reward successfully",
			setupManager: func() *RewardManager {
				return NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        150,
			currentTime:          150,
			expectedError:        false,
			shouldUpdate:         true,
			checkAccumulatedHeight: true,
			expectedAccumulatedHeight: 150,
			checkAccumulatedTime: true,
			expectedAccumulatedTime: 150,
		},
		{
			name: "edge case - rewardPerDepositX128 is zero returns nil immediately",
			setupManager: func() *RewardManager {
				return NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
			},
			rewardPerDepositX128: u256.Zero(),
			currentHeight:        150,
			currentTime:          150,
			expectedError:        false,
			shouldUpdate:         false,
		},
		{
			name: "edge case - accumulatedTime greater than currentTime returns nil",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					150, // accumulatedTime = 150
				)
				return manager
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        160,
			currentTime:          140, // currentTime < accumulatedTime
			expectedError:        false,
			shouldUpdate:         false,
		},
		{
			name: "edge case - distributeStartTime greater than currentTime returns nil",
			setupManager: func() *RewardManager {
				return NewRewardManager(
					1000000,
					200, // distributeStartTime = 200
					300,
					100,
					100,
				)
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        150,
			currentTime:          150, // currentTime < distributeStartTime
			expectedError:        false,
			shouldUpdate:         false,
		},
		{
			name: "edge case - currentTime greater than distributeEndTime caps to end",
			setupManager: func() *RewardManager {
				return NewRewardManager(
					1000000,
					100,
					200, // distributeEndTime = 200
					100,
					100,
				)
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        250,
			currentTime:          300, // currentTime > distributeEndTime
			expectedError:        false,
			shouldUpdate:         true,
			checkAccumulatedTime: true,
			expectedAccumulatedTime: 200, // capped to distributeEndTime
		},
		{
			name: "boundary - verify accumulated reward increases",
			setupManager: func() *RewardManager {
				manager := NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
				manager.accumulatedRewardPerDepositX128 = u256.NewUintFromInt64(1000)
				return manager
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        150,
			currentTime:          150,
			expectedError:        false,
			shouldUpdate:         true,
			checkAccumulatedHeight: true,
			expectedAccumulatedHeight: 150,
		},
		{
			name: "boundary - currentTime equals distributeEndTime",
			setupManager: func() *RewardManager {
				return NewRewardManager(
					1000000,
					100,
					200,
					100,
					100,
				)
			},
			rewardPerDepositX128: u256.NewUintFromInt64(500),
			currentHeight:        200,
			currentTime:          200, // exactly at end
			expectedError:        false,
			shouldUpdate:         true,
			checkAccumulatedTime: true,
			expectedAccumulatedTime: 200,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// given
			manager := tt.setupManager()
			initialAccumulated := manager.accumulatedRewardPerDepositX128.Clone()

			// when
			err := manager.addRewardPerDepositX128(
				tt.rewardPerDepositX128,
				tt.currentHeight,
				tt.currentTime,
			)

			// then
			if tt.expectedError {
				uassert.NotNil(t, err)
			} else {
				uassert.Nil(t, err)

				if tt.shouldUpdate {
					// Verify accumulated was updated
					uassert.False(t, manager.accumulatedRewardPerDepositX128.Eq(initialAccumulated),
						"Accumulated reward should be updated")

					if tt.checkAccumulatedHeight {
						uassert.Equal(t, manager.accumulatedHeight, tt.expectedAccumulatedHeight,
							"Accumulated height mismatch")
					}

					if tt.checkAccumulatedTime {
						uassert.Equal(t, manager.accumulatedTime, tt.expectedAccumulatedTime,
							"Accumulated time mismatch")
					}
				} else {
					// Verify nothing was updated
					uassert.True(t, manager.accumulatedRewardPerDepositX128.Eq(initialAccumulated),
						"Accumulated reward should not change")
				}
			}
		})
	}
}
