package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
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
			manager := NewEmissionRewardManager()

			// Then: Should initialize with zero values
			uassert.NotEqual(t, manager, nil)
			uassert.Equal(t, manager.GetAccumulatedRewardX128PerStake().ToString(), "0")
			uassert.Equal(t, manager.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, manager.GetTotalStakedAmount(), int64(0))
			uassert.Equal(t, manager.GetDistributedAmount(), int64(0))
		})
	}
}

// Test GetAccumulatedRewardX128PerStake
func TestEmissionRewardManager_GetAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name     string
		setup    func(*EmissionRewardManager)
		expected string
	}{
		{
			name:     "Initial accumulated reward should be zero",
			setup:    func(m *EmissionRewardManager) {},
			expected: "0",
		},
		{
			name: "After setting accumulated reward",
			setup: func(m *EmissionRewardManager) {
				m.accumulatedRewardX128PerStake = u256.NewUintFromInt64(1000)
			},
			expected: "1000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager
			manager := NewEmissionRewardManager()
			tt.setup(manager)

			// When: Get accumulated reward X128 per stake
			result := manager.GetAccumulatedRewardX128PerStake()

			// Then: Should return expected value
			uassert.Equal(t, result.ToString(), tt.expected)
		})
	}
}

// Test GetClaimableRewardAmount
func TestEmissionRewardManager_GetClaimableRewardAmount(t *testing.T) {
	tests := []struct {
		name                     string
		setupManager             func(*EmissionRewardManager)
		currentDistributedAmount int64
		address                  string
		currentHeight            int64
		expected                 int64
	}{
		{
			name:                     "No reward state for address",
			setupManager:             func(m *EmissionRewardManager) {},
			currentDistributedAmount: 1000,
			address:                  "user1",
			currentHeight:            100,
			expected:                 0,
		},
		{
			name: "With existing reward state",
			setupManager: func(m *EmissionRewardManager) {
				// Add stake to create reward state
				m.addStake("user1", 1000, 50)
				m.totalStakedAmount = 1000
			},
			currentDistributedAmount: 1000,
			address:                  "user1",
			currentHeight:            100,
			expected:                 1000, // Full distributed amount for single staker
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := NewEmissionRewardManager()
			tt.setupManager(manager)

			// When: Get claimable reward amount
			result, _ := manager.GetClaimableRewardAmount(
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

	manager := NewEmissionRewardManager()

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Add stake
			manager.addStake(tt.address, tt.amount, tt.currentHeight)

			// Then: Total staked amount should be updated
			uassert.Equal(t, manager.GetTotalStakedAmount(), tt.expectedTotal)

			// And: Reward state should be created/updated
			rewardStateI, ok := manager.rewardStates.Get(tt.address)
			uassert.True(t, ok)
			uassert.NotEqual(t, rewardStateI, nil)
		})
	}
}

// Test removeStake
func TestEmissionRewardManager_removeStake(t *testing.T) {
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
			manager := NewEmissionRewardManager()
			manager.addStake("user1", tt.initialAmount, 50)

			// When: Remove stake
			manager.removeStake("user1", tt.removeAmount, tt.currentHeight)

			// Then: Total staked amount should be updated
			uassert.Equal(t, manager.GetTotalStakedAmount(), tt.expectedAmount)
		})
	}
}

