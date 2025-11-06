package v1

import (
    "math"
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/gov/staker"
)

// Test EmissionRewardManager creation
func TestNewEmissionRewardManager(t *testing.T) {
	tests := []struct {
		name string
	}{
		{
			name: "Create new emission reward manager",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new emission reward manager
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)

			// Then: Should initialize with zero values
			uassert.NotEqual(t, resolver, nil)
			uassert.Equal(t, resolver.GetAccumulatedRewardX128PerStake().ToString(), "0")
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))
			uassert.Equal(t, resolver.GetDistributedAmount(), int64(0))
		})
	}
}

// Test GetAccumulatedRewardX128PerStake
func TestEmissionRewardManager_GetAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(*EmissionRewardManagerResolver)
		expected string
	}{
		{
			name:     "Initial accumulated reward should be zero",
			setup:    func(m *EmissionRewardManagerResolver) {},
			expected: "0",
		},
		{
			name: "After setting accumulated reward",
			setup: func(m *EmissionRewardManagerResolver) {
				m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(1000))
			},
			expected: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)
			tt.setup(resolver)

			// When: Get accumulated reward X128 per stake
			result := resolver.GetAccumulatedRewardX128PerStake()

			// Then: Should return expected value
			uassert.Equal(t, result.ToString(), tt.expected)
		})
	}
}

