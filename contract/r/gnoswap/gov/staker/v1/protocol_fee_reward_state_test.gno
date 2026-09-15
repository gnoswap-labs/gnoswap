package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"

	"gno.land/r/gnoswap/gov/staker"
)

func u256Lsh128(amount int64) *u256.Uint {
	return u256.Zero().Lsh(u256.NewUintFromInt64(amount), 128)
}

// newPfTestView builds an accumulator view from (epoch, value) pairs, with the value
// given in whole units per stake.
func newPfTestView(foldedEpoch int64, epochs []int64, values []int64) *protocolFeeAccumulatorView {
	accumulator := staker.NewProtocolFeeTokenAccumulator()
	for i, epoch := range epochs {
		accumulator.SetAccumulatedX128PerStakeAt(epoch, u256Lsh128(values[i]))
	}
	accumulator.SetFoldedEpoch(foldedEpoch)

	return &protocolFeeAccumulatorView{
		accumulator:  accumulator,
		extraEpochs:  []int64{},
		extraValues:  []*u256.Uint{},
		current:      accumulator.GetAccumulatedX128PerStake().Clone(),
		firstEpoch:   accumulator.GetFirstEpoch(),
		foldedEpoch:  foldedEpoch,
		currentEpoch: foldedEpoch + 1,
	}
}

func TestProtocolFeeRewardState_loadTokenSettlement_NoFeeFolded(cur realm, t *testing.T) {
	t.Run("skips every event once every closed epoch is folded", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(50, 2))

		view := newPfTestView(1, nil, nil)
		view.currentEpoch = 2

		settlement := resolver.loadTokenSettlement(pfTestBar, view)
		uassert.Equal(t, settlement.eventCursor, int64(2))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(150))
	})

	t.Run("keeps events pending while a closed epoch is not folded", func(cur realm, t *testing.T) {
		// A bucket from epoch 1 may still be pending, so the events cannot be skipped:
		// settleEvents settles them, gated by foldedEpoch, once that bucket is folded.
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(50, 2))

		view := newPfTestView(0, nil, nil)
		view.currentEpoch = 2

		settlement := resolver.loadTokenSettlement(pfTestBar, view)
		uassert.Equal(t, settlement.eventCursor, int64(0))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(0))

		uassert.False(t, resolver.settleEvents(settlement, view, 0))
		uassert.Equal(t, settlement.eventCursor, int64(1))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(100))
	})
}

func TestProtocolFeeRewardState_addStake(cur realm, t *testing.T) {
	resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())

	uassert.NoError(t, resolver.addStake(100, 1))
	uassert.NoError(t, resolver.addStake(50, 4))
	uassert.Equal(t, resolver.GetStakedAmount(), int64(150))
	uassert.Equal(t, resolver.GetStakeEventCount(), int64(2))

	event, ok := resolver.GetStakeEvent(1)
	uassert.True(t, ok)
	uassert.Equal(t, event.GetEpoch(), int64(4))
	uassert.Equal(t, event.GetStakedAmount(), int64(150))

	uassert.ErrorContains(t, resolver.addStake(0, 5), errAmountMustBePositive)
	uassert.ErrorContains(t, resolver.addStake(-5, 5), errAmountMustBePositive)
}

func TestProtocolFeeRewardState_removeStake(cur realm, t *testing.T) {
	resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())

	uassert.NoError(t, resolver.addStake(100, 1))
	uassert.NoError(t, resolver.removeStake(30, 2))
	uassert.Equal(t, resolver.GetStakedAmount(), int64(70))
	uassert.Equal(t, resolver.GetStakeEventCount(), int64(2))

	uassert.ErrorContains(t, resolver.removeStake(-1, 3), errAmountMustBeNonNegative)
	uassert.ErrorContains(t, resolver.removeStake(71, 3), errRemoveAmountExceedsStaked)

	// Removing zero is allowed and still records an event.
	uassert.NoError(t, resolver.removeStake(0, 3))
	uassert.Equal(t, resolver.GetStakeEventCount(), int64(3))
}

