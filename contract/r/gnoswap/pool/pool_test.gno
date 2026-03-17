package pool

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	avl "gno.land/p/nt/avl/v0"
	uassert "gno.land/p/nt/uassert/v0"
)

func makeTestPool() *Pool {
	return &Pool{
		token0Path:  "gno.land/r/onbloc/bar",
		token1Path:  "gno.land/r/onbloc/foo",
		fee:         500,
		tickSpacing: 10,
		ticks:       *avl.NewTree(),
		tickBitmaps: *avl.NewTree(),
		positions:   *avl.NewTree(),
	}
}

func makeTestTickInfo(liquidityGross, feeGrowth0, feeGrowth1, liquidityNet string, initialized bool) TickInfo {
	info := NewTickInfo()
	info.SetLiquidityGross(u256.MustFromDecimal(liquidityGross))
	info.SetLiquidityNet(i256.MustFromDecimal(liquidityNet))
	info.SetFeeGrowthOutside0X128(u256.MustFromDecimal(feeGrowth0))
	info.SetFeeGrowthOutside1X128(u256.MustFromDecimal(feeGrowth1))
	info.SetInitialized(initialized)
	return info
}

func TestPool_HasTick(t *testing.T) {
	pool := makeTestPool()
	tick := int32(100)

	uassert.False(t, pool.HasTick(tick))

	tickInfo := makeTestTickInfo("1000", "100", "200", "500", true)
	pool.SetTick(tick, tickInfo)

	uassert.True(t, pool.HasTick(tick))
	uassert.False(t, pool.HasTick(200))
}

func TestPool_GetTick(t *testing.T) {
	pool := makeTestPool()
	tick := int32(100)

	_, err := pool.GetTick(tick)
	uassert.NotNil(t, err)

	expected := makeTestTickInfo("1000", "100", "200", "500", true)
	pool.SetTick(tick, expected)

	got, err := pool.GetTick(tick)
	uassert.Nil(t, err)
	uassert.Equal(t, expected.LiquidityGross().ToString(), got.LiquidityGross().ToString())
	uassert.Equal(t, expected.LiquidityNet().ToString(), got.LiquidityNet().ToString())
	uassert.Equal(t, expected.Initialized(), got.Initialized())
}

func TestPool_SetTick(t *testing.T) {
	pool := makeTestPool()
	tick := int32(100)

	info1 := makeTestTickInfo("1000", "100", "200", "500", true)
	pool.SetTick(tick, info1)

	got1, _ := pool.GetTick(tick)
	uassert.Equal(t, "1000", got1.LiquidityGross().ToString())

	info2 := makeTestTickInfo("2000", "300", "400", "1000", true)
	pool.SetTick(tick, info2)

	got2, _ := pool.GetTick(tick)
	uassert.Equal(t, "2000", got2.LiquidityGross().ToString())
}

func TestPool_DeleteTick(t *testing.T) {
	pool := makeTestPool()
	tick := int32(100)

	tickInfo := makeTestTickInfo("1000", "100", "200", "500", true)
	pool.SetTick(tick, tickInfo)
	uassert.True(t, pool.HasTick(tick))

	pool.DeleteTick(tick)
	uassert.False(t, pool.HasTick(tick))

	_, err := pool.GetTick(tick)
	uassert.NotNil(t, err)
}

func TestPool_IterateTicks(t *testing.T) {
	pool := makeTestPool()

	ticks := []int32{-100, 0, 100, 200, 300}
	for _, tick := range ticks {
		info := makeTestTickInfo("1000", "100", "200", "500", true)
		pool.SetTick(tick, info)
	}

	t.Run("iterate all", func(t *testing.T) {
		visited := []int32{}
		pool.IterateTicks(-100, 300, func(tick int32, _ TickInfo) bool {
			visited = append(visited, tick)
			return false
		})

		uassert.Equal(t, len(ticks), len(visited))
		for i, tick := range ticks {
			uassert.Equal(t, tick, visited[i])
		}
	})

	t.Run("iterate partial range", func(t *testing.T) {
		visited := []int32{}
		pool.IterateTicks(0, 200, func(tick int32, _ TickInfo) bool {
			visited = append(visited, tick)
			return false
		})

		expected := []int32{0, 100, 200}
		uassert.Equal(t, len(expected), len(visited))
		for i, tick := range expected {
			uassert.Equal(t, tick, visited[i])
		}
	})

	t.Run("empty range", func(t *testing.T) {
		visited := []int32{}
		pool.IterateTicks(400, 500, func(tick int32, _ TickInfo) bool {
			visited = append(visited, tick)
			return false
		})

		uassert.Equal(t, 0, len(visited))
	})
}

