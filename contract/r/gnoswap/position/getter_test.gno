package position

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func newStoredPosition() *Position {
	return NewPosition(
		"foo:bar:3000",
		-100,
		100,
		u256.MustFromDecimal("1000"),
		u256.MustFromDecimal("2000"),
		u256.MustFromDecimal("3000"),
		u256.MustFromDecimal("4000"),
		u256.MustFromDecimal("5000"),
		false,
		adminAddr,
	)
}

func mutatePosition(position *Position) {
	position.SetPoolKey("mutated:pool:500")
	position.SetTickLower(-200)
	position.SetTickUpper(200)
	position.SetBurned(true)
	position.Liquidity().Set(u256.MustFromDecimal("1100"))
	position.FeeGrowthInside0LastX128().Set(u256.MustFromDecimal("2200"))
	position.FeeGrowthInside1LastX128().Set(u256.MustFromDecimal("3300"))
	position.TokensOwed0().Set(u256.MustFromDecimal("4400"))
	position.TokensOwed1().Set(u256.MustFromDecimal("5500"))
}

func assertPositionUnchanged(t *testing.T, position *Position) {
	t.Helper()
	uassert.Equal(t, adminAddr, position.Operator())
	uassert.Equal(t, "foo:bar:3000", position.PoolKey())
	uassert.Equal(t, int32(-100), position.TickLower())
	uassert.Equal(t, int32(100), position.TickUpper())
	uassert.Equal(t, false, position.Burned())
	uassert.Equal(t, "1000", position.Liquidity().ToString())
	uassert.Equal(t, "2000", position.FeeGrowthInside0LastX128().ToString())
	uassert.Equal(t, "3000", position.FeeGrowthInside1LastX128().ToString())
	uassert.Equal(t, "4000", position.TokensOwed0().ToString())
	uassert.Equal(t, "5000", position.TokensOwed1().ToString())
}

func TestGetPositionIsolation(t *testing.T) {
	resetTestState(t)
	mockPosition := newMockPosition("v1")
	implementation = mockPosition
	storedPosition := newStoredPosition()
	mockPosition.Response.Set("GetPosition", *storedPosition, true)
	result, err := GetPosition(1)
	if err != nil {
		t.Fatalf("GetPosition() unexpected error: %v", err)
	}

	mutatePosition(&result)

	assertPositionUnchanged(t, storedPosition)
	uassert.Equal(t, adminAddr, result.Operator())
	uassert.Equal(t, "mutated:pool:500", result.PoolKey())
	uassert.Equal(t, int32(-200), result.TickLower())
	uassert.Equal(t, int32(200), result.TickUpper())
	uassert.Equal(t, true, result.Burned())
	uassert.Equal(t, "1100", result.Liquidity().ToString())
	uassert.Equal(t, "2200", result.FeeGrowthInside0LastX128().ToString())
	uassert.Equal(t, "3300", result.FeeGrowthInside1LastX128().ToString())
	uassert.Equal(t, "4400", result.TokensOwed0().ToString())
	uassert.Equal(t, "5500", result.TokensOwed1().ToString())

	if storedPosition.Liquidity() == result.Liquidity() ||
		storedPosition.FeeGrowthInside0LastX128() == result.FeeGrowthInside0LastX128() ||
		storedPosition.FeeGrowthInside1LastX128() == result.FeeGrowthInside1LastX128() ||
		storedPosition.TokensOwed0() == result.TokensOwed0() ||
		storedPosition.TokensOwed1() == result.TokensOwed1() {
		t.Fatal("GetPosition() returned aliased nested mutable state")
	}
}

func TestGetPositionIDsIsolation(t *testing.T) {
	resetTestState(t)
	mockPosition := newMockPosition("v1")
	implementation = mockPosition
	stored := []uint64{1, 2, 3}
	mockPosition.Response.Set("GetPositionIDs", stored)

	result := GetPositionIDs(0, 10)
	result[0] = 99
	result = append(result, 100)

	uassert.Equal(t, uint64(1), stored[0])
	uassert.Equal(t, 3, len(stored))
	if len(stored) > 0 && len(result) > 0 && &stored[0] == &result[0] {
		t.Fatal("GetPositionIDs() returned aliased slice backing array")
	}
}