func TestProtocolFeeRewardState_loadTokenSettlement(cur realm, t *testing.T) {
	t.Run("with no fee ever folded every event is skipped", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(100, 2))

		settlement := resolver.loadTokenSettlement(pfTestBar, newPfTestView(-1, nil, nil))
		uassert.Equal(t, settlement.eventCursor, int64(2))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(200))
		uassert.Equal(t, settlement.segmentStartX128.ToString(), "0")
	})

	t.Run("events up to the first fee epoch are skipped", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(100, 3))
		uassert.NoError(t, resolver.addStake(100, 7))

		// First fee at epoch 3: the event at epoch 3 closes a zero segment, so the open
		// segment starts there with 200 staked.
		settlement := resolver.loadTokenSettlement(pfTestBar, newPfTestView(6, []int64{3}, []int64{5}))
		uassert.Equal(t, settlement.eventCursor, int64(2))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(200))
		uassert.Equal(t, settlement.segmentStartX128.ToString(), "0")
	})

	t.Run("a fee before every event starts from the first event", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 5))

		settlement := resolver.loadTokenSettlement(pfTestBar, newPfTestView(6, []int64{2}, []int64{5}))
		uassert.Equal(t, settlement.eventCursor, int64(0))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(0))
	})

	t.Run("the boundary event is found across a long history", func(cur realm, t *testing.T) {
		// Events at epochs 1..40, two of them at the first fee epoch 20: the cursor must
		// land after the last event at epoch 20 and pick up its stake.
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		for epoch := int64(1); epoch <= 40; epoch++ {
			uassert.NoError(t, resolver.addStake(1, epoch))
			if epoch == 20 {
				uassert.NoError(t, resolver.addStake(5, epoch))
			}
		}

		settlement := resolver.loadTokenSettlement(pfTestBar, newPfTestView(39, []int64{20}, []int64{5}))
		uassert.Equal(t, settlement.eventCursor, int64(21))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(25))

		// A first fee after every event skips them all.
		settlement = resolver.loadTokenSettlement(pfTestBar, newPfTestView(41, []int64{41}, []int64{5}))
		uassert.Equal(t, settlement.eventCursor, int64(41))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(45))
	})

	t.Run("a stored token state is loaded as is", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		tokenState := staker.NewProtocolFeeTokenRewardState(3, 40, u256.NewUint(9))
		tokenState.SetEarnedX128(u256.NewUint(1234))
		resolver.SetTokenState(pfTestBar, tokenState)

		settlement := resolver.loadTokenSettlement(pfTestBar, newPfTestView(-1, nil, nil))
		uassert.Equal(t, settlement.eventCursor, int64(3))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(40))
		uassert.Equal(t, settlement.segmentStartX128.ToString(), "9")
		uassert.Equal(t, settlement.earnedX128.ToString(), "1234")
	})
}

