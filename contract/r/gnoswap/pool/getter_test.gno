package pool

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	uassert "gno.land/p/nt/uassert/v0"
)

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

func TestMutablePoolGetterIsolation(cur realm, t *testing.T) {
	tests := []struct {
		name      string
		setup     func(m *MockPool)
		getter    func() any
		assertGot func(t *testing.T, result any)
		mutate    func(result any)
		assertRaw func(cur realm, t *testing.T)
	}{
		{
			name:   "GetFeeAmountTickSpacings",
			setup:  func(m *MockPool) { m.Response.Set("GetFeeAmountTickSpacings", map[uint32]int32{500: 10}) },
			getter: func() any { return GetFeeAmountTickSpacings() },
			mutate: func(result any) {
				values := result.(map[uint32]int32)
				values[500] = 20
				values[3000] = 60
			},
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
				value := implementation.(*MockPool).Response.responses["GetSlot0SqrtPriceX96"][0].(*u256.Uint)
				uassert.Equal(t, "3000", value.ToString())
			},
		},
		{
			name: "GetSlot0",
			setup: func(m *MockPool) {
				slot0 := NewSlot0(u256.MustFromDecimal("3000"), 12, 34, true)
				slot0.SetObservationIndex(7)
				slot0.SetObservationCardinality(8)
				slot0.SetObservationCardinalityNext(9)
				m.Response.Set("GetSlot0", slot0)
			},
			getter: func() any { return GetSlot0("foo:bar:500") },
			assertGot: func(t *testing.T, result any) {
				slot0 := result.(Slot0)
				uassert.Equal(t, "3000", slot0.SqrtPriceX96().ToString())
				uassert.Equal(t, int32(12), slot0.Tick())
				uassert.Equal(t, uint8(34), slot0.FeeProtocol())
				uassert.Equal(t, true, slot0.Unlocked())
				uassert.Equal(t, uint16(7), slot0.ObservationIndex())
				uassert.Equal(t, uint16(8), slot0.ObservationCardinality())
				uassert.Equal(t, uint16(9), slot0.ObservationCardinalityNext())
			},
			mutate: func(result any) {
				slot0 := result.(Slot0)
				slot0.SetSqrtPriceX96(u256.MustFromDecimal("9000"))
				slot0.SetObservationIndex(70)
				slot0.SetObservationCardinality(80)
				slot0.SetObservationCardinalityNext(90)
			},
			assertRaw: func(cur realm, t *testing.T) {
				slot0 := implementation.(*MockPool).Response.responses["GetSlot0"][0].(Slot0)
				uassert.Equal(t, "3000", slot0.SqrtPriceX96().ToString())
				uassert.Equal(t, uint16(7), slot0.ObservationIndex())
				uassert.Equal(t, uint16(8), slot0.ObservationCardinality())
				uassert.Equal(t, uint16(9), slot0.ObservationCardinalityNext())
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
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
				bitmap := implementation.(*MockPool).Response.responses["GetTickBitmaps"][0].(string)
				uassert.Equal(t, "1234", bitmap)
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
			assertRaw: func(cur realm, t *testing.T) {
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
			assertRaw: func(cur realm, t *testing.T) {
				value := implementation.(*MockPool).Response.responses["GetTWAP"][1].(*u256.Uint)
				uassert.Equal(t, "5000", value.ToString())
			},
		},
		{
			name: "GetObservationState",
			setup: func(m *MockPool) {
				state := NewObservationState(100)
				obs := NewObservation(123, 77, "2000", true)
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
				state.Observations()[8] = NewObservation(1, 2, "4", true)
			},
			assertRaw: func(cur realm, t *testing.T) {
				state := implementation.(*MockPool).Response.responses["GetObservationState"][0].(*ObservationState)
				uassert.Equal(t, int64(123), state.Observations()[7].BlockTimestamp())
				uassert.Equal(t, int64(77), state.Observations()[7].TickCumulative())
				uassert.Equal(t, "2000", state.Observations()[7].SecondsPerLiquidityCumulativeX128())
				uassert.Equal(t, true, state.Observations()[7].Initialized())
				_, ok := state.Observations()[8]
				uassert.Equal(t, false, ok)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockPool := newMockPool("v1")
			implementation = mockPool
			tt.setup(mockPool)
			result := tt.getter()
			if tt.assertGot != nil {
				tt.assertGot(t, result)
			}
			tt.mutate(result)
			tt.assertRaw(cur, t)
		})
	}
}

func TestReadOnlyTreeGetters(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		method   string
		getter   func() *rotree.ReadOnlyTree
		wantKeys []string
	}{
		{
			name:     "GetPools",
			method:   "GetPools",
			getter:   func() *rotree.ReadOnlyTree { return GetPools() },
			wantKeys: []string{"foo:bar:500", "foo:baz:3000"},
		},
		{
			name:     "GetPoolPositions",
			method:   "GetPoolPositions",
			getter:   func() *rotree.ReadOnlyTree { return GetPoolPositions("foo:bar:500") },
			wantKeys: []string{"pos0", "pos1"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			resetTestState(t)
			mockPool := newMockPool("v1")
			implementation = mockPool

			tree := bptree.NewBPTree32()
			for i, key := range tt.wantKeys {
				tree.Set(key, i)
			}
			mockPool.Response.Set(tt.method, rotree.Wrap(tree, nil))

			got := tt.getter()
			uassert.Equal(t, len(tt.wantKeys), got.Size())

			keys := make([]string, 0, got.Size())
			got.IterateByOffset(0, got.Size(), func(key string, value any) bool {
				keys = append(keys, key)
				return false
			})
			uassert.Equal(t, len(tt.wantKeys), len(keys))
			for i, want := range tt.wantKeys {
				uassert.Equal(t, want, keys[i])
			}

			uassert.True(t, got.Has(tt.wantKeys[0]))
			uassert.Equal(t, 0, got.Get(tt.wantKeys[0]).(int))

			// The view refuses writes, so the underlying tree stays untouched.
			uassert.PanicsWithMessage(t, cur, "Set operation not supported on ReadOnlyTree", func() {
				got.Set("mutated", 0)
			})
			uassert.PanicsWithMessage(t, cur, "Remove operation not supported on ReadOnlyTree", func() {
				got.Remove(tt.wantKeys[0])
			})
			uassert.Equal(t, len(tt.wantKeys), tree.Size())
		})
	}
}

func TestReadOnlyTreeGetters_NoImplementationResponse(cur realm, t *testing.T) {
	resetTestState(t)
	mockPool := newMockPool("v1")
	implementation = mockPool

	uassert.True(t, GetPools() == nil)
	uassert.True(t, GetPoolPositions("foo:bar:500") == nil)
}