// Test GetClaimableRewardAmount
func TestEmissionRewardManager_GetClaimableRewardAmount(t *testing.T) {
	tests := []struct {
		name                     string
		setupManager             func(*EmissionRewardManagerResolver)
		currentDistributedAmount int64
		address                  string
		currentHeight            int64
		expected                 int64
	}{
		{
			name:                     "No reward state for address",
			setupManager:             func(m *EmissionRewardManagerResolver) {},
			currentDistributedAmount: 1000,
			address:                  "user1",
			currentHeight:            100,
			expected:                 0,
		},
		{
			name: "With existing reward state",
			setupManager: func(m *EmissionRewardManagerResolver) {
				// Add stake to create reward state
				m.addStake("user1", 1000, 50)
				m.SetTotalStakedAmount(1000)
			},
			currentDistributedAmount: 1000,
			address:                  "user1",
			currentHeight:            100,
			expected:                 1000, // Full distributed amount for single staker
		},
		{
		    name: "Get claimable with past timestamp",
            setupManager: func(m *EmissionRewardManagerResolver) {
                m.addStake("user1", 1000, 100)
                m.updateAccumulatedRewardX128PerStake(1000, 100)
            },
            currentDistributedAmount: 2000,
            address:                  "user1",
            currentHeight:            50, // past timestamp
            expected:                 0,  // Should return 0 as no rewards accrued before stake time
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)
			tt.setupManager(resolver)

			// When: Get claimable reward amount
			result, _ := resolver.GetClaimableRewardAmount(
				tt.currentDistributedAmount,
				tt.address,
				tt.currentHeight,
			)

			// Then: Should return expected amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test addStake
func TestEmissionRewardManager_addStake(t *testing.T) {
	tests := []struct {
		name             string
		address          string
		amount           int64
		currentHeight    int64
		expectedTotal    int64
		expectedHasError bool
	}{
		{
			name:             "Add stake for new user",
			address:          "user1",
			amount:           1000,
			currentHeight:    100,
			expectedTotal:    1000,
			expectedHasError: false,
		},
		{
			name:             "Add stake with negative amount",
			address:          "user1",
			amount:           -200,
			currentHeight:    300,
			expectedTotal:    0, // Should not change when error occurs
			expectedHasError: true,
		},
		{
			name:             "Add stake with zero amount",
			address:          "user1",
			amount:           0,
			currentHeight:    400,
			expectedTotal:    0,
			expectedHasError: false,
		},
		{
			name:             "Add stake causing overflow",
			address:          "user1",
			amount:           1,
			currentHeight:    500,
			expectedTotal:    0,
			expectedHasError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: New emission reward manager for each test
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)

			// Special setup for overflow test
			if tt.name == "Add stake causing overflow" {
				// Set total to MaxInt64
				resolver.SetTotalStakedAmount(math.MaxInt64)
			}

			// When: Add stake
			err := resolver.addStake(tt.address, tt.amount, tt.currentHeight)

			// Then: Check error expectation
			if tt.expectedHasError {
				uassert.Error(t, err)
				return
			}

			// And: Total staked amount should be updated
			uassert.NoError(t, err)
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
func TestEmissionRewardManager_removeStake(t *testing.T) {
	tests := []struct {
		name             string
		initialAmount    int64
		removeAmount     int64
		currentHeight    int64
		expectedAmount   int64
		expectedHasError bool
	}{
		{
			name:             "Remove partial stake",
			initialAmount:    1000,
			removeAmount:     300,
			currentHeight:    100,
			expectedAmount:   700,
			expectedHasError: false,
		},
		{
			name:             "Remove all stake",
			initialAmount:    700,
			removeAmount:     700,
			currentHeight:    200,
			expectedAmount:   0,
			expectedHasError: false,
		},
		{
			name:             "Remove zero stake",
			initialAmount:    500,
			removeAmount:     0,
			currentHeight:    300,
			expectedAmount:   500,
			expectedHasError: false,
		},
		{
			name:             "Remove negative stake (should not allow)",
			initialAmount:    400,
			removeAmount:     -100,
			currentHeight:    400,
			expectedAmount:   400, // Should not change when error occurs
			expectedHasError: true,
		},
		{
			name:             "Remove excessive stake (clamps to zero)",
			initialAmount:    200,
			removeAmount:     300,
			currentHeight:    500,
			expectedAmount:   0, // Clamped to zero
			expectedHasError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Manager with initial stake
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)
			if tt.initialAmount > 0 {
				resolver.addStake("user1", tt.initialAmount, 50)
			}

			// When: Remove stake
			err := resolver.removeStake("user1", tt.removeAmount, tt.currentHeight)

			// Then: Check error expectation
			if tt.expectedHasError {
				uassert.Error(t, err)
				uassert.Equal(t, resolver.GetTotalStakedAmount(), tt.expectedAmount)
				return
			}

			// And: Total staked amount should be updated
			uassert.NoError(t, err)
			uassert.Equal(t, resolver.GetTotalStakedAmount(), tt.expectedAmount)
		})
	}
}

// Test claimRewards
func TestEmissionRewardManager_claimRewards(t *testing.T) {
	tests := []struct {
		name           string
		setupManager   func(*EmissionRewardManagerResolver)
		address        string
		currentHeight  int64
		expectError    bool
		expectedReward int64
	}{
		{
			name:           "Claim rewards for non-existent user",
			setupManager:   func(m *EmissionRewardManagerResolver) {},
			address:        "user1",
			currentHeight:  100,
			expectedReward: 0,
			expectError:    false,
		},
		{
			name: "Claim rewards for existing user",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.addStake("user1", 1000, 50)
				m.updateAccumulatedRewardX128PerStake(1000, 50)
			},
			address:        "user1",
			currentHeight:  100,
			expectError:    false,
			expectedReward: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)
			tt.setupManager(resolver)

			// When: Claim rewards
			println("=== Before claiming rewards ===")
			claimableReward, _ := resolver.GetClaimableRewardAmount(resolver.GetDistributedAmount(), tt.address, tt.currentHeight)
			println("Claimable reward amount:", claimableReward)

			reward, err := resolver.claimRewards(tt.address, tt.currentHeight)
			println("Actual claimed reward:", reward)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, reward, tt.expectedReward)
			}
		})
	}

}

