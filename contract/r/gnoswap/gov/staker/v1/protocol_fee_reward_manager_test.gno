package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gov/staker"
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
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)

			// Then: Should initialize with empty values
			uassert.NotEqual(t, resolver, nil)
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, len(resolver.GetAllAccumulatedProtocolFeeX128PerStake()), 0)
			uassert.Equal(t, len(resolver.GetProtocolFeeAmounts()), 0)
		})
	}
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

// Test calculateAccumulatedRewardX128PerStake
func TestProtocolFeeRewardManager_calculateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name               string
		setupManager       func(*ProtocolFeeRewardManagerResolver)
		protocolFeeAmounts map[string]int64
		currentTimestamp   int64
		shouldIncrease     bool
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
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward manager setup
			manager := staker.NewProtocolFeeRewardManager()
			resolver := NewProtocolFeeRewardManagerResolver(manager)
			tt.setupManager(resolver)

			initialRewards := make(map[string]*u256.Uint)
			for token, reward := range resolver.GetAllAccumulatedProtocolFeeX128PerStake() {
				initialRewards[token] = reward.Clone()
			}

			// When: Calculate accumulated reward X128 per stake
			result, _, _ := resolver.calculateAccumulatedRewardX128PerStake(
				tt.protocolFeeAmounts,
				tt.currentTimestamp,
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

// TestProtocolFeeRewardManager_ErrorCases tests error and boundary conditions
func TestProtocolFeeRewardManager_ErrorCases(t *testing.T) {
	t.Run("addStake with negative amount", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// when - add stake with negative amount
		err := resolver.addStake("user1", -100, 10)

		// then - should succeed (no validation in addStake)
		uassert.NoError(t, err)
		// Total stake becomes negative (implementation allows this)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(-100))
	})

	t.Run("addStake with zero amount", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// when - add zero stake
		err := resolver.addStake("user1", 0, 10)

		// then - should succeed (no-op)
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))
	})

	t.Run("removeStake with amount exceeding staked", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 100, 10)

		// when - remove more than staked
		err := resolver.removeStake("user1", 200, 20)

		// then - should succeed
		uassert.NoError(t, err)
		// Implementation allows negative total
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(-100))
	})

	t.Run("removeStake with negative amount", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 100, 10)

		// when - remove negative amount (effectively adds)
		err := resolver.removeStake("user1", -50, 20)

		// then - should succeed
		uassert.NoError(t, err)
		// Removing negative adds to total: 100 - (-50) = 150
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(150))
	})

	t.Run("calculateAccumulatedRewardX128PerStake with max int64", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.SetTotalStakedAmount(1)

		// when - distribute max int64
		maxInt64 := int64(9223372036854775807)
		protocolFeeAmounts := map[string]int64{
			"token1": maxInt64,
		}
		accumulatedReward, _, err := resolver.calculateAccumulatedRewardX128PerStake(
			protocolFeeAmounts,
			100,
		)

		// then - should calculate without overflow
		uassert.NoError(t, err)
		uassert.NotEqual(t, accumulatedReward["token1"].ToString(), "0")
	})

	t.Run("updateAccumulatedProtocolFeeX128PerStake with past timestamp", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.SetAccumulatedTimestamp(100)
		initialAccumulated := resolver.GetAllAccumulatedProtocolFeeX128PerStake()

		// when - update with past timestamp (out of order)
		protocolFeeAmounts := map[string]int64{
			"token1": 1000,
		}
		err := resolver.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 50)

		// then - should not update (returns early)
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(100))
		uassert.Equal(t, len(resolver.GetAllAccumulatedProtocolFeeX128PerStake()), len(initialAccumulated))
	})

	t.Run("GetClaimableRewardAmounts with past timestamp", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 1000, 100)
		protocolFeeAmounts := map[string]int64{
			"token1": 1000,
		}
		resolver.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 100)

		// when - get claimable with past timestamp
		claimable, err := resolver.GetClaimableRewardAmounts(
			protocolFeeAmounts,
			"user1",
			50, // past timestamp
		)

		// then - should use current accumulated state
		uassert.NoError(t, err)
		uassert.NotEqual(t, claimable, nil)
	})

	t.Run("claimRewards multiple times", func(t *testing.T) {
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

	t.Run("addStake with large amount values", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// when - add very large stake
		largeAmount := int64(1000000000000) // 1 trillion
		err := resolver.addStake("user1", largeAmount, 10)

		// then - should succeed
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), largeAmount)
	})

	t.Run("distribution with single wei precision for multiple tokens", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 1000000, 10)

		// when - distribute very small amounts (1 wei) across multiple tokens
		protocolFeeAmounts := map[string]int64{
			"token1": 1,
			"token2": 1,
			"token3": 1,
		}
		resolver.updateAccumulatedProtocolFeeX128PerStake(protocolFeeAmounts, 20)

		// then - should calculate without losing precision
		claimable, err := resolver.GetClaimableRewardAmounts(protocolFeeAmounts, "user1", 30)
		uassert.NoError(t, err)
		uassert.Equal(t, len(claimable), 3)
	})

	t.Run("empty protocol fee amounts map", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.addStake("user1", 1000, 10)

		// when - calculate with empty map
		emptyMap := make(map[string]int64)
		accumulatedReward, changedAmounts, err := resolver.calculateAccumulatedRewardX128PerStake(
			emptyMap,
			20,
		)

		// then - should return empty maps
		uassert.NoError(t, err)
		uassert.Equal(t, len(accumulatedReward), 0)
		uassert.Equal(t, len(changedAmounts), 0)
	})

	t.Run("removeStake for non-existent user", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)

		// when - remove stake for user that never staked
		err := resolver.removeStake("user1", 100, 10)

		// then - should succeed (creates new state)
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(-100))
	})

	t.Run("multiple tokens with mixed positive and zero deltas", func(t *testing.T) {
		// given
		manager := staker.NewProtocolFeeRewardManager()
		resolver := NewProtocolFeeRewardManagerResolver(manager)
		resolver.SetTotalStakedAmount(1000)

		// Setup initial fees
		initialFees := map[string]int64{
			"token1": 100,
			"token2": 200,
		}
		resolver.SetProtocolFeeAmounts(initialFees)

		// when - update with mixed deltas
		newFees := map[string]int64{
			"token1": 150, // positive delta
			"token2": 200, // zero delta
			"token3": 50,  // new token
		}
		accumulatedReward, _, err := resolver.calculateAccumulatedRewardX128PerStake(newFees, 100)

		// then - should handle all cases correctly
		uassert.NoError(t, err)
		uassert.Equal(t, len(accumulatedReward), 3)
		// token1 should have increased
		uassert.NotEqual(t, accumulatedReward["token1"].ToString(), "0")
	})
}
