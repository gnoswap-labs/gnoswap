package staker

import (
	"testing"

	"gno.land/p/demo/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// Test EmissionRewardState creation
func TestNewEmissionRewardState(t *testing.T) {
	tests := []struct {
		name                               string
		accumulatedRewardX128PerStake      *u256.Uint
		expectedRewardDebt                 string
		expectedAccumulatedRewardAmount    int64
		expectedClaimedRewardAmount        int64
		expectedStakedAmount               int64
	}{
		{
			name:                               "Create with zero accumulated reward",
			accumulatedRewardX128PerStake:      u256.NewUint(0),
			expectedRewardDebt:                 "0",
			expectedAccumulatedRewardAmount:    0,
			expectedClaimedRewardAmount:        0,
			expectedStakedAmount:               0,
		},
		{
			name:                               "Create with non-zero accumulated reward",
			accumulatedRewardX128PerStake:      u256.NewUintFromInt64(1000),
			expectedRewardDebt:                 "1000",
			expectedAccumulatedRewardAmount:    0,
			expectedClaimedRewardAmount:        0,
			expectedStakedAmount:               0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new emission reward state
			state := NewEmissionRewardState(tt.accumulatedRewardX128PerStake)

			// Then: Should initialize correctly
			uassert.NotEqual(t, state, nil)
			uassert.Equal(t, state.rewardDebtX128.ToString(), tt.expectedRewardDebt)
			uassert.Equal(t, state.accumulatedRewardAmount, tt.expectedAccumulatedRewardAmount)
			uassert.Equal(t, state.claimedRewardAmount, tt.expectedClaimedRewardAmount)
			uassert.Equal(t, state.stakedAmount, tt.expectedStakedAmount)
		})
	}
}

// Test IsClaimable
func TestEmissionRewardState_IsClaimable(t *testing.T) {
	tests := []struct {
		name          string
		claimedHeight int64
		currentHeight int64
		expected      bool
	}{
		{
			name:          "Not claimable when current height equals claimed height",
			claimedHeight: 100,
			currentHeight: 100,
			expected:      false,
		},
		{
			name:          "Not claimable when current height is less than claimed height",
			claimedHeight: 100,
			currentHeight: 50,
			expected:      false,
		},
		{
			name:          "Claimable when current height is greater than claimed height",
			claimedHeight: 50,
			currentHeight: 100,
			expected:      true,
		},
		{
			name:          "Claimable when never claimed before",
			claimedHeight: 0,
			currentHeight: 100,
			expected:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state with claimed height
			state := NewEmissionRewardState(u256.NewUint(0))
			state.claimedHeight = tt.claimedHeight

			// When: Check if claimable
			result := state.IsClaimable(tt.currentHeight)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test GetClaimableRewardAmount
func TestEmissionRewardState_GetClaimableRewardAmount(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expected                      int64
	}{
		{
			name: "No accumulated rewards and no new rewards",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedRewardAmount = 0
				s.stakedAmount = 1000
				s.rewardDebtX128 = u256.NewUint(0)
			},
			accumulatedRewardX128PerStake: u256.NewUint(0),
			currentHeight:                 100,
			expected:                      0,
		},
		{
			name: "With accumulated rewards",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedRewardAmount = 500
				s.stakedAmount = 1000
				s.rewardDebtX128 = u256.NewUint(0)
			},
			accumulatedRewardX128PerStake: u256.NewUint(0),
			currentHeight:                 100,
			expected:                      500,
		},
		{
			name: "With new rewards to calculate",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedRewardAmount = 0
				s.stakedAmount = 1000
				s.rewardDebtX128 = u256.NewUint(0)
				s.accumulatedHeight = 50
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128), // 1000 << 128
			currentHeight:                 100,
			expected:                      1000 * 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Get claimable reward amount
			result := state.GetClaimableRewardAmount(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: Should return expected amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test calculateClaimableRewards
func TestEmissionRewardState_calculateClaimableRewards(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expected                      int64
	}{
		{
			name: "Current height less than accumulated height",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedHeight = 200
				s.stakedAmount = 1000
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expected:                      0,
		},
		{
			name: "Normal reward calculation",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedHeight = 50
				s.stakedAmount = 1000
				s.rewardDebtX128 = u256.NewUint(0)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
			currentHeight:                 100,
			expected:                      1000 * 1000,
		},
		{
			name: "No staked amount",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedHeight = 50
				s.stakedAmount = 0
				s.rewardDebtX128 = u256.NewUint(0)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
			currentHeight:                 100,
			expected:                      0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Calculate claimable rewards
			result := state.calculateClaimableRewards(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: Should return expected amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test addStake
func TestEmissionRewardState_addStake(t *testing.T) {
	tests := []struct {
		name           string
		initialStake   int64
		addAmount      int64
		expectedStake  int64
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state with initial stake
			state := NewEmissionRewardState(u256.NewUint(0))
			state.stakedAmount = tt.initialStake

			// When: Add stake
			state.addStake(tt.addAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStake)
		})
	}
}

// Test removeStake
func TestEmissionRewardState_removeStake(t *testing.T) {
	tests := []struct {
		name           string
		initialStake   int64
		removeAmount   int64
		expectedStake  int64
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state with initial stake
			state := NewEmissionRewardState(u256.NewUint(0))
			state.stakedAmount = tt.initialStake

			// When: Remove stake
			state.removeStake(tt.removeAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStake)
		})
	}
}

// Test claimRewards
func TestEmissionRewardState_claimRewards(t *testing.T) {
	tests := []struct {
		name                     string
		setupState               func(*EmissionRewardState)
		currentHeight            int64
		expectError              bool
		expectedClaimedAmount    int64
		expectedNewClaimedHeight int64
	}{
		{
			name: "Claim when not claimable",
			setupState: func(s *EmissionRewardState) {
				s.claimedHeight = 100
				s.accumulatedRewardAmount = 1000
				s.claimedRewardAmount = 500
			},
			currentHeight: 100,
			expectError:   true,
		},
		{
			name: "Successful claim",
			setupState: func(s *EmissionRewardState) {
				s.claimedHeight = 50
				s.accumulatedRewardAmount = 1000
				s.claimedRewardAmount = 300
			},
			currentHeight:            100,
			expectError:              false,
			expectedClaimedAmount:    700, // Previous claimed amount
			expectedNewClaimedHeight: 100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Claim rewards
			claimedAmount, err := state.claimRewards(tt.currentHeight)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, claimedAmount, tt.expectedClaimedAmount)
				uassert.Equal(t, state.claimedHeight, tt.expectedNewClaimedHeight)
				uassert.Equal(t, state.claimedRewardAmount, state.accumulatedRewardAmount)
			}
		})
	}
}

