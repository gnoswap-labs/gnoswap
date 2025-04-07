package router

import (
	"testing"

	"gno.land/p/demo/uassert"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/gnoswap/v1/gns"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
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
				_, result, swapAvailable := processDryswapResult(tt.swapType, resultAmountIn, resultAmountOut, amountSpecified, amountLimit)
				uassert.Equal(t, tt.expected, result)
				uassert.Equal(t, tt.expectedSwap, swapAvailable)
			case ExactOut:
				result, _, swapAvailable := processDryswapResult(tt.swapType, resultAmountIn, resultAmountOut, amountSpecified, amountLimit)
				uassert.Equal(t, tt.expected, result)
				uassert.Equal(t, tt.expectedSwap, swapAvailable)
			}
		})
	}
}

type testDrySwapRouteCases struct {
	name              string
	inputToken        string
	outputToken       string
	specifiedAmount   string
	swapTypeStr       string
	strRouteArr       string
	quoteArr          string
	tokenAmountLimit  string
	expectedAmountIn  string
	expectedAmountOut string
	expectedSuccess   bool
	expectPanic       bool
}

func TestDrySwapRoute(t *testing.T) {
	t.Skip("run this test separately with `gno test -v -run TestDrySwapRoute`")
	createBasicPool(t)

	tests := []testDrySwapRouteCases{
		{
			name:              "ExactIn - Single Route",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/baz",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_IN",
			strRouteArr:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
			quoteArr:          "100",
			tokenAmountLimit:  "1",
			expectedAmountIn:  "1000",
			expectedAmountOut: "2711",
			expectedSuccess:   true,
		},
		{
			name:              "ExactOut - Single Route",
			inputToken:        "gno.land/r/onbloc/baz",
			outputToken:       "gno.land/r/onbloc/bar",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_OUT",
			strRouteArr:       "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500",
			quoteArr:          "100",
			tokenAmountLimit:  "100000",
			expectedAmountIn:  "2724",
			expectedAmountOut: "1000",
			expectedSuccess:   true,
		},
		{
			name:              "ExactIn - Multi Route",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/qux",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_IN",
			strRouteArr:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
			quoteArr:          "100",
			tokenAmountLimit:  "1",
			expectedAmountIn:  "1000",
			expectedAmountOut: "7337",
			expectedSuccess:   true,
		},
		{
			name:              "ExactOut - Multi Route",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/qux",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_OUT",
			strRouteArr:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:500",
			quoteArr:          "100",
			tokenAmountLimit:  "10000",
			expectedAmountIn:  "138",
			expectedAmountOut: "370",
			expectedSuccess:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amountIn, amountOut, success := DrySwapRoute(
				tt.inputToken,
				tt.outputToken,
				tt.specifiedAmount,
				tt.swapTypeStr,
				tt.strRouteArr,
				tt.quoteArr,
				tt.tokenAmountLimit,
			)

			uassert.Equal(t, tt.expectedAmountIn, amountIn)
			uassert.Equal(t, tt.expectedAmountOut, amountOut)
			uassert.Equal(t, tt.expectedSuccess, success)
		})
	}
}

func TestDrySwapRouteOverflow(t *testing.T) {
	t.Skip("run this test separately with `gno test -v -run TestDrySwapRouteOverflow`")
	tests := []testDrySwapRouteCases{
		{
			name:              "ExactIn - Overflow in calculateSwapAmount",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/baz",
			specifiedAmount:   "115792089237316195423570985008687907853269984665640564039457584007913129639935", // max uint256
			swapTypeStr:       "EXACT_IN",
			strRouteArr:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
			quoteArr:          "100",
			tokenAmountLimit:  "1",
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
		},
		{
			name:              "ExactOut - Overflow in calculateSwapAmount",
			inputToken:        "gno.land/r/onbloc/baz",
			outputToken:       "gno.land/r/onbloc/bar",
			specifiedAmount:   "115792089237316195423570985008687907853269984665640564039457584007913129639935", // max uint256
			swapTypeStr:       "EXACT_OUT",
			strRouteArr:       "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500",
			quoteArr:          "100",
			tokenAmountLimit:  "100000",
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
		},
		{
			name:              "ExactIn - Overflow in resultAmountIn",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/baz",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_IN",
			strRouteArr:       "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500,gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500",
			quoteArr:          "50,50",
			tokenAmountLimit:  "1",
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
		},
		{
			name:              "ExactOut - Overflow in resultAmountOut",
			inputToken:        "gno.land/r/onbloc/baz",
			outputToken:       "gno.land/r/onbloc/bar",
			specifiedAmount:   "1000",
			swapTypeStr:       "EXACT_OUT",
			strRouteArr:       "gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500,gno.land/r/onbloc/baz:gno.land/r/onbloc/bar:500",
			quoteArr:          "50,50",
			tokenAmountLimit:  "100000",
			expectedAmountIn:  "0",
			expectedAmountOut: "0",
			expectedSuccess:   false,
			expectPanic:       true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			defer func() {
				if r := recover(); r != nil {
					if !tt.expectPanic {
						t.Errorf("unexpected panic: %v", r)
					}
				} else if tt.expectPanic {
					t.Error("expected panic but got none")
				}
			}()

			amountIn, amountOut, success := DrySwapRoute(
				tt.inputToken,
				tt.outputToken,
				tt.specifiedAmount,
				tt.swapTypeStr,
				tt.strRouteArr,
				tt.quoteArr,
				tt.tokenAmountLimit,
			)

			if !tt.expectPanic {
				uassert.Equal(t, tt.expectedAmountIn, amountIn)
				uassert.Equal(t, tt.expectedAmountOut, amountOut)
				uassert.Equal(t, tt.expectedSuccess, success)
			}
		})
	}
}

func createBasicPool(t *testing.T) {
	t.Helper()
	testing.SetRealm(adminRealm)

	gns.Approve(poolAddr, pl.GetPoolCreationFee()*2)

	pl.CreatePool(barPath, bazPath, uint32(500), "130621891405341611593710811006") // tick = 10_000
	pl.CreatePool(bazPath, quxPath, uint32(500), "130621891405341611593710811006") // tick = 10_000

	bar.Approve(poolAddr, consts.UINT64_MAX)
	baz.Approve(poolAddr, consts.UINT64_MAX)
	qux.Approve(poolAddr, consts.UINT64_MAX)

	pn.Mint(barPath, bazPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", 9999999999, adminAddr, adminAddr, "")
	pn.Mint(bazPath, quxPath, uint32(500), int32(9000), int32(11000), "100000", "100000", "0", "0", 9999999999, adminAddr, adminAddr, "")
}
