package staker

import (
	"testing"

	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
	u256 "gno.land/p/gnoswap/uint256"
)

// TestNewProtocolFeeRewardManager tests creating a new protocol fee reward manager
func TestNewProtocolFeeRewardManager(t *testing.T) {
	t.Run("Create new protocol fee reward manager", func(t *testing.T) {
		// when
		manager := NewProtocolFeeRewardManager()

		// then
		uassert.NotNil(t, manager)
		uassert.NotNil(t, manager.GetProtocolFeeAmounts())
		uassert.NotNil(t, manager.GetAllAccumulatedProtocolFeeX128PerStake())
		uassert.Equal(t, manager.GetAccumulatedTimestamp(), int64(0))
		uassert.Equal(t, manager.GetTotalStakedAmount(), int64(0))
	})
}

// TestProtocolFeeRewardManager_SettersAndGetters tests all setter and getter methods
func TestProtocolFeeRewardManager_SettersAndGetters(t *testing.T) {
	tests := []struct {
		name                               string
		accumulatedProtocolFeeX128PerStake map[string]*u256.Uint
		protocolFeeAmounts                 map[string]int64
		accumulatedTimestamp               int64
		totalStakedAmount                  int64
	}{
		{
			name: "Set and get all values",
			accumulatedProtocolFeeX128PerStake: map[string]*u256.Uint{
				"token1": u256.NewUint(1000),
				"token2": u256.NewUint(2000),
			},
			protocolFeeAmounts: map[string]int64{
				"token1": 100,
				"token2": 200,
			},
			accumulatedTimestamp: 1000000,
			totalStakedAmount:    50000,
		},
		{
			name:                               "Set empty maps",
			accumulatedProtocolFeeX128PerStake: make(map[string]*u256.Uint),
			protocolFeeAmounts:                 make(map[string]int64),
			accumulatedTimestamp:               0,
			totalStakedAmount:                  0,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := NewProtocolFeeRewardManager()

			// when
			manager.SetAccumulatedProtocolFeeX128PerStake(tc.accumulatedProtocolFeeX128PerStake)
			manager.SetProtocolFeeAmounts(tc.protocolFeeAmounts)
			manager.SetAccumulatedTimestamp(tc.accumulatedTimestamp)
			manager.SetTotalStakedAmount(tc.totalStakedAmount)

			// then
			uassert.Equal(t, len(manager.GetAllAccumulatedProtocolFeeX128PerStake()), len(tc.accumulatedProtocolFeeX128PerStake))
			uassert.Equal(t, len(manager.GetProtocolFeeAmounts()), len(tc.protocolFeeAmounts))
			uassert.Equal(t, manager.GetAccumulatedTimestamp(), tc.accumulatedTimestamp)
			uassert.Equal(t, manager.GetTotalStakedAmount(), tc.totalStakedAmount)

			// Verify individual token values
			for token, expectedValue := range tc.accumulatedProtocolFeeX128PerStake {
				actualValue := manager.GetAccumulatedProtocolFeeX128PerStake(token)
				uassert.Equal(t, actualValue.ToString(), expectedValue.ToString())
			}

			for token, expectedAmount := range tc.protocolFeeAmounts {
				actualAmount := manager.GetProtocolFeeAmount(token)
				uassert.Equal(t, actualAmount, expectedAmount)
			}
		})
	}
}

// TestProtocolFeeRewardManager_RewardState tests reward state management
func TestProtocolFeeRewardManager_RewardState(t *testing.T) {
	tests := []struct {
		name    string
		address string
	}{
		{
			name:    "Set and get reward state",
			address: "addr1",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := NewProtocolFeeRewardManager()
			rewardState := NewProtocolFeeRewardState(make(map[string]*u256.Uint))

			// when
			manager.SetRewardState(tc.address, rewardState)

			// then
			result, exists, err := manager.GetRewardState(tc.address)
			uassert.NoError(t, err)
			uassert.True(t, exists)
			uassert.NotNil(t, result)
		})
	}
}

// TestProtocolFeeRewardManager_GetRewardState_NonExistent tests getting non-existent state
func TestProtocolFeeRewardManager_GetRewardState_NonExistent(t *testing.T) {
	tests := []struct {
		name    string
		address string
	}{
		{
			name:    "Get non-existent reward state",
			address: "nonexistent",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := NewProtocolFeeRewardManager()

			// when
			_, exists, err := manager.GetRewardState(tc.address)

			// then
			uassert.NoError(t, err)
			uassert.False(t, exists)
		})
	}
}

// TestProtocolFeeRewardManager_SetRewardStates tests setting entire reward states tree
func TestProtocolFeeRewardManager_SetRewardStates(t *testing.T) {
	tests := []struct {
		name      string
		addresses []string
	}{
		{
			name:      "Set reward states tree",
			addresses: []string{"addr1", "addr2", "addr3"},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := NewProtocolFeeRewardManager()
			newTree := avl.NewTree()
			for _, addr := range tc.addresses {
				newTree.Set(addr, NewProtocolFeeRewardState(make(map[string]*u256.Uint)))
			}

			// when
			manager.SetRewardStates(newTree)

			// then
			for _, addr := range tc.addresses {
				result, exists, err := manager.GetRewardState(addr)
				uassert.NoError(t, err)
				uassert.True(t, exists)
				uassert.NotNil(t, result)
			}
		})
	}
}
