package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestNewProtocolFeeRewardState tests creating a new protocol fee reward state
func TestNewProtocolFeeRewardState(t *testing.T) {
	tests := []struct {
		name                              string
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		expectedMapSize                   int
	}{
		{
			name: "Create with empty map",
			accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
			expectedMapSize:                   0,
		},
		{
			name: "Create with single token",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUint(1000),
			},
			expectedMapSize: 1,
		},
		{
			name: "Create with multiple tokens",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUint(1000),
				"token2": u256.NewUint(2000),
				"token3": u256.NewUint(3000),
			},
			expectedMapSize: 3,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			state := NewProtocolFeeRewardState(tc.accumulatedProtocolFeeX128PerStake)

			// then
			uassert.NotNil(t, state)
			uassert.NotNil(t, state.GetRewardDebtX128())
			uassert.NotNil(t, state.GetAccumulatedRewards())
			uassert.NotNil(t, state.GetClaimedRewards())
			uassert.Equal(t, len(state.GetRewardDebtX128()), tc.expectedMapSize)
			uassert.Equal(t, state.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, state.GetClaimedTimestamp(), int64(0))
			uassert.Equal(t, state.GetStakedAmount(), int64(0))

			// Verify cloned values
			for token, expectedValue := range tc.accumulatedProtocolFeeX128PerStake {
				actualValue := state.GetRewardDebtX128ForToken(token)
				uassert.NotNil(t, actualValue)
				uassert.Equal(t, actualValue.ToString(), expectedValue.ToString())
			}
		})
	}
}

// TestProtocolFeeRewardState_SettersAndGetters tests all setter and getter methods
func TestProtocolFeeRewardState_SettersAndGetters(t *testing.T) {
	tests := []struct {
		name                 string
		rewardDebtX128       map[string]*u256.Uint
		accumulatedRewards   map[string]int64
		claimedRewards       map[string]int64
		accumulatedTimestamp int64
		claimedTimestamp     int64
		stakedAmount         int64
	}{
		{
			name: "Set and get all values",
			rewardDebtX128: map[string]*u256.Uint{
				"token1": u256.NewUint(1000),
				"token2": u256.NewUint(2000),
			},
			accumulatedRewards: map[string]int64{
				"token1": 100,
				"token2": 200,
			},
			claimedRewards: map[string]int64{
				"token1": 50,
				"token2": 75,
			},
			accumulatedTimestamp: 1000000,
			claimedTimestamp:     2000000,
			stakedAmount:         50000,
		},
		{
			name:                 "Set empty maps",
			rewardDebtX128:       make(map[string]*u256.Uint),
			accumulatedRewards:   make(map[string]int64),
			claimedRewards:       make(map[string]int64),
			accumulatedTimestamp: 0,
			claimedTimestamp:     0,
			stakedAmount:         0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))

			// when
			state.SetRewardDebtX128(tc.rewardDebtX128)
			state.SetAccumulatedRewards(tc.accumulatedRewards)
			state.SetClaimedRewards(tc.claimedRewards)
			state.SetAccumulatedTimestamp(tc.accumulatedTimestamp)
			state.SetClaimedTimestamp(tc.claimedTimestamp)
			state.SetStakedAmount(tc.stakedAmount)

			// then
			uassert.Equal(t, len(state.GetRewardDebtX128()), len(tc.rewardDebtX128))
			uassert.Equal(t, len(state.GetAccumulatedRewards()), len(tc.accumulatedRewards))
			uassert.Equal(t, len(state.GetClaimedRewards()), len(tc.claimedRewards))
			uassert.Equal(t, state.GetAccumulatedTimestamp(), tc.accumulatedTimestamp)
			uassert.Equal(t, state.GetClaimedTimestamp(), tc.claimedTimestamp)
			uassert.Equal(t, state.GetStakedAmount(), tc.stakedAmount)
		})
	}
}

