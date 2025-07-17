package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// Test ProtocolFeeRewardManager creation
func TestNewProtocolFeeRewardManager(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Create new protocol fee reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new protocol fee reward manager
			manager := NewProtocolFeeRewardManager()

			// Then: Should initialize with empty values
			uassert.NotEqual(t, manager, nil)
			uassert.Equal(t, manager.GetAccumulatedHeight(), int64(0))
			uassert.Equal(t, len(manager.accumulatedProtocolFeeX128PerStake), 0)
			uassert.Equal(t, len(manager.protocolFeeAmounts), 0)
		})
	}
}

// Test GetAccumulatedProtocolFeeX128PerStake
func TestProtocolFeeRewardManager_GetAccumulatedProtocolFeeX128PerStake(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(*ProtocolFeeRewardManager)
		token    string
		expected string
	}{
		{
			name:     "Get non-existent token",
			setup:    func(m *ProtocolFeeRewardManager) {},
			token:    "token1",
			expected: "0",
		},
		{
			name: "Get existing token",
			setup: func(m *ProtocolFeeRewardManager) {
				m.accumulatedProtocolFeeX128PerStake["token1"] = u256.NewUintFromInt64(1000)
			},
			token:    "token1",
			expected: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager
			manager := NewProtocolFeeRewardManager()
			tt.setup(manager)

			// When: Get accumulated protocol fee X128 per stake
			result := manager.GetAccumulatedProtocolFeeX128PerStake(tt.token)

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
		setupManager       func(*ProtocolFeeRewardManager)
		protocolFeeAmounts map[string]int64
		address            string
		currentHeight      int64
		expectedLength     int
	}{
		{
			name:         "No reward state for address",
			setupManager: func(m *ProtocolFeeRewardManager) {},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			address:        "user1",
			currentHeight:  100,
			expectedLength: 0,
		},
		{
			name: "With existing reward state",
			setupManager: func(m *ProtocolFeeRewardManager) {
				// Add stake to create reward state
				m.addStake("user1", 1000, 50)
				m.totalStakedAmount = 1000
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
				"token2": 500,
			},
			address:        "user1",
			currentHeight:  100,
			expectedLength: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := NewProtocolFeeRewardManager()
			tt.setupManager(manager)

			// When: Get claimable reward amounts
			result := manager.GetClaimableRewardAmounts(
				tt.protocolFeeAmounts,
				tt.address,
				tt.currentHeight,
			)

			// Then: Should return expected number of rewards
			uassert.Equal(t, len(result), tt.expectedLength)
		})
	}
}

// Test addStake
func TestProtocolFeeRewardManager_addStake(t *testing.T) {
	tests := []struct {
		name          string
		address       string
		amount        int64
		currentHeight int64
		expectedTotal int64
	}{
		{
			name:          "Add stake for new user",
			address:       "user1",
			amount:        1000,
			currentHeight: 100,
			expectedTotal: 1000,
		},
		{
			name:          "Add stake for existing user",
			address:       "user1",
			amount:        500,
			currentHeight: 200,
			expectedTotal: 1500,
		},
	}

	manager := NewProtocolFeeRewardManager()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Add stake
			manager.addStake(tt.address, tt.amount, tt.currentHeight)

			// Then: Total staked amount should be updated
			uassert.Equal(t, manager.totalStakedAmount, tt.expectedTotal)

			// And: Reward state should be created/updated
			rewardStateI, ok := manager.rewardStates.Get(tt.address)
			uassert.True(t, ok)
			uassert.NotEqual(t, rewardStateI, nil)
		})
	}
}

// Test removeStake
func TestProtocolFeeRewardManager_removeStake(t *testing.T) {
	tests := []struct {
		name           string
		initialAmount  int64
		removeAmount   int64
		currentHeight  int64
		expectedAmount int64
	}{
		{
			name:           "Remove partial stake",
			initialAmount:  1000,
			removeAmount:   300,
			currentHeight:  100,
			expectedAmount: 700,
		},
		{
			name:           "Remove all stake",
			initialAmount:  700,
			removeAmount:   700,
			currentHeight:  200,
			expectedAmount: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Manager with initial stake
			manager := NewProtocolFeeRewardManager()
			manager.addStake("user1", tt.initialAmount, 50)

			// When: Remove stake
			manager.removeStake("user1", tt.removeAmount, tt.currentHeight)

			// Then: Total staked amount should be updated
			uassert.Equal(t, manager.totalStakedAmount, tt.expectedAmount)
		})
	}
}

