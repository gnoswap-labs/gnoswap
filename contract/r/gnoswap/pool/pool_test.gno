package pool

import (
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/avl"
	"gno.land/p/nt/uassert"
)

func makeTestPool() *Pool {
	return &Pool{
		token0Path:  "gno.land/r/onbloc/bar",
		token1Path:  "gno.land/r/onbloc/foo",
		fee:         500,
		tickSpacing: 10,
		ticks:       avl.NewTree(),
		tickBitmaps: avl.NewTree(),
		positions:   avl.NewTree(),
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
