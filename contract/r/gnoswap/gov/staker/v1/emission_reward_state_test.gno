package v1

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/gov/staker"
)

// Test EmissionRewardState creation
func TestNewEmissionRewardState(t *testing.T) {
	tests := []struct {
		name                            string
		accumulatedRewardX128PerStake   *u256.Uint
		expectedRewardDebt              string
		expectedAccumulatedRewardAmount int64
		expectedClaimedRewardAmount     int64
		expectedStakedAmount            int64
	}{
		{
			name:                            "Create with zero accumulated reward",
			accumulatedRewardX128PerStake:   u256.NewUint(0),
			expectedRewardDebt:              "0",
			expectedAccumulatedRewardAmount: 0,
			expectedClaimedRewardAmount:     0,
			expectedStakedAmount:            0,
		},
		{
			name:                            "Create with non-zero accumulated reward",
			accumulatedRewardX128PerStake:   u256.NewUintFromInt64(1000),
			expectedRewardDebt:              "1000",
			expectedAccumulatedRewardAmount: 0,
			expectedClaimedRewardAmount:     0,
			expectedStakedAmount:            0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// When: Create new emission reward state
			state := staker.NewEmissionRewardState(tt.accumulatedRewardX128PerStake)
			resolver := NewEmissionRewardStateResolver(state)

			// Then: Should initialize correctly
			uassert.NotEqual(t, resolver, nil)
			uassert.Equal(t, resolver.GetRewardDebtX128().ToString(), tt.expectedRewardDebt)
			uassert.Equal(t, resolver.GetAccumulatedRewardAmount(), tt.expectedAccumulatedRewardAmount)
			uassert.Equal(t, resolver.GetClaimedRewardAmount(), tt.expectedClaimedRewardAmount)
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStakedAmount)
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
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			resolver.SetClaimedTimestamp(tt.claimedHeight)

			// When: Check if claimable
			result := resolver.IsClaimable(tt.currentHeight)

			// Then: Should return expected result
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test GetClaimableRewardAmount
func TestEmissionRewardState_GetClaimableRewardAmount(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expected                      int64
	}{
		{
			name: "No accumulated rewards and no new rewards",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedRewardAmount(0)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUint(0))
			},
			accumulatedRewardX128PerStake: u256.NewUint(0),
			currentHeight:                 100,
			expected:                      0,
		},
		{
			name: "With accumulated rewards",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedRewardAmount(500)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUint(0))
			},
			accumulatedRewardX128PerStake: u256.NewUint(0),
			currentHeight:                 100,
			expected:                      500,
		},
		{
			name: "With new rewards to calculate",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedRewardAmount(0)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUint(0))
				s.SetAccumulatedTimestamp(50)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128), // 1000 << 128
			currentHeight:                 100,
			expected:                      1000 * 1000,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Get claimable reward amount
			result, _ := resolver.GetClaimableRewardAmount(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: Should return expected amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test calculateClaimableRewards
func TestEmissionRewardState_calculateClaimableRewards(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expected                      int64
	}{
		{
			name: "Current height less than accumulated height",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(200)
				s.SetStakedAmount(1000)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expected:                      0,
		},
		{
			name: "Normal reward calculation",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUint(0))
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
			currentHeight:                 100,
			expected:                      1000 * 1000,
		},
		{
			name: "No staked amount",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(0)
				s.SetRewardDebtX128(u256.NewUint(0))
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
			currentHeight:                 100,
			expected:                      0,
		},
		{
			name: "debt slightly less than accumulated",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUintFromInt64(900).Lsh(u256.NewUintFromInt64(900), 128))
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000).Lsh(u256.NewUintFromInt64(1000), 128),
			currentHeight:                 100,
			expected:                      100 * 1000, // (1000 - 900) * 1000
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Calculate claimable rewards
			result, _ := resolver.calculateClaimableRewards(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: Should return expected amount
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test addStake
func TestEmissionRewardState_addStake(t *testing.T) {
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state with initial stake
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			resolver.SetStakedAmount(tt.initialStake)

			// When: Add stake
			resolver.addStake(tt.addAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStake)
		})
	}
}

// Test removeStake
func TestEmissionRewardState_removeStake(t *testing.T) {
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
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state with initial stake
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			resolver.SetStakedAmount(tt.initialStake)

			// When: Remove stake
			resolver.removeStake(tt.removeAmount)

			// Then: Staked amount should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStake)
		})
	}
}

