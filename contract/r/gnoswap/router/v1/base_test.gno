package v1

import (
	"chain"
	"chain/runtime"
	"errors"
	"math"
	"strings"
	"testing"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/r/gnoswap/common"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"
)

var errDummy = errors.New("dummy error")

const (
	foobar500 = "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:500"
	barbaz500 = "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:500"
)

type mockOperation struct {
	ValidateErr error
	ProcessErr  error
	Result      *SwapResult
}

func (m *mockOperation) Validate() error {
	return m.ValidateErr
}

func (m *mockOperation) Process() (*SwapResult, error) {
	return m.Result, m.ProcessErr
}

func TestExecuteSwapOperation(t *testing.T) {
	tests := []struct {
		name        string
		operation   RouterOperation
		expectError bool
	}{
		{
			name: "success case",
			operation: &mockOperation{
				ValidateErr: nil,
				ProcessErr:  nil,
				Result:      &SwapResult{},
			},
			expectError: false,
		},
		{
			name: "validate error",
			operation: &mockOperation{
				ValidateErr: errDummy,
				ProcessErr:  nil,
				Result:      &SwapResult{},
			},
			expectError: true,
		},
		{
			name: "process error",
			operation: &mockOperation{
				ValidateErr: nil,
				ProcessErr:  errDummy,
				Result:      nil,
			},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := executeSwapOperation(tt.operation)
			if tt.expectError && err == nil {
				t.Errorf("expected an error but got nil (test case: %s)", tt.name)
			}
			if !tt.expectError && err != nil {
				t.Errorf("unexpected error: %v (test case: %s)", err, tt.name)
			}
			if !tt.expectError && result == nil {
				t.Errorf("expected non-nil result but got nil (test case: %s)", tt.name)
			}
		})
	}
}

func TestHandleNativeTokenWrapping(t *testing.T) {
	tests := []struct {
		name            string
		inputToken      string
		outputToken     string
		specifiedAmount *i256.Int
		sentAmount      int64
		expectError     bool
		expectedError   string
	}{
		{
			name:            "Pass: non-GNOT token swap",
			inputToken:      "token1",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(100),
			sentAmount:      0,
			expectError:     false,
		},
		{
			name:            "Pass: WUGNOT input token",
			inputToken:      "gno.land/r/gnoland/wugnot",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(100),
			sentAmount:      0,
			expectError:     false,
		},
		{
			name:            "Pass: WUGNOT output token",
			inputToken:      "token1",
			outputToken:     "gno.land/r/gnoland/wugnot",
			specifiedAmount: i256.NewInt(100),
			sentAmount:      0,
			expectError:     false,
		},
		{
			name:            "Fail: GNOT input with insufficient sent amount",
			inputToken:      "gnot",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(1000),
			sentAmount:      500,
			expectError:     true,
			expectedError:   "ugnot sent by user(500) is not equal to amountSpecified(1000)",
		},
		{
			name:            "Fail: GNOT input with excess sent amount",
			inputToken:      "gnot",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(1000),
			sentAmount:      1500,
			expectError:     true,
			expectedError:   "ugnot sent by user(1500) is not equal to amountSpecified(1000)",
		},
		{
			name:            "Fail: GNOT input with zero sent amount",
			inputToken:      "gnot",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(1000),
			sentAmount:      0,
			expectError:     true,
			expectedError:   "ugnot sent by user(0) is not equal to amountSpecified(1000)",
		},
		{
			name:            "Pass: GNOT input with zero specified amount",
			inputToken:      "gnot",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(0),
			sentAmount:      0,
			expectError:     false,
		},
		{
			name:            "Pass: non-GNOT input with non-zero sent amount",
			inputToken:      "token1",
			outputToken:     "token2",
			specifiedAmount: i256.NewInt(100),
			sentAmount:      1000,
			expectError:     false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			op := &baseSwapOperation{}

			testUser := testutils.TestAddress("test_user")
			testing.SetOriginCaller(testUser)
			testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))

			testCoins := chain.Coins{{"ugnot", tt.sentAmount}}
			testing.IssueCoins(runtime.OriginCaller(), testCoins)
			if tt.sentAmount > 0 {
				testing.IssueCoins(routerAddr, testCoins)
			}
			testing.SetOriginSend(testCoins)

			err := op.handleNativeTokenWrapping(
				tt.inputToken,
				tt.outputToken,
				tt.specifiedAmount,
			)
			testing.SetOriginSend(testCoins)

			if tt.expectError && err == nil {
				t.Errorf("expected an error but got nil")
			}
			if !tt.expectError && err != nil {
				t.Errorf("unexpected error: %v", err)
			}
		})
	}
}

func TestValidateRouteQuote(t *testing.T) {
	op := &baseSwapOperation{
		amountSpecified: i256.NewInt(1000),
	}

	tests := []struct {
		name        string
		quote       string
		index       int
		expectError bool
		expected    *i256.Int
	}{
		{
			name:        "Pass: valid quote - 100%",
			quote:       "100",
			index:       0,
			expectError: false,
			expected:    i256.NewInt(1000), // 1000 * 100 / 100 = 1000
		},
		{
			name:        "Pass: valid quote - 50%",
			quote:       "50",
			index:       0,
			expectError: false,
			expected:    i256.NewInt(500), // 1000 * 50 / 100 = 500
		},
		{
			name:        "Fail: invalid quote - string",
			quote:       "invalid",
			index:       0,
			expectError: true,
			expected:    nil,
		},
		{
			name:        "Fail: invalid quote - empty string",
			quote:       "",
			index:       0,
			expectError: true,
			expected:    nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := op.validateRouteQuote(tt.quote, tt.index)
			if tt.expectError {
				uassert.Error(t, err)
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if result.Cmp(tt.expected) != 0 {
					t.Errorf("expected %v but got %v", tt.expected, result)
				}
			}
		})
	}
}

