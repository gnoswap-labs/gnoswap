package router

import (
	"std"
	"testing"

	"gno.land/p/demo/uassert"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/access"
	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
)

func TestCalculateSqrtPriceLimitForSwap(t *testing.T) {
	tests := []struct {
		name              string
		zeroForOne        bool
		fee               uint32
		sqrtPriceLimitX96 *u256.Uint
		expected          *u256.Uint
	}{
		{
			name:              "already set sqrtPriceLimit",
			zeroForOne:        true,
			fee:               500,
			sqrtPriceLimitX96: u256.NewUint(1000),
			expected:          u256.NewUint(1000),
		},
		{
			name:              "when zeroForOne is true, calculate min tick",
			zeroForOne:        true,
			fee:               500,
			sqrtPriceLimitX96: u256.Zero(),
			expected: u256.Zero().Add(
				common.TickMathGetSqrtRatioAtTick(getMinTick(500)+1),
				u256.One(),
			),
		},
		{
			name:              "when zeroForOne is false, calculate max tick",
			zeroForOne:        false,
			fee:               500,
			sqrtPriceLimitX96: u256.Zero(),
			expected: u256.Zero().Sub(
				common.TickMathGetSqrtRatioAtTick(getMaxTick(500)-1),
				u256.One(),
			),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := calculateSqrtPriceLimitForSwap(
				tt.zeroForOne,
				tt.fee,
				tt.sqrtPriceLimitX96,
			)
			uassert.Equal(t, result.ToString(), tt.expected.ToString())
		})
	}
}

func TestSwapInner(t *testing.T) {
	t.Skip()
	user2Realm := std.NewUserRealm(user2Addr)
	routerAddr, _ := access.GetAddress(access.ROLE_ROUTER)
	poolAddr, _ := access.GetAddress(access.ROLE_POOL)

	tests := []struct {
		name              string
		setupFn           func(t *testing.T)
		amountSpecified   *i256.Int
		recipient         std.Address
		sqrtPriceLimitX96 *u256.Uint
		data              SwapCallbackData
		expectedRecv      string
		expectedOut       string
		expectError       bool
	}{
		{
			name: "normal swap - exact input",
			setupFn: func(t *testing.T) {
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)

				testing.SetRealm(user2Realm)
				bar.Approve(routerAddr, maxApprove)
				baz.Approve(routerAddr, maxApprove)
				TokenFaucet(t, barPath, user2Addr)
				TokenFaucet(t, bazPath, user2Addr)
			},
			amountSpecified:   i256.MustFromDecimal("100"),
			recipient:         alice,
			sqrtPriceLimitX96: u256.NewUint(4295128740),
			data: SwapCallbackData{
				tokenIn:  barPath,
				tokenOut: bazPath,
				fee:      3000,
				payer:    routerAddr,
			},
			expectedRecv: "100",
			expectedOut:  "98",
			expectError:  false,
		},
		{
			name: "exact output swap with insufficient approve amount",
			setupFn: func(t *testing.T) {
				CreatePoolWithoutFee(t)
				MakeMintPositionWithoutFee(t)

				testing.SetRealm(user2Realm)
				bar.Approve(routerAddr, maxApprove)
				baz.Approve(routerAddr, maxApprove)
				TokenFaucet(t, barPath, user2Addr)
				TokenFaucet(t, bazPath, user2Addr)
			},
			amountSpecified:   i256.MustFromDecimal("-100"), // negative for exact output
			recipient:         alice,
			sqrtPriceLimitX96: u256.NewUint(4295128740),
			data: SwapCallbackData{
				tokenIn:  barPath,
				tokenOut: bazPath,
				fee:      3000,
				payer:    routerAddr,
			},
			expectedRecv: "102", // expected input amount
			expectedOut:  "100", // exact output amount
			expectError:  true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(user2Realm)
			bar.Approve(routerAddr, maxApprove)
			baz.Approve(routerAddr, maxApprove)

			// Set insufficient approve amount for pool
			if tt.expectError {
				bar.Approve(poolAddr, 50) // less than required amount
				baz.Approve(poolAddr, 50)
			} else {
				bar.Approve(poolAddr, maxApprove)
				baz.Approve(poolAddr, maxApprove)
			}

			TokenFaucet(t, barPath, routerAddr)

			if tt.setupFn != nil {
				tt.setupFn(t)
			}

			if tt.expectError {
				defer func() {
					if r := recover(); r == nil {
						t.Error("expected error but got none")
					}
				}()
			}

			poolRecv, poolOut := swapInner(
				tt.amountSpecified,
				tt.recipient,
				tt.sqrtPriceLimitX96,
				tt.data,
			)

			if !tt.expectError {
				uassert.Equal(t, poolRecv.ToString(), tt.expectedRecv)
				uassert.Equal(t, poolOut.ToString(), tt.expectedOut)
			}
		})
	}
}
