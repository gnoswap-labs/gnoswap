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
		name                     string
		setupAccumulatedFee      func() *avl.Tree
		setupProtocolFeeAmounts  func() *avl.Tree
		accumulatedTimestamp     int64
		totalStakedAmount        int64
		expectedAccumulatedSize  int
		expectedProtocolFeeSize  int
		verifyAccumulatedFee     func(*testing.T, *ProtocolFeeRewardManager)
		verifyProtocolFeeAmounts func(*testing.T, *ProtocolFeeRewardManager)
	}{
		{
			name: "Set and get all values",
			setupAccumulatedFee: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", u256.NewUint(1000))
				tree.Set("token2", u256.NewUint(2000))
				return tree
			},
			setupProtocolFeeAmounts: func() *avl.Tree {
				tree := avl.NewTree()
				tree.Set("token1", int64(100))
				tree.Set("token2", int64(200))
				return tree
			},
			accumulatedTimestamp:    1000000,
			totalStakedAmount:       50000,
			expectedAccumulatedSize: 2,
			expectedProtocolFeeSize: 2,
			verifyAccumulatedFee: func(t *testing.T, manager *ProtocolFeeRewardManager) {
				uassert.Equal(t, manager.GetAccumulatedProtocolFeeX128PerStake("token1").ToString(), u256.NewUint(1000).ToString())
				uassert.Equal(t, manager.GetAccumulatedProtocolFeeX128PerStake("token2").ToString(), u256.NewUint(2000).ToString())
			},
			verifyProtocolFeeAmounts: func(t *testing.T, manager *ProtocolFeeRewardManager) {
				uassert.Equal(t, manager.GetProtocolFeeAmount("token1"), int64(100))
				uassert.Equal(t, manager.GetProtocolFeeAmount("token2"), int64(200))
			},
		},
		{
			name: "Set empty maps",
			setupAccumulatedFee: func() *avl.Tree {
				return avl.NewTree()
			},
			setupProtocolFeeAmounts: func() *avl.Tree {
				return avl.NewTree()
			},
			accumulatedTimestamp:     0,
			totalStakedAmount:        0,
			expectedAccumulatedSize:  0,
			expectedProtocolFeeSize:  0,
			verifyAccumulatedFee:     func(t *testing.T, manager *ProtocolFeeRewardManager) {},
			verifyProtocolFeeAmounts: func(t *testing.T, manager *ProtocolFeeRewardManager) {},
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			// given
			manager := NewProtocolFeeRewardManager()

			// when
			manager.SetAccumulatedProtocolFeeX128PerStake(tc.setupAccumulatedFee())
			manager.SetProtocolFeeAmounts(tc.setupProtocolFeeAmounts())
			manager.SetAccumulatedTimestamp(tc.accumulatedTimestamp)
			manager.SetTotalStakedAmount(tc.totalStakedAmount)

			// then
			uassert.Equal(t, manager.GetAllAccumulatedProtocolFeeX128PerStake().Size(), tc.expectedAccumulatedSize)
			uassert.Equal(t, manager.GetProtocolFeeAmounts().Size(), tc.expectedProtocolFeeSize)
			uassert.Equal(t, manager.GetAccumulatedTimestamp(), tc.accumulatedTimestamp)
			uassert.Equal(t, manager.GetTotalStakedAmount(), tc.totalStakedAmount)

			// Verify individual token values
			tc.verifyAccumulatedFee(t, manager)
			tc.verifyProtocolFeeAmounts(t, manager)
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
			rewardState := NewProtocolFeeRewardState(avl.NewTree())

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
				newTree.Set(addr, NewProtocolFeeRewardState(avl.NewTree()))
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
