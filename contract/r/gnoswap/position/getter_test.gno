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
		"1000",
		"2000",
		"3000",
		4000,
		5000,
		false,
		adminAddr,
	)
}

func mutatePosition(position *Position) {
	position.SetPoolKey("mutated:pool:500")
	position.SetTickLower(-200)
	position.SetTickUpper(200)
	position.SetBurned(true)
	position.SetLiquidity("1100")
	position.SetFeeGrowthInside0LastX128("2200")
	position.SetFeeGrowthInside1LastX128("3300")
	position.SetTokensOwed0(4400)
	position.SetTokensOwed1(5500)
}

func assertPositionUnchanged(t *testing.T, position *Position) {
	t.Helper()
	uassert.Equal(t, adminAddr, position.Operator())
	uassert.Equal(t, "foo:bar:3000", position.PoolKey())
	uassert.Equal(t, int32(-100), position.TickLower())
	uassert.Equal(t, int32(100), position.TickUpper())
	uassert.Equal(t, false, position.Burned())
	uassert.Equal(t, "1000", position.Liquidity())
	uassert.Equal(t, "2000", position.FeeGrowthInside0LastX128())
	uassert.Equal(t, "3000", position.FeeGrowthInside1LastX128())
	uassert.Equal(t, int64(4000), position.TokensOwed0())
	uassert.Equal(t, int64(5000), position.TokensOwed1())
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
	uassert.Equal(t, "1100", result.Liquidity())
	uassert.Equal(t, "2200", result.FeeGrowthInside0LastX128())
	uassert.Equal(t, "3300", result.FeeGrowthInside1LastX128())
	uassert.Equal(t, int64(4400), result.TokensOwed0())
	uassert.Equal(t, int64(5500), result.TokensOwed1())

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

func TestPositionTokenBalanceGetterComposition(t *testing.T) {
	resetTestState(t)
	mockPosition := newMockPosition("v1")
	implementation = mockPosition
	mockPosition.Response.Set(
		"GetPositionTokenBalances",
		int64(6000),
		int64(7000),
	)

	balance0, balance1 := GetPositionTokenBalances(1)
	uassert.Equal(t, int64(6000), balance0)
	uassert.Equal(t, int64(7000), balance1)
	uassert.Equal(t, int64(6000), GetPositionToken0Balance(1))
	uassert.Equal(t, int64(7000), GetPositionToken1Balance(1))
	uassert.Equal(t, 3, mockPosition.Response.CallCount("GetPositionTokenBalances"))
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
			name: "GetPositionFeeGrowthInside0LastX128",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionFeeGrowthInside0LastX128", "2000")
				return nil
			},
			getter:     func() any { return GetPositionFeeGrowthInside0LastX128(1) },
			mutate:     func(result any) { _ = result.(string) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "2000", result.(string)) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "2000", implementation.(*MockPosition).Response.data["GetPositionFeeGrowthInside0LastX128"][0].(string))
			},
		},
		{
			name: "GetPositionFeeGrowthInside1LastX128",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionFeeGrowthInside1LastX128", "3000")
				return nil
			},
			getter:     func() any { return GetPositionFeeGrowthInside1LastX128(1) },
			mutate:     func(result any) { _ = result.(string) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "3000", result.(string)) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "3000", implementation.(*MockPosition).Response.data["GetPositionFeeGrowthInside1LastX128"][0].(string))
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
				_ = values[0].(string)
				_ = values[1].(string)
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, "2000", values[0].(string))
				uassert.Equal(t, "3000", values[1].(string))
			},
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "2000", raw.FeeGrowthInside0LastX128())
				uassert.Equal(t, "3000", raw.FeeGrowthInside1LastX128())
			},
		},
		{
			name: "GetPositionLiquidity",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionLiquidity", "1000")
				return nil
			},
			getter:     func() any { return GetPositionLiquidity(1) },
			mutate:     func(result any) { _ = result.(string) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, "1000", result.(string)) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, "1000", implementation.(*MockPosition).Response.data["GetPositionLiquidity"][0].(string))
			},
		},
		{
			name: "GetPositionTokensOwed0",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionTokensOwed0", int64(4000))
				return nil
			},
			getter:     func() any { return GetPositionTokensOwed0(1) },
			mutate:     func(result any) { _ = result.(int64) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, int64(4000), result.(int64)) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, int64(4000), implementation.(*MockPosition).Response.data["GetPositionTokensOwed0"][0].(int64))
			},
		},
		{
			name: "GetPositionTokensOwed1",
			setup: func(m *MockPosition) *Position {
				m.Response.Set("GetPositionTokensOwed1", int64(5000))
				return nil
			},
			getter:     func() any { return GetPositionTokensOwed1(1) },
			mutate:     func(result any) { _ = result.(int64) },
			assertSame: func(t *testing.T, result any) { uassert.Equal(t, int64(5000), result.(int64)) },
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, int64(5000), implementation.(*MockPosition).Response.data["GetPositionTokensOwed1"][0].(int64))
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
				_ = values[0].(int64)
				_ = values[1].(int64)
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, int64(4000), values[0].(int64))
				uassert.Equal(t, int64(5000), values[1].(int64))
			},
			assertRaw: func(t *testing.T, raw *Position) {
				uassert.Equal(t, int64(4000), raw.TokensOwed0())
				uassert.Equal(t, int64(5000), raw.TokensOwed1())
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
				values[0] = "9920"
				values[1] = "9930"
			},
			assertSame: func(t *testing.T, result any) {
				values := result.([]any)
				uassert.Equal(t, "9920", values[0].(string))
				uassert.Equal(t, "9930", values[1].(string))
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

func TestGetPositionTokenBalances(t *testing.T) {
	t.Run("returns balances for existing position", func(t *testing.T) {
		resetTestState(t)
		mockPosition := newMockPosition("v1")
		implementation = mockPosition

		mockPosition.Response.Set("GetPositionTokenBalances", int64(6000), int64(7000))

		token0Balance, token1Balance := GetPositionTokenBalances(1)
		uassert.Equal(t, int64(6000), token0Balance)
		uassert.Equal(t, int64(7000), token1Balance)
	})

	t.Run("returns zero balances for missing position", func(t *testing.T) {
		resetTestState(t)
		mockPosition := newMockPosition("v1")
		implementation = mockPosition

		token0Balance, token1Balance := GetPositionTokenBalances(999)
		uassert.Equal(t, int64(0), token0Balance)
		uassert.Equal(t, int64(0), token1Balance)
	})
}
