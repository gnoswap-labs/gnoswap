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

		cloned, ok := clonePoolEntry(stored).(*pl.Pool)
		uassert.True(t, ok)
		uassert.False(t, cloned == stored)
		uassert.Equal(t, stored.BalanceToken0(), cloned.BalanceToken0())

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
