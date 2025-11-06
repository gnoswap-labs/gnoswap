package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gov/staker"
)

// Test ProtocolFeeRewardManager creation
func TestNewProtocolFeeRewardManager(t *testing.T) {
	t.Run("Create new protocol fee reward manager", func(t *testing.T) {
		// When: Create new protocol fee reward manager
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// Then: Should initialize with empty values
		uassert.NotEqual(t, resolver, nil)
		uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(0))
		uassert.Equal(t, len(resolver.GetAllAccumulatedProtocolFeeX128PerStake()), 0)
		uassert.Equal(t, len(resolver.GetProtocolFeeAmounts()), 0)
	})
}

// Test GetAccumulatedProtocolFeeX128PerStake
func TestProtocolFeeRewardManager_GetAccumulatedProtocolFeeX128PerStake(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(*ProtocolFeeRewardManagerResolver)
		token    string
		expected string
	}{
		{
			name:     "Get non-existent token",
			setup:    func(m *ProtocolFeeRewardManagerResolver) {},
			token:    "token1",
			expected: "0",
		},
		{
			name: "Get existing token",
			setup: func(m *ProtocolFeeRewardManagerResolver) {
				accumulatedMap := make(map[string]*u256.Uint)
				accumulatedMap["token1"] = u256.NewUintFromInt64(1000)
				m.SetAccumulatedProtocolFeeX128PerStake(accumulatedMap)
			},
			token:    "token1",
			expected: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			tt.setup(resolver)

			// When: Get accumulated protocol fee X128 per stake
			result := resolver.GetAccumulatedProtocolFeeX128PerStake(tt.token)

			// Then: Should return expected value or nil
			if tt.expected == "0" {
				if result != nil {
					uassert.Equal(t, result.ToString(), tt.expected)
				}
			} else {
				uassert.NotEqual(t, result, nil)
				uassert.Equal(t, result.ToString(), tt.expected)
			}
		})
	}
}

// Test GetClaimableRewardAmounts
func TestProtocolFeeRewardManager_GetClaimableRewardAmounts(t *testing.T) {
	tests := []struct {
		name               string
		setupManager       func(*ProtocolFeeRewardManagerResolver)
		protocolFeeAmounts map[string]int64
		address            string
		currentTimestamp   int64
		expectedLength     int
	}{
		{
			name:         "No reward state for address",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			address:          "user1",
			currentTimestamp: 100,
			expectedLength:   0,
		},
		{
			name: "With existing reward state",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				// Add stake to create reward state
				m.addStake("user1", 1000, 50)
				m.SetTotalStakedAmount(1000)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
				"token2": 500,
			},
			address:          "user1",
			currentTimestamp: 100,
			expectedLength:   2,
		},
		{
			name: "Get claimable with past timestamp",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				// Add stake to create reward state
				m.addStake("user1", 1000, 100)
				m.SetTotalStakedAmount(1000)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			address:          "user1",
			currentTimestamp: 50, // past timestamp
			expectedLength:   0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			tt.setupManager(resolver)

			// When: Get claimable reward amounts
			result, _ := resolver.GetClaimableRewardAmounts(
				tt.protocolFeeAmounts,
				tt.address,
				tt.currentTimestamp,
			)

			// Then: Should return expected number of rewards
			uassert.Equal(t, len(result), tt.expectedLength)
		})
	}
}

// Test addStake
func TestProtocolFeeRewardManager_addStake(t *testing.T) {
	tests := []struct {
		name             string
		address          string
		amount           int64
		currentTimestamp int64
		expectedTotal    int64
	}{
		{
			name:             "Add stake for new user",
			address:          "user1",
			amount:           1000,
			currentTimestamp: 100,
			expectedTotal:    1000,
		},
		{
			name:             "Add stake for existing user",
			address:          "user1",
			amount:           500,
			currentTimestamp: 200,
			expectedTotal:    1500,
		},
		{
			name:             "Add stake with negative amount",
			address:          "user1",
			amount:           -200,
			currentTimestamp: 300,
			expectedTotal:    1300, // 1500 - 200
		},
		{
			name:            "Add stake with zero amount",
			address:         "user1",
			amount:          0,
			currentTimestamp: 400,
			expectedTotal:   1300, // No change
		},
	}

	manager := staker.NewProtocolFeeRewardManager()
	resolver := NewProtocolFeeRewardManagerResolver(manager)

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Add stake
			resolver.addStake(tt.address, tt.amount, tt.currentTimestamp)

			// Then: Total staked amount should be updated
			uassert.Equal(t, resolver.GetTotalStakedAmount(), tt.expectedTotal)

			// And: Reward state should be created/updated
			rewardState, ok, err := resolver.GetRewardState(tt.address)
			uassert.NoError(t, err)
			uassert.True(t, ok)
			uassert.NotEqual(t, rewardState, nil)
		})
	}
}

