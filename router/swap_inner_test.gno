package router

import (
	"std"
	"testing"

	"gno.land/r/gnoswap/v1/common"

	"gno.land/p/demo/uassert"
	pusers "gno.land/p/demo/users"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/demo/users"
	"gno.land/r/gnoswap/v1/consts"
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
			expected: common.TickMathGetSqrtRatioAtTick(getMinTick(500)).Add(
				common.TickMathGetSqrtRatioAtTick(getMinTick(500)),
				u256.One(),
			),
		},
		{
			name:              "when zeroForOne is false, calculate max tick",
			zeroForOne:        false,
			fee:               500,
			sqrtPriceLimitX96: u256.Zero(),
			expected: common.TickMathGetSqrtRatioAtTick(getMaxTick(500)).Sub(
				common.TickMathGetSqrtRatioAtTick(getMaxTick(500)),
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

			if !result.Eq(tt.expected) {
				t.Errorf(
					"case '%s': expected %s, actual %s",
					tt.name,
					tt.expected.ToString(),
					result.ToString(),
				)
			}
		})
	}
}

func TestSwapInner(t *testing.T) {
	tests := []struct {
		name              string
		setupFn           func(t *testing.T)
		amountSpecified   *i256.Int
		recipient         std.Address
		sqrtPriceLimitX96 *u256.Uint
		data              SwapCallbackData
		expectedRecv      *u256.Uint
		expectedOut       *u256.Uint
		expectError       bool
	}{
		{
			name: "normal swap - exact input",
			setupFn: func(t *testing.T) {
				CreatePoolWithoutFee(t)
			},
			amountSpecified:   i256.MustFromDecimal("100"), // exact input
			recipient:         users.Resolve(alice),
			sqrtPriceLimitX96: u256.NewUint(4295128740),
			data: SwapCallbackData{
				tokenIn:  barPath,
				tokenOut: bazPath,
				fee:      3000,
				payer:    consts.ROUTER_ADDR,
			},
			expectedRecv: u256.MustFromDecimal("100"),
			expectedOut:  u256.MustFromDecimal("95"),
			expectError:  false,
		},
	}

	for _, tt := range tests {
		if tt.setupFn != nil {
			tt.setupFn(t)
		}

		poolRecv, poolOut := swapInner(
			tt.amountSpecified,
			tt.recipient,
			tt.sqrtPriceLimitX96,
			tt.data,
		)

		panic("poolRecv: " + poolRecv.ToString() + "poolOut: " + poolOut.ToString())
	}
}