func TestProtocolFeeRewardState_settleEvents(cur realm, t *testing.T) {
	t.Run("folds each closed segment at the accumulator before the event", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(200, 3))
		uassert.NoError(t, resolver.removeStake(300, 5))

		// per-stake: 10 after epoch 1, 12 after epoch 2, 13 after epoch 4
		view := newPfTestView(5, []int64{1, 2, 4}, []int64{10, 12, 13})
		settlement := resolver.loadTokenSettlement(pfTestBar, view)
		uassert.Equal(t, settlement.eventCursor, int64(1))

		done := resolver.settleEvents(settlement, view, 0)
		uassert.True(t, done)
		// 100 * (12 - 0) + 300 * (13 - 12)
		uassert.Equal(t, settlement.earnedX128.ToString(), x128(1500))
		uassert.Equal(t, settlement.segmentStakedAmount, int64(0))
		uassert.Equal(t, settlement.segmentStartX128.ToString(), x128(13))
	})

	t.Run("stops at maxEvents", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(100, 3))
		uassert.NoError(t, resolver.addStake(100, 5))

		view := newPfTestView(5, []int64{1, 2, 4}, []int64{10, 12, 13})
		settlement := resolver.loadTokenSettlement(pfTestBar, view)

		uassert.False(t, resolver.settleEvents(settlement, view, 1))
		uassert.Equal(t, settlement.eventCursor, int64(2))
		uassert.Equal(t, settlement.earnedX128.ToString(), x128(1200))

		uassert.True(t, resolver.settleEvents(settlement, view, 1))
		uassert.Equal(t, settlement.eventCursor, int64(3))
		uassert.Equal(t, settlement.earnedX128.ToString(), x128(1400))
	})

	t.Run("stops before an event whose previous epoch is not folded", func(cur realm, t *testing.T) {
		resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
		uassert.NoError(t, resolver.addStake(100, 1))
		uassert.NoError(t, resolver.addStake(100, 3))
		uassert.NoError(t, resolver.addStake(100, 5))

		view := newPfTestView(2, []int64{1, 2}, []int64{10, 12})
		settlement := resolver.loadTokenSettlement(pfTestBar, view)

		uassert.False(t, resolver.settleEvents(settlement, view, 0))
		uassert.Equal(t, settlement.eventCursor, int64(2))
		uassert.Equal(t, settlement.earnedX128.ToString(), x128(1200))
	})
}

func TestProtocolFeeRewardState_takeReward(cur realm, t *testing.T) {
	settlement := &protocolFeeTokenSettlement{
		earnedX128: u256.Zero().Add(u256Lsh128(7), u256.NewUint(12345)),
	}

	uassert.Equal(t, takeReward(settlement), int64(7))
	uassert.Equal(t, settlement.earnedX128.ToString(), "12345")
	uassert.Equal(t, takeReward(settlement), int64(0))
}

func TestProtocolFeeRewardState_claimTokenReward(cur realm, t *testing.T) {
	resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())
	uassert.NoError(t, resolver.addStake(100, 1))

	view := newPfTestView(1, []int64{1}, []int64{10})
	reward, err := resolver.claimTokenReward(pfTestBar, view, 0)
	uassert.NoError(t, err)
	uassert.Equal(t, reward, int64(1000))
	uassert.Equal(t, resolver.GetClaimedReward(pfTestBar), int64(1000))

	tokenState, ok := resolver.GetTokenState(pfTestBar)
	uassert.True(t, ok)
	uassert.Equal(t, tokenState.GetEventCursor(), int64(1))
	uassert.Equal(t, tokenState.GetSegmentStartX128().ToString(), x128(10))
	uassert.Equal(t, tokenState.GetEarnedX128().ToString(), "0")

	// The query agrees with the claim and does not move state.
	view = newPfTestView(2, []int64{1, 2}, []int64{10, 15})
	uassert.Equal(t, resolver.getClaimableReward(pfTestBar, view), int64(500))
	uassert.Equal(t, tokenState.GetSegmentStartX128().ToString(), x128(10))

	reward, err = resolver.claimTokenReward(pfTestBar, view, 0)
	uassert.NoError(t, err)
	uassert.Equal(t, reward, int64(500))
	uassert.Equal(t, resolver.GetClaimedReward(pfTestBar), int64(1500))
}

func TestProtocolFeeRewardState_IsClaimable(cur realm, t *testing.T) {
	resolver := NewProtocolFeeRewardStateResolver(staker.NewProtocolFeeRewardState())

	uassert.True(t, resolver.IsClaimable(1))
	resolver.SetClaimedTimestamp(10)
	uassert.False(t, resolver.IsClaimable(10))
	uassert.False(t, resolver.IsClaimable(9))
	uassert.True(t, resolver.IsClaimable(11))
}
