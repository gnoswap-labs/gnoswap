package position

import (
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	bptree "gno.land/p/nt/bptree/v0"
	rotree "gno.land/p/nt/bptree/v0/rotree"
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

func TestGetPositionsIsolation(cur realm, t *testing.T) {
	resetTestState(t)
	mockPosition := newMockPosition("v1")
	implementation = mockPosition

	stored := bptree.NewBPTree32()
	stored.Set("1", uint64(1))
	stored.Set("2", uint64(2))
	mockPosition.Response.Set("GetPositions", rotree.Wrap(stored, nil))

	result := GetPositions()
	uassert.Equal(t, 2, result.Size())

	keys := make([]string, 0, result.Size())
	result.IterateByOffset(0, result.Size(), func(key string, _ any) bool {
		keys = append(keys, key)
		return false
	})
	uassert.Equal(t, "1", keys[0])
	uassert.Equal(t, "2", keys[1])

	// The view refuses writes, so the stored tree stays untouched.
	uassert.PanicsWithMessage(t, cur, "Set operation not supported on ReadOnlyTree", func() {
		result.Set("3", uint64(3))
	})
	uassert.PanicsWithMessage(t, cur, "Remove operation not supported on ReadOnlyTree", func() {
		result.Remove("1")
	})
	uassert.Equal(t, 2, stored.Size())
}

func TestGetPositions_NoImplementationResponse(t *testing.T) {
	resetTestState(t)
	mockPosition := newMockPosition("v1")
	implementation = mockPosition

	uassert.True(t, GetPositions() == nil)
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

	balance0, balance1, err := GetPositionTokenBalances(1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(6000), balance0)
	uassert.Equal(t, int64(7000), balance1)
	balance0, err = GetPositionToken0Balance(1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(6000), balance0)
	balance1, err = GetPositionToken1Balance(1)
	uassert.NoError(t, err)
	uassert.Equal(t, int64(7000), balance1)
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
			getter: func() any {
				value, err := GetPositionFeeGrowthInside0LastX128(1)
				if err != nil {
					t.Fatal(err)
				}
				return value
			},
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
			getter: func() any {
				value, err := GetPositionFeeGrowthInside1LastX128(1)
				if err != nil {
					t.Fatal(err)
				}
				return value
			},
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
				tree := bptree.NewBPTree32()
				tree.Set("1", *stored)
				m.Response.Set("GetPositions", rotree.Wrap(tree, nil))
				return stored
			},
			getter: func() any {
				fee0, fee1, err := GetPositionFeeGrowthInsideLastX128(1)
				if err != nil {
					t.Fatal(err)
				}
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
			getter: func() any {
				value, err := GetPositionLiquidity(1)
				if err != nil {
					t.Fatal(err)
				}
				return value
			},
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
			getter: func() any {
				value, err := GetPositionTokensOwed0(1)
				if err != nil {
					t.Fatal(err)
				}
				return value
			},
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
			getter: func() any {
				value, err := GetPositionTokensOwed1(1)
				if err != nil {
					t.Fatal(err)
				}
				return value
			},
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
				tree := bptree.NewBPTree32()
				tree.Set("1", *stored)
				m.Response.Set("GetPositions", rotree.Wrap(tree, nil))
				return stored
			},
			getter: func() any {
				owed0, owed1, err := GetPositionTokensOwed(1)
				if err != nil {
					t.Fatal(err)
				}
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
				fee0, fee1, err := GetUnclaimedFee(1)
				if err != nil {
					t.Fatal(err)
				}
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

		token0Balance, token1Balance, err := GetPositionTokenBalances(1)
		uassert.NoError(t, err)
		uassert.Equal(t, int64(6000), token0Balance)
		uassert.Equal(t, int64(7000), token1Balance)
	})

	t.Run("returns zero balances for missing position", func(t *testing.T) {
		resetTestState(t)
		mockPosition := newMockPosition("v1")
		implementation = mockPosition

		token0Balance, token1Balance, err := GetPositionTokenBalances(999)
		uassert.NotNil(t, err)
		uassert.Equal(t, int64(0), token0Balance)
		uassert.Equal(t, int64(0), token1Balance)
	})
}