func TestMutablePositionGetterIsolation(t *testing.T) {
	tests := []struct {
		name       string
		setup      func(m *MockPosition) *Position
		getter     func() any
		mutate     func(result any)
		assertSame func(t *testing.T, result any)
		assertRaw  func(t *testing.T, raw *Position)
	}{
		{
			name: "GetPositionToken0Balance",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionToken0Balance", u256.MustFromDecimal("6000"))
				return nil
			},
			getter: func() any { return GetPositionToken0Balance(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9000")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9000", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "6000", implementation.(*MockPosition).Response.data["GetPositionToken0Balance"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionToken1Balance",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionToken1Balance", u256.MustFromDecimal("7000"))
				return nil
			},
			getter: func() any { return GetPositionToken1Balance(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9100")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9100", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "7000", implementation.(*MockPosition).Response.data["GetPositionToken1Balance"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionFeeGrowthInside0LastX128",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionFeeGrowthInside0LastX128", u256.MustFromDecimal("2000"))
				return nil
			},
			getter: func() any { return GetPositionFeeGrowthInside0LastX128(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9200")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9200", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "2000", implementation.(*MockPosition).Response.data["GetPositionFeeGrowthInside0LastX128"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionFeeGrowthInside1LastX128",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionFeeGrowthInside1LastX128", u256.MustFromDecimal("3000"))
				return nil
			},
			getter: func() any { return GetPositionFeeGrowthInside1LastX128(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9300")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9300", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "3000", implementation.(*MockPosition).Response.data["GetPositionFeeGrowthInside1LastX128"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionFeeGrowthInsideLastX128",
			setup: func(m *MockPosition) *Position {
				stored := newStoredPosition()
				m.Response.Set("GetPosition", *stored, true)
				return stored
			},
			getter: func() any {
				fee0, fee1 := GetPositionFeeGrowthInsideLastX128(1)
				return []any{fee0, fee1}
			},
			mutate: func(result any) {
				values := result.([]any)
				values[0].(*u256.Uint).Set(u256.MustFromDecimal("9400"))
				values[1].(*u256.Uint).Set(u256.MustFromDecimal("9500"))
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, "9400", values[0].(*u256.Uint).ToString())
				uassert.Equal(t, "9500", values[1].(*u256.Uint).ToString())
			},
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "2000", raw.FeeGrowthInside0LastX128().ToString())
				uassert.Equal(t, "3000", raw.FeeGrowthInside1LastX128().ToString())
			},
		},
		{
			name: "GetPositionLiquidity",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionLiquidity", u256.MustFromDecimal("1000"))
				return nil
			},
			getter: func() any { return GetPositionLiquidity(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9600")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9600", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "1000", implementation.(*MockPosition).Response.data["GetPositionLiquidity"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionTokensOwed0",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionTokensOwed0", u256.MustFromDecimal("4000"))
				return nil
			},
			getter: func() any { return GetPositionTokensOwed0(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9700")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9700", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "4000", implementation.(*MockPosition).Response.data["GetPositionTokensOwed0"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionTokensOwed1",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionTokensOwed1", u256.MustFromDecimal("5000"))
				return nil
			},
			getter: func() any { return GetPositionTokensOwed1(1) },
			mutate: func(result any) { result.(*u256.Uint).Set(u256.MustFromDecimal("9800")) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "9800", result.(*u256.Uint).ToString()) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "5000", implementation.(*MockPosition).Response.data["GetPositionTokensOwed1"][0].(*u256.Uint).ToString())
			},
		},
		{
			name: "GetPositionTokensOwed",
			setup: func(m *MockPosition) *Position {
				stored := newStoredPosition()
				m.Response.Set("GetPosition", *stored, true)
				return stored
			},
			getter: func() any {
				owed0, owed1 := GetPositionTokensOwed(1)
				return []any{owed0, owed1}
			},
			mutate: func(result any) {
				values := result.([]any)
				values[0].(*u256.Uint).Set(u256.MustFromDecimal("9900"))
				values[1].(*u256.Uint).Set(u256.MustFromDecimal("9910"))
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, "9900", values[0].(*u256.Uint).ToString())
				uassert.Equal(t, "9910", values[1].(*u256.Uint).ToString())
			},
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "4000", raw.TokensOwed0().ToString())
				uassert.Equal(t, "5000", raw.TokensOwed1().ToString())
			},
		},
		{
			name: "GetUnclaimedFee",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetUnclaimedFee", u256.MustFromDecimal("1111"), u256.MustFromDecimal("2222"))
				return nil
			},
			getter: func() any {
				fee0, fee1 := GetUnclaimedFee(1)
				return []any{fee0, fee1}
			},
			mutate: func(result any) {
				values := result.([]any)
				values[0].(*u256.Uint).Set(u256.MustFromDecimal("9920"))
				values[1].(*u256.Uint).Set(u256.MustFromDecimal("9930"))
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, "9920", values[0].(*u256.Uint).ToString())
				uassert.Equal(t, "9930", values[1].(*u256.Uint).ToString())
			},
			assertRaw: func(t *testing.T, raw *Position) {
				values := implementation.(*MockPosition).Response.data["GetUnclaimedFee"]
				uassert.Equal(t, "1111", values[0].(*u256.Uint).ToString())
				uassert.Equal(t, "2222", values[1].(*u256.Uint).ToString())
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			mockPosition := newMockPosition("v1")
			implementation = mockPosition
			stored := tt.setup(mockPosition)

			result := tt.getter()
			tt.mutate(result)
			tt.assertSame(t, result)
			tt.assertRaw(t, stored)
		})
	}
}
