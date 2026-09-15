package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

func TestNewProtocolFeeRewardState(cur realm, t *testing.T) {
	state := NewProtocolFeeRewardState()

	uassert.Equal(t, state.GetStakedAmount(), int64(0))
	uassert.Equal(t, state.GetStakeEventCount(), int64(0))
	uassert.Equal(t, state.GetClaimedTimestamp(), int64(0))
	uassert.Equal(t, len(state.GetTokenPaths()), 0)
	uassert.Equal(t, state.GetClaimedReward("gno.land/r/demo/foo"), int64(0))

	_, ok := state.GetStakeEvent(0)
	uassert.False(t, ok)
	_, ok = state.GetTokenState("gno.land/r/demo/foo")
	uassert.False(t, ok)
}

func TestProtocolFeeRewardState_StakeEvents(cur realm, t *testing.T) {
	state := NewProtocolFeeRewardState()

	state.SetStakedAmount(100)
	state.AppendStakeEvent(1, 100)
	state.SetStakedAmount(250)
	state.AppendStakeEvent(4, 250)
	state.SetStakedAmount(0)
	state.AppendStakeEvent(9, 0)

	uassert.Equal(t, state.GetStakedAmount(), int64(0))
	uassert.Equal(t, state.GetStakeEventCount(), int64(3))

	first, ok := state.GetStakeEvent(0)
	uassert.True(t, ok)
	uassert.Equal(t, first.GetEpoch(), int64(1))
	uassert.Equal(t, first.GetStakedAmount(), int64(100))

	last, ok := state.GetStakeEvent(2)
	uassert.True(t, ok)
	uassert.Equal(t, last.GetEpoch(), int64(9))
	uassert.Equal(t, last.GetStakedAmount(), int64(0))

	_, ok = state.GetStakeEvent(3)
	uassert.False(t, ok)
}

func TestProtocolFeeRewardState_TokenStates(cur realm, t *testing.T) {
	state := NewProtocolFeeRewardState()

	start := u256.NewUint(5)
	tokenState := NewProtocolFeeTokenRewardState(2, 100, start)
	start.Add(start, u256.NewUint(1))

	uassert.Equal(t, tokenState.GetEventCursor(), int64(2))
	uassert.Equal(t, tokenState.GetSegmentStakedAmount(), int64(100))
	uassert.Equal(t, tokenState.GetSegmentStartX128().ToString(), "5")
	uassert.Equal(t, tokenState.GetEarnedX128().ToString(), "0")
	uassert.Equal(t, tokenState.GetClaimedReward(), int64(0))

	tokenState.SetSegment(3, 40, u256.NewUint(9))
	tokenState.SetEarnedX128(u256.NewUint(1234))
	tokenState.SetClaimedReward(77)

	uassert.Equal(t, tokenState.GetEventCursor(), int64(3))
	uassert.Equal(t, tokenState.GetSegmentStakedAmount(), int64(40))
	uassert.Equal(t, tokenState.GetSegmentStartX128().ToString(), "9")
	uassert.Equal(t, tokenState.GetEarnedX128().ToString(), "1234")
	uassert.Equal(t, tokenState.GetClaimedReward(), int64(77))

	state.SetTokenState("gno.land/r/demo/foo", tokenState)
	state.SetTokenState("gno.land/r/demo/bar", NewProtocolFeeTokenRewardState(0, 0, u256.Zero()))

	stored, ok := state.GetTokenState("gno.land/r/demo/foo")
	uassert.True(t, ok)
	uassert.Equal(t, stored.GetClaimedReward(), int64(77))
	uassert.Equal(t, state.GetClaimedReward("gno.land/r/demo/foo"), int64(77))

	tokenPaths := state.GetTokenPaths()
	uassert.Equal(t, len(tokenPaths), 2)
	uassert.Equal(t, tokenPaths[0], "gno.land/r/demo/bar")
	uassert.Equal(t, tokenPaths[1], "gno.land/r/demo/foo")

	state.SetClaimedTimestamp(99)
	uassert.Equal(t, state.GetClaimedTimestamp(), int64(99))
}