// Test removeStake
func TestProtocolFeeRewardManager_removeStake(t *testing.T) {
	tests := []struct {
		name             string
		initialAmount    int64
		removeAmount     int64
		currentTimestamp int64
		expectedAmount   int64
	}{
		{
			name:             "Remove partial stake",
			initialAmount:    1000,
			removeAmount:     300,
			currentTimestamp: 100,
			expectedAmount:   700,
		},
		{
			name:             "Remove all stake",
			initialAmount:    700,
			removeAmount:     700,
			currentTimestamp: 200,
			expectedAmount:   0,
		},
		{
			name:             "Remove zero stake",
			initialAmount:    500,
			removeAmount:     0,
			currentTimestamp: 300,
			expectedAmount:   500,
		},
		{
			name:             "Remove negative stake (effectively adds)",
			initialAmount:    400,
			removeAmount:     -100,
			currentTimestamp: 400,
			expectedAmount:   500, // 400 - (-100) = 500
		},
		{
			name:             "Remove stake when none exists",
			initialAmount:    0,
			removeAmount:     100,
			currentTimestamp: 500,
			expectedAmount:   -100, // 0 - 100 = -100
		},
		{
			name:             "Remove stake with amount exceeding staked",
			initialAmount:    100,
			removeAmount:     200,
			currentTimestamp: 600,
			expectedAmount:   -100, // 100 - 200 = -100
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Manager with initial stake
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			resolver.addStake("user1", tt.initialAmount, 50)

			// When: Remove stake
			resolver.removeStake("user1", tt.removeAmount, tt.currentTimestamp)

			// Then: Total staked amount should be updated
			uassert.Equal(t, resolver.GetTotalStakedAmount(), tt.expectedAmount)
		})
	}
}

// Test claimRewards
func TestProtocolFeeRewardManager_claimRewards(t *testing.T) {
	tests := []struct {
		name             string
		setupManager     func(*ProtocolFeeRewardManagerResolver)
		address          string
		currentTimestamp int64
		expectError      bool
	}{
		{
			name:             "Claim rewards for non-existent user",
			setupManager:     func(m *ProtocolFeeRewardManagerResolver) {},
			address:          "user1",
			currentTimestamp: 100,
			expectError:      false,
		},
		{
			name: "Claim rewards for existing user",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.addStake("user1", 1000, 50)
				// Simulate some protocol fees
				accumulatedMap := make(map[string]*u256.Uint)
				accumulatedMap["token1"] = u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128)
				m.SetAccumulatedProtocolFeeX128PerStake(accumulatedMap)
			},
			address:          "user1",
			currentTimestamp: 100,
			expectError:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			tt.setupManager(resolver)

			// When: Claim rewards
			rewards, err := resolver.claimRewards(tt.address, tt.currentTimestamp)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
				uassert.Equal(t, rewards, nil)
			} else {
				uassert.NoError(t, err)
				uassert.NotEqual(t, rewards, nil)
			}
		})
	}
}

func TestProtocolFeeRewardManager_claimRewards_Multipletimes(t *testing.T) {
	t.Run("Claim rewards multiple times", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 1000, 10)
		protocolFeeAmounts := map[string]int64{
			"token1": 1000,
		}
		resolver.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 20)

		// when - claim rewards multiple times
		claimed1, err1 := resolver.claimRewards("user1", 30)
		uassert.NoError(t, err1)

		claimed2, err2 := resolver.claimRewards("user1", 40)
		uassert.NoError(t, err2)

		// then - second claim should return zero amounts (no new rewards)
		uassert.NotEqual(t, claimed1, nil)
		uassert.NotEqual(t, claimed2, nil)
		// All amounts in second claim should be zero
		for _, amount := range claimed2 {
			uassert.Equal(t, amount, int64(0))
		}
	})
}