func TestPool_TickMethods_NegativeTicks(t *testing.T) {
	pool := makeTestPool()
	ticks := []int32{-MAX_TICK, -100000, -1000, -100, -1}

	for _, tick := range ticks {
		info := makeTestTickInfo("1000", "100", "200", "-500", true)

		pool.SetTick(tick, info)
		uassert.True(t, pool.HasTick(tick))

		got, err := pool.GetTick(tick)
		uassert.Nil(t, err)
		uassert.Equal(t, info.LiquidityGross().ToString(), got.LiquidityGross().ToString())

		pool.DeleteTick(tick)
		uassert.False(t, pool.HasTick(tick))
	}
}

func TestPool_TickMethods_BoundaryTicks(t *testing.T) {
	pool := makeTestPool()
	ticks := []int32{-MAX_TICK, MAX_TICK}

	for _, tick := range ticks {
		info := makeTestTickInfo("999999", "1000", "2000", "500000", true)

		pool.SetTick(tick, info)
		uassert.True(t, pool.HasTick(tick))

		got, err := pool.GetTick(tick)
		uassert.Nil(t, err)
		uassert.Equal(t, info.LiquidityGross().ToString(), got.LiquidityGross().ToString())
	}
}

// TestTickInfo_ValueTypeImmutability verifies that TickInfo retrieved from
// avl.Tree is an independent value copy.
//
// Verifies no external mutation
func TestTickInfo_ValueTypeImmutability(t *testing.T) {
	const tick = int32(100)

	mutationTests := []struct {
		name   string
		mutate func(info TickInfo)
	}{
		{
			"setter mutation does not affect tree",
			func(info TickInfo) {
				info.SetLiquidityGross(u256.MustFromDecimal("9999"))
				info.SetLiquidityNet(i256.MustFromDecimal("-9999"))
				info.SetFeeGrowthOutside0X128(u256.MustFromDecimal("8888"))
				info.SetFeeGrowthOutside1X128(u256.MustFromDecimal("7777"))
				info.SetSecondsPerLiquidityOutsideX128(u256.MustFromDecimal("6666"))
				info.SetSecondsOutside(12345)
				info.SetTickCumulativeOutside(99999)
				info.SetInitialized(false)
			},
		},
		{
			"accessor pointer arithmetic does not affect tree",
			func(info TickInfo) {
				info.LiquidityGross().Add(info.LiquidityGross(), u256.MustFromDecimal("1000"))
				info.FeeGrowthOutside0X128().Set(u256.MustFromDecimal("99999"))
			},
		},
	}

	for _, tt := range mutationTests {
		t.Run(tt.name, func(t *testing.T) {
			pool := makeCanonicalTickPool(tick)
			retrieved, _ := pool.GetTick(tick)
			tt.mutate(retrieved)
			verifyTickInfoUnchanged(t, pool, tick)
		})
	}

	t.Run("two retrievals are independent copies", func(t *testing.T) {
		pool := makeCanonicalTickPool(tick)

		copy1, _ := pool.GetTick(tick)
		copy2, _ := pool.GetTick(tick)

		copy1.SetLiquidityGross(u256.MustFromDecimal("0"))
		uassert.Equal(t, "1000", copy2.LiquidityGross().ToString())
	})

	t.Run("changes require explicit SetTick", func(t *testing.T) {
		pool := makeCanonicalTickPool(tick)

		modified, _ := pool.GetTick(tick)
		modified.SetLiquidityGross(u256.MustFromDecimal("2000"))

		// without SetTick -> tree unchanged
		verifyTickInfoUnchanged(t, pool, tick)

		// with SetTick -> tree updated
		pool.SetTick(tick, modified)
		stored, _ := pool.GetTick(tick)
		uassert.Equal(t, "2000", stored.LiquidityGross().ToString())
	})

	t.Run("iterate returns independent copies", func(t *testing.T) {
		pool := makeTestPool()
		pool.SetTick(100, makeTestTickInfo("1000", "100", "200", "500", true))
		pool.SetTick(200, makeTestTickInfo("2000", "300", "400", "1000", true))

		pool.IterateTicks(100, 200, func(tick int32, info TickInfo) bool {
			info.SetLiquidityGross(u256.MustFromDecimal("0"))
			info.LiquidityGross().Set(u256.MustFromDecimal("0"))
			return false
		})

		t1, _ := pool.GetTick(100)
		t2, _ := pool.GetTick(200)
		uassert.Equal(t, "1000", t1.LiquidityGross().ToString())
		uassert.Equal(t, "2000", t2.LiquidityGross().ToString())
	})

	t.Run("cross-tick isolation", func(t *testing.T) {
		pool := makeTestPool()
		pool.SetTick(100, makeTestTickInfo("1000", "10", "20", "500", true))
		pool.SetTick(200, makeTestTickInfo("2000", "30", "40", "1000", true))
		pool.SetTick(300, makeTestTickInfo("3000", "50", "60", "1500", true))

		// mutate tick 200's copy
		t200, _ := pool.GetTick(200)
		t200.SetLiquidityGross(u256.MustFromDecimal("0"))
		t200.SetFeeGrowthOutside0X128(u256.MustFromDecimal("0"))

		// all ticks retain original values
		s100, _ := pool.GetTick(100)
		s200, _ := pool.GetTick(200)
		s300, _ := pool.GetTick(300)

		uassert.Equal(t, "1000", s100.LiquidityGross().ToString())
		uassert.Equal(t, "2000", s200.LiquidityGross().ToString())
		uassert.Equal(t, "3000", s300.LiquidityGross().ToString())
		uassert.Equal(t, "10", s100.FeeGrowthOutside0X128().ToString())
		uassert.Equal(t, "30", s200.FeeGrowthOutside0X128().ToString())
		uassert.Equal(t, "50", s300.FeeGrowthOutside0X128().ToString())
	})
}