// TestProtocolFeeRewardState_TokenSpecificGetters tests token-specific getter methods
func TestProtocolFeeRewardState_TokenSpecificGetters(t *testing.T) {
	tests := []struct {
		name               string
		token              string
		rewardDebtX128     *u256.Uint
		accumulatedReward  int64
		claimedReward      int64
	}{
		{
			name:              "Get values for existing token",
			token:             "token1",
			rewardDebtX128:    u256.NewUint(1000),
			accumulatedReward: 100,
			claimedReward:     50,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewProtocolFeeRewardState(map[string]*u256.Uint{
				tc.token: tc.rewardDebtX128,
			})
			state.SetAccumulatedRewardForToken(tc.token, tc.accumulatedReward)
			state.SetClaimedRewardForToken(tc.token, tc.claimedReward)

			// when & then
			actualDebt := state.GetRewardDebtX128ForToken(tc.token)
			uassert.NotNil(t, actualDebt)
			uassert.Equal(t, actualDebt.ToString(), tc.rewardDebtX128.ToString())
			uassert.Equal(t, state.GetAccumulatedRewardForToken(tc.token), tc.accumulatedReward)
			uassert.Equal(t, state.GetClaimedRewardForToken(tc.token), tc.claimedReward)
		})
	}
}

// TestProtocolFeeRewardState_TokenSpecificSetters tests token-specific setter methods
func TestProtocolFeeRewardState_TokenSpecificSetters(t *testing.T) {
	tests := []struct {
		name              string
		token             string
		rewardDebtX128    *u256.Uint
		accumulatedReward int64
		claimedReward     int64
	}{
		{
			name:              "Set values for new token",
			token:             "token1",
			rewardDebtX128:    u256.NewUint(5000),
			accumulatedReward: 200,
			claimedReward:     100,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))

			// when
			state.SetRewardDebtX128ForToken(tc.token, tc.rewardDebtX128)
			state.SetAccumulatedRewardForToken(tc.token, tc.accumulatedReward)
			state.SetClaimedRewardForToken(tc.token, tc.claimedReward)

			// then
			actualDebt := state.GetRewardDebtX128ForToken(tc.token)
			uassert.NotNil(t, actualDebt)
			uassert.Equal(t, actualDebt.ToString(), tc.rewardDebtX128.ToString())
			uassert.Equal(t, state.GetAccumulatedRewardForToken(tc.token), tc.accumulatedReward)
			uassert.Equal(t, state.GetClaimedRewardForToken(tc.token), tc.claimedReward)
		})
	}
}

// TestProtocolFeeRewardState_NilMapHandling tests handling of nil maps
func TestProtocolFeeRewardState_NilMapHandling(t *testing.T) {
	tests := []struct {
		name  string
		token string
	}{
		{
			name:  "Get from nil maps returns default values",
			token: "nonexistent",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := &ProtocolFeeRewardState{
				rewardDebtX128:     nil,
				accumulatedRewards: nil,
				claimedRewards:     nil,
			}

			// when & then
			// GetRewardDebtX128ForToken returns nil for non-existent token when map is nil
			debt := state.GetRewardDebtX128ForToken(tc.token)
			if debt != nil {
				t.Errorf("expected nil debt for non-existent token")
			}
			uassert.Equal(t, state.GetAccumulatedRewardForToken(tc.token), int64(0))
			uassert.Equal(t, state.GetClaimedRewardForToken(tc.token), int64(0))
		})
	}
}

// TestProtocolFeeRewardState_Clone tests that reward debt is cloned
func TestProtocolFeeRewardState_Clone(t *testing.T) {
	tests := []struct {
		name          string
		token         string
		originalValue *u256.Uint
		modifiedValue *u256.Uint
	}{
		{
			name:          "Modifying original should not affect state",
			token:         "token1",
			originalValue: u256.NewUint(1000),
			modifiedValue: u256.NewUint(9999),
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			original := map[string]*u256.Uint{
				tc.token: tc.originalValue,
			}

			// when
			state := NewProtocolFeeRewardState(original)
			original[tc.token] = tc.modifiedValue // Try to modify original

			// then - state should still have the original value
			actualValue := state.GetRewardDebtX128ForToken(tc.token)
			uassert.Equal(t, actualValue.ToString(), tc.originalValue.ToString())
			uassert.NotEqual(t, actualValue.ToString(), tc.modifiedValue.ToString())
		})
	}
}