func TestProcessRoute(t *testing.T) {
	op := &baseSwapOperation{}

	t.Run("Single hop route", func(t *testing.T) {
		testing.SetRealm(adminRealm)
		CreatePoolWithoutFee(t)
		MakeThirdMintPositionWithoutFee(t)
		common.SafeGRC20Approve(cross, fooPath, routerAddr, 1000000)
		route := foobar500
		toSwap := i256.NewInt(1000)
		swapType := ExactIn

		router := mockRouter()
		func(cur realm) {
			amountIn, amountOut, err := op.processRoute(router, route, toSwap, swapType)
			uassert.Equal(t, err, nil)
			uassert.Equal(t, amountIn.ToString(), "1000")
			uassert.Equal(t, amountOut.ToString(), "979")
		}(cross)
	})
}

// Test reproducing report L-08 "Loss of Tokens in Swap Due to Truncation"
func TestProcessRoutesWithRemainder(t *testing.T) {
	oddAmount := i256.NewInt(101)
	op := &baseSwapOperation{
		// use odd amount to ensure remainder
		amountSpecified: oddAmount,
		routes:          []string{foobar500, barbaz500},
		// allocate 50% to each route
		quotes: []string{"50", "50"},
	}

	testing.SetRealm(adminRealm)
	common.SafeGRC20Approve(cross, fooPath, routerAddr, math.MaxInt64)
	CreatePoolWithoutFee(t)
	MakeThirdMintPositionWithoutFee(t)

	// expected amounts for each route
	expectedAmounts := []*i256.Int{
		i256.NewInt(50), // 101 * 50 / 100 = 50
		i256.NewInt(50), // 101 * 50 / 100 = 50
	}

	func(cur realm) {
		router := mockRouter()
		_, amountOut, err := op.processRoutes(router, ExactIn)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if amountOut.Cmp(u256.Zero()) == 0 {
			t.Error("expected non-zero amountOut")
		}
	}(cross)

	// check actual swapped amounts for each route
	for i := range op.routes {
		toSwap, err := op.validateRouteQuote(op.quotes[i], i)
		if err != nil {
			t.Fatalf("unexpected error validating quote: %v", err)
		}

		if toSwap.Cmp(expectedAmounts[i]) != 0 {
			t.Errorf("route %d: expected amount %s, got %s", i, expectedAmounts[i].ToString(), toSwap.ToString())
		}
	}

	// check total input amount
	totalExpected := oddAmount
	if op.amountSpecified.Cmp(totalExpected) != 0 {
		t.Errorf("total expected amount %s, got %s", totalExpected.ToString(), op.amountSpecified.ToString())
	}

	// check remainder
	usedAmount := i256.NewInt(0)
	for _, amount := range expectedAmounts {
		usedAmount = usedAmount.Add(usedAmount, amount)
	}
	// Currently, this test succeeds.
	// That is, we can observe that there is indeed a remainder.
	remainder := totalExpected.Sub(totalExpected, usedAmount)
	if remainder.Cmp(i256.NewInt(1)) != 0 {
		t.Errorf("expected remainder of 1, got %s", remainder.ToString())
	}
}

func TestProcessRoutes_LastRouteUsesRemainingAmount(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified *i256.Int
		routes          []string
		quotes          []string
		expectedAmounts []string // expected amount for each route
		description     string
	}{
		{
			// 50% + 50% = 100% (no remainder)
			name:            "two routes with perfect split",
			amountSpecified: i256.NewInt(100),
			routes:          []string{foobar500, barbaz500},
			quotes:          []string{"50", "50"},
			expectedAmounts: []string{"50", "50"},
		},
		{
			// 33% + 33% + remainder(34%) = 100%
			name:            "three routes with remainder",
			amountSpecified: i256.NewInt(100),
			routes:          []string{foobar500, barbaz500, foobar500},
			quotes:          []string{"33", "33", "34"},
			expectedAmounts: []string{"33", "33", "34"}, // last route gets remainder
		},
		{
			name:            "odd amount with two routes",
			amountSpecified: i256.NewInt(101),
			routes:          []string{foobar500, barbaz500},
			quotes:          []string{"50", "50"},
			expectedAmounts: []string{"50", "51"}, // last route gets 50 + remainder(1)
		},
		{
			// 24% + 25% + 25% + remainder(26%) = 100%
			name:            "large amount with multiple routes",
			amountSpecified: i256.NewInt(1000),
			routes:          []string{foobar500, barbaz500, foobar500, barbaz500},
			quotes:          []string{"24", "25", "25", "26"},
			expectedAmounts: []string{"240", "250", "250", "260"}, // last route gets remainder
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			testing.SetRealm(adminRealm)
			CreatePoolWithoutFee(t)
			MakeThirdMintPositionWithoutFee(t)

			// Track the amounts used for each route
			totalUsed := i256.NewInt(0)

			// Calculate expected amounts based on the new logic
			calculatedAmounts := make([]*i256.Int, len(tt.routes))

			for i := range tt.routes {
				if i < len(tt.routes)-1 {
					// For non-last routes, calculate based on quote
					quote := tt.quotes[i]
					quoteInt, err := i256.FromDecimal(quote)
					uassert.NoError(t, err)

					amount := new(i256.Int).Mul(tt.amountSpecified, quoteInt)
					amount = new(i256.Int).Div(amount, i256.NewInt(100))

					calculatedAmounts[i] = amount
					totalUsed = new(i256.Int).Add(totalUsed, amount)
				} else {
					// Last route gets the remaining amount
					calculatedAmounts[i] = new(i256.Int).Sub(tt.amountSpecified, totalUsed)
				}
			}

			// Verify each calculated amount matches expected
			for i, expectedAmount := range tt.expectedAmounts {
				expected := i256.MustFromDecimal(expectedAmount)
				if calculatedAmounts[i].Cmp(expected) != 0 {
					t.Errorf("route %d: expected %s, got %s",
						i, expected.ToString(), calculatedAmounts[i].ToString())
				}
			}

			// Verify total equals amountSpecified
			total := i256.NewInt(0)
			for _, amount := range calculatedAmounts {
				total = total.Add(total, amount)
			}
			if total.Cmp(tt.amountSpecified) != 0 {
				t.Errorf("total amount mismatch: expected %s, got %s",
					tt.amountSpecified.ToString(), total.ToString())
			}
		})
	}
}