func TestEmissionRewardManager_claimRewards_MultipleTimes(t *testing.T) {
    t.Run("Claim rewards multiple times", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)
		resolver.addStake("user1", 1000, 10)
		resolver.updateAccumulatedRewardX128PerStake(1000, 20)

		// when - claim rewards multiple times
		claimed1, err1 := resolver.claimRewards("user1", 30)
		uassert.NoError(t, err1)

		claimed2, err2 := resolver.claimRewards("user1", 40)
		uassert.NoError(t, err2)

		// then - second claim should return zero (no new rewards)
		uassert.True(t, claimed1 > 0)
		uassert.Equal(t, claimed2, int64(0))
	})
}

// Test calculateAccumulatedRewardX128PerStake
func TestEmissionRewardManager_calculateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name                     string
		setupManager             func(*EmissionRewardManagerResolver)
		currentDistributedAmount int64
		currentHeight            int64
		shouldIncrease           bool
	}{
		{
			name: "Current height less than accumulated height",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetAccumulatedTimestamp(200)
				m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(1000))
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           false,
		},
		{
			name: "No staked amount",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetTotalStakedAmount(0)
				m.SetAccumulatedTimestamp(50)
				m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(500))
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           false,
		},
		{
			name: "Normal reward calculation",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetTotalStakedAmount(1000)
				m.SetDistributedAmount(500)
				m.SetAccumulatedTimestamp(50)
				m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(0))
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           true,
		},
		{
		    name: "Calculate with negative distributed amount",
			setupManager: func(m *EmissionRewardManagerResolver) {
                m.SetTotalStakedAmount(1000)
                m.SetDistributedAmount(1500)
                m.SetAccumulatedTimestamp(50)
                m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(0))
            },
            currentDistributedAmount: 1000, // less than previous
            currentHeight:            100,
            shouldIncrease:           false, // should not increase
		},
		{
		    name: "Calculate with max int64",
			setupManager: func(m *EmissionRewardManagerResolver) {
                m.SetTotalStakedAmount(1)
                m.SetDistributedAmount(0)
                m.SetAccumulatedTimestamp(50)
                m.SetAccumulatedRewardX128PerStake(u256.NewUintFromInt64(0))
            },
            currentDistributedAmount: int64(9223372036854775807), // Max int64
            currentHeight:            100,
            shouldIncrease:           true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)
			tt.setupManager(resolver)

			// Capture initial reward state after setup
			initialReward := u256.NewUintFromInt64(0)
			if resolver.GetAccumulatedRewardX128PerStake() != nil {
				initialReward = resolver.GetAccumulatedRewardX128PerStake().Clone()
			}

			// When: Calculate accumulated reward X128 per stake
			result, _ := resolver.calculateAccumulatedRewardX128PerStake(
				tt.currentDistributedAmount,
				tt.currentHeight,
			)

			// Then: Check if result increased as expected
			if tt.shouldIncrease {
				uassert.True(t, result.Gt(initialReward))
			} else {
				uassert.Equal(t, result.Cmp(initialReward), 0)
			}
		})
	}
}

// Test updateAccumulatedRewardX128PerStake
func TestEmissionRewardManager_updateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name                     string
		setupManager             func(*EmissionRewardManagerResolver)
		currentDistributedAmount int64
		currentHeight            int64
		shouldUpdate             bool
	}{
		{
			name: "Should not update when current height is less",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetAccumulatedTimestamp(200)
				m.SetDistributedAmount(500)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             false,
		},
		{
			name: "Should not update when no staked amount",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(0)
				m.SetDistributedAmount(500)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             false,
		},
		{
			name: "Should update normally",
			setupManager: func(m *EmissionRewardManagerResolver) {
				m.SetAccumulatedTimestamp(50)
				m.SetTotalStakedAmount(1000)
				m.SetDistributedAmount(500)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             true,
		},
		{
		    name: "Update with past timestamp",
	        setupManager: func(m *EmissionRewardManagerResolver) {
                m.SetAccumulatedTimestamp(100)
                m.SetDistributedAmount(0)
            },
            currentDistributedAmount: 1000,
            currentHeight:            50, // past timestamp
            shouldUpdate:             false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := staker.NewEmissionRewardManager()
			resolver := NewEmissionRewardManagerResolver(manager)

			tt.setupManager(resolver)
			initialHeight := resolver.GetAccumulatedTimestamp()
			initialDistributed := resolver.GetDistributedAmount()

			// When: Update accumulated reward X128 per stake
			resolver.updateAccumulatedRewardX128PerStake(
				tt.currentDistributedAmount,
				tt.currentHeight,
			)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentHeight)
				uassert.Equal(t, resolver.GetDistributedAmount(), tt.currentDistributedAmount)
			} else {
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), initialHeight)
				uassert.Equal(t, resolver.GetDistributedAmount(), initialDistributed)
			}
		})
	}
}

