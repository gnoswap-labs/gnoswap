package v1

import (
	"strconv"
	"testing"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
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
	routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	tests := []struct {
		name              string
		setupFn           func(*TestEnv)
		amountSpecified   int64
		recipient         address
		sqrtPriceLimitX96 *u256.Uint
		data              SwapCallbackData
		expectedRecv      int64
		expectedOut       int64
		expectError       bool
		expectedErrorMsg  string
	}{
		{
			name: "normal swap - exact input",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
				TokenFaucet(t, barPath, alice)
			},
			amountSpecified:   100,
			recipient:         alice,
			sqrtPriceLimitX96: u256.NewUint(4295128740),
			data: SwapCallbackData{
				tokenIn:  barPath,
				tokenOut: bazPath,
				fee:      3000,
				payer:    alice,
			},
			expectedRecv: 100,
			expectedOut:  98,
			expectError:  false,
		},
		{
			name: "insufficient balance - large amount",
			setupFn: func(env *TestEnv) {
				defaultSetupFn(env)
				TokenFaucet(t, barPath, alice)
			},
			amountSpecified:   9223372036854775807, // Large amount (int64 max)
			recipient:         alice,
			sqrtPriceLimitX96: u256.NewUint(4295128740),
			data: SwapCallbackData{
				tokenIn:  barPath,
				tokenOut: bazPath,
				fee:      3000,
				payer:    alice,
			},
			expectedRecv:     0,
			expectedOut:      0,
			expectError:      true,
			expectedErrorMsg: "insufficient balance in router for callback",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			// Additional setup for swapInner test requirements
			aliceRealm := testing.NewUserRealm(alice)
			testing.SetRealm(aliceRealm)
			bar.Approve(cross, routerAddr, maxApprove)
			baz.Approve(cross, routerAddr, maxApprove)
			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)
			TokenFaucet(t, barPath, routerAddr)

			testing.SetRealm(routerRealm)

			router := mockRouter()

			swapInnerFn := func(cur realm) (int64, int64) {
				return router.swapInner(
					tt.amountSpecified,
					tt.recipient,
					tt.sqrtPriceLimitX96,
					tt.data,
				)
			}

			if tt.expectError {
				uassert.AbortsWithMessage(t, tt.expectedErrorMsg, func() {
					swapInnerFn(cross)
				})
			} else {
				poolRecv, poolOut := swapInnerFn(cross)

				if !tt.expectError {
					uassert.Equal(t, strconv.FormatInt(poolRecv, 10), strconv.FormatInt(tt.expectedRecv, 10))
					uassert.Equal(t, strconv.FormatInt(poolOut, 10), strconv.FormatInt(tt.expectedOut, 10))
				}
			}
		})
	}
}