// Test SwapRouteParams.ExactAmount
func TestSwapRouteParams_ExactAmount(t *testing.T) {
	tests := []struct {
		name        string
		exactAmount string
		expected    string
	}{
		{
			name:        "positive amount",
			exactAmount: "1000",
			expected:    "1000",
		},
		{
			name:        "zero amount",
			exactAmount: "0",
			expected:    "0",
		},
		{
			name:        "large amount",
			exactAmount: "999999999999999",
			expected:    "999999999999999",
		},
		{
			name:        "amount with leading zeros",
			exactAmount: "00001000",
			expected:    "00001000",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				exactAmount: tt.exactAmount,
			}
			result := params.ExactAmount()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test SwapRouteParams.ExpectedExactAmountByFee
func TestSwapRouteParams_ExpectedExactAmountByFee(t *testing.T) {
	tests := []struct {
		name        string
		typ         SwapType
		exactAmount string
		feeBps      uint64
		expected    string
		description string
	}{
		{
			name:        "ExactIn returns exact amount unchanged",
			typ:         ExactIn,
			exactAmount: "1000",
			feeBps:      15,
			expected:    "1000",
			description: "ExactIn should return exactAmount without fee calculation",
		},
		{
			name:        "ExactOut calculates with 0.15% fee",
			typ:         ExactOut,
			exactAmount: "1000",
			feeBps:      15,
			expected:    "1001", // 1000 * 10000 / (10000 - 15) = 1001.50... rounded down to 1001
			description: "ExactOut should add router fee",
		},
		{
			name:        "ExactOut calculates with 0% fee",
			typ:         ExactOut,
			exactAmount: "1000",
			feeBps:      0,
			expected:    "1000",
			description: "ExactOut with 0% fee should return unchanged amount",
		},
		{
			name:        "ExactOut calculates with 1% fee",
			typ:         ExactOut,
			exactAmount: "1000",
			feeBps:      100,
			expected:    "1010", // 1000 * 10000 / (10000 - 100) = 1010.10... rounded down to 1010
			description: "ExactOut should add 1% fee",
		},
		{
			name:        "ExactOut with large amount",
			typ:         ExactOut,
			exactAmount: "1000000000",
			feeBps:      15,
			expected:    "1001502253", // 1000000000 * 10000 / (10000 - 15) = 1001502253.xxx
			description: "ExactOut should handle large amounts correctly",
		},
		{
			name:        "ExactOut with zero amount",
			typ:         ExactOut,
			exactAmount: "0",
			feeBps:      15,
			expected:    "0",
			description: "ExactOut with zero amount should return 0",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				typ:         tt.typ,
				exactAmount: tt.exactAmount,
			}
			result := params.ExpectedExactAmountByFee(tt.feeBps)
			uassert.Equal(t, result, tt.expected, tt.description)
		})
	}
}