// removeStake bug reproduction 1:
// When removeStake is called for a new address (not present in the tree),
// internally a NewEmissionRewardState(...) is created. If rewardStates.Set(...) is missing,
// the new state is not persisted in the tree, and this was a bug.
// With the fixed code, the state should be saved correctly.
func TestEmissionRewardManager_removeStake_persistsStateForNewAddress(t *testing.T) {
	manager := staker.NewEmissionRewardManager()
	resolver := NewEmissionRewardManagerResolver(manager)

	// Prepare: advance global accumulator once for safety
	resolver.SetAccumulatedRewardX128PerStake(u256.NewUint(0))
	resolver.updateAccumulatedRewardX128PerStake(0, 10)

	// When: calling removeStake on an address that does not exist yet
	addr := "user-new"
	uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

	err := resolver.removeStake(addr, 100, 20)
	uassert.NoError(t, err)

	// Then: state should be persisted in the tree
	// (this fails in the buggy version where Set was missing)
	rs, ok, err := resolver.GetRewardState(addr)
	uassert.NoError(t, err)
	uassert.True(t, ok)

	uassert.NotEqual(t, rs, nil)
	uassert.Equal(t, rs.GetStakedAmount(), int64(0)) // clamped to 0, no negative values
	// rewardDebtX128 should be a cloned snapshot
	uassert.NotEqual(t, rs.GetRewardDebtX128(), nil)
}

// removeStake bug reproduction 2 (defensive check):
// After adding stake for an existing address and then removing part of it,
// the updated staked amount must be persisted in the tree.
// In the buggy version, this may rely on pointer aliasing instead of Set persistence.
// This test ensures round-trip read/write correctness.
func TestEmissionRewardManager_removeStake_updatesPersistedState(t *testing.T) {
	manager := staker.NewEmissionRewardManager()
	resolver := NewEmissionRewardManagerResolver(manager)

	addr := "user1"
	// Given: add stake → creates and saves state
	err := resolver.addStake(addr, 1000, 50)
	uassert.NoError(t, err)
	uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(1000))

	// When: remove part of the stake
	err = resolver.removeStake(addr, 300, 100)
	uassert.NoError(t, err)
	uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(700))

	// Then: re-read from tree should reflect the reduced stake
	rs, ok, err := resolver.GetRewardState(addr)
	uassert.NoError(t, err)
	uassert.True(t, ok)

	uassert.NotEqual(t, rs, nil)
	uassert.Equal(t, rs.GetStakedAmount(), int64(700))

	// Extra check: subsequent operations should remain consistent
	claimed, err := resolver.claimRewards(addr, 120)
	uassert.NoError(t, err)
	// Since no rewards were distributed, claimed amount should be zero
	uassert.Equal(t, claimed, int64(0))
}