// Test updateRewardDebtX128
func TestEmissionRewardState_updateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedAccumulatedAmount     int64
		expectedAccumulatedHeight     int64
	}{
		{
			name: "Update with new rewards",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedHeight = 50
				s.accumulatedRewardAmount = 200
				s.stakedAmount = 1000
				s.rewardDebtX128 = u256.NewUint(0)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(800).Lsh(u256.NewUintFromInt64(800), 128),
			currentHeight:                 100,
			expectedAccumulatedAmount:     800200, // 200 + 800* 1000
			expectedAccumulatedHeight:     100,
		},
		{
			name: "No update when current height is not greater",
			setupState: func(s *EmissionRewardState) {
				s.accumulatedHeight = 100
				s.accumulatedRewardAmount = 200
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(800),
			currentHeight:                 100,
			expectedAccumulatedAmount:     200, // No change
			expectedAccumulatedHeight:     100, // No change
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Update reward debt X128
			state.updateRewardDebtX128(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: State should be updated correctly
			uassert.Equal(t, state.accumulatedRewardAmount, tt.expectedAccumulatedAmount)
			uassert.Equal(t, state.accumulatedHeight, tt.expectedAccumulatedHeight)
			uassert.Equal(t, state.rewardDebtX128.Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test addStakeWithUpdateRewardDebtX128
func TestEmissionRewardState_addStakeWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		amount                        int64
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedStakedAmount          int64
	}{
		{
			name: "Add stake with reward debt update",
			setupState: func(s *EmissionRewardState) {
				s.stakedAmount = 500
				s.accumulatedHeight = 50
			},
			amount:                        300,
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectedStakedAmount:          800,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Add stake with update reward debt X128
			state.addStakeWithUpdateRewardDebtX128(
				tt.amount,
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Both stake and reward debt should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStakedAmount)
			uassert.Equal(t, state.accumulatedHeight, tt.currentHeight)
			uassert.Equal(t, state.rewardDebtX128.Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test removeStakeWithUpdateRewardDebtX128
func TestEmissionRewardState_removeStakeWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		amount                        int64
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedStakedAmount          int64
	}{
		{
			name: "Remove stake with reward debt update",
			setupState: func(s *EmissionRewardState) {
				s.stakedAmount = 1000
				s.accumulatedHeight = 50
			},
			amount:                        300,
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectedStakedAmount:          700,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Remove stake with update reward debt X128
			state.removeStakeWithUpdateRewardDebtX128(
				tt.amount,
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Both stake and reward debt should be updated
			uassert.Equal(t, state.stakedAmount, tt.expectedStakedAmount)
			uassert.Equal(t, state.accumulatedHeight, tt.currentHeight)
			uassert.Equal(t, state.rewardDebtX128.Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test claimRewardsWithUpdateRewardDebtX128
func TestEmissionRewardState_claimRewardsWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardState)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectError                   bool
		expectedClaimedAmount         int64
	}{
		{
			name: "Claim with update when claimable",
			setupState: func(s *EmissionRewardState) {
				s.claimedHeight = 50
				s.accumulatedRewardAmount = 500
				s.claimedRewardAmount = 200
				s.accumulatedHeight = 50
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectError:                   false,
			expectedClaimedAmount:         300, // Previous claimed amount
		},
		{
			name: "Claim with update when not claimable",
			setupState: func(s *EmissionRewardState) {
				s.claimedHeight = 100
				s.accumulatedRewardAmount = 500
				s.claimedRewardAmount = 200
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectError:                   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := NewEmissionRewardState(u256.NewUint(0))
			tt.setupState(state)

			// When: Claim rewards with update reward debt X128
			claimedAmount, err := state.claimRewardsWithUpdateRewardDebtX128(
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, claimedAmount, tt.expectedClaimedAmount)
				uassert.Equal(t, state.accumulatedHeight, tt.currentHeight)
				uassert.Equal(t, state.rewardDebtX128.Cmp(tt.accumulatedRewardX128PerStake), 0)
			}
		})
	}
} 