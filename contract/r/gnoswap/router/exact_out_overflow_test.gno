package router

import (
	"testing"

	"gno.land/p/gnoswap/gnsmath"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestExactOutOverflow(t *testing.T) {
	tests := []struct {
		name             string
		sqrtPriceCurrent string
		sqrtPriceTarget  string
		liquidity        string
		amountRemaining  string // Negative for ExactOut
		feePips          uint64
		expectPanic      bool
	}{
		{
			name:             "Small negative amount (-1) with normal liquidity",
			sqrtPriceCurrent: "79228162514264337593543950336", // 1.0 price
			sqrtPriceTarget:  "79623317895830914510639640423", // 1.01 price
			liquidity:        "1000000000000000000",           // 1e18
			amountRemaining:  "-1",
			feePips:          3000,
			expectPanic:      false,
		},
		{
			// Should handle large output requests that exceed liquidity
			name:             "Large negative amount exceeding liquidity",
			sqrtPriceCurrent: "79228162514264337593543950336",
			sqrtPriceTarget:  "79623317895830914510639640423",
			liquidity:        "1000000",
			amountRemaining:  "-1000000000000000000000000", // Very large output request
			feePips:          3000,
			expectPanic:      false, // Should not panic but handle gracefully
		},
		{
			name:             "Edge case: int64 min value",
			sqrtPriceCurrent: "79228162514264337593543950336",
			sqrtPriceTarget:  "79623317895830914510639640423",
			liquidity:        "1000000000000000000",
			amountRemaining:  "-9223372036854775808", // int64 min
			feePips:          3000,
			expectPanic:      false,
		},
		{
			name:             "Maximum uint256 as negative",
			sqrtPriceCurrent: "79228162514264337593543950336",
			sqrtPriceTarget:  "79623317895830914510639640423",
			liquidity:        "1000000000000000000",
			amountRemaining:  "-115792089237316195423570985008687907853269984665640564039457584007913129639935", // -max uint256
			feePips:          3000,
			expectPanic:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			sqrtCurrent := u256.MustFromDecimal(tt.sqrtPriceCurrent)
			sqrtTarget := u256.MustFromDecimal(tt.sqrtPriceTarget)
			liquidity := u256.MustFromDecimal(tt.liquidity)
			amountRemaining := i256.MustFromDecimal(tt.amountRemaining)

			if tt.expectPanic {
				defer func() {
					if r := recover(); r == nil {
						t.Errorf("%s: expected panic but didn't get one", tt.name)
					}
				}()
			}

			sqrtNext, amountIn, amountOut, feeAmount := gnsmath.SwapMathComputeSwapStep(
				sqrtCurrent,
				sqrtTarget,
				liquidity,
				amountRemaining,
				tt.feePips,
			)

			if !tt.expectPanic {
				if sqrtNext == nil || amountIn == nil || amountOut == nil || feeAmount == nil {
					t.Errorf("%s: got nil result", tt.name)
				}

				// For ExactOut, amountOut should not exceed the absolute value of amountRemaining
				if amountRemaining.IsNeg() {
					amountRemainingAbs := amountRemaining.Abs()
					if amountOut.Gt(amountRemainingAbs) {
						t.Errorf("%s: amountOut (%s) exceeds requested amount (%s)",
							tt.name, amountOut.ToString(), amountRemainingAbs.ToString())
					}
				}
			}
		})
	}
}

// TestPoolLiquidityValidation simulates the missing validation in pool swap
func TestPoolLiquidityValidation(t *testing.T) {
	tests := []struct {
		name            string
		poolBalance     string
		requestedOutput string
		shouldFail      bool
		description     string
	}{
		{
			name:            "Request more than pool balance",
			poolBalance:     "1000000",
			requestedOutput: "2000000",
			shouldFail:      true,
			description:     "Should fail when output exceeds pool balance",
		},
		{
			name:            "Request exactly pool balance",
			poolBalance:     "1000000",
			requestedOutput: "1000000",
			shouldFail:      false,
			description:     "Should succeed when output equals pool balance",
		},
		{
			name:            "Request less than pool balance",
			poolBalance:     "1000000",
			requestedOutput: "500000",
			shouldFail:      false,
			description:     "Should succeed when output is less than pool balance",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			poolBalance := u256.MustFromDecimal(tt.poolBalance)
			requestedOutput := u256.MustFromDecimal(tt.requestedOutput)

			// Simulate the validation that should be in the pool
			if requestedOutput.Gt(poolBalance) {
				if !tt.shouldFail {
					t.Errorf("%s: expected success but would fail", tt.name)
				}
				t.Logf("%s: Correctly identified insufficient liquidity", tt.name)
			} else {
				if tt.shouldFail {
					t.Errorf("%s: expected failure but would succeed", tt.name)
				}
				t.Logf("%s: Sufficient liquidity available", tt.name)
			}
		})
	}
}
