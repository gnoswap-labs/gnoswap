package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestNewProtocolFeeRewardState(t *testing.T) {
	tests := []struct {
		name                               string
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		expectedTokenCount                 int
	}{
		{
			name:                               "Create with empty protocol fee map",
			accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
			expectedTokenCount:                 0,
		},
		{
			name: "Create with single token",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			expectedTokenCount: 1,
		},
		{
			name: "Create with multiple tokens",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
				"token2": u256.NewUintFromInt64(2000),
				"token3": u256.NewUintFromInt64(3000),
			},
			expectedTokenCount: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new protocol fee reward state
			state := NewProtocolFeeRewardState(tt.accumulatedProtocolFeeX128PerStake)

			// Then: Should initialize correctly
			uassert.NotEqual(t, state, nil)
			uassert.Equal(t, len(state.rewardDebtX128), tt.expectedTokenCount)
			uassert.Equal(t, state.accumulatedTimestamp, int64(0))
			uassert.Equal(t, state.claimedTimestamp, int64(0))
			uassert.Equal(t, state.stakedAmount, int64(0))

			// Verify reward debt is properly cloned
			for token, originalAmount := range tt.accumulatedProtocolFeeX128PerStake {
				debtAmount := state.rewardDebtX128[token]
				uassert.NotEqual(t, debtAmount, nil)
				uassert.Equal(t, debtAmount.Cmp(originalAmount), 0)
			}
		})
	}
}

// Test IsClaimable
func TestProtocolFeeRewardState_IsClaimable(t *testing.T) {
	tests := []struct {
		name             string
		claimedTimestamp int64
		currentTimestamp int64
		expected         bool
	}{
		{
			name:             "Not claimable when current height equals claimed height",
			claimedTimestamp: 100,
			currentTimestamp: 100,
			expected:         false,
		},
		{
			name:             "Not claimable when current height is less than claimed height",
			claimedTimestamp: 100,
			currentTimestamp: 50,
			expected:         false,
		},
		{
			name:             "Claimable when current height is greater than claimed height",
			claimedTimestamp: 50,
			currentTimestamp: 100,
			expected:         true,
		},
		{
			name:             "Claimable when never claimed before",
			claimedTimestamp: 0,
			currentTimestamp: 100,
			expected:         true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with claimed height
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			state.claimedTimestamp = tt.claimedTimestamp

			// When: Check if claimable
			result := state.IsClaimable(tt.currentTimestamp)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test GetClaimableRewardAmounts
func TestProtocolFeeRewardState_GetClaimableRewardAmounts(t *testing.T) {
	tests := []struct {
		name                           string
		setupState                     func(*ProtocolFeeRewardState)
		accumulatedRewardsX128PerStake map[string]*u256.Uint
		currentTimestamp               int64
		expectedTokenCount             int
	}{
		{
			name: "No rewards when accumulated height is greater than current height",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 200
				s.accumulatedRewards["token1"] = 1000
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp:   100,
			expectedTokenCount: 1, // Returns accumulated rewards
		},
		{
			name: "Calculate rewards when current height is greater",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 50
				s.stakedAmount = 1000
				s.rewardDebtX128["token1"] = u256.NewUint(0)
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
			},
			currentTimestamp:   100,
			expectedTokenCount: 1,
		},
		{
			name: "Multiple tokens calculation",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 50
				s.stakedAmount = 1000
				s.rewardDebtX128["token1"] = u256.NewUint(0)
				s.rewardDebtX128["token2"] = u256.NewUint(0)
				s.rewardDebtX128["token3"] = u256.NewUint(0)
			},
			accumulatedRewardsX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(100).Lsh(u256.NewUintFromInt64(100), 128),
				"token2": u256.NewUintFromInt64(200).Lsh(u256.NewUintFromInt64(200), 128),
				"token3": u256.NewUintFromInt64(300).Lsh(u256.NewUintFromInt64(300), 128),
			},
			currentTimestamp:   100,
			expectedTokenCount: 3,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			tt.setupState(state)

			// When: Get claimable reward amounts
			result := state.GetClaimableRewardAmounts(tt.accumulatedRewardsX128PerStake, tt.currentTimestamp)

			// Then: Should return expected number of tokens
			uassert.Equal(t, len(result), tt.expectedTokenCount)

			// Verify all amounts are non-negative
			for token, amount := range result {
				uassert.True(t, amount >= 0, "Reward amount should be non-negative for token: "+token)
			}
		})
	}
}