// TestEmissionRewardManager_DistributeWithZeroTotalStake tests distribution when totalStakedAmount is zero
// Critical: Validates safe handling of division by zero in reward calculations
func TestEmissionRewardManager_DistributeWithZeroTotalStake(t *testing.T) {
	t.Run("distribute with zero total stake - returns zero without panic", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		// Verify initial state: no stakes
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

		// when - Try to distribute rewards with zero total stake
		currentDistributedAmount := int64(1000)
		accumulatedReward, err := resolver.calculateAccumulatedRewardX128PerStake(
			currentDistributedAmount,
			int64(0), // totalStakedAmount = 0
		)

		// then - Should handle gracefully (returns previous accumulated or zero)
		uassert.NoError(t, err)
		// With zero total stake, reward per stake should remain at zero
		uassert.Equal(t, accumulatedReward.ToString(), "0")
	})

	t.Run("distribute after all stakes removed", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		addr := "user1"

		// Add stake
		err := resolver.addStake(addr, 1000, 50)
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(1000))

		// Remove all stake
		err = resolver.removeStake(addr, 1000, 100)
		uassert.NoError(t, err)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

		// when - Distribute rewards after all stakes removed
		currentDistributedAmount := int64(500)
		accumulatedReward, err := resolver.calculateAccumulatedRewardX128PerStake(
			currentDistributedAmount,
			int64(0), // totalStakedAmount now zero
		)

		// then - Should not panic
		uassert.NoError(t, err)
		// Reward calculation with zero stake should return zero delta
		uassert.Equal(t, accumulatedReward.ToString(), "0")
	})

	t.Run("add stake after zero stake period", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		// Distribute with zero stakes (should be no-op)
		_, err := resolver.calculateAccumulatedRewardX128PerStake(1000, 0)
		uassert.NoError(t, err)

		// when - Add first stake after distribution
		err = resolver.addStake("user1", 500, 100)
		uassert.NoError(t, err)

		// Distribute again with stake present
		accumulatedReward, err := resolver.calculateAccumulatedRewardX128PerStake(2000, 500)
		uassert.NoError(t, err)

		// then - Should calculate rewards correctly for new distribution only
		// Delta = 2000 - 1000 = 1000 (previous distribution at zero stake doesn't count)
		// But since distributed amount tracks cumulative, delta considers last update
		// Reward per stake = 1000 * 2^128 / 500
		uassert.NotEqual(t, accumulatedReward.ToString(), "0")
	})
}

// TestEmissionRewardManager_ZeroStakeEdgeCases tests additional edge cases with zero stakes
func TestEmissionRewardManager_ZeroStakeEdgeCases(t *testing.T) {
	t.Run("multiple users all remove stakes", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		// Add multiple users
		resolver.addStake("user1", 100, 10)
		resolver.addStake("user2", 200, 20)
		resolver.addStake("user3", 300, 30)

		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(600))

		// when - All users remove their stakes
		resolver.removeStake("user1", 100, 40)
		resolver.removeStake("user2", 200, 50)
		resolver.removeStake("user3", 300, 60)

		// then - Total stake should be zero
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

		// Distribution with zero stake should not panic
		accumulatedReward, err := resolver.calculateAccumulatedRewardX128PerStake(1000, 0)
		uassert.NoError(t, err)
		uassert.Equal(t, accumulatedReward.ToString(), "0")
	})

	t.Run("claim rewards when total stake becomes zero", func(t *testing.T) {
		// given
		manager := staker.NewEmissionRewardManager()
		resolver := NewEmissionRewardManagerResolver(manager)

		addr := "user1"
		resolver.addStake(addr, 500, 10)

		// Distribute rewards
		resolver.updateAccumulatedRewardX128PerStake(1000, 20)

		// Remove all stake
		resolver.removeStake(addr, 500, 30)
		uassert.Equal(t, resolver.GetTotalStakedAmount(), int64(0))

		// when - Try to claim rewards after stake removal
		claimed, err := resolver.claimRewards(addr, 40)

		// then - Should successfully claim earned rewards
		uassert.NoError(t, err)
		// User should have earned rewards before removal
		uassert.True(t, claimed >= 0)
	})
}