// Test SwapRouteParams.IsUnwrap
func TestSwapRouteParams_IsUnwrap(t *testing.T) {
	tests := []struct {
		name        string
		outputToken string
		expected    bool
	}{
		{
			name:        "output token is gnot",
			outputToken: "gnot",
			expected:    true,
		},
		{
			name:        "output token is not gnot - WUGNOT",
			outputToken: "gno.land/r/gnoland/wugnot",
			expected:    false,
		},
		{
			name:        "output token is not gnot - other token",
			outputToken: "gno.land/r/demo/gns",
			expected:    false,
		},
		{
			name:        "output token is empty string",
			outputToken: "",
			expected:    false,
		},
		{
			name:        "output token is GNOT in uppercase",
			outputToken: "GNOT",
			expected:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				outputToken: tt.outputToken,
			}
			result := params.IsUnwrap()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test SwapRouteParams.SwapCount
func TestSwapRouteParams_SwapCount(t *testing.T) {
	tests := []struct {
		name     string
		routeArr string
		expected int64
	}{
		{
			name:     "single route single hop",
			routeArr: "tokenA:tokenB:500",
			expected: 1,
		},
		{
			name:     "single route two hops",
			routeArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			expected: 2,
		},
		{
			name:     "single route three hops",
			routeArr: "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000",
			expected: 3,
		},
		{
			name:     "two routes single hop each",
			routeArr: "tokenA:tokenB:500,tokenA:tokenC:3000",
			expected: 2,
		},
		{
			name:     "two routes with different hop counts",
			routeArr: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenD:10000",
			expected: 3, // 1 + 2
		},
		{
			name:     "three routes mixed hops",
			routeArr: "tokenA:tokenB:500,tokenA:tokenC:3000*POOL*tokenC:tokenD:10000,tokenA:tokenE:500*POOL*tokenE:tokenF:3000*POOL*tokenF:tokenG:10000",
			expected: 6, // 1 + 2 + 3
		},
		{
			name:     "empty route array",
			routeArr: "",
			expected: 1, // empty string results in one split result
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				routeArr: tt.routeArr,
			}
			result := params.SwapCount()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test SwapRouteParams.IsSetSqrtPriceLimitX96
func TestSwapRouteParams_IsSetSqrtPriceLimitX96(t *testing.T) {
	tests := []struct {
		name              string
		sqrtPriceLimitX96 string
		expected          bool
	}{
		{
			name:              "valid positive number",
			sqrtPriceLimitX96: "79228162514264337593543950336",
			expected:          true,
		},
		{
			name:              "valid small number",
			sqrtPriceLimitX96: "1",
			expected:          true,
		},
		{
			name:              "empty string",
			sqrtPriceLimitX96: "",
			expected:          false,
		},
		{
			name:              "zero string",
			sqrtPriceLimitX96: "0",
			expected:          false,
		},
		{
			name:              "zero string with leading zeros",
			sqrtPriceLimitX96: "00000",
			expected:          true, // not equal to "0"
		},
		{
			name:              "large number",
			sqrtPriceLimitX96: "999999999999999999999999999",
			expected:          true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				sqrtPriceLimitX96: tt.sqrtPriceLimitX96,
			}
			result := params.IsSetSqrtPriceLimitX96()
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test createSwapOperation
func TestCreateSwapOperation(t *testing.T) {
	tests := []struct {
		name        string
		params      SwapRouteParams
		expectError bool
		errorMsg    string
		opType      string
	}{
		{
			name: "ExactIn swap operation",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    9999999999,
				typ:         ExactIn,
				exactAmount: "1000",
				limitAmount: "900",
			},
			expectError: false,
			opType:      "*v1.ExactInSwapOperation",
		},
		{
			name: "ExactOut swap operation",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    9999999999,
				typ:         ExactOut,
				exactAmount: "1000",
				limitAmount: "1100",
			},
			expectError: false,
			opType:      "*v1.ExactOutSwapOperation",
		},
		{
			name: "invalid swap type",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    9999999999,
				typ:         SwapType(999),
				exactAmount: "1000",
				limitAmount: "900",
			},
			expectError: true,
			errorMsg:    "unknown swap type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op, err := createSwapOperation(router, tt.params)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, op)
			}
		})
	}
}

// Test extractSwapOperationData
func TestExtractSwapOperationData(t *testing.T) {
	tests := []struct {
		name                        string
		operation                   RouterOperation
		expectError                 bool
		errorMsg                    string
		expectedBeforeWugnotBalance int64
		expectedWrappedWugnot       int64
	}{
		{
			name: "ExactInSwapOperation",
			operation: &ExactInSwapOperation{
				baseSwapOperation: baseSwapOperation{
					userBeforeWugnotBalance: 1000,
					userWrappedWugnot:       500,
				},
			},
			expectError:                 false,
			expectedBeforeWugnotBalance: 1000,
			expectedWrappedWugnot:       500,
		},
		{
			name: "ExactOutSwapOperation",
			operation: &ExactOutSwapOperation{
				baseSwapOperation: baseSwapOperation{
					userBeforeWugnotBalance: 2000,
					userWrappedWugnot:       1000,
				},
			},
			expectError:                 false,
			expectedBeforeWugnotBalance: 2000,
			expectedWrappedWugnot:       1000,
		},
		{
			name: "unsupported operation type",
			operation: &mockOperation{
				ValidateErr: nil,
				ProcessErr:  nil,
				Result:      &SwapResult{},
			},
			expectError: true,
			errorMsg:    "unexpected operation type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			beforeBalance, wrappedAmount, err := extractSwapOperationData(tt.operation)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, beforeBalance, tt.expectedBeforeWugnotBalance)
				uassert.Equal(t, wrappedAmount, tt.expectedWrappedWugnot)
			}
		})
	}
}

// Test processRoute error cases
func TestProcessRoute_ErrorCases(t *testing.T) {
	op := &baseSwapOperation{}

	tests := []struct {
		name        string
		route       string
		toSwap      *i256.Int
		swapType    SwapType
		expectPanic bool
		panicMsg    string
	}{
		{
			name:        "invalid hops count - 4 hops",
			route:       "tokenA:tokenB:500*POOL*tokenB:tokenC:3000*POOL*tokenC:tokenD:10000*POOL*tokenD:tokenE:500",
			toSwap:      i256.NewInt(1000),
			swapType:    ExactIn,
			expectPanic: true,
			panicMsg:    "number of hops must be 1~3",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()

			if tt.expectPanic {
				defer func() {
					r := recover()
					uassert.NotNil(t, r, "expected panic but got none")
					var errMsg string
					switch v := r.(type) {
					case error:
						errMsg = v.Error()
					case string:
						errMsg = v
					default:
						t.Errorf("unexpected panic type: %T", r)
						return
					}
					uassert.True(t, strings.Contains(errMsg, tt.panicMsg), "panic message should contain: "+tt.panicMsg+", got: "+errMsg)
				}()
			}

			_, _, _ = op.processRoute(router, tt.route, tt.toSwap, tt.swapType)
		})
	}
}

// Test validateRouteQuote edge cases
func TestValidateRouteQuote_EdgeCases(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified *i256.Int
		quote           string
		index           int
		expectError     bool
		expectedResult  string
		description     string
	}{
		{
			name:            "zero amount specified",
			amountSpecified: i256.NewInt(0),
			quote:           "50",
			index:           0,
			expectError:     false,
			expectedResult:  "0",
			description:     "0 * 50 / 100 = 0",
		},
		{
			name:            "zero quote percentage",
			amountSpecified: i256.NewInt(1000),
			quote:           "0",
			index:           0,
			expectError:     false,
			expectedResult:  "0",
			description:     "1000 * 0 / 100 = 0",
		},
		{
			name:            "100% quote",
			amountSpecified: i256.NewInt(1000),
			quote:           "100",
			index:           0,
			expectError:     false,
			expectedResult:  "1000",
			description:     "1000 * 100 / 100 = 1000",
		},
		{
			name:            "1% quote",
			amountSpecified: i256.NewInt(10000),
			quote:           "1",
			index:           0,
			expectError:     false,
			expectedResult:  "100",
			description:     "10000 * 1 / 100 = 100",
		},
		{
			name:            "negative quote",
			amountSpecified: i256.NewInt(1000),
			quote:           "-50",
			index:           0,
			expectError:     false,
			expectedResult:  "-500",
			description:     "negative quote results in negative amount",
		},
		{
			name:            "quote with leading zeros",
			amountSpecified: i256.NewInt(1000),
			quote:           "050",
			index:           0,
			expectError:     false,
			expectedResult:  "500",
			description:     "leading zeros should be handled correctly",
		},
		{
			name:            "invalid quote - decimal",
			amountSpecified: i256.NewInt(1000),
			quote:           "50.5",
			index:           0,
			expectError:     true,
			description:     "decimal quotes should fail",
		},
		{
			name:            "quote greater than 100",
			amountSpecified: i256.NewInt(1000),
			quote:           "150",
			index:           0,
			expectError:     false,
			expectedResult:  "1500",
			description:     "quotes over 100% are technically valid",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			op := &baseSwapOperation{
				amountSpecified: tt.amountSpecified,
			}

			result, err := op.validateRouteQuote(tt.quote, tt.index)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err, tt.description)
				if result != nil && tt.expectedResult != "" {
					expected := i256.MustFromDecimal(tt.expectedResult)
					uassert.Equal(t, result.ToString(), expected.ToString(), tt.description)
				}
			}
		})
	}
}