// Test claimRewards
func TestProtocolFeeRewardManager_claimRewards(t *testing.T) {
	tests := []struct {
		name          string
		setupManager  func(*ProtocolFeeRewardManager)
		address       string
		currentHeight int64
		expectError   bool
	}{
		{
			name:         "Claim rewards for non-existent user",
			setupManager: func(m *ProtocolFeeRewardManager) {},
			address:      "user1",
			currentHeight: 100,
			expectError:  false,
		},
		{
			name: "Claim rewards for existing user",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.addStake("user1", 1000, 50)
				// Simulate some protocol fees
				m.accumulatedProtocolFeeX128PerStake["token1"] = u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128)
			},
			address:       "user1",
			currentHeight: 100,
			expectError:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := NewProtocolFeeRewardManager()
			tt.setupManager(manager)

			// When: Claim rewards
			rewards, err := manager.claimRewards(tt.address, tt.currentHeight)

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

// Test calculateAccumulatedRewardX128PerStake
func TestProtocolFeeRewardManager_calculateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name               string
		setupManager       func(*ProtocolFeeRewardManager)
		protocolFeeAmounts map[string]int64
		currentHeight      int64
		shouldIncrease     bool
	}{
		{
			name: "Current height less than accumulated height",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 200
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentHeight:  100,
			shouldIncrease: false,
		},
		{
			name: "Normal calculation with positive protocol fee delta",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 50
				m.totalStakedAmount = 1000
				m.protocolFeeAmounts["token1"] = 500
				m.accumulatedProtocolFeeX128PerStake["token1"] = u256.NewUint(0)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000, // Increase from 500 to 1000
			},
			currentHeight:  100,
			shouldIncrease: true,
		},
		{
			name: "No increase when protocol fee delta is zero",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 50
				m.totalStakedAmount = 1000
				m.protocolFeeAmounts["token1"] = 1000
				m.accumulatedProtocolFeeX128PerStake["token1"] = u256.NewUint(500)
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000, // No change
			},
			currentHeight:  100,
			shouldIncrease: false,
		},
		{
			name: "No increase when no staked amount",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 50
				m.totalStakedAmount = 0
				m.protocolFeeAmounts["token1"] = 500
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentHeight:  100,
			shouldIncrease: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := NewProtocolFeeRewardManager()
			tt.setupManager(manager)
			
			initialRewards := make(map[string]*u256.Uint)
			for token, reward := range manager.accumulatedProtocolFeeX128PerStake {
				initialRewards[token] = reward.Clone()
			}

			// When: Calculate accumulated reward X128 per stake
			result, _ := manager.calculateAccumulatedRewardX128PerStake(
				tt.protocolFeeAmounts,
				tt.currentHeight,
			)

			// Then: Check if result increased as expected
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
		setupManager       func(*ProtocolFeeRewardManager)
		protocolFeeAmounts map[string]int64
		currentHeight      int64
		shouldUpdate       bool
	}{
		{
			name: "Should not update when current height is less",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 200
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentHeight: 100,
			shouldUpdate:  false,
		},
		{
			name: "Should not update when current height equals accumulated height",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 100
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentHeight: 100,
			shouldUpdate:  false,
		},
		{
			name: "Should update when current height is greater",
			setupManager: func(m *ProtocolFeeRewardManager) {
				m.accumulatedHeight = 50
				m.totalStakedAmount = 1000
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 1000,
			},
			currentHeight: 100,
			shouldUpdate:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := NewProtocolFeeRewardManager()
			tt.setupManager(manager)
			initialHeight := manager.accumulatedHeight

			// When: Update accumulated protocol fee X128 per stake
			manager.updateAccumulatedProtocolFeeX128PerStake(
				tt.protocolFeeAmounts,
				tt.currentHeight,
			)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, manager.accumulatedHeight, tt.currentHeight)
			} else {
				uassert.Equal(t, manager.accumulatedHeight, initialHeight)
			}
		})
	}
}

// Test edge cases and complex scenarios
func TestProtocolFeeRewardManager_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		setupTest   func(*ProtocolFeeRewardManager)
		description string
	}{
		{
			name: "Multiple tokens with different fee amounts",
			setupTest: func(m *ProtocolFeeRewardManager) {
				// Setup multiple tokens
				m.totalStakedAmount = 1000
				m.accumulatedHeight = 50
				
				// Add stake for a user
				m.addStake("user1", 1000, 50)
				
				// Simulate protocol fees for multiple tokens
				protocolFeeAmounts := map[string]int64{
					"token1": 1000,
					"token2": 500,
					"token3": 750,
				}
				
				m.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 100)
				
				// Verify claimable amounts
				claimableAmounts := m.GetClaimableRewardAmounts(protocolFeeAmounts, "user1", 100)
				
				uassert.Equal(t, len(claimableAmounts), 3)
				for token, amount := range claimableAmounts {
					uassert.True(t, amount >= 0, "Amount should be non-negative for token: "+token)
				}
			},
			description: "Should handle multiple tokens correctly",
		},
		{
			name: "Zero protocol fee amounts",
			setupTest: func(m *ProtocolFeeRewardManager) {
				m.addStake("user1", 1000, 50)
				
				protocolFeeAmounts := map[string]int64{
					"token1": 0,
				}
				
				claimableAmounts := m.GetClaimableRewardAmounts(protocolFeeAmounts, "user1", 100)
				uassert.Equal(t, claimableAmounts["token1"], int64(0))
			},
			description: "Should handle zero protocol fee amounts",
		},
		{
			name: "Negative protocol fee delta",
			setupTest: func(m *ProtocolFeeRewardManager) {
				m.totalStakedAmount = 1000
				m.protocolFeeAmounts["token1"] = 1000
				m.accumulatedProtocolFeeX128PerStake["token1"] = u256.NewUintFromInt64(500)
				
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
			manager := NewProtocolFeeRewardManager()

			// When: Execute test setup
			tt.setupTest(manager)

			// Then: Test should complete without panicking
			// Additional assertions are done within setupTest
		})
	}
} 