// TestPositionInfo_ValueTypeImmutability verifies that PositionInfo retrieved
// from avl.Tree is an independent value copy.
func TestPositionInfo_ValueTypeImmutability(t *testing.T) {
	const key = "pos_key"

	mutationTests := []struct {
		name   string
		mutate func(info PositionInfo)
	}{
		{
			"setter mutation does not affect tree",
			func(info PositionInfo) {
				info.SetLiquidity(u256.MustFromDecimal("0"))
				info.SetFeeGrowthInside0LastX128(u256.MustFromDecimal("99999"))
				info.SetFeeGrowthInside1LastX128(u256.MustFromDecimal("88888"))
				info.SetTokensOwed0(u256.MustFromDecimal("77777"))
				info.SetTokensOwed1(u256.MustFromDecimal("66666"))
			},
		},
		{
			"accessor pointer arithmetic does not affect tree",
			func(info PositionInfo) {
				info.Liquidity().Add(info.Liquidity(), u256.MustFromDecimal("7000"))
				info.TokensOwed0().Set(u256.MustFromDecimal("99999"))
			},
		},
	}

	for _, tt := range mutationTests {
		t.Run(tt.name, func(t *testing.T) {
			pool := makeCanonicalPositionPool(key)
			iVal, _ := pool.positions.Get(key)
			retrieved := iVal.(PositionInfo)
			tt.mutate(retrieved)
			verifyPositionInfoUnchanged(t, pool, key)
		})
	}

	t.Run("two retrievals are independent copies", func(t *testing.T) {
		pool := makeCanonicalPositionPool(key)

		iVal1, _ := pool.positions.Get(key)
		copy1 := iVal1.(PositionInfo)

		iVal2, _ := pool.positions.Get(key)
		copy2 := iVal2.(PositionInfo)

		copy1.SetLiquidity(u256.MustFromDecimal("0"))
		uassert.Equal(t, "5000", copy2.Liquidity().ToString())
	})
}

// TestValueType_SetterDereferencesInput verifies that setters store a
// dereferenced copy, so mutating the original pointer after setting
// does not propagate to the stored value.
func TestValueType_SetterDereferencesInput(t *testing.T) {
	t.Run("Pool", func(t *testing.T) {
		pool := makeTestPool()
		val := u256.MustFromDecimal("1000")
		pool.SetFeeGrowthGlobal0X128(val)
		val.Set(u256.MustFromDecimal("9999"))
		uassert.Equal(t, "1000", pool.FeeGrowthGlobal0X128().ToString())
	})

	t.Run("TickInfo", func(t *testing.T) {
		info := NewTickInfo()
		val := u256.MustFromDecimal("5000")
		info.SetLiquidityGross(val)
		val.Set(u256.MustFromDecimal("9999"))
		uassert.Equal(t, "5000", info.LiquidityGross().ToString())
	})

	t.Run("PositionInfo", func(t *testing.T) {
		info := NewPositionInfo(
			u256.MustFromDecimal("1000"),
			u256.MustFromDecimal("100"),
			u256.MustFromDecimal("200"),
			u256.MustFromDecimal("10"),
			u256.MustFromDecimal("20"),
		)
		val := u256.MustFromDecimal("8000")
		info.SetLiquidity(val)
		val.Set(u256.MustFromDecimal("0"))
		uassert.Equal(t, "8000", info.Liquidity().ToString())
	})
}

