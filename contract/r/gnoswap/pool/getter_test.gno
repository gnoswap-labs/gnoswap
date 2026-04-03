package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func newPoolFixture() *Pool {
	pool := NewPool("foo", "bar", 500, u256.MustFromDecimal("100"), 10, 5, 6)
	pool.SetBalanceToken0(1000)
	pool.SetBalanceToken1(2000)
	pool.SetProtocolFeesToken0(3000)
	pool.SetProtocolFeesToken1(4000)
	pool.SetFeeGrowthGlobal0X128(u256.MustFromDecimal("5000"))
	pool.SetFeeGrowthGlobal1X128(u256.MustFromDecimal("6000"))
	pool.SetLiquidity(u256.MustFromDecimal("7000"))
	pool.SetSlot0(newSlot0(u256.MustFromDecimal("9000"), 11, 12, true))
	return pool
}

func newTickInfoFixture() TickInfo {
	tickInfo := NewTickInfo()
	tickInfo.SetLiquidityGross("1000")
	tickInfo.SetLiquidityNet("2000")
	tickInfo.SetFeeGrowthOutside0X128("3000")
	tickInfo.SetFeeGrowthOutside1X128("4000")
	tickInfo.SetTickCumulativeOutside(5)
	tickInfo.SetSecondsPerLiquidityOutsideX128("6000")
	tickInfo.SetSecondsOutside(7)
	tickInfo.SetInitialized(true)
	return tickInfo
}

func newPositionInfoFixture() PositionInfo {
	positionInfo := PositionInfo{}
	positionInfo.SetLiquidity("1000")
	positionInfo.SetFeeGrowthInside0LastX128("2000")
	positionInfo.SetFeeGrowthInside1LastX128("3000")
	positionInfo.SetTokensOwed0(4000)
	positionInfo.SetTokensOwed1(5000)
	return positionInfo
}

func TestMutablePoolGetterIsolation(t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockPool)
		getter    func() any
		assertGot func(t *testing.T, result any)
		mutate    func(result any)
		assertRaw func(t *testing.T)
	}{
		{
			name:   "GetPoolPaths",
			setup:  func(m *MockPool) { m.Response.Set("GetPoolPaths", []string{"foo", "bar"}) },
			getter: func() any { return GetPoolPaths(0, 10) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "baz")
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetPoolPaths"][0].([]string)
				uassert.Equal(t, "foo", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name:   "GetFeeAmountTickSpacings",
			setup:  func(m *MockPool) { m.Response.Set("GetFeeAmountTickSpacings", map[uint32]int32{500: 10}) },
			getter: func() any { return GetFeeAmountTickSpacings() },
			mutate: func(result any) {
				values := result.(map[uint32]int32)
				values[500] = 20
				values[3000] = 60
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetFeeAmountTickSpacings"][0].(map[uint32]int32)
				uassert.Equal(t, int32(10), values[500])
				_, ok := values[3000]
				uassert.Equal(t, false, ok)
			},
		},
		{
			name: "GetFeeGrowthGlobalX128",
			setup: func(m *MockPool) {
				m.Response.Set("GetFeeGrowthGlobalX128", u256.MustFromDecimal("1000"), u256.MustFromDecimal("2000"))
			},
			getter: func() any {
				fee0, fee1 := GetFeeGrowthGlobalX128("foo:bar:500")
				return []any{fee0, fee1}
			},
			mutate: func(result any) {
				values := result.([]any)
				values[0] = "3000"
				values[1] = "4000"
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetFeeGrowthGlobalX128"]
				uassert.Equal(t, "1000", values[0].(*u256.Uint).ToString())
				uassert.Equal(t, "2000", values[1].(*u256.Uint).ToString())
			},
		},
		{
			name:   "GetPositionLiquidity",
			setup:  func(m *MockPool) { m.Response.Set("GetPositionLiquidity", "1000") },
			getter: func() any { return GetPositionLiquidity("foo:bar:500", "pos") },
			mutate: func(result any) {},
			assertRaw: func(t *testing.T) {
				value := implementation.(*MockPool).Response.responses["GetPositionLiquidity"][0].(string)
				uassert.Equal(t, "1000", value)
			},
		},
		{
			name:  "GetTickFeeGrowthOutsideX128",
			setup: func(m *MockPool) { m.Response.Set("GetTickFeeGrowthOutsideX128", "1100", "2200") },
			getter: func() any {
				fee0, fee1 := GetTickFeeGrowthOutsideX128("foo:bar:500", 10)
				return []any{fee0, fee1}
			},
			mutate: func(result any) {
				values := result.([]any)
				values[0] = "3300"
				values[1] = "4400"
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetTickFeeGrowthOutsideX128"]
				uassert.Equal(t, "1100", values[0].(string))
				uassert.Equal(t, "2200", values[1].(string))
			},
		},
		{
			name:   "GetSlot0SqrtPriceX96",
			setup:  func(m *MockPool) { m.Response.Set("GetSlot0SqrtPriceX96", u256.MustFromDecimal("3000")) },
			getter: func() any { return GetSlot0SqrtPriceX96("foo:bar:500") },
			mutate: func(result any) {},
			assertRaw: func(t *testing.T) {
				value := implementation.(*MockPool).Response.responses["GetSlot0SqrtPriceX96"][0].(*u256.Uint)
				uassert.Equal(t, "3000", value.ToString())
			},
		},
		{
			name:  "GetPool",
			setup: func(m *MockPool) { m.Response.Set("GetPool", newPoolFixture(), nil) },
			getter: func() any {
				pool, err := GetPool("foo", "bar", 500)
				uassert.NoError(t, err)
				return pool
			},
			mutate: func(result any) {
				pool := result.(*Pool)
				pool.SetToken0Path("mutated0")
				pool.SetToken1Path("mutated1")
				pool.SetFee(600)
				pool.SetTickSpacing(20)
				pool.SetBalanceToken0(1010)
				pool.SetBalanceToken1(2020)
				pool.SetProtocolFeesToken0(3030)
				pool.SetProtocolFeesToken1(4040)
				pool.SetFeeGrowthGlobal0X128(u256.MustFromDecimal("6060"))
				pool.SetFeeGrowthGlobal1X128(u256.MustFromDecimal("7070"))
				pool.SetLiquidity(u256.MustFromDecimal("8080"))
				slot0 := pool.Slot0()
				slot0.SetSqrtPriceX96(u256.MustFromDecimal("9090"))
				slot0.SetTick(12)
				slot0.SetFeeProtocol(13)
				slot0.SetUnlocked(false)
				pool.SetSlot0(slot0)
			},
			assertRaw: func(t *testing.T) {
				pool := implementation.(*MockPool).Response.responses["GetPool"][0].(*Pool)
				uassert.Equal(t, "foo", pool.Token0Path())
				uassert.Equal(t, "bar", pool.Token1Path())
				uassert.Equal(t, uint32(500), pool.Fee())
				uassert.Equal(t, int32(10), pool.TickSpacing())
				uassert.Equal(t, int64(1000), pool.BalanceToken0())
				uassert.Equal(t, int64(2000), pool.BalanceToken1())
				uassert.Equal(t, int64(3000), pool.ProtocolFeesToken0())
				uassert.Equal(t, int64(4000), pool.ProtocolFeesToken1())
				uassert.Equal(t, "5000", pool.FeeGrowthGlobal0X128().ToString())
				uassert.Equal(t, "6000", pool.FeeGrowthGlobal1X128().ToString())
				uassert.Equal(t, "7000", pool.Liquidity().ToString())
				uassert.Equal(t, "9000", pool.Slot0SqrtPriceX96().ToString())
				uassert.Equal(t, int32(11), pool.Slot0Tick())
				uassert.Equal(t, uint8(12), pool.Slot0FeeProtocol())
				uassert.Equal(t, true, pool.Slot0Unlocked())
			},
		},
		{
			name:   "GetPoolPositionKeys",
			setup:  func(m *MockPool) { m.Response.Set("GetPoolPositionKeys", []string{"pos0", "pos1"}) },
			getter: func() any { return GetPoolPositionKeys("foo:bar:500", 0, 10) },
			mutate: func(result any) {
				values := result.([]string)
				values[0] = "mutated"
				_ = append(values, "pos2")
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetPoolPositionKeys"][0].([]string)
				uassert.Equal(t, "pos0", values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name:  "GetTickInfo",
			setup: func(m *MockPool) { m.Response.Set("GetTickInfo", newTickInfoFixture(), nil) },
			getter: func() any {
				tickInfo, err := GetTickInfo("foo:bar:500", 10)
				uassert.NoError(t, err)
				return tickInfo
			},
			mutate: func(result any) {
				tickInfo := result.(TickInfo)
				tickInfo.SetLiquidityGross("1010")
				tickInfo.SetLiquidityNet("2020")
				tickInfo.SetFeeGrowthOutside0X128("3030")
				tickInfo.SetFeeGrowthOutside1X128("4040")
				tickInfo.SetTickCumulativeOutside(50)
				tickInfo.SetSecondsPerLiquidityOutsideX128("6060")
				tickInfo.SetSecondsOutside(70)
				tickInfo.SetInitialized(false)
			},
			assertRaw: func(t *testing.T) {
				tickInfo := implementation.(*MockPool).Response.responses["GetTickInfo"][0].(TickInfo)
				uassert.Equal(t, "1000", tickInfo.LiquidityGross())
				uassert.Equal(t, "2000", tickInfo.LiquidityNet())
				uassert.Equal(t, "3000", tickInfo.FeeGrowthOutside0X128())
				uassert.Equal(t, "4000", tickInfo.FeeGrowthOutside1X128())
				uassert.Equal(t, int64(5), tickInfo.TickCumulativeOutside())
				uassert.Equal(t, "6000", tickInfo.SecondsPerLiquidityOutsideX128())
				uassert.Equal(t, uint32(7), tickInfo.SecondsOutside())
				uassert.Equal(t, true, tickInfo.Initialized())
			},
		},
		{
			name:  "GetTickBitmaps",
			setup: func(m *MockPool) { m.Response.Set("GetTickBitmaps", "1234", nil) },
			getter: func() any {
				bitmap, err := GetTickBitmaps("foo:bar:500", 0)
				uassert.NoError(t, err)
				return bitmap
			},
			mutate: func(result any) {},
			assertRaw: func(t *testing.T) {
				bitmap := implementation.(*MockPool).Response.responses["GetTickBitmaps"][0].(string)
				uassert.Equal(t, "1234", bitmap)
			},
		},
		{
			name:  "GetPosition",
			setup: func(m *MockPool) { m.Response.Set("GetPosition", newPositionInfoFixture(), nil) },
			getter: func() any {
				positionInfo, err := GetPosition("foo:bar:500", "pos")
				uassert.NoError(t, err)
				return positionInfo
			},
			mutate: func(result any) {
				positionInfo := result.(PositionInfo)
				positionInfo.SetLiquidity("1111")
				positionInfo.SetFeeGrowthInside0LastX128("2222")
				positionInfo.SetFeeGrowthInside1LastX128("3333")
				positionInfo.SetTokensOwed0(4444)
				positionInfo.SetTokensOwed1(5555)
			},
			assertRaw: func(t *testing.T) {
				positionInfo := implementation.(*MockPool).Response.responses["GetPosition"][0].(PositionInfo)
				uassert.Equal(t, "1000", positionInfo.Liquidity())
				uassert.Equal(t, "2000", positionInfo.FeeGrowthInside0LastX128())
				uassert.Equal(t, "3000", positionInfo.FeeGrowthInside1LastX128())
				uassert.Equal(t, int64(4000), positionInfo.TokensOwed0())
				uassert.Equal(t, int64(5000), positionInfo.TokensOwed1())
			},
		},
		{
			name:   "GetInitializedTicksInRange",
			setup:  func(m *MockPool) { m.Response.Set("GetInitializedTicksInRange", []int32{-10, 10}) },
			getter: func() any { return GetInitializedTicksInRange("foo:bar:500", -20, 20) },
			mutate: func(result any) {
				values := result.([]int32)
				values[0] = -99
				_ = append(values, 99)
			},
			assertRaw: func(t *testing.T) {
				values := implementation.(*MockPool).Response.responses["GetInitializedTicksInRange"][0].([]int32)
				uassert.Equal(t, int32(-10), values[0])
				uassert.Equal(t, 2, len(values))
			},
		},
		{
			name:  "GetTWAP",
			setup: func(m *MockPool) { m.Response.Set("GetTWAP", int32(5), u256.MustFromDecimal("5000"), error(nil)) },
			getter: func() any {
				_, liquidity, err := GetTWAP("foo:bar:500", 10)
				uassert.NoError(t, err)
				return liquidity
			},
			mutate: func(result any) {},
			assertRaw: func(t *testing.T) {
				value := implementation.(*MockPool).Response.responses["GetTWAP"][1].(*u256.Uint)
				uassert.Equal(t, "5000", value.ToString())
			},
		},
		{
			name: "GetObservationState",
			setup: func(m *MockPool) {
				state := NewObservationState(100)
				state.SetIndex(3)
				state.SetCardinality(4)
				state.SetCardinalityNext(5)
				obs := NewObservation(123, 77, "1000", "2000", true)
				state.Observations()[7] = obs
				m.Response.Set("GetObservationState", state, error(nil))
			},
			getter: func() any {
				state, err := GetObservationState("foo:bar:500")
				uassert.NoError(t, err)
				return state
			},
			assertGot: func(t *testing.T, result any) {
				state := result.(*ObservationState)
				uassert.Equal(t, 2, len(state.Observations()))
				uassert.Equal(t, int64(100), state.Observations()[0].BlockTimestamp())
				uassert.Equal(t, int64(123), state.Observations()[7].BlockTimestamp())
			},
			mutate: func(result any) {
				state := result.(*ObservationState)
				state.SetIndex(8)
				state.SetCardinality(9)
				state.SetCardinalityNext(10)
				state.Observations()[8] = NewObservation(1, 2, "3", "4", true)
			},
			assertRaw: func(t *testing.T) {
				state := implementation.(*MockPool).Response.responses["GetObservationState"][0].(*ObservationState)
				uassert.Equal(t, uint16(3), state.Index())
				uassert.Equal(t, uint16(4), state.Cardinality())
				uassert.Equal(t, uint16(5), state.CardinalityNext())
				uassert.Equal(t, int64(123), state.Observations()[7].BlockTimestamp())
				uassert.Equal(t, int64(77), state.Observations()[7].TickCumulative())
				uassert.Equal(t, "1000", state.Observations()[7].LiquidityCumulative())
				uassert.Equal(t, "2000", state.Observations()[7].SecondsPerLiquidityCumulativeX128())
				uassert.Equal(t, true, state.Observations()[7].Initialized())
				_, ok := state.Observations()[8]
				uassert.Equal(t, false, ok)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			mockPool := newMockPool("v1")
			implementation = mockPool
			tt.setup(mockPool)
			result := tt.getter()
			if tt.assertGot != nil {
				tt.assertGot(t, result)
			}
			tt.mutate(result)
			tt.assertRaw(t)
		})
	}
}