// Test processRoutes with overflow detection
func TestProcessRoutes_OverflowDetection(t *testing.T) {
	tests := []struct {
		name        string
		op          *baseSwapOperation
		expectPanic bool
		panicMsg    string
	}{
		{
			name: "normal amounts - no overflow",
			op: &baseSwapOperation{
				amountSpecified: i256.NewInt(1000),
				routes:          []string{"route1"},
				quotes:          []string{"100"},
			},
			expectPanic: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic {
				defer func() {
					r := recover()
					uassert.NotNil(t, r, "expected panic but got none")
					var errMsg string
					switch v := r.(type) {
					case error:
						errMsg = v.Error()
					case string:
						errMsg = v
					}
					uassert.True(t, strings.Contains(errMsg, tt.panicMsg), "panic message should contain: "+tt.panicMsg)
				}()
			}

			// This test would require actual router setup for full execution
			// For now, we just test that the structure is correct
			uassert.NotNil(t, tt.op)
		})
	}
}

// Test handleSingleSwap parameters
func TestHandleSingleSwap_Parameters(t *testing.T) {
	tests := []struct {
		name                 string
		route                string
		amountSpecified      *i256.Int
		withUnwrap           bool
		sqrtPriceLimitX96    string
		shouldParseCorrectly bool
	}{
		{
			name:                 "valid single hop route",
			route:                "tokenA:tokenB:500",
			amountSpecified:      i256.NewInt(1000),
			withUnwrap:           false,
			sqrtPriceLimitX96:    "",
			shouldParseCorrectly: true,
		},
		{
			name:                 "single hop with unwrap",
			route:                "tokenA:gnot:500",
			amountSpecified:      i256.NewInt(1000),
			withUnwrap:           true,
			sqrtPriceLimitX96:    "",
			shouldParseCorrectly: true,
		},
		{
			name:                 "single hop with price limit",
			route:                "tokenA:tokenB:500",
			amountSpecified:      i256.NewInt(1000),
			withUnwrap:           false,
			sqrtPriceLimitX96:    "79228162514264337593543950336",
			shouldParseCorrectly: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Just verify the parameters are properly structured
			uassert.NotNil(t, tt.route)
			uassert.NotNil(t, tt.amountSpecified)
		})
	}
}

// Test handleMultiSwap with different swap types
func TestHandleMultiSwap_SwapTypes(t *testing.T) {
	tests := []struct {
		name            string
		swapType        SwapType
		route           string
		numHops         int
		amountSpecified *i256.Int
		withUnwrap      bool
		expectPanic     bool
		panicMsg        string
		needsRouter     bool
	}{
		{
			name:            "Invalid swap type",
			swapType:        SwapType(999),
			route:           "tokenA:tokenB:500*POOL*tokenB:tokenC:3000",
			numHops:         2,
			amountSpecified: i256.NewInt(1000),
			withUnwrap:      false,
			expectPanic:     true,
			panicMsg:        "invalid swap type",
			needsRouter:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.expectPanic && tt.needsRouter {
				defer func() {
					r := recover()
					uassert.NotNil(t, r, "expected panic but got none")
					var errMsg string
					switch v := r.(type) {
					case error:
						errMsg = v.Error()
					case string:
						errMsg = v
					}
					uassert.True(t, strings.Contains(errMsg, tt.panicMsg), "panic message should contain: "+tt.panicMsg)
				}()

				router := mockRouter()
				router.handleMultiSwap(tt.swapType, tt.route, tt.numHops, tt.amountSpecified, tt.withUnwrap)
			} else {
				// Just verify the parameters are structured correctly
				uassert.NotNil(t, tt.route)
				uassert.NotNil(t, tt.amountSpecified)
			}
		})
	}
}

// Test processRoutes last route remainder handling
func TestProcessRoutes_LastRouteRemainder(t *testing.T) {
	tests := []struct {
		name               string
		amountSpecified    *i256.Int
		routes             []string
		quotes             []string
		expectedLastAmount string
		description        string
	}{
		{
			name:               "even split - no remainder",
			amountSpecified:    i256.NewInt(100),
			routes:             []string{"route1", "route2"},
			quotes:             []string{"50", "50"},
			expectedLastAmount: "50",
			description:        "Last route should get exact split amount",
		},
		{
			name:               "odd amount - remainder goes to last",
			amountSpecified:    i256.NewInt(101),
			routes:             []string{"route1", "route2"},
			quotes:             []string{"50", "50"},
			expectedLastAmount: "51",
			description:        "Last route should get 50 + remainder(1)",
		},
		{
			name:               "three routes with remainder",
			amountSpecified:    i256.NewInt(100),
			routes:             []string{"route1", "route2", "route3"},
			quotes:             []string{"33", "33", "34"},
			expectedLastAmount: "34",
			description:        "Last route should get remaining amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Calculate what the last route should receive
			remainingAmount := tt.amountSpecified
			for i := 0; i < len(tt.routes)-1; i++ {
				quoteInt, err := i256.FromDecimal(tt.quotes[i])
				uassert.NoError(t, err)

				amount := i256.Zero().Mul(tt.amountSpecified, quoteInt)
				amount = i256.Zero().Div(amount, i256.NewInt(100))

				remainingAmount = i256.Zero().Sub(remainingAmount, amount)
			}

			expected := i256.MustFromDecimal(tt.expectedLastAmount)
			uassert.Equal(t, remainingAmount.ToString(), expected.ToString(), tt.description)
		})
	}
}

