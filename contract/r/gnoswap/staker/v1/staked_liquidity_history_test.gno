package staker

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"

	sr "gno.land/r/gnoswap/staker"
)

func TestStakedLiquidityHistoryStoresFixedWidthStrings(cur realm, t *testing.T) {
	const createTime = int64(1000)

	pool := sr.NewPool("test_pool", createTime)
	initial, ok := pool.StakedLiquidity().Get(createTime)
	uassert.True(t, ok)
	initialString, ok := initial.(string)
	uassert.True(t, ok)
	uassert.Equal(t, 16, len(initialString))
	for i := 0; i < len(initialString); i++ {
		uassert.Equal(t, byte(0), initialString[i])
	}

	value := &u256.Uint{0x1020304050607080, 0x0102030405060708, 0, 0}
	pool.SetStakedLiquidityAt(createTime+10, value)
	stored, ok := pool.StakedLiquidity().Get(createTime + 10)
	uassert.True(t, ok)
	storedString, ok := stored.(string)
	uassert.True(t, ok)
	uassert.Equal(t, 16, len(storedString))
	wantBytes := [16]byte{1, 2, 3, 4, 5, 6, 7, 8, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80}
	for i := range wantBytes {
		uassert.Equal(t, wantBytes[i], storedString[i])
	}

	// The encoded value is independent of the caller's mutable uint256.
	expected := value.Clone()
	value[0] = 0
	resolver := NewPoolResolver(pool)
	uassert.Equal(t, expected.ToString(), resolver.CurrentStakedLiquidity(createTime+10).ToString())
}

func TestStakedLiquidityHistorySemantics(cur realm, t *testing.T) {
	const createTime = int64(1000)

	pool := sr.NewPool("test_pool", createTime)
	resolver := NewPoolResolver(pool)

	// A query before the first checkpoint has no predecessor and returns zero.
	uassert.Equal(t, "0", resolver.CurrentStakedLiquidity(createTime-1).ToString())

	pool.SetStakedLiquidityAt(createTime+10, u256.NewUint(100))
	pool.SetStakedLiquidityAt(createTime+20, u256.NewUint(200))
	uassert.Equal(t, "0", resolver.CurrentStakedLiquidity(createTime-1).ToString())
	uassert.Equal(t, "100", resolver.CurrentStakedLiquidity(createTime+15).ToString())
	uassert.Equal(t, "200", resolver.CurrentStakedLiquidity(createTime+20).ToString())

	// Rewriting one timestamp replaces its value rather than adding a second key.
	pool.SetStakedLiquidityAt(createTime+20, u256.NewUint(300))
	uassert.Equal(t, 3, pool.StakedLiquidity().Size())
	uassert.Equal(t, "300", resolver.CurrentStakedLiquidity(createTime+20).ToString())

	// A decoded value is also isolated from the string stored in the tree.
	returned := resolver.CurrentStakedLiquidity(createTime + 20)
	returned[0] = 0
	uassert.Equal(t, "300", resolver.CurrentStakedLiquidity(createTime+20).ToString())
}

func TestCurrentStakedLiquidityRejectsMalformedGenericValues(cur realm, t *testing.T) {
	const createTime = int64(1000)

	t.Run("invalid length", func(cur realm, t *testing.T) {
		pool := sr.NewPool("test_pool", createTime)
		pool.StakedLiquidity().Set(createTime+1, string(make([]byte, 15)))

		uassert.AbortsContains(t, cur, "", func() {
			NewPoolResolver(pool).CurrentStakedLiquidity(createTime + 1)
		})
	})

	t.Run("invalid value type", func(cur realm, t *testing.T) {
		pool := sr.NewPool("test_pool", createTime)
		pool.StakedLiquidity().Set(createTime+1, u256.Zero())

		uassert.AbortsContains(t, cur, "", func() {
			NewPoolResolver(pool).CurrentStakedLiquidity(createTime + 1)
		})
	})
}

func TestSetStakedLiquidityAtRejectsUint128Overflow(cur realm, t *testing.T) {
	pool := sr.NewPool("test_pool", 1000)

	uassert.AbortsContains(t, cur, "", func() {
		pool.SetStakedLiquidityAt(1001, &u256.Uint{0, 0, 1, 0})
	})
}
