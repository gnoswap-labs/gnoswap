package router

import (
	"std"
	"strconv"
	"strings"
    "testing"

	"gno.land/p/demo/uassert"
	"gno.land/p/demo/testutils"

	"gno.land/r/gnoswap/v1/consts"
    i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"
	"gno.land/r/demo/wugnot"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
	"gno.land/r/gnoswap/v1/gns"

	pusers "gno.land/p/demo/users"
)

func TestNewRouteParams(t *testing.T) {
    tests := []struct {
        name           string
        inputToken     string
        outputToken    string
        amountSpec    string
        swapType      string
        routes        string
        quotes        string
        expectError   bool
    }{
        {
            name:        "Valid parameters",
            inputToken:  "tokenA",
            outputToken: "tokenB",
            amountSpec: "100",
            swapType:   ExactIn,
            routes:     "routeA*POOL*routeB",
            quotes:     "100",
            expectError: false,
        },
        {
            name:        "Invalid amount",
            inputToken:  "tokenA",
            outputToken: "tokenB",
            amountSpec: "invalid",
            swapType:   ExactIn,
            routes:     "routeA*POOL*routeB",
            quotes:     "100",
            expectError: true,
        },
        {
            name:        "Invalid quotes",
            inputToken:  "tokenA",
            outputToken: "tokenB",
            amountSpec: "100",
            swapType:   ExactIn,
            routes:     "routeA*POOL*routeB",
            quotes:     "invalid",
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            params, err := newRouteParams(
                tt.inputToken,
                tt.outputToken,
                tt.amountSpec,
                tt.swapType,
                tt.routes,
                tt.quotes,
            )
            
            if tt.expectError {
				if err == nil {
					t.Errorf("expected error, got nil")
				}
            } else {
				if err != nil {
					t.Errorf("expected no error, got %v", err)
				}

				uassert.Equal(t, tt.inputToken, params.inputToken)
				uassert.Equal(t, tt.outputToken, params.outputToken)
				uassert.Equal(t, tt.swapType, params.swapType)
            }
        })
    }
}

func TestValidateRouteParams(t *testing.T) {
    tests := []struct {
        name        string
        params      *RouteParams
        expectError bool
    }{
        {
            name: "Valid parameters",
            params: &RouteParams{
                inputToken:      "tokenA",
                outputToken:     "tokenB",
                amountSpecified: i256.NewInt(100),
                swapType:        ExactIn,
                routes:          []string{"routeA"},
                quotes:          []int{100},
            },
            expectError: false,
        },
        {
            name: "Invalid swap type",
            params: &RouteParams{
                inputToken:      "tokenA",
                outputToken:     "tokenB",
                amountSpecified: i256.NewInt(100),
                swapType:        "INVALID",
                routes:          []string{"routeA"},
                quotes:          []int{100},
            },
            expectError: true,
        },
        {
            name: "Invalid quotes sum",
            params: &RouteParams{
                inputToken:      "tokenA",
                outputToken:     "tokenB",
                amountSpecified: i256.NewInt(100),
                swapType:        ExactIn,
                routes:          []string{"routeA"},
                quotes:          []int{90},
            },
            expectError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
			err := tt.params.validate()
            if tt.expectError {
				if err == nil {
					t.Errorf("expected error, got nil")
				}
            }
        })
    }
}

func TestValidateSlippageLimit(t *testing.T) {
    tests := []struct {
        name            string
        swapType        string
        tokenAmountLimit string
        afterFee        string
        resultAmountIn  string
        expectError     bool
    }{
        {
            name:            "ExactIn - Ok",
            swapType:        ExactIn,
            tokenAmountLimit: "100",
            afterFee:        "150",
            resultAmountIn:  "100",
            expectError:     false,
        },
        {
            name:            "ExactIn - exceed slippage",
            swapType:        ExactIn,
            tokenAmountLimit: "150",
            afterFee:        "100",
            resultAmountIn:  "100",
            expectError:     true,
        },
        {
            name:            "ExactOut - Ok",
            swapType:        ExactOut,
            tokenAmountLimit: "150",
            afterFee:        "100",
            resultAmountIn:  "100",
            expectError:     false,
        },
        {
            name:            "ExactOut - exceed slippage",
            swapType:        ExactOut,
            tokenAmountLimit: "100",
            afterFee:        "100",
            resultAmountIn:  "150",
            expectError:     true,
        },
        {
            name:            "Invalid swap type",
            swapType:        "INVALID",
            tokenAmountLimit: "100",
            afterFee:        "100",
            resultAmountIn:  "100",
            expectError:     true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            limit := u256.MustFromDecimal(tt.tokenAmountLimit)
            afterFee := u256.MustFromDecimal(tt.afterFee)
            resultAmountIn := u256.MustFromDecimal(tt.resultAmountIn)

            err := validateSlippageLimit(tt.swapType, limit, afterFee, resultAmountIn)

            if tt.expectError && err == nil {
                t.Error("expected error but got nil")
            }
            if !tt.expectError && err != nil {
                t.Errorf("expected no error but got: %v", err)
            }
        })
    }
}