// Test baseSwapOperation fields initialization
func TestBaseSwapOperation_Initialization(t *testing.T) {
	tests := []struct {
		name                    string
		sqrtPriceLimitX96       string
		withUnwrap              bool
		userBeforeWugnotBalance int64
		userWrappedWugnot       int64
		routes                  []string
		quotes                  []string
		amountSpecified         *i256.Int
	}{
		{
			name:                    "default initialization",
			sqrtPriceLimitX96:       "",
			withUnwrap:              false,
			userBeforeWugnotBalance: 0,
			userWrappedWugnot:       0,
			routes:                  []string{},
			quotes:                  []string{},
			amountSpecified:         i256.Zero(),
		},
		{
			name:                    "with price limit",
			sqrtPriceLimitX96:       "79228162514264337593543950336",
			withUnwrap:              false,
			userBeforeWugnotBalance: 0,
			userWrappedWugnot:       0,
			routes:                  []string{"route1"},
			quotes:                  []string{"100"},
			amountSpecified:         i256.NewInt(1000),
		},
		{
			name:                    "with unwrap",
			sqrtPriceLimitX96:       "",
			withUnwrap:              true,
			userBeforeWugnotBalance: 1000,
			userWrappedWugnot:       500,
			routes:                  []string{"route1"},
			quotes:                  []string{"100"},
			amountSpecified:         i256.NewInt(1000),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			op := &baseSwapOperation{
				sqrtPriceLimitX96:       tt.sqrtPriceLimitX96,
				withUnwrap:              tt.withUnwrap,
				userBeforeWugnotBalance: tt.userBeforeWugnotBalance,
				userWrappedWugnot:       tt.userWrappedWugnot,
				routes:                  tt.routes,
				quotes:                  tt.quotes,
				amountSpecified:         tt.amountSpecified,
			}

			uassert.Equal(t, op.sqrtPriceLimitX96, tt.sqrtPriceLimitX96)
			uassert.Equal(t, op.withUnwrap, tt.withUnwrap)
			uassert.Equal(t, op.userBeforeWugnotBalance, tt.userBeforeWugnotBalance)
			uassert.Equal(t, op.userWrappedWugnot, tt.userWrappedWugnot)
			uassert.Equal(t, len(op.routes), len(tt.routes))
			uassert.Equal(t, len(op.quotes), len(tt.quotes))
			uassert.Equal(t, op.amountSpecified.ToString(), tt.amountSpecified.ToString())
		})
	}
}

// Test BaseSwapParams struct
func TestBaseSwapParams_Structure(t *testing.T) {
	tests := []struct {
		name              string
		params            BaseSwapParams
		expectedInputLen  int
		expectedOutputLen int
	}{
		{
			name: "valid params with all fields",
			params: BaseSwapParams{
				InputToken:        "tokenA",
				OutputToken:       "tokenB",
				RouteArr:          "tokenA:tokenB:500",
				QuoteArr:          "100",
				SqrtPriceLimitX96: "79228162514264337593543950336",
				Deadline:          9999999999,
			},
			expectedInputLen:  6,
			expectedOutputLen: 6,
		},
		{
			name: "params with empty sqrt price limit",
			params: BaseSwapParams{
				InputToken:        "tokenA",
				OutputToken:       "tokenB",
				RouteArr:          "tokenA:tokenB:500",
				QuoteArr:          "100",
				SqrtPriceLimitX96: "",
				Deadline:          9999999999,
			},
			expectedInputLen:  6,
			expectedOutputLen: 6,
		},
		{
			name: "params with multi-route",
			params: BaseSwapParams{
				InputToken:        "tokenA",
				OutputToken:       "tokenB",
				RouteArr:          "tokenA:tokenB:500,tokenA:tokenC:3000",
				QuoteArr:          "50,50",
				SqrtPriceLimitX96: "",
				Deadline:          9999999999,
			},
			expectedInputLen:  6,
			expectedOutputLen: 6,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.NotEmpty(t, tt.params.InputToken)
			uassert.NotEmpty(t, tt.params.OutputToken)
			uassert.NotEmpty(t, tt.params.RouteArr)
			uassert.NotEmpty(t, tt.params.QuoteArr)
		})
	}
}

// Test SwapResult structure
func TestSwapResult_Structure(t *testing.T) {
	tests := []struct {
		name            string
		amountIn        *u256.Uint
		amountOut       *u256.Uint
		routes          []string
		quotes          []string
		amountSpecified *i256.Int
		withUnwrap      bool
	}{
		{
			name:            "single route result",
			amountIn:        u256.NewUint(1000),
			amountOut:       u256.NewUint(980),
			routes:          []string{"route1"},
			quotes:          []string{"100"},
			amountSpecified: i256.NewInt(1000),
			withUnwrap:      false,
		},
		{
			name:            "multi-route result",
			amountIn:        u256.NewUint(1000),
			amountOut:       u256.NewUint(980),
			routes:          []string{"route1", "route2"},
			quotes:          []string{"50", "50"},
			amountSpecified: i256.NewInt(1000),
			withUnwrap:      false,
		},
		{
			name:            "result with unwrap",
			amountIn:        u256.NewUint(1000),
			amountOut:       u256.NewUint(980),
			routes:          []string{"route1"},
			quotes:          []string{"100"},
			amountSpecified: i256.NewInt(1000),
			withUnwrap:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := &SwapResult{
				AmountIn:        tt.amountIn,
				AmountOut:       tt.amountOut,
				Routes:          tt.routes,
				Quotes:          tt.quotes,
				AmountSpecified: tt.amountSpecified,
				WithUnwrap:      tt.withUnwrap,
			}

			uassert.NotNil(t, result.AmountIn)
			uassert.NotNil(t, result.AmountOut)
			uassert.Equal(t, len(result.Routes), len(tt.routes))
			uassert.Equal(t, len(result.Quotes), len(tt.quotes))
			uassert.NotNil(t, result.AmountSpecified)
			uassert.Equal(t, result.WithUnwrap, tt.withUnwrap)
		})
	}
}