// Test addStake
func TestProtocolFeeRewardState_addStake(t *testing.T) {
	tests := []struct {
		name          string
		initialStake  int64
		addAmount     int64
		expectedStake int64
	}{
		{
			name:          "Add stake to empty state",
			initialStake:  0,
			addAmount:     1000,
			expectedStake: 1000,
		},
		{
			name:          "Add stake to existing stake",
			initialStake:  500,
			addAmount:     300,
			expectedStake: 800,
		},
		{
			name:          "Add zero stake",
			initialStake:  1000,
			addAmount:     0,
			expectedStake: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with initial stake
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			state.stakedAmount = tt.initialStake

			// When: Add stake
			state.addStake(tt.addAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStake)
		})
	}
}

// Test removeStake
func TestProtocolFeeRewardState_removeStake(t *testing.T) {
	tests := []struct {
		name          string
		initialStake  int64
		removeAmount  int64
		expectedStake int64
	}{
		{
			name:          "Remove partial stake",
			initialStake:  1000,
			removeAmount:  300,
			expectedStake: 700,
		},
		{
			name:          "Remove all stake",
			initialStake:  1000,
			removeAmount:  1000,
			expectedStake: 0,
		},
		{
			name:          "Remove zero stake",
			initialStake:  1000,
			removeAmount:  0,
			expectedStake: 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state with initial stake
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			state.stakedAmount = tt.initialStake

			// When: Remove stake
			state.removeStake(tt.removeAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStake)
		})
	}
}

// Test claimRewards
func TestProtocolFeeRewardState_claimRewards(t *testing.T) {
	tests := []struct {
		name                  string
		setupState            func(*ProtocolFeeRewardState)
		currentTimestamp      int64
		expectError           bool
		expectedClaimedLength int
	}{
		{
			name: "Claim when not claimable",
			setupState: func(s *ProtocolFeeRewardState) {
				s.claimedTimestamp = 100
				s.accumulatedRewards["token1"] = 1000
			},
			currentTimestamp: 100,
			expectError:      true,
		},
		{
			name: "Claim when accumulated height is less than current height",
			setupState: func(s *ProtocolFeeRewardState) {
				s.claimedTimestamp = 50
				s.accumulatedTimestamp = 50
				s.accumulatedRewards["token1"] = 1000
			},
			currentTimestamp: 100,
			expectError:      true, // Must update reward debt before claiming
		},
		{
			name: "Successful claim",
			setupState: func(s *ProtocolFeeRewardState) {
				s.claimedTimestamp = 50
				s.accumulatedTimestamp = 100
				s.accumulatedRewards["token1"] = 1000
				s.accumulatedRewards["token2"] = 500
				s.claimedRewards["token1"] = 300
				s.claimedRewards["token2"] = 0
			},
			currentTimestamp:      100,
			expectError:           false,
			expectedClaimedLength: 2,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			tt.setupState(state)

			// When: Claim rewards
			claimedRewards, err := state.claimRewards(tt.currentTimestamp)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
				uassert.Equal(t, claimedRewards, nil)
			} else {
				uassert.NoError(t, err)
				uassert.NotEqual(t, claimedRewards, nil)
				uassert.Equal(t, len(claimedRewards), tt.expectedClaimedLength)
				uassert.Equal(t, state.claimedTimestamp, tt.currentTimestamp)
			}
		})
	}
}

// Test updateRewardDebtX128
func TestProtocolFeeRewardState_updateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                               string
		setupState                         func(*ProtocolFeeRewardState)
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		currentTimestamp                   int64
		shouldUpdate                       bool
	}{
		{
			name: "No update when accumulated height is greater than current height",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 200
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "No update when accumulated height equals current height",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 100
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(1000),
			},
			currentTimestamp: 100,
			shouldUpdate:     false,
		},
		{
			name: "Update when current height is greater",
			setupState: func(s *ProtocolFeeRewardState) {
				s.accumulatedTimestamp = 50
				s.stakedAmount = 1000
				s.rewardDebtX128["token1"] = u256.NewUint(0)
				s.accumulatedRewards["token1"] = 200
			},
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
			},
			currentTimestamp: 100,
			shouldUpdate:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Protocol fee reward state setup
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
			tt.setupState(state)
			initialTimestamp := state.accumulatedTimestamp

			// When: Update reward debt X128
			state.updateRewardDebtX128(tt.accumulatedProtocolFeeX128PerStake, tt.currentTimestamp)

			// Then: Check if state was updated as expected
			if tt.shouldUpdate {
				uassert.Equal(t, state.accumulatedTimestamp, tt.currentTimestamp)
			} else {
				uassert.Equal(t, state.accumulatedTimestamp, initialTimestamp)
			}
		})
	}
}

