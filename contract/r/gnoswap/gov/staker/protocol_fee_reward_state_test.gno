package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestNewProtocolFeeRewardState tests creating a new protocol fee reward state
func TestNewProtocolFeeRewardState(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestProtocolFeeRewardState_SettersAndGetters(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestProtocolFeeRewardState_TokenSpecificGetters(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestProtocolFeeRewardState_TokenSpecificSetters(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestProtocolFeeRewardState_NilMapHandling(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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
func TestProtocolFeeRewardState_Clone(cur realm, t *testing.T) {
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
		t.Run(tc.name, func(cur realm, t *testing.T) {
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

func TestProtocolFeeRewardState_ForTokenSetters(cur realm, t *testing.T) {
	t.Run("Preserve existing entries", func(cur realm, t *testing.T) {
		state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
		state.SetRewardDebtX128ForToken("token1", u256.NewUint(100))
		state.SetRewardDebtX128ForToken("token2", u256.NewUint(200))
		state.SetAccumulatedRewardForToken("token1", 10)
		state.SetAccumulatedRewardForToken("token2", 20)
		state.SetClaimedRewardForToken("token1", 1)
		state.SetClaimedRewardForToken("token2", 2)

		state.SetRewardDebtX128ForToken("token1", u256.NewUint(300))
		state.SetAccumulatedRewardForToken("token1", 30)
		state.SetClaimedRewardForToken("token1", 3)

		uassert.Equal(t, len(state.GetRewardDebtX128()), 2)
		uassert.Equal(t, state.GetRewardDebtX128ForToken("token1").ToString(), "300")
		uassert.Equal(t, state.GetRewardDebtX128ForToken("token2").ToString(), "200")
		uassert.Equal(t, len(state.GetAccumulatedRewards()), 2)
		uassert.Equal(t, state.GetAccumulatedRewardForToken("token1"), int64(30))
		uassert.Equal(t, state.GetAccumulatedRewardForToken("token2"), int64(20))
		uassert.Equal(t, len(state.GetClaimedRewards()), 2)
		uassert.Equal(t, state.GetClaimedRewardForToken("token1"), int64(3))
		uassert.Equal(t, state.GetClaimedRewardForToken("token2"), int64(2))
	})

	t.Run("Clone uint values", func(cur realm, t *testing.T) {
		state := NewProtocolFeeRewardState(make(map[string]*u256.Uint))
		value := u256.NewUint(100)
		state.SetRewardDebtX128ForToken("token", value)
		value.Set(u256.NewUint(200))

		uassert.Equal(t, state.GetRewardDebtX128ForToken("token").ToString(), "100")
	})

	t.Run("Initialize nil maps", func(cur realm, t *testing.T) {
		state := &ProtocolFeeRewardState{}
		state.SetRewardDebtX128ForToken("token", u256.NewUint(100))
		state.SetAccumulatedRewardForToken("token", 10)
		state.SetClaimedRewardForToken("token", 1)

		uassert.NotNil(t, state.GetRewardDebtX128())
		uassert.Equal(t, state.GetRewardDebtX128ForToken("token").ToString(), "100")
		uassert.NotNil(t, state.GetAccumulatedRewards())
		uassert.Equal(t, state.GetAccumulatedRewardForToken("token"), int64(10))
		uassert.NotNil(t, state.GetClaimedRewards())
		uassert.Equal(t, state.GetClaimedRewardForToken("token"), int64(1))
	})
}
