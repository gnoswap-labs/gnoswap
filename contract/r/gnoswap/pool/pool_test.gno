package pool

import (
	"std"
	"testing"

	"gno.land/p/demo/testutils"
	"gno.land/p/demo/uassert"

	"gno.land/p/gnoswap/consts"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

func TestMint(t *testing.T) {
	token0Path := "test_token0"
	token1Path := "test_token1"
	fee := uint32(3000)
	recipient := testutils.TestAddress("recipient")
	tickLower := int32(-100)
	tickUpper := int32(100)
	liquidityAmount := "100000"
	authorized := consts.POSITION_ADDR
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"

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
		defer func() {
			if r := recover(); r == nil {
				t.Error("mint with 0 liquidity should fail")
			}
		}()

		Mint(token0Path, token1Path, fee, recipient, tickLower, tickUpper, "0", authorized)
	})

	t.Run("invalid tick range should fail", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Error("invalid tick range should fail")
			}
		}()
		Mint(token0Path, token1Path, fee, recipient, 100, 100, liquidityAmount, authorized)
	})

	t.Run("invalid fee amount should fail", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Error("invalid fee amount should fail")
			}
		}()
		Mint(token0Path, token1Path, 2000, recipient, -100, 100, liquidityAmount, authorized)
	})

	t.Run("non-existent pool should fail", func(t *testing.T) {
		defer func() {
			if r := recover(); r == nil {
				t.Error("non-existent pool should fail")
			}
		}()
		Mint("nonexistent_token0", "nonexistent_token1", fee, recipient, -100, 100, liquidityAmount, authorized)
	})

	t.Run("successful mint", func(t *testing.T) {
		// create pool first
		std.TestSetRealm(adminRealm)
		SetPoolCreationFeeByAdmin(0)
		CreatePool(
			barTokenPath,
			bazTokenPath,
			FeeTier100,
			"79228162514264337593543950336",
		)

		// approve enough token to mint position
		bar.Approve(consts.POOL_ADDR, consts.UINT64_MAX)
		baz.Approve(consts.POOL_ADDR, consts.UINT64_MAX)

		beforeBalance0 := bar.BalanceOf(consts.POOL_ADDR)
		beforeBalance1 := baz.BalanceOf(consts.POOL_ADDR)

		std.TestSetRealm(std.NewCodeRealm(consts.POSITION_PATH))
		mintAmount0, mintAmount1 := Mint(
			barTokenPath,
			bazTokenPath,
			FeeTier100,
			consts.POSITION_ADDR,
			int32(-100),
			int32(100),
			"10000000000",
			consts.ADMIN,
		)
		uassert.Equal(t, mintAmount0, "49872721")
		uassert.Equal(t, mintAmount1, "49872721")

		afterBalance0 := bar.BalanceOf(consts.POOL_ADDR)
		afterBalance1 := baz.BalanceOf(consts.POOL_ADDR)
		uassert.Equal(t, uint64(49872721), afterBalance0-beforeBalance0)
		uassert.Equal(t, uint64(49872721), afterBalance1-beforeBalance1)
	})
}

func TestBurn(t *testing.T) {
	barTokenPath := "gno.land/r/onbloc/bar"
	bazTokenPath := "gno.land/r/onbloc/baz"

	tests := []struct {
		name            string
		liquidityAmount string
		tickLower       int32
		tickUpper       int32
		fee             uint32
		expectedAmount0 string
		expectedAmount1 string
		expectPanic     bool
	}{
		{
			name:            "successful burn",
			liquidityAmount: "10000000000", // burn all liquidity
			tickLower:       -100,
			tickUpper:       100,
			fee:             FeeTier100,
			expectedAmount0: "49872720",
			expectedAmount1: "49872720",
		},
		{
			name:            "zero liquidity",
			liquidityAmount: "0",
			tickLower:       -100,
			tickUpper:       100,
			fee:             FeeTier100,
			expectPanic:     true,
		},
		{
			name:            "invalid tick range",
			liquidityAmount: "100000",
			tickLower:       200,
			tickUpper:       100,
			expectPanic:     true,
		},
		{
			name:            "invalid fee amount",
			liquidityAmount: "100000",
			tickLower:       -100,
			tickUpper:       100,
			fee:             2000,
			expectPanic:     true,
		},
		{
			name:            "non-existent pool",
			liquidityAmount: "100000",
			tickLower:       -100,
			tickUpper:       100,
			fee:             FeeTier500,
			expectPanic:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("expected panic but got none")
					}
				}()
			}

			std.TestSetRealm(std.NewCodeRealm(consts.POSITION_PATH))
			amount0, amount1 := Burn(
				barTokenPath,
				bazTokenPath,
				tt.fee,
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

				pool := GetPool(barTokenPath, bazTokenPath, FeeTier100)
				posKey := getPositionKey(consts.POSITION_ADDR, tt.tickLower, tt.tickUpper)
				newPosition := pool.mustGetPosition(posKey)
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

func TestSetFeeProtocolInternal(t *testing.T) {
	tests := []struct {
		name         string
		feeProtocol0 uint8
		feeProtocol1 uint8
		eventName    string
	}{
		{
			name:         "set fee protocol by admin",
			feeProtocol0: 4,
			feeProtocol1: 5,
			eventName:    "SetFeeProtocolByAdmin",
		},
	}

	for _, tt := range tests {
		t.Run("set fee protocol by admin", func(t *testing.T) {
			InitialisePoolTest(t)
			pool := GetPool(wugnotPath, gnsPath, fee3000)
			SetFeeProtocolByAdmin(tt.feeProtocol0, tt.feeProtocol1)
			uassert.Equal(t, tt.feeProtocol0, pool.Slot0FeeProtocol()%16)
			uassert.Equal(t, tt.feeProtocol1, pool.Slot0FeeProtocol()>>4)
		})
	}
}