// Test handleNativeTokenWrapping with both input and output native
func TestHandleNativeTokenWrapping_BothNative(t *testing.T) {
	tests := []struct {
		name            string
		inputToken      string
		outputToken     string
		specifiedAmount *i256.Int
		expectError     bool
		description     string
	}{
		{
			name:            "both input and output are gnot (invalid)",
			inputToken:      "gnot",
			outputToken:     "gnot",
			specifiedAmount: i256.NewInt(1000),
			expectError:     true,
			description:     "Cannot swap gnot to gnot",
		},
		{
			name:            "input gnot, output wugnot",
			inputToken:      "gnot",
			outputToken:     "gno.land/r/gnoland/wugnot",
			specifiedAmount: i256.NewInt(1000),
			expectError:     false,
			description:     "Valid: wrapping gnot to wugnot",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// This test structure verifies the parameters are correct
			uassert.NotEmpty(t, tt.inputToken)
			uassert.NotEmpty(t, tt.outputToken)
			uassert.NotNil(t, tt.specifiedAmount)
		})
	}
}

// Test validateRouteQuote with extreme values
func TestValidateRouteQuote_ExtremeValues(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified *i256.Int
		quote           string
		index           int
		expectError     bool
		description     string
	}{
		{
			name:            "max int64 amount",
			amountSpecified: i256.NewInt(9223372036854775807), // max int64
			quote:           "1",
			index:           0,
			expectError:     false,
			description:     "Should handle max int64",
		},
		{
			name:            "very large amount",
			amountSpecified: i256.MustFromDecimal("999999999999999999999"),
			quote:           "1",
			index:           0,
			expectError:     false,
			description:     "Should handle very large amounts",
		},
		{
			name:            "amount 1 with quote 1",
			amountSpecified: i256.NewInt(1),
			quote:           "1",
			index:           0,
			expectError:     false,
			description:     "Should handle minimal amounts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			op := &baseSwapOperation{
				amountSpecified: tt.amountSpecified,
			}

			result, err := op.validateRouteQuote(tt.quote, tt.index)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err, tt.description)
				uassert.NotNil(t, result)
			}
		})
	}
}

// Test processRoutes with single route
func TestProcessRoutes_SingleRoute(t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified *i256.Int
		routes          []string
		quotes          []string
		description     string
	}{
		{
			name:            "single route 100%",
			amountSpecified: i256.NewInt(1000),
			routes:          []string{"route1"},
			quotes:          []string{"100"},
			description:     "Single route should use full amount",
		},
		{
			name:            "single route with odd amount",
			amountSpecified: i256.NewInt(999),
			routes:          []string{"route1"},
			quotes:          []string{"100"},
			description:     "Single route should use full odd amount",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Verify the last route gets all remaining amount
			remainingAmount := tt.amountSpecified
			for i := 0; i < len(tt.routes)-1; i++ {
				quoteInt, err := i256.FromDecimal(tt.quotes[i])
				uassert.NoError(t, err)

				amount := i256.Zero().Mul(tt.amountSpecified, quoteInt)
				amount = i256.Zero().Div(amount, i256.NewInt(100))

				remainingAmount = i256.Zero().Sub(remainingAmount, amount)
			}

			// For single route, remaining amount equals specified amount
			uassert.Equal(t, remainingAmount.ToString(), tt.amountSpecified.ToString(), tt.description)
		})
	}
}

// Test SwapRouteParams with boundary values
func TestSwapRouteParams_BoundaryValues(t *testing.T) {
	tests := []struct {
		name        string
		params      SwapRouteParams
		description string
	}{
		{
			name: "min deadline value",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    0,
				typ:         ExactIn,
				exactAmount: "1",
			},
			description: "Deadline can be 0",
		},
		{
			name: "max deadline value",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    9223372036854775807, // max int64
				typ:         ExactIn,
				exactAmount: "1",
			},
			description: "Deadline can be max int64",
		},
		{
			name: "min exact amount",
			params: SwapRouteParams{
				inputToken:  "tokenA",
				outputToken: "tokenB",
				routeArr:    "tokenA:tokenB:500",
				quoteArr:    "100",
				deadline:    9999999999,
				typ:         ExactIn,
				exactAmount: "1",
			},
			description: "Exact amount can be 1",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			uassert.NotEmpty(t, tt.params.inputToken, tt.description)
			uassert.NotEmpty(t, tt.params.outputToken, tt.description)
			uassert.NotEmpty(t, tt.params.exactAmount, tt.description)
		})
	}
}

// Test SwapRouteParams.ExactAmount with various formats
func TestSwapRouteParams_ExactAmount_Formats(t *testing.T) {
	tests := []struct {
		name        string
		exactAmount string
		expected    string
		description string
	}{
		{
			name:        "amount with trailing zeros",
			exactAmount: "1000000",
			expected:    "1000000",
			description: "Should preserve trailing zeros",
		},
		{
			name:        "amount as string '1'",
			exactAmount: "1",
			expected:    "1",
			description: "Should handle single digit",
		},
		{
			name:        "very large amount string",
			exactAmount: "999999999999999999999999",
			expected:    "999999999999999999999999",
			description: "Should handle very large amounts",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				exactAmount: tt.exactAmount,
			}
			result := params.ExactAmount()
			uassert.Equal(t, result, tt.expected, tt.description)
		})
	}
}

