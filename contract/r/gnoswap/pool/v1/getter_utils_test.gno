package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
	pl "gno.land/r/gnoswap/pool"
)

func TestClonePoolEntry(cur realm, t *testing.T) {
	t.Run("returns nil for a value that is not a pool", func(cur realm, t *testing.T) {
		uassert.Equal(t, nil, clonePoolEntry("not a pool"))
		uassert.Equal(t, nil, clonePoolEntry(nil))
	})

	t.Run("returns a copy the caller cannot write back through", func(cur realm, t *testing.T) {
		stored := pl.NewPool("token0", "token1", 3000, u256.MustFromDecimal("100"), 10, 5, 6)
		stored.SetBalanceToken0(1000)
		slot0 := stored.Slot0()
		slot0.SetObservationIndex(7)
		slot0.SetObservationCardinality(8)
		slot0.SetObservationCardinalityNext(9)
		stored.SetSlot0(slot0)

		cloned, ok := clonePoolEntry(stored).(*pl.Pool)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.BalanceToken0(), cloned.BalanceToken0())
		clonedSlot0 := cloned.Slot0()
		uassert.Equal(t, uint16(7), clonedSlot0.ObservationIndex())
		uassert.Equal(t, uint16(8), clonedSlot0.ObservationCardinality())
		uassert.Equal(t, uint16(9), clonedSlot0.ObservationCardinalityNext())

		cloned.SetBalanceToken0(2000)
		uassert.Equal(t, int64(1000), stored.BalanceToken0())
	})

	t.Run("returns a distinct copy per read", func(cur realm, t *testing.T) {
		stored := pl.NewPool("token0", "token1", 3000, u256.MustFromDecimal("100"), 10, 5, 6)

		first, ok := clonePoolEntry(stored).(*pl.Pool)
		uassert.True(t, ok)
		second, ok := clonePoolEntry(stored).(*pl.Pool)
		uassert.True(t, ok)
		uassert.False(t, first == second)
	})
}
