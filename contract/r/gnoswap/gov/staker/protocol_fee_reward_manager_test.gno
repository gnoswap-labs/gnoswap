package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestNewProtocolFeeRewardManager(cur realm, t *testing.T) {
	manager := NewProtocolFeeRewardManager()

	uassert.Equal(t, manager.GetCurrentEpoch(), int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmount(), int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(0), int64(0))
	uassert.Equal(t, manager.GetAccumulatedTimestamp(), int64(0))
	uassert.Equal(t, len(manager.GetTokenPaths()), 0)
	uassert.Equal(t, manager.GetAccumulatedProtocolFeeX128PerStake("gno.land/r/demo/token") == nil, true)
	uassert.Equal(t, manager.GetProtocolFeeAmount("gno.land/r/demo/token"), int64(0))

	_, ok, err := manager.GetRewardState("alice")
	uassert.NoError(t, err)
	uassert.False(t, ok)
}

func TestProtocolFeeRewardManager_TotalStakedHistory(cur realm, t *testing.T) {
	manager := NewProtocolFeeRewardManager()

	manager.SetCurrentEpoch(3)
	manager.SetTotalStakedAmount(500)
	manager.SetTotalStakedAmountAt(3, 500)
	manager.SetTotalStakedAmountAt(7, 200)

	uassert.Equal(t, manager.GetCurrentEpoch(), int64(3))
	uassert.Equal(t, manager.GetTotalStakedAmount(), int64(500))

	// The amount in force during an epoch is the latest one recorded at or before it.
	uassert.Equal(t, manager.GetTotalStakedAmountAt(-1), int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(0), int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(2), int64(0))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(3), int64(500))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(6), int64(500))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(7), int64(200))
	uassert.Equal(t, manager.GetTotalStakedAmountAt(100), int64(200))
}

func TestProtocolFeeRewardManager_TokenAccumulators(cur realm, t *testing.T) {
	manager := NewProtocolFeeRewardManager()

	_, ok := manager.GetTokenAccumulator("gno.land/r/demo/foo")
	uassert.False(t, ok)

	foo := NewProtocolFeeTokenAccumulator()
	foo.SetAccumulatedX128PerStakeAt(2, u256.NewUint(10))
	foo.SetProtocolFeeAmount(1000)
	manager.SetTokenAccumulator("gno.land/r/demo/foo", foo)

	bar := NewProtocolFeeTokenAccumulator()
	manager.SetTokenAccumulator("gno.land/r/demo/bar", bar)

	stored, ok := manager.GetTokenAccumulator("gno.land/r/demo/foo")
	uassert.True(t, ok)
	uassert.Equal(t, stored.GetProtocolFeeAmount(), int64(1000))
	uassert.Equal(t, manager.GetAccumulatedProtocolFeeX128PerStake("gno.land/r/demo/foo").ToString(), "10")
	uassert.Equal(t, manager.GetProtocolFeeAmount("gno.land/r/demo/foo"), int64(1000))

	// Token paths come back in key order.
	tokenPaths := manager.GetTokenPaths()
	uassert.Equal(t, len(tokenPaths), 2)
	uassert.Equal(t, tokenPaths[0], "gno.land/r/demo/bar")
	uassert.Equal(t, tokenPaths[1], "gno.land/r/demo/foo")
}

func TestProtocolFeeRewardManager_RewardStates(cur realm, t *testing.T) {
	manager := NewProtocolFeeRewardManager()

	state := NewProtocolFeeRewardState()
	state.SetStakedAmount(42)
	manager.SetRewardState("alice", state)

	stored, ok, err := manager.GetRewardState("alice")
	uassert.NoError(t, err)
	uassert.True(t, ok)
	uassert.Equal(t, stored.GetStakedAmount(), int64(42))

	_, ok, err = manager.GetRewardState("bob")
	uassert.NoError(t, err)
	uassert.False(t, ok)

	manager.SetAccumulatedTimestamp(12345)
	uassert.Equal(t, manager.GetAccumulatedTimestamp(), int64(12345))
}
