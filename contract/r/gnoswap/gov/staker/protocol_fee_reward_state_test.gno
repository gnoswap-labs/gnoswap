package staker

import (
	"testing"

	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestNewProtocolFeeRewardState tests creating a new protocol fee reward state
func TestNewProtocolFeeRewardState(t *testing.T) {
	tests := []struct {
		name            string
		setup           func() *avl.Tree
		expectedMapSize int
		verifyValues    func(*testing.T, *ProtocolFeeRewardState)
	}{
		{
			name: "Create with empty map",
			setup: func() *avl.Tree {
				return avl.NewTree()
			},
			expectedMapSize: 0,
			verifyValues:    func(t *testing.T, state *ProtocolFeeRewardState) {},
		},
		{
			name: "Create with single token",
			setup: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", u256.NewUint(1000))
				return tree
			},
			expectedMapSize: 1,
			verifyValues: func(t *testing.T, state *ProtocolFeeRewardState) {
				actualValue := state.GetRewardDebtX128ForToken("token1")
				uassert.NotNil(t, actualValue)
				uassert.Equal(t, actualValue.ToString(), u256.NewUint(1000).ToString())
			},
		},
		{
			name: "Create with multiple tokens",
			setup: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", u256.NewUint(1000))
				tree.Set("token2", u256.NewUint(2000))
				tree.Set("token3", u256.NewUint(3000))
				return tree
			},
			expectedMapSize: 3,
			verifyValues: func(t *testing.T, state *ProtocolFeeRewardState) {
				uassert.Equal(t, state.GetRewardDebtX128ForToken("token1").ToString(), u256.NewUint(1000).ToString())
				uassert.Equal(t, state.GetRewardDebtX128ForToken("token2").ToString(), u256.NewUint(2000).ToString())
				uassert.Equal(t, state.GetRewardDebtX128ForToken("token3").ToString(), u256.NewUint(3000).ToString())
			},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// when
			state := NewProtocolFeeRewardState(tc.setup())

			// then
			uassert.NotNil(t, state)
			uassert.NotNil(t, state.GetRewardDebtX128())
			uassert.NotNil(t, state.GetAccumulatedRewards())
			uassert.NotNil(t, state.GetClaimedRewards())
			uassert.Equal(t, state.GetRewardDebtX128().Size(), tc.expectedMapSize)
			uassert.Equal(t, state.GetAccumulatedTimestamp(), int64(0))
			uassert.Equal(t, state.GetClaimedTimestamp(), int64(0))
			uassert.Equal(t, state.GetStakedAmount(), int64(0))

			// Verify values
			tc.verifyValues(t, state)
		})
	}
}

// TestProtocolFeeRewardState_SettersAndGetters tests all setter and getter methods
func TestProtocolFeeRewardState_SettersAndGetters(t *testing.T) {
	tests := []struct {
		name                 string
		setupRewardDebt      func() *avl.Tree
		setupAccumulated     func() *avl.Tree
		setupClaimed         func() *avl.Tree
		accumulatedTimestamp int64
		claimedTimestamp     int64
		stakedAmount         int64
		expectedDebtSize     int
		expectedAccumSize    int
		expectedClaimedSize  int
	}{
		{
			name: "Set and get all values",
			setupRewardDebt: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", u256.NewUint(1000))
				tree.Set("token2", u256.NewUint(2000))
				return tree
			},
			setupAccumulated: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", int64(100))
				tree.Set("token2", int64(200))
				return tree
			},
			setupClaimed: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", int64(50))
				tree.Set("token2", int64(75))
				return tree
			},
			accumulatedTimestamp: 1000000,
			claimedTimestamp:     2000000,
			stakedAmount:         50000,
			expectedDebtSize:     2,
			expectedAccumSize:    2,
			expectedClaimedSize:  2,
		},
		{
			name: "Set empty maps",
			setupRewardDebt: func() *avl.Tree {
				return avl.NewTree()
			},
			setupAccumulated: func() *avl.Tree {
				return avl.NewTree()
			},
			setupClaimed: func() *avl.Tree {
				return avl.NewTree()
			},
			accumulatedTimestamp: 0,
			claimedTimestamp:     0,
			stakedAmount:         0,
			expectedDebtSize:     0,
			expectedAccumSize:    0,
			expectedClaimedSize:  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			state := NewProtocolFeeRewardState(avl.NewTree())

			// when
			state.SetRewardDebtX128(tc.setupRewardDebt())
			state.SetAccumulatedRewards(tc.setupAccumulated())
			state.SetClaimedRewards(tc.setupClaimed())
			state.SetAccumulatedTimestamp(tc.accumulatedTimestamp)
			state.SetClaimedTimestamp(tc.claimedTimestamp)
			state.SetStakedAmount(tc.stakedAmount)

			// then
			uassert.Equal(t, state.GetRewardDebtX128().Size(), tc.expectedDebtSize)
			uassert.Equal(t, state.GetAccumulatedRewards().Size(), tc.expectedAccumSize)
			uassert.Equal(t, state.GetClaimedRewards().Size(), tc.expectedClaimedSize)
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
			tree := avl.NewTree()
			tree.Set(tc.token, tc.rewardDebtX128)
			state := NewProtocolFeeRewardState(tree)
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
			state := NewProtocolFeeRewardState(avl.NewTree())

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
			tree := avl.NewTree()
			tree.Set(tc.token, tc.originalValue)

			// when
			state := NewProtocolFeeRewardState(tree)
			tree.Set(tc.token, tc.modifiedValue) // Try to modify original tree

			// then - state should still have the original value
			actualValue := state.GetRewardDebtX128ForToken(tc.token)
			uassert.Equal(t, actualValue.ToString(), tc.originalValue.ToString())
			uassert.NotEqual(t, actualValue.ToString(), tc.modifiedValue.ToString())
		})
	}
}
