package router

import (
	"testing"

	"gno.land/p/demo/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func TestProcessResult(t *testing.T) {
	tests := []struct {
		name            string
		swapType        SwapType
		resultAmountIn  string
		resultAmountOut string
		amountSpecified string
		expected        string
		expectedSwap    bool
	}{
		{
			name:            "ExactIn - Normal",
			swapType:        ExactIn,
			resultAmountIn:  "100",
			resultAmountOut: "95",
			amountSpecified: "100",
			expected:        "95",
			expectedSwap:    true,
		},
		{
			name:            "ExactIn - Input Mismatch",
			swapType:        ExactIn,
			resultAmountIn:  "99",
			resultAmountOut: "5",
			amountSpecified: "100",
			expected:        "5",
			expectedSwap:    false,
		},
		{
			name:            "ExactOut - Normal",
			swapType:        ExactOut,
			resultAmountIn:  "105",
			resultAmountOut: "100",
			amountSpecified: "100",
			expected:        "105",
			expectedSwap:    true,
		},
		{
			name:            "ExactOut - Output Mismatch",
			swapType:        ExactOut,
			resultAmountIn:  "105",
			resultAmountOut: "95",
			amountSpecified: "100",
			expected:        "105",
			expectedSwap:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			resultAmountIn, _ := u256.FromDecimal(tt.resultAmountIn)
			resultAmountOut, _ := u256.FromDecimal(tt.resultAmountOut)
			amountSpecified, _ := i256.FromDecimal(tt.amountSpecified)
			amountLimit, _ := i256.FromDecimal("10")
			if tt.swapType == ExactOut {
				amountLimit, _ = i256.FromDecimal("500")
			}

			switch tt.swapType {
			case ExactIn:
				_, result, swapAvailable := processResult(tt.swapType, resultAmountIn, resultAmountOut, amountSpecified, amountLimit)
				uassert.Equal(t, tt.expected, result)
				uassert.Equal(t, tt.expectedSwap, swapAvailable)
			case ExactOut:
				result, _, swapAvailable := processResult(tt.swapType, resultAmountIn, resultAmountOut, amountSpecified, amountLimit)
				uassert.Equal(t, tt.expected, result)
				uassert.Equal(t, tt.expectedSwap, swapAvailable)
			}
		})
	}
}