func TestHandleWugnotPreSwap(t *testing.T) {
    testAddr := testutils.TestAddress("test")
    std.TestSetOrigCaller(testAddr)

	t.Run("Swap with non-GNOT tokens", func(t *testing.T) {
        params := &RouteParams{
            inputToken:  barPath,
            outputToken: bazPath,
            swapType:    ExactIn,
        }
        
        balance, wrapped, err := handleWugnotPreSwap(barPath, bazPath, params)
		if err != nil {
            t.Errorf("unexpected error: %v", err)
        }

        uassert.Equal(t, uint64(0), balance)
        uassert.Equal(t, uint64(0), wrapped)
    })

	t.Run("Swap with different amount of GNOT", func(t *testing.T) {
        amount := uint64(1000)
        wrongAmount := uint64(500)
        
        params := &RouteParams{
            inputToken:      consts.GNOT,
            outputToken:     barPath,
            swapType:       ExactIn,
            amountSpecified: i256.NewInt(int64(amount)),
        }

        std.TestSetOrigSend(std.Coins{{"ugnot", int64(wrongAmount)}}, nil)

        _, _, err := handleWugnotPreSwap(consts.GNOT, barPath, params)
        if err == nil {
			t.Errorf("expected error, got nil")
		}
    })

	t.Run("Swap for GNOT output", func(t *testing.T) {
        params := &RouteParams{
            inputToken:  barPath,
            outputToken: consts.GNOT,
            swapType:    ExactIn,
        }
        
        balance, wrapped, err := handleWugnotPreSwap(barPath, consts.GNOT, params)
        if err != nil {
			t.Errorf("unexpected error: %v", err)
		}
        uassert.Equal(t, ugnotBalanceOf(t, testAddr), balance)
        uassert.Equal(t, uint64(0), wrapped)
    })
}

func TestProcessResult(t *testing.T) {
	tests := []struct {
		name            string
		swapType        string
		resultAmountIn  *u256.Uint
		resultAmountOut *u256.Uint
		amountSpecified *i256.Int
		expectedAmount  string
		expectError     bool
	}{
		{
			name:            "ExactIn success",
			swapType:        ExactIn,
			resultAmountIn:  u256.MustFromDecimal("100"),
			resultAmountOut: u256.MustFromDecimal("95"),
			amountSpecified: i256.MustFromDecimal("100"),
			expectedAmount:  "95",
			expectError:     false,
		},
		{
			name:            "ExactIn amount mismatt.",
			swapType:        ExactIn,
			resultAmountIn:  u256.MustFromDecimal("90"),
			resultAmountOut: u256.MustFromDecimal("85"),
			amountSpecified: i256.MustFromDecimal("100"),
			expectedAmount:  "-1",
			expectError:     true,
		},
		{
			name:            "ExactOut success",
			swapType:        ExactOut,
			resultAmountIn:  u256.MustFromDecimal("105"),
			resultAmountOut: u256.MustFromDecimal("100"),
			amountSpecified: i256.MustFromDecimal("100"),
			expectedAmount:  "105",
			expectError:     false,
		},
		{
			name:            "ExactOut insufficient output",
			swapType:        ExactOut,
			resultAmountIn:  u256.MustFromDecimal("105"),
			resultAmountOut: u256.MustFromDecimal("95"),
			amountSpecified: i256.MustFromDecimal("100"),
			expectedAmount:  "-1",
			expectError:     true,
		},
		{
			name:            "Invalid swap type",
			swapType:        "INVALID",
			resultAmountIn:  u256.MustFromDecimal("100"),
			resultAmountOut: u256.MustFromDecimal("95"),
			amountSpecified: i256.MustFromDecimal("100"),
			expectedAmount:  "",
			expectError:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amount, err := processResult(tt.swapType, tt.resultAmountIn, tt.resultAmountOut, tt.amountSpecified)
			
			if tt.expectError {
				if err == nil {
					t.Errorf("expected error but got none")
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}

			if amount != tt.expectedAmount {
				t.Errorf("expected amount %s, got %s", tt.expectedAmount, amount)
			}
		})
	}
}