// Test calculateAccumulatedRewardX128PerStake
func TestProtocolFeeRewardManager_calculateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name                string
		setupManager        func(*ProtocolFeeRewardManagerResolver)
		protocolFeeAmounts  map[string]int64
		currentTimestamp    int64
		shouldIncrease      bool
		expectedResultLen   int // -1 means don't check
		expectedChangedLen  int // -1 means don't check
	}{
		{
			name: "Current timestamp less than accumulated timestamp",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(200)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 100,
			shouldIncrease:   false,
			expectedResultLen:  -1,
			expectedChangedLen: -1,
		},
		{
			name: "Normal calculation with positive protocol fee delta",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(1000)
				protocolFeeMap := make(map[string]int64)
				protocolFeeMap["token1"] = 500
				m.SetProtocolFeeAmounts(protocolFeeMap)
				accumulatedMap := make(map[string]*u256.Uint)
				accumulatedMap["token1"] = u256.NewUint(0)
				m.SetAccumulatedProtocolFeeX128PerStake(accumulatedMap)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000, // Increase from 500 to 1000
			},
			currentTimestamp: 100,
			shouldIncrease:   true,
			expectedResultLen:  -1,
			expectedChangedLen: -1,
		},
		{
			name: "No increase when protocol fee delta is zero",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(1000)
				protocolFeeMap := make(map[string]int64)
				protocolFeeMap["token1"] = 1000
				m.SetProtocolFeeAmounts(protocolFeeMap)
				accumulatedMap := make(map[string]*u256.Uint)
				accumulatedMap["token1"] = u256.NewUint(500)
				m.SetAccumulatedProtocolFeeX128PerStake(accumulatedMap)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000, // No change
			},
			currentTimestamp: 100,
			shouldIncrease:   false,
			expectedResultLen:  -1,
			expectedChangedLen: -1,
		},
		{
			name: "No increase when no staked amount",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(0)
				protocolFeeMap := make(map[string]int64)
				protocolFeeMap["token1"] = 500
				m.SetProtocolFeeAmounts(protocolFeeMap)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 100,
			shouldIncrease:   false,
			expectedResultLen:  -1,
			expectedChangedLen: -1,
		},
		{
			name: "Calculate with max int64 protocol fee",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetTotalStakedAmount(1)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": int64(9223372036854775807),
			},
			currentTimestamp:   100,
			shouldIncrease:     true,
			expectedResultLen:  1,
			expectedChangedLen: -1,
		},
		{
			name: "Calculate with empty protocol fee amounts map",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.addStake("user1", 1000, 10)
			},
			protocolFeeAmounts: map[string]int64{},
			currentTimestamp:   20,
			shouldIncrease:     false,
			expectedResultLen:  0,
			expectedChangedLen: 0,
		},
		{
			name: "Multiple tokens with mixed positive and zero deltas",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetTotalStakedAmount(1000)
				initialFees := map[string]int64{
					"token1": 100,
					"token2": 200,
				}
				m.SetProtocolFeeAmounts(initialFees)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 150, // positive delta
				"token2": 200, // zero delta
				"token3": 50,  // new token
			},
			currentTimestamp:   100,
			shouldIncrease:     true,
			expectedResultLen:  3,
			expectedChangedLen: -1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			if tt.setupManager != nil {
				tt.setupManager(resolver)
			}

			initialRewards := make(map[string]*u256.Uint)
			for token, reward := range resolver.GetAllAccumulatedProtocolFeeX128PerStake() {
				initialRewards[token] = reward.Clone()
			}

			// When: Calculate accumulated reward X128 per stake
			result, changedAmounts, err := resolver.calculateAccumulatedRewardX128PerStake(
				tt.protocolFeeAmounts,
				tt.currentTimestamp,
			)

			uassert.NoError(t, err)

			// Optional: check returned maps length expectations
			if tt.expectedResultLen != -1 {
				uassert.Equal(t, len(result), tt.expectedResultLen)
			}
			if tt.expectedChangedLen != -1 {
				uassert.Equal(t, len(changedAmounts), tt.expectedChangedLen)
			}

			// Then: Check if result increased as expected for provided tokens
			for token := range tt.protocolFeeAmounts {
				resultReward, ok := result[token]
				if !ok {
					resultReward = u256.NewUint(0)
				}

				initialReward, _ := initialRewards[token]

				if tt.shouldIncrease {
					if initialReward != nil {
						uassert.True(t, resultReward.Gt(initialReward))
					} else {
						uassert.True(t, resultReward.Gt(u256.NewUint(0)))
					}
				} else {
					if initialReward != nil {
						uassert.Equal(t, resultReward.Cmp(initialReward), 0)
					} else {
						uassert.Equal(t, resultReward.ToString(), "0")
					}
				}
			}
		})
	}
}