// TestValueType_ZeroInitialization verifies that constructors produce
// properly zero-initialized structs and handle nil arguments safely.
func TestValueType_ZeroInitialization(t *testing.T) {
	t.Run("NewTickInfo", func(t *testing.T) {
		info := NewTickInfo()
		uassert.Equal(t, "0", info.LiquidityGross().ToString())
		uassert.Equal(t, "0", info.LiquidityNet().ToString())
		uassert.Equal(t, "0", info.FeeGrowthOutside0X128().ToString())
		uassert.Equal(t, "0", info.FeeGrowthOutside1X128().ToString())
		uassert.Equal(t, "0", info.SecondsPerLiquidityOutsideX128().ToString())
		uassert.Equal(t, uint32(0), info.SecondsOutside())
		uassert.Equal(t, int64(0), info.TickCumulativeOutside())
		uassert.False(t, info.Initialized())
	})

	t.Run("NewPositionInfo with nil args", func(t *testing.T) {
		info := NewPositionInfo(nil, nil, nil, nil, nil)
		uassert.Equal(t, "0", info.Liquidity().ToString())
		uassert.Equal(t, "0", info.FeeGrowthInside0LastX128().ToString())
		uassert.Equal(t, "0", info.FeeGrowthInside1LastX128().ToString())
		uassert.Equal(t, "0", info.TokensOwed0().ToString())
		uassert.Equal(t, "0", info.TokensOwed1().ToString())
	})
}

// TestPool_ValueFieldAccessorMutatesPool verifies that Pool-level value
// field accessors (feeGrowthGlobal, liquidity) return &pool.field, so
// mutations through the returned pointer DO affect the Pool. This is
// intentional behavior — Pool is managed by pointer.
func TestPool_ValueFieldAccessorMutatesPool(t *testing.T) {
	pool := makeTestPool()
	pool.SetFeeGrowthGlobal0X128(u256.MustFromDecimal("1000"))
	pool.SetFeeGrowthGlobal1X128(u256.MustFromDecimal("2000"))
	pool.SetLiquidity(u256.MustFromDecimal("5000"))

	pool.FeeGrowthGlobal0X128().Add(
		pool.FeeGrowthGlobal0X128(), u256.MustFromDecimal("500"),
	)

	uassert.Equal(t, "1500", pool.FeeGrowthGlobal0X128().ToString())
	uassert.Equal(t, "2000", pool.FeeGrowthGlobal1X128().ToString())
	uassert.Equal(t, "5000", pool.Liquidity().ToString())
}

func verifyTickInfoUnchanged(t *testing.T, pool *Pool, tick int32) {
	t.Helper()
	stored, err := pool.GetTick(tick)
	uassert.Nil(t, err)
	uassert.Equal(t, "1000", stored.LiquidityGross().ToString())
	uassert.Equal(t, "500", stored.LiquidityNet().ToString())
	uassert.Equal(t, "100", stored.FeeGrowthOutside0X128().ToString())
	uassert.Equal(t, "200", stored.FeeGrowthOutside1X128().ToString())
	uassert.True(t, stored.Initialized())
}

func verifyPositionInfoUnchanged(t *testing.T, pool *Pool, key string) {
	t.Helper()
	iStored, ok := pool.positions.Get(key)
	uassert.True(t, ok)
	stored := iStored.(PositionInfo)
	uassert.Equal(t, "5000", stored.Liquidity().ToString())
	uassert.Equal(t, "100", stored.FeeGrowthInside0LastX128().ToString())
	uassert.Equal(t, "200", stored.FeeGrowthInside1LastX128().ToString())
	uassert.Equal(t, "50", stored.TokensOwed0().ToString())
	uassert.Equal(t, "60", stored.TokensOwed1().ToString())
}

func makeCanonicalTickPool(tick int32) *Pool {
	pool := makeTestPool()
	pool.SetTick(tick, makeTestTickInfo("1000", "100", "200", "500", true))
	return pool
}

func makeCanonicalPositionPool(key string) *Pool {
	pool := makeTestPool()
	pool.positions.Set(key, NewPositionInfo(
		u256.MustFromDecimal("5000"),
		u256.MustFromDecimal("100"),
		u256.MustFromDecimal("200"),
		u256.MustFromDecimal("50"),
		u256.MustFromDecimal("60"),
	))
	return pool
}