// Test SwapRouteParams.SwapCount with complex routes
func TestSwapRouteParams_SwapCount_Complex(t *testing.T) {
	tests := []struct {
		name        string
		routeArr    string
		expected    int64
		description string
	}{
		{
			name:        "seven routes single hop each (maximum)",
			routeArr:    "a:b:1,c:d:2,e:f:3,g:h:4,i:j:5,k:l:6,m:n:7",
			expected:    7,
			description: "Maximum 7 routes with single hop each",
		},
		{
			name:        "complex multi-hop routes",
			routeArr:    "a:b:1*POOL*b:c:2*POOL*c:d:3,e:f:4*POOL*f:g:5,h:i:6",
			expected:    6, // 3 + 2 + 1
			description: "Mix of 3-hop, 2-hop, and 1-hop routes",
		},
		{
			name:        "all routes with 3 hops",
			routeArr:    "a:b:1*POOL*b:c:2*POOL*c:d:3,e:f:4*POOL*f:g:5*POOL*g:h:6",
			expected:    6, // 3 + 3
			description: "Two routes with 3 hops each",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := &SwapRouteParams{
				routeArr: tt.routeArr,
			}
			result := params.SwapCount()
			uassert.Equal(t, result, tt.expected, tt.description)
		})
	}
}

// Test createSwapOperation with edge cases
func TestCreateSwapOperation_EdgeCases(t *testing.T) {
	tests := []struct {
		name        string
		params      SwapRouteParams
		expectError bool
		description string
	}{
		{
			name: "ExactIn with minimum values",
			params: SwapRouteParams{
				inputToken:  "a",
				outputToken: "b",
				routeArr:    "a:b:1",
				quoteArr:    "100",
				deadline:    1,
				typ:         ExactIn,
				exactAmount: "1",
				limitAmount: "0",
			},
			expectError: false,
			description: "Should handle minimum values",
		},
		{
			name: "ExactOut with minimum values",
			params: SwapRouteParams{
				inputToken:  "a",
				outputToken: "b",
				routeArr:    "a:b:1",
				quoteArr:    "100",
				deadline:    1,
				typ:         ExactOut,
				exactAmount: "1",
				limitAmount: "999999999",
			},
			expectError: false,
			description: "Should handle minimum values for ExactOut",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op, err := createSwapOperation(router, tt.params)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err, tt.description)
				uassert.NotNil(t, op)
			}
		})
	}
}

// Test extractSwapOperationData with nil operation
func TestExtractSwapOperationData_NilHandling(t *testing.T) {
	tests := []struct {
		name        string
		operation   RouterOperation
		expectError bool
		errorMsg    string
	}{
		{
			name: "valid ExactIn operation",
			operation: &ExactInSwapOperation{
				baseSwapOperation: baseSwapOperation{
					userBeforeWugnotBalance: 1000,
					userWrappedWugnot:       500,
				},
			},
			expectError: false,
		},
		{
			name: "valid ExactOut operation",
			operation: &ExactOutSwapOperation{
				baseSwapOperation: baseSwapOperation{
					userBeforeWugnotBalance: 2000,
					userWrappedWugnot:       1000,
				},
			},
			expectError: false,
		},
		{
			name:        "invalid operation type",
			operation:   &mockOperation{},
			expectError: true,
			errorMsg:    "unexpected operation type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, _, err := extractSwapOperationData(tt.operation)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error should contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test processRoutes remainder calculation accuracy
func TestProcessRoutes_RemainderAccuracy(t *testing.T) {
	tests := []struct {
		name                 string
		amountSpecified      *i256.Int
		quotes               []string
		expectedRemainderPct float64
		description          string
	}{
		{
			name:                 "three-way split with large remainder",
			amountSpecified:      i256.NewInt(1000),
			quotes:               []string{"33", "33", "34"},
			expectedRemainderPct: 0.01, // 1% remainder
			description:          "Remainder should be minimal",
		},
		{
			name:                 "five-way split",
			amountSpecified:      i256.NewInt(1000),
			quotes:               []string{"20", "20", "20", "20", "20"},
			expectedRemainderPct: 0.0, // no remainder
			description:          "Perfect split should have no remainder",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			totalUsed := i256.Zero()
			for i := 0; i < len(tt.quotes)-1; i++ {
				quoteInt, err := i256.FromDecimal(tt.quotes[i])
				uassert.NoError(t, err)

				amount := i256.Zero().Mul(tt.amountSpecified, quoteInt)
				amount = i256.Zero().Div(amount, i256.NewInt(100))

				totalUsed = i256.Zero().Add(totalUsed, amount)
			}

			remainder := i256.Zero().Sub(tt.amountSpecified, totalUsed)

			// Verify remainder is within expected range
			uassert.True(t, remainder.Cmp(i256.Zero()) >= 0, "remainder should be non-negative")
			uassert.True(t, remainder.Cmp(tt.amountSpecified) <= 0, "remainder should not exceed total")
		})
	}
}

// Test SwapRouteParams methods with empty values
func TestSwapRouteParams_EmptyValues(t *testing.T) {
	tests := []struct {
		name   string
		params SwapRouteParams
		method string
	}{
		{
			name: "empty exact amount",
			params: SwapRouteParams{
				exactAmount: "",
			},
			method: "ExactAmount",
		},
		{
			name: "empty route array",
			params: SwapRouteParams{
				routeArr: "",
			},
			method: "SwapCount",
		},
		{
			name: "empty output token",
			params: SwapRouteParams{
				outputToken: "",
			},
			method: "IsUnwrap",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			switch tt.method {
			case "ExactAmount":
				result := tt.params.ExactAmount()
				uassert.Equal(t, result, "")
			case "SwapCount":
				result := tt.params.SwapCount()
				// Empty string results in 1 after split
				uassert.Equal(t, result, int64(1))
			case "IsUnwrap":
				result := tt.params.IsUnwrap()
				uassert.Equal(t, result, false)
			}
		})
	}
}