// Test updateAccumulatedProtocolFeeX128PerStake
func TestProtocolFeeRewardManager_updateAccumulatedProtocolFeeX128PerStake(t *testing.T) {
	tests := []struct {
		name               string
		setupManager       func(*ProtocolFeeRewardManagerResolver)
		protocolFeeAmounts map[string]int64
		currentTimestamp   int64
		shouldUpdate       bool
	}{
		{
			name: "Should not update when current timestamp is less",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(200)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "Should not update when current timestamp equals accumulated timestamp",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(100)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "Should update when current timestamp is greater",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(1000)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 100,
			shouldUpdate:     true,
		},
		{
			name: "Update with past timestamp preserves state",
			setupManager: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetAccumulatedTimestamp(100)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentTimestamp: 50, // past timestamp
			shouldUpdate:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			tt.setupManager(resolver)
			initialTimestamp := resolver.GetAccumulatedTimestamp()

			// When: Update accumulated protocol fee X128 per stake
			resolver.updateAccumulatedProtocolFeeX128PerStake(
				tt.protocolFeeAmounts,
				tt.currentTimestamp,
			)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentTimestamp)
			} else {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), initialTimestamp)
			}
		})
	}
}

func TestProtocolFeeRewardManager_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		setupTest   func(*ProtocolFeeRewardManagerResolver)
		description string
	}{
		{
			name: "Multiple tokens with different fee amounts",
			setupTest: func(m *ProtocolFeeRewardManagerResolver) {
				// Setup multiple tokens
				m.SetTotalStakedAmount(1000)
				m.SetAccumulatedTimestamp(50)

				// Add stake for a user
				m.addStake("user1", 1000, 50)

				// Simulate protocol fees for multiple tokens
				protocolFeeAmounts := map[string]int64{
					"token1": 1000,
					"token2": 500,
					"token3": 750,
				}

				err := m.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 100)
				uassert.NoError(t, err)

				// Verify claimable amounts
				claimableAmounts, _ := m.GetClaimableRewardAmounts(protocolFeeAmounts, "user1", 100)

				uassert.Equal(t, len(claimableAmounts), 3)
				for token, amount := range claimableAmounts {
					uassert.True(t, amount >= 0, "Amount should be non-negative for token: "+token)
				}
			},
			description: "Should handle multiple tokens correctly",
		},
		{
			name: "Zero protocol fee amounts",
			setupTest: func(m *ProtocolFeeRewardManagerResolver) {
				m.addStake("user1", 1000, 50)

				protocolFeeAmounts := map[string]int64{
					"token1": 0,
				}

				claimableAmounts, _ := m.GetClaimableRewardAmounts(protocolFeeAmounts, "user1", 100)
				uassert.Equal(t, claimableAmounts["token1"], int64(0))
			},
			description: "Should handle zero protocol fee amounts",
		},
		{
			name: "Negative protocol fee delta",
			setupTest: func(m *ProtocolFeeRewardManagerResolver) {
				m.SetTotalStakedAmount(1000)
				protocolFeeMap := make(map[string]int64)
				protocolFeeMap["token1"] = 1000
				m.SetProtocolFeeAmounts(protocolFeeMap)
				accumulatedMap := make(map[string]*u256.Uint)
				accumulatedMap["token1"] = u256.NewUintFromInt64(500)
				m.SetAccumulatedProtocolFeeX128PerStake(accumulatedMap)

				// Try with smaller amount (negative delta)
				protocolFeeAmounts := map[string]int64{
					"token1": 500, // Less than stored amount
				}

				uassert.PanicsWithMessage(t, "val is negative", func() {
					m.calculateAccumulatedRewardX128PerStake(protocolFeeAmounts, 100)
				})
			},
			description: "Should handle negative protocol fee delta",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh protocol fee reward manager
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)

			// When: Execute test setup
			tt.setupTest(resolver)

			// Then: Test should complete without panicking
			// Additional assertions are done within setupTest
		})
	}
}
