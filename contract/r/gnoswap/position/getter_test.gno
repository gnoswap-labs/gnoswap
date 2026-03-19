package position

import (
	"chain/runtime"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	uassert "gno.land/p/nt/uassert/v0"
)

func TestGetPositionLiquidityIsolation(t *testing.T) {
	tests := []struct {
		name                    string
		setup                   func(t *testing.T) *Position
		positionId              uint64
		callerRealm             runtime.Realm
		mutatedLiquidity        string
		expectedStoredLiquidity string
		expectedResultLiquidity string
		expectedCallCount       int
	}{
		{
			name: "returned position liquidity does not alias stored state",
			setup: func(t *testing.T) *Position {
				mockPosition := newMockPosition("v1")
				implementation = mockPosition

				storedPosition := NewPosition(
					"foo:bar:3000",
					-100,
					100,
					u256.MustFromDecimal("1000"),
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					u256.Zero(),
					false,
					adminAddr,
				)

				mockPosition.Response.Set("GetPosition", *storedPosition, true)
				return storedPosition
			},
			positionId:              1,
			callerRealm:             testing.NewCodeRealm("gno.land/r/gnoswap/position"),
			mutatedLiquidity:        "2000",
			expectedStoredLiquidity: "1000",
			expectedResultLiquidity: "2000",
			expectedCallCount:       1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resetTestState(t)
			storedPosition := tt.setup(t)

			mockPosition := implementation.(*MockPosition)

			testing.SetRealm(tt.callerRealm)
			result, err := GetPosition(tt.positionId)
			if err != nil {
				t.Fatalf("GetPosition() unexpected error: %v", err)
			}

			result.Liquidity().Set(u256.MustFromDecimal(tt.mutatedLiquidity))

			uassert.Equal(t, tt.expectedStoredLiquidity, storedPosition.Liquidity().ToString())
			uassert.Equal(t, tt.expectedResultLiquidity, result.Liquidity().ToString())
			if storedPosition.Liquidity() == result.Liquidity() {
				t.Fatal("GetPosition() returned aliased liquidity pointer")
			}
			if mockPosition.Response.CallCount("GetPosition") != tt.expectedCallCount {
				t.Errorf("GetPosition() call count = %d, want %d", mockPosition.Response.CallCount("GetPosition"), tt.expectedCallCount)
			}
		})
	}
}
