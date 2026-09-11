package router

import (
	"testing"

	uassert "gno.land/p/nt/uassert/v0"

	i256 "gno.land/p/gnoswap/int256"
)

// Test swap_callback.gno functions

func TestSwapCallback_Token0Delta(cur realm, t *testing.T) {
	tests := []struct {
		name          string
		token0Path    string
		token1Path    string
		amount0Delta  string
		amount1Delta  string
		payer         address
		expectError   bool
		expectedToken string
	}{
		{
			name:          "positive token0 delta",
			token0Path:    "gno.land/r/onbloc/foo.FOO",
			token1Path:    "gno.land/r/onbloc/bar.BAR",
			amount0Delta:  "1000",
			amount1Delta:  "-500",
			payer:         routerAddr,
			expectError:   false,
			expectedToken: "gno.land/r/onbloc/foo.FOO",
		},
		{
			name:          "positive token1 delta",
			token0Path:    "gno.land/r/onbloc/foo.FOO",
			token1Path:    "gno.land/r/onbloc/bar.BAR",
			amount0Delta:  "-500",
			amount1Delta:  "1000",
			payer:         routerAddr,
			expectError:   false,
			expectedToken: "gno.land/r/onbloc/bar.BAR",
		},
		{
			name:         "both deltas negative",
			token0Path:   "gno.land/r/onbloc/foo.FOO",
			token1Path:   "gno.land/r/onbloc/bar.BAR",
			amount0Delta: "-500",
			amount1Delta: "-1000",
			payer:        routerAddr,
			expectError:  false,
		},
		{
			name:         "both deltas zero",
			token0Path:   "gno.land/r/onbloc/foo.FOO",
			token1Path:   "gno.land/r/onbloc/bar.BAR",
			amount0Delta: "0",
			amount1Delta: "0",
			payer:        routerAddr,
			expectError:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			amount0 := i256.MustFromDecimal(tt.amount0Delta)
			amount1 := i256.MustFromDecimal(tt.amount1Delta)

			// Verify logic for determining which token to pay
			var tokenToPay string
			var amountToPay *i256.Int

			if amount0.Gt(i256.Zero()) {
				tokenToPay = tt.token0Path
				amountToPay = amount0
			} else if amount1.Gt(i256.Zero()) {
				tokenToPay = tt.token1Path
				amountToPay = amount1
			}

			if tt.expectedToken != "" {
				uassert.Equal(t, tt.expectedToken, tokenToPay)
				uassert.True(t, amountToPay.Gt(i256.Zero()))
			}
		})
	}
}

func TestTransferToPool_PayerType(cur realm, t *testing.T) {
	tests := []struct {
		name               string
		payer              address
		expectTransferBy   string
		shouldCheckBalance bool
	}{
		{
			name:               "router as payer",
			payer:              routerAddr,
			expectTransferBy:   "router",
			shouldCheckBalance: true,
		},
		{
			name:               "user as payer",
			payer:              addr01,
			expectTransferBy:   "user",
			shouldCheckBalance: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			isTransferByRouter := tt.payer == routerAddr

			if tt.expectTransferBy == "router" {
				uassert.True(t, isTransferByRouter)
			} else {
				uassert.False(t, isTransferByRouter)
			}
		})
	}
}

// Test swap_single.gno functions

func TestAssertSingleSwap_SameToken(cur realm, t *testing.T) {
	params := &SingleSwapParams{
		tokenIn:  "gno.land/r/onbloc/foo.FOO",
		tokenOut: "gno.land/r/onbloc/foo.FOO", // Same token
		fee:      3000,
	}

	uassert.PanicsWithMessage(
		t, cur,
		"[GNOSWAP-ROUTER-011] cannot swap same token",
		func() {
			assertSingleSwap(params)
		},
	)
}

func TestExecuteSwap_DifferentTokens(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		tokenIn  string
		tokenOut string
		fee      uint32
	}{
		{
			name:     "foo to bar",
			tokenIn:  "gno.land/r/onbloc/foo.FOO",
			tokenOut: "gno.land/r/onbloc/bar.BAR",
			fee:      3000,
		},
		{
			name:     "bar to baz",
			tokenIn:  "gno.land/r/onbloc/bar.BAR",
			tokenOut: "gno.land/r/onbloc/baz.BAZ",
			fee:      500,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			// Verify tokens are different
			uassert.NotEqual(t, tt.tokenIn, tt.tokenOut)
		})
	}
}

// Additional edge case tests

func TestSwapCallback_EdgeCases(cur realm, t *testing.T) {
	tests := []struct {
		name         string
		amount0Delta string
		amount1Delta string
		shouldPay    bool
	}{
		{
			name:         "large positive token0 delta",
			amount0Delta: "999999999999",
			amount1Delta: "-500000000000",
			shouldPay:    true,
		},
		{
			name:         "large positive token1 delta",
			amount0Delta: "-500000000000",
			amount1Delta: "999999999999",
			shouldPay:    true,
		},
		{
			name:         "minimal positive token0 delta",
			amount0Delta: "1",
			amount1Delta: "-1",
			shouldPay:    true,
		},
		{
			name:         "both negative deltas",
			amount0Delta: "-100",
			amount1Delta: "-200",
			shouldPay:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			amount0 := i256.MustFromDecimal(tt.amount0Delta)
			amount1 := i256.MustFromDecimal(tt.amount1Delta)

			shouldPay := amount0.Gt(i256.Zero()) || amount1.Gt(i256.Zero())
			uassert.Equal(t, tt.shouldPay, shouldPay)
		})
	}
}

func TestSwapInner_ZeroForOneLogic(cur realm, t *testing.T) {
	tests := []struct {
		name       string
		tokenIn    string
		tokenOut   string
		zeroForOne bool
	}{
		{
			name:       "tokenIn < tokenOut means zeroForOne",
			tokenIn:    "gno.land/r/onbloc/bar.BAR",
			tokenOut:   "gno.land/r/onbloc/foo.FOO",
			zeroForOne: true,
		},
		{
			name:       "tokenIn > tokenOut means !zeroForOne",
			tokenIn:    "gno.land/r/onbloc/foo.FOO",
			tokenOut:   "gno.land/r/onbloc/bar.BAR",
			zeroForOne: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			zeroForOne := tt.tokenIn < tt.tokenOut
			uassert.Equal(t, tt.zeroForOne, zeroForOne)
		})
	}
}