// Test claimRewards
func TestEmissionRewardState_claimRewards(t *testing.T) {
	tests := []struct {
		name                     string
		setupState               func(*EmissionRewardStateResolver)
		currentHeight            int64
		expectError              bool
		expectedClaimedAmount    int64
		expectedNewClaimedHeight int64
	}{
		{
			name: "Claim when not claimable",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetClaimedTimestamp(100)
				s.SetAccumulatedRewardAmount(1000)
				s.SetClaimedRewardAmount(500)
			},
			currentHeight: 100,
			expectError:   true,
		},
		{
			name: "Successful claim",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetAccumulatedRewardAmount(1000)
				s.SetClaimedRewardAmount(300)
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
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Claim rewards
			claimedAmount, err := resolver.claimRewards(tt.currentHeight)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, claimedAmount, tt.expectedClaimedAmount)
				uassert.Equal(t, resolver.GetClaimedTimestamp(), tt.expectedNewClaimedHeight)
				uassert.Equal(t, resolver.GetClaimedRewardAmount(), resolver.GetAccumulatedRewardAmount())
			}
		})
	}
}

// Test updateRewardDebtX128
func TestEmissionRewardState_updateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedAccumulatedAmount     int64
		expectedAccumulatedHeight     int64
	}{
		{
			name: "Update with new rewards",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(50)
				s.SetAccumulatedRewardAmount(200)
				s.SetStakedAmount(1000)
				s.SetRewardDebtX128(u256.NewUint(0))
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(800).Lsh(u256.NewUintFromInt64(800), 128),
			currentHeight:                 100,
			expectedAccumulatedAmount:     800200, // 200 + 800* 1000
			expectedAccumulatedHeight:     100,
		},
		{
			name: "No update when current height is not greater",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetAccumulatedTimestamp(100)
				s.SetAccumulatedRewardAmount(200)
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
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Update reward debt X128
			resolver.updateRewardDebtX128(tt.accumulatedRewardX128PerStake, tt.currentHeight)

			// Then: State should be updated correctly
			uassert.Equal(t, resolver.GetAccumulatedRewardAmount(), tt.expectedAccumulatedAmount)
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.expectedAccumulatedHeight)
			uassert.Equal(t, resolver.GetRewardDebtX128().Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test addStakeWithUpdateRewardDebtX128
func TestEmissionRewardState_addStakeWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		amount                        int64
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedStakedAmount          int64
	}{
		{
			name: "Add stake with reward debt update",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetStakedAmount(500)
				s.SetAccumulatedTimestamp(50)
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
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Add stake with update reward debt X128
			resolver.addStakeWithUpdateRewardDebtX128(
				tt.amount,
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Both stake and reward debt should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStakedAmount)
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentHeight)
			uassert.Equal(t, resolver.GetRewardDebtX128().Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test removeStakeWithUpdateRewardDebtX128
func TestEmissionRewardState_removeStakeWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		amount                        int64
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectedStakedAmount          int64
	}{
		{
			name: "Remove stake with reward debt update",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetStakedAmount(1000)
				s.SetAccumulatedTimestamp(50)
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
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Remove stake with update reward debt X128
			resolver.removeStakeWithUpdateRewardDebtX128(
				tt.amount,
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Both stake and reward debt should be updated
			uassert.Equal(t, resolver.GetStakedAmount(), tt.expectedStakedAmount)
			uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentHeight)
			uassert.Equal(t, resolver.GetRewardDebtX128().Cmp(tt.accumulatedRewardX128PerStake), 0)
		})
	}
}

// Test claimRewardsWithUpdateRewardDebtX128
func TestEmissionRewardState_claimRewardsWithUpdateRewardDebtX128(t *testing.T) {
	tests := []struct {
		name                          string
		setupState                    func(*EmissionRewardStateResolver)
		accumulatedRewardX128PerStake *u256.Uint
		currentHeight                 int64
		expectError                   bool
		expectedClaimedAmount         int64
	}{
		{
			name: "Claim with update when claimable",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetClaimedTimestamp(50)
				s.SetAccumulatedRewardAmount(500)
				s.SetClaimedRewardAmount(200)
				s.SetAccumulatedTimestamp(50)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectError:                   false,
			expectedClaimedAmount:         300, // Previous claimed amount
		},
		{
			name: "Claim with update when not claimable",
			setupState: func(s *EmissionRewardStateResolver) {
				s.SetClaimedTimestamp(100)
				s.SetAccumulatedRewardAmount(500)
				s.SetClaimedRewardAmount(200)
			},
			accumulatedRewardX128PerStake: u256.NewUintFromInt64(1000),
			currentHeight:                 100,
			expectError:                   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Given: Emission reward state setup
			state := staker.NewEmissionRewardState(u256.NewUint(0))
			resolver := NewEmissionRewardStateResolver(state)
			tt.setupState(resolver)

			// When: Claim rewards with update reward debt X128
			claimedAmount, err := resolver.claimRewardsWithUpdateRewardDebtX128(
				tt.accumulatedRewardX128PerStake,
				tt.currentHeight,
			)

			// Then: Check result
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, claimedAmount, tt.expectedClaimedAmount)
				uassert.Equal(t, resolver.GetAccumulatedTimestamp(), tt.currentHeight)
				uassert.Equal(t, resolver.GetRewardDebtX128().Cmp(tt.accumulatedRewardX128PerStake), 0)
			}
		})
	}
}