func TestFinalizeSwap(t *testing.T) {
	mockToken := &struct {
		GRC20Interface
	}{
		GRC20Interface: MockGRC20{
			TransferFn: func(to pusers.AddressOrName, amount uint64) {},
			TransferFromFn: func(from, to pusers.AddressOrName, amount uint64) {},
			BalanceOfFn: func(owner pusers.AddressOrName) uint64 { return 1000 },
			ApproveFn: func(spender pusers.AddressOrName, amount uint64) {},
		},
	}

	registerGRC20ForTest(t, "token1", mockToken)
	registerGRC20ForTest(t, "token2", mockToken)

	tests := []struct {
		name                   string
		inputToken            string
		outputToken           string
		resultAmountIn        *u256.Uint
		resultAmountOut       *u256.Uint
		swapType              string
		tokenAmountLimit      *u256.Uint
		userBeforeWugnotBalance uint64
		userWrappedWugnot     uint64
		amountSpecified       *u256.Uint
		expectedAmountIn      string
		expectedAmountOut     string
		expectError           bool
		errorMessage          string
	}{
		{
			name: "ExactIn - Success",
			inputToken: "token1",
			outputToken: "token2",
			resultAmountIn: u256.MustFromDecimal("100"),
			resultAmountOut: u256.MustFromDecimal("95"),
			swapType: ExactIn,
			tokenAmountLimit: u256.MustFromDecimal("90"),
			amountSpecified: u256.MustFromDecimal("100"),
			expectedAmountIn: "100",
			expectedAmountOut: "-95",
			expectError: false,
		},
		{
			name: "ExactIn - Slippage error",
			inputToken: "token1",
			outputToken: "token2",
			resultAmountIn: u256.MustFromDecimal("100"),
			resultAmountOut: u256.MustFromDecimal("85"),
			swapType: ExactIn,
			tokenAmountLimit: u256.MustFromDecimal("90"),
			amountSpecified: u256.MustFromDecimal("100"),
			expectError: true,
			errorMessage: "minimum amount not received",
		},
		{
			name: "ExactOut - Success",
			inputToken: "token1",
			outputToken: "token2",
			resultAmountIn: u256.MustFromDecimal("105"),
			resultAmountOut: u256.MustFromDecimal("100"),
			swapType: ExactOut,
			tokenAmountLimit: u256.MustFromDecimal("110"),
			amountSpecified: u256.MustFromDecimal("100"),
			expectedAmountIn: "105",
			expectedAmountOut: "-100",
			expectError: false,
		},
		{
			name: "ExactOut - Slippage error",
			inputToken: "token1",
			outputToken: "token2",
			resultAmountIn: u256.MustFromDecimal("115"),
			resultAmountOut: u256.MustFromDecimal("100"),
			swapType: ExactOut,
			tokenAmountLimit: u256.MustFromDecimal("110"),
			amountSpecified: u256.MustFromDecimal("100"),
			expectError: true,
			errorMessage: "maximum amount exceeded",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			amountIn, amountOut, err := finalizeSwap(
				tt.inputToken,
				tt.outputToken,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.swapType,
				tt.tokenAmountLimit,
				tt.userBeforeWugnotBalance,
				tt.userWrappedWugnot,
				tt.amountSpecified,
			)

			if tt.expectError {
				if err == nil {
					t.Errorf("expected error containing '%s', got no error", tt.errorMessage)
				} else if !strings.Contains(err.Error(), tt.errorMessage) {
					t.Errorf("expected error containing '%s', got '%s'", tt.errorMessage, err.Error())
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}

			if amountIn != tt.expectedAmountIn {
				t.Errorf("amountIn: expected %s, got %s", tt.expectedAmountIn, amountIn)
			}

			if amountOut != tt.expectedAmountOut {
				t.Errorf("amountOut: expected %s, got %s", tt.expectedAmountOut, amountOut)
			}
		})
	}

	unregisterGRC20ForTest(t, "token1")
	unregisterGRC20ForTest(t, "token2")
}

func registerGRC20ForTest(t *testing.T, pkgPath string, igrc20 GRC20Interface) {
	t.Helper()
	registered[pkgPath] = igrc20
}

func unregisterGRC20ForTest(t *testing.T, pkgPath string) {
	t.Helper()
	delete(registered, pkgPath)
}

type MockGRC20 struct {
	TransferFn      func(to pusers.AddressOrName, amount uint64)
	TransferFromFn  func(from, to pusers.AddressOrName, amount uint64)
	BalanceOfFn     func(owner pusers.AddressOrName) uint64
	ApproveFn       func(spender pusers.AddressOrName, amount uint64)
	AllowanceFn     func(owner, spender pusers.AddressOrName) uint64
}

func (m MockGRC20) Transfer() func(to pusers.AddressOrName, amount uint64) {
	return m.TransferFn
}

func (m MockGRC20) TransferFrom() func(from, to pusers.AddressOrName, amount uint64) {
	return m.TransferFromFn
}

func (m MockGRC20) BalanceOf() func(owner pusers.AddressOrName) uint64 {
	return m.BalanceOfFn
}

func (m MockGRC20) Approve() func(spender pusers.AddressOrName, amount uint64) {
	return m.ApproveFn
}

func (m MockGRC20) Allowance() func(owner, spender pusers.AddressOrName) uint64 {
	if m.AllowanceFn != nil {
		return m.AllowanceFn
	}
	return func(owner, spender pusers.AddressOrName) uint64 {
		return 1000000000000
	}
}

func setupTestPool(
	t *testing.T,
	token0Path, token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	t.Helper()

	std.TestSetRealm(std.NewUserRealm(consts.ADMIN))
	pl.SetPoolCreationFeeByAdmin(1)

	if token0Path > token1Path {
		t.Fatalf("tokens are not sorted: %s > %s", token0Path, token1Path)
	}

	pl.CreatePool(token0Path, token1Path, fee, sqrtPriceX96)
}
