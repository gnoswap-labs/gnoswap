package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
)

func TestMint(t *testing.T) {
	token0Path := "test_token0"
	token1Path := "test_token1"
	fee := uint32(3000)
	recipient := testutils.TestAddress("recipient")
	tickLower := int32(-100)
	tickUpper := int32(100)
	liquidityAmount := "100000"

	t.Run("unauthorized caller mint should fail", func(t *testing.T) {
		unauthorized := testutils.TestAddress("unauthorized")
		defer func() {
			if r := recover(); r == nil {
				t.Error("unauthorized caller mint should fail")
			}
		}()

		Mint(token0Path, token1Path, fee, recipient, tickLower, tickUpper, liquidityAmount, unauthorized)
	})

	t.Run("mint with 0 liquidity should fail", func(t *testing.T) {
		authorized := consts.POSITION_ADDR
		defer func() {
			if r := recover(); r == nil {
				t.Error("mint with 0 liquidity should fail")
			}
		}()

		Mint(token0Path, token1Path, fee, recipient, tickLower, tickUpper, "0", authorized)
	})
}

func TestBurn(t *testing.T) {
	// Setup
	originalGetPool := GetPool
	defer func() {
		GetPool = originalGetPool
	}()

	// Mock data
	mockCaller := consts.POSITION_ADDR
	mockPosition := PositionInfo{
		liquidity:   u256.NewUint(1000),
		tokensOwed0: u256.NewUint(0),
		tokensOwed1: u256.NewUint(0),
	}
	mockPool := &Pool{
		positions: make(map[string]PositionInfo),
	}

	GetPool = func(token0Path, token1Path string, fee uint32) *Pool {
		return mockPool
	}

	tests := []struct {
		name            string
		liquidityAmount string
		tickLower       int32
		tickUpper       int32
		expectedAmount0 string
		expectedAmount1 string
		expectPanic     bool
	}{
		{
			name:            "successful burn",
			liquidityAmount: "500",
			tickLower:       -100,
			tickUpper:       100,
			expectedAmount0: "100",
			expectedAmount1: "200",
		},
		{
			name:            "zero liquidity",
			liquidityAmount: "0",
			tickLower:       -100,
			tickUpper:       100,
			expectPanic:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.name == "successful burn" {
				t.Skip("skipping until find better way to test this")
			}

			// setup position for this test
			posKey := positionGetKey(mockCaller, tt.tickLower, tt.tickUpper)
			mockPool.positions[posKey] = mockPosition

			if tt.expectPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but got none")
					}
				}()
			}

			amount0, amount1 := Burn(
				"token0",
				"token1",
				3000,
				tt.tickLower,
				tt.tickUpper,
				tt.liquidityAmount,
			)

			if !tt.expectPanic {
				if amount0 != tt.expectedAmount0 {
					t.Errorf("expected amount0 %s, got %s", tt.expectedAmount0, amount0)
				}
				if amount1 != tt.expectedAmount1 {
					t.Errorf("expected amount1 %s, got %s", tt.expectedAmount1, amount1)
				}

				newPosition := mockPool.positions[posKey]
				if newPosition.tokensOwed0.IsZero() {
					t.Error("expected tokensOwed0 to be updated")
				}
				if newPosition.tokensOwed1.IsZero() {
					t.Error("expected tokensOwed1 to be updated")
				}
			}
		})
	}
}