// Test combined operations
func TestProtocolFeeRewardState_CombinedOperations(t *testing.T) {
	tests := []struct {
		name        string
		operations  func(*ProtocolFeeRewardState)
		description string
	}{
		{
			name: "Add stake with update reward debt",
			operations: func(s *ProtocolFeeRewardState) {
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000),
				}

				s.addStakeWithUpdateRewardDebtX128(500, accumulatedFees, 100)

				uassert.Equal(t, s.stakedAmount, int64(500))
				uassert.Equal(t, s.accumulatedTimestamp, int64(100))
			},
			description: "Should add stake and update reward debt",
		},
		{
			name: "Remove stake with update reward debt",
			operations: func(s *ProtocolFeeRewardState) {
				s.stakedAmount = 1000
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000),
				}

				s.removeStakeWithUpdateRewardDebtX128(300, accumulatedFees, 100)

				uassert.Equal(t, s.stakedAmount, int64(700))
				uassert.Equal(t, s.accumulatedTimestamp, int64(100))
			},
			description: "Should remove stake and update reward debt",
		},
		{
			name: "Claim rewards with update reward debt",
			operations: func(s *ProtocolFeeRewardState) {
				s.claimedTimestamp = 50
				s.stakedAmount = 1000
				accumulatedFees := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(500).Lsh(u256.NewUintFromInt64(500), 128),
				}

				rewards, err := s.claimRewardsWithUpdateRewardDebtX128(accumulatedFees, 100)

				uassert.NoError(t, err)
				uassert.NotEqual(t, rewards, nil)
				uassert.Equal(t, s.accumulatedTimestamp, int64(100))
				uassert.Equal(t, s.claimedTimestamp, int64(100))
			},
			description: "Should claim rewards and update reward debt",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh protocol fee reward state
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))

			// When: Execute operations
			tt.operations(state)

			// Then: Operations should complete successfully
			// Assertions are done within the operations function
		})
	}
}

// Test edge cases
func TestProtocolFeeRewardState_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		setupTest   func(*ProtocolFeeRewardState)
		description string
	}{
		{
			name: "Handle nil reward debt for new token",
			setupTest: func(s *ProtocolFeeRewardState) {
				s.stakedAmount = 1000
				accumulatedRewards := map[string]*u256.Uint{
					"newtoken": u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
				}

				// Should handle nil reward debt gracefully
				result := s.calculateClaimableRewards(accumulatedRewards, 100)

				uassert.NotEqual(t, result, nil)
				uassert.True(t, len(result) > 0)
			},
			description: "Should handle nil reward debt for new tokens",
		},
		{
			name: "Multiple claim attempts",
			setupTest: func(s *ProtocolFeeRewardState) {
				s.claimedTimestamp = 50
				s.accumulatedTimestamp = 100
				s.accumulatedRewards["token1"] = 1000
				s.claimedRewards["token1"] = 0

				// First claim
				rewards1, err1 := s.claimRewards(100)
				uassert.NoError(t, err1)
				uassert.Equal(t, rewards1["token1"], int64(1000))

				// Second claim should fail (same height)
				_, err2 := s.claimRewards(100)
				uassert.Error(t, err2)
			},
			description: "Should handle multiple claim attempts correctly",
		},
		{
			name: "Zero staked amount calculation",
			setupTest: func(s *ProtocolFeeRewardState) {
				s.stakedAmount = 0
				accumulatedRewards := map[string]*u256.Uint{
					"token1": u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
				}

				result := s.calculateClaimableRewards(accumulatedRewards, 100)

				// Should return zero rewards when no stake
				uassert.Equal(t, result["token1"], int64(0))
			},
			description: "Should handle zero staked amount correctly",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Fresh protocol fee reward state
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))

			// When: Execute test setup
			tt.setupTest(state)

			// Then: Test should complete without panicking
			// Additional assertions are done within setupTest
		})
	}
}
