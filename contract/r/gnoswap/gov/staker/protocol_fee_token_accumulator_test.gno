package staker

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestNewProtocolFeeTokenAccumulator(cur realm, t *testing.T) {
	accumulator := NewProtocolFeeTokenAccumulator()

	uassert.Equal(t, accumulator.GetAccumulatedX128PerStake().ToString(), "0")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(0).ToString(), "0")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(100).ToString(), "0")
	uassert.Equal(t, accumulator.GetFirstEpoch(), int64(-1))
	uassert.Equal(t, accumulator.GetFoldedEpoch(), int64(-1))
	uassert.Equal(t, accumulator.GetProtocolFeeAmount(), int64(0))
}

func TestProtocolFeeTokenAccumulator_History(cur realm, t *testing.T) {
	accumulator := NewProtocolFeeTokenAccumulator()

	accumulator.SetAccumulatedX128PerStakeAt(3, u256.NewUint(10))
	accumulator.SetAccumulatedX128PerStakeAt(5, u256.NewUint(25))

	// The latest value is the last one set; the first epoch is the earliest one set.
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStake().ToString(), "25")
	uassert.Equal(t, accumulator.GetFirstEpoch(), int64(3))

	// The value at an epoch is the one after the latest folded epoch at or before it.
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(-1).ToString(), "0")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(2).ToString(), "0")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(3).ToString(), "10")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(4).ToString(), "10")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(5).ToString(), "25")
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(9).ToString(), "25")

	// Folding the open epoch again overwrites its entry and keeps the first epoch.
	accumulator.SetAccumulatedX128PerStakeAt(5, u256.NewUint(30))
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStakeAt(5).ToString(), "30")
	uassert.Equal(t, accumulator.GetFirstEpoch(), int64(3))

	// Stored values are copies of the argument.
	value := u256.NewUint(40)
	accumulator.SetAccumulatedX128PerStakeAt(6, value)
	value.Add(value, u256.NewUint(1))
	uassert.Equal(t, accumulator.GetAccumulatedX128PerStake().ToString(), "40")

	accumulator.SetFoldedEpoch(5)
	accumulator.SetProtocolFeeAmount(777)
	uassert.Equal(t, accumulator.GetFoldedEpoch(), int64(5))
	uassert.Equal(t, accumulator.GetProtocolFeeAmount(), int64(777))
}