// Test claimRewards
func TestEmissionRewardManager_claimRewards(t *testing.T) {
	tests := []struct {
		name           string
		setupManager   func(*EmissionRewardManager)
		address        string
		currentHeight  int64
		expectError    bool
		expectedReward int64
	}{
		{
			name:           "Claim rewards for non-existent user",
			setupManager:   func(m *EmissionRewardManager) {},
			address:        "user1",
			currentHeight:  100,
			expectedReward: 0,
			expectError:    false,
		},
		{
			name: "Claim rewards for existing user",
			setupManager: func(m *EmissionRewardManager) {
				m.addStake("user1", 1000, 50)
				// Simulate some distributed rewards
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
			manager := NewEmissionRewardManager()
			tt.setupManager(manager)

			// When: Claim rewards
			reward, err := manager.claimRewards(tt.address, tt.currentHeight)

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

// Test calculateAccumulatedRewardX128PerStake
func TestEmissionRewardManager_calculateAccumulatedRewardX128PerStake(t *testing.T) {
	tests := []struct {
		name                     string
		setupManager             func(*EmissionRewardManager)
		currentDistributedAmount int64
		currentHeight            int64
		shouldIncrease           bool
	}{
		{
			name: "Current height less than accumulated height",
			setupManager: func(m *EmissionRewardManager) {
				m.accumulatedTimestamp = 200
				m.accumulatedRewardX128PerStake = u256.NewUintFromInt64(1000)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           false,
		},
		{
			name: "No staked amount",
			setupManager: func(m *EmissionRewardManager) {
				m.totalStakedAmount = 0
				m.accumulatedTimestamp = 50
				m.accumulatedRewardX128PerStake = u256.NewUintFromInt64(500)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           false,
		},
		{
			name: "Normal reward calculation",
			setupManager: func(m *EmissionRewardManager) {
				m.totalStakedAmount = 1000
				m.distributedAmount = 500
				m.accumulatedTimestamp = 50
				m.accumulatedRewardX128PerStake = u256.NewUintFromInt64(0)
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldIncrease:           true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := NewEmissionRewardManager()
			initialReward := u256.NewUintFromInt64(0)
			tt.setupManager(manager)
			if manager.accumulatedRewardX128PerStake != nil {
				initialReward = manager.accumulatedRewardX128PerStake.Clone()
			}

			// When: Calculate accumulated reward X128 per stake
			result, _ := manager.calculateAccumulatedRewardX128PerStake(
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
		setupManager             func(*EmissionRewardManager)
		currentDistributedAmount int64
		currentHeight            int64
		shouldUpdate             bool
	}{
		{
			name: "Should not update when current height is less",
			setupManager: func(m *EmissionRewardManager) {
				m.accumulatedTimestamp = 200
				m.distributedAmount = 500
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             false,
		},
		{
			name: "Should not update when no staked amount",
			setupManager: func(m *EmissionRewardManager) {
				m.accumulatedTimestamp = 50
				m.totalStakedAmount = 0
				m.distributedAmount = 500
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             false,
		},
		{
			name: "Should update normally",
			setupManager: func(m *EmissionRewardManager) {
				m.accumulatedTimestamp = 50
				m.totalStakedAmount = 1000
				m.distributedAmount = 500
			},
			currentDistributedAmount: 1000,
			currentHeight:            100,
			shouldUpdate:             true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward manager setup
			manager := NewEmissionRewardManager()
			tt.setupManager(manager)
			initialHeight := manager.accumulatedTimestamp
			initialDistributed := manager.distributedAmount

			// When: Update accumulated reward X128 per stake
			manager.updateAccumulatedRewardX128PerStake(
				tt.currentDistributedAmount,
				tt.currentHeight,
			)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, manager.accumulatedTimestamp, tt.currentHeight)
				uassert.Equal(t, manager.distributedAmount, tt.currentDistributedAmount)
			} else {
				uassert.Equal(t, manager.accumulatedTimestamp, initialHeight)
				uassert.Equal(t, manager.distributedAmount, initialDistributed)
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
	manager := NewEmissionRewardManager()

	// Prepare: advance global accumulator once for safety
	manager.accumulatedRewardX128PerStake = u256.NewUint(0)
	manager.updateAccumulatedRewardX128PerStake(0, 10)

	// When: calling removeStake on an address that does not exist yet
	addr := "user-new"
	uassert.Equal(t, manager.totalStakedAmount, int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmount(), int64(0))

	err := manager.removeStake(addr, 100, 20)
	uassert.NoError(t, err)

	// Then: state should be persisted in the tree
	// (this fails in the buggy version where Set was missing)
	if ri, ok := manager.rewardStates.Get(addr); !ok {
		t.Fatalf("expected reward state to be persisted for new address after removeStake, but not found (bug)")
	} else {
		// Type and field checks
		rs, castOK := ri.(*EmissionRewardState)
		uassert.True(t, castOK)
		uassert.NotEqual(t, rs, nil)
		uassert.Equal(t, rs.stakedAmount, int64(0)) // clamped to 0, no negative values
		// rewardDebtX128 should be a cloned snapshot
		uassert.NotEqual(t, rs.rewardDebtX128, nil)
	}
}

// removeStake bug reproduction 2 (defensive check):
// After adding stake for an existing address and then removing part of it,
// the updated staked amount must be persisted in the tree.
// In the buggy version, this may rely on pointer aliasing instead of Set persistence.
// This test ensures round-trip read/write correctness.
func TestEmissionRewardManager_removeStake_updatesPersistedState(t *testing.T) {
	manager := NewEmissionRewardManager()

	addr := "user1"
	// Given: add stake → creates and saves state
	err := manager.addStake(addr, 1000, 50)
	uassert.NoError(t, err)
	uassert.Equal(t, manager.GetTotalStakedAmount(), int64(1000))

	// When: remove part of the stake
	err = manager.removeStake(addr, 300, 100)
	uassert.NoError(t, err)
	uassert.Equal(t, manager.GetTotalStakedAmount(), int64(700))

	// Then: re-read from tree should reflect the reduced stake
	ri, ok := manager.rewardStates.Get(addr)
	uassert.True(t, ok)
	rs, castOK := ri.(*EmissionRewardState)
	uassert.True(t, castOK)
	uassert.NotEqual(t, rs, nil)
	uassert.Equal(t, rs.stakedAmount, int64(700))

	// Extra check: subsequent operations should remain consistent
	claimed, err := manager.claimRewards(addr, 120)
	uassert.NoError(t, err)
	// Since no rewards were distributed, claimed amount should be zero
	uassert.Equal(t, claimed, int64(0))
}
