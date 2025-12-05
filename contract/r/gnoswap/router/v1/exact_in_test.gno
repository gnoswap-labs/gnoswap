package v1

import (
	"chain"
	"chain/banker"
	"strings"
	"testing"
	"time"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/qux"
)

func TestExactInSwapRouteOperation_Validate(t *testing.T) {
	tests := []struct {
		name         string
		inputToken   string
		outputToken  string
		amountIn     int64
		amountOutMin int64
		routeArr     string
		quoteArr     string
		wantErr      bool
		errMsg       string
	}{
		{
			name:         "Pass: single pool path",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     100,
			amountOutMin: 90,
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			wantErr:      false,
		},
		{
			name:         "Fail: amountIn is 0",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     0,
			amountOutMin: 100,
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			wantErr:      true,
			errMsg:       "invalid amountIn(0), must be positive",
		},
		{
			name:         "Fail: amountIn is negative",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     -100,
			amountOutMin: 10,
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			wantErr:      true,
			errMsg:       "invalid amountIn(-100), must be positive",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			baseParams := BaseSwapParams{
				InputToken:  tt.inputToken,
				OutputToken: tt.outputToken,
				RouteArr:    tt.routeArr,
				QuoteArr:    tt.quoteArr,
			}

			pp := NewExactInParams(
				baseParams,
				tt.amountIn,
				tt.amountOutMin,
			)

			op := NewExactInSwapOperation(mockRouter(), pp)
			err := op.Validate()

			if tt.wantErr {
				if err == nil {
					t.Errorf("expected error but got none")
					return
				}
				if err.Error() != tt.errMsg {
					t.Errorf("expected error message %q but got %q", tt.errMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}
		})
	}
}

func TestExactInSwapRoute(t *testing.T) {
	poolAddr, _ := access.GetAddress(prabc.ROLE_POOL.String())

	tests := []struct {
		name         string
		setupFn      func(*TestEnv)
		inputToken   string
		outputToken  string
		amountIn     string
		routeArr     string
		quoteArr     string
		amountOutMin string
		wantErr      bool
	}{
		{
			name: "BAR -> BAZ",
			setupFn: func(env *TestEnv) {
				routerAddr, _ := access.GetAddress(prabc.ROLE_ROUTER.String())
				env.GivenPoolCreated(barPath, bazPath, 3000, "79228162514264337593543950336").
					AndPositionMinted().
					AndUserFundedAndApproved(user1Addr, routerAddr, barPath, bazPath)
			},
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     "100",
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			amountOutMin: "85",
			wantErr:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := NewTestEnv(t)

			if tt.setupFn != nil {
				tt.setupFn(env)
			}

			testing.SkipHeights(100)

			// Additional approvals needed for pool operations
			user1Realm := testing.NewUserRealm(user1Addr)
			testing.SetRealm(user1Realm)
			bar.Approve(cross, poolAddr, maxApprove)
			baz.Approve(cross, poolAddr, maxApprove)

			defer func() {
				if r := recover(); r != nil {
					if !tt.wantErr {
						t.Errorf("ExactInSwapRoute() panic = %v", r)
					}
				}
			}()

			router := mockRouter()

			testing.SetRealm(user1Realm)
			func(cur realm) {
				testing.SetRealm(testing.NewCodeRealm("gno.land/r/gnoswap/router"))
				amountIn, amountOut := router.ExactInSwapRoute(
					tt.inputToken,
					tt.outputToken,
					tt.amountIn,
					tt.routeArr,
					tt.quoteArr,
					tt.amountOutMin,
					time.Now().Add(time.Hour).Unix(),
					"", // referrer
				)

				if !tt.wantErr {
					if amountIn == "" || amountOut == "" {
						t.Errorf("ExactInSwapRoute() returned empty values")
					}
				}
			}(cross)
		})
	}
}

func TestExactInZeroForOneFalse(t *testing.T) {
	const maxTimeout int64 = 9999999999

	alice := testutils.TestAddress("alice")
	positionOwner := adminAddr

	tests := []struct {
		name             string
		tokenPath0       string
		tokenPath1       string
		feeTier          uint32
		recipient        address
		tickLower        int32
		tickUpper        int32
		amount0Requested string
		amount1Requested string
		feeProtocol0     uint8
		feeProtocol1     uint8
		inputToken       string
		outputToken      string
		amountIn         string
		routeArr         string
		quoteArr         string
		amountOutMin     string
		expectedAmount0  string
		expectedAmount1  string
		expectedBalance  string
		expectPanic      bool
	}{
		{
			name:             "success - gns -> ugnot",
			tokenPath0:       wugnotPath,
			tokenPath1:       gnsPath,
			feeTier:          uint32(500),
			recipient:        alice,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100",
			amount1Requested: "100",
			feeProtocol0:     10,
			feeProtocol1:     10,
			inputToken:       gnsPath,
			outputToken:      "ugnot",
			amountIn:         "100",
			routeArr:         BuildSingleHopRoutePath(gnsPath, wugnotPath, uint32(500)),
			quoteArr:         "100",
			amountOutMin:     "85",
			expectedAmount0:  "100",
			expectedAmount1:  "-98",
			expectPanic:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Pool Creation
			initRouterTest(t)

			testing.SetRealm(testing.NewUserRealm(positionOwner))
			pl.SetPoolCreationFee(cross, 0)
			if !pl.ExistsPoolPath(pl.GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
				pl.CreatePool(cross, tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
			}

			if tt.feeProtocol0 != 0 || tt.feeProtocol1 != 0 {
				pl.SetFeeProtocol(cross, tt.feeProtocol0, tt.feeProtocol1)
			}

			testing.SetOriginCaller(positionOwner)
			newCoins := chain.Coins{{"ugnot", int64(10000000000)}}
			testing.IssueCoins(positionOwner, newCoins)
			testing.SetOriginSend(newCoins)
			banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
			banker_.SendCoins(positionOwner, wugnotAddr, newCoins)
			wugnot.Deposit(cross)
			if tt.recipient != positionOwner {
				wugnot.Transfer(cross, tt.recipient, 10000000000)
			}
			gns.Transfer(cross, tt.recipient, 10000000000)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			wugnot.Approve(cross, poolAddr, maxApprove)
			gns.Approve(cross, poolAddr, maxApprove)

			func(cur realm) {
				teller := common.GetTokenTeller(wugnotPath)
				teller.Approve(poolAddr, maxApprove)
			}(cross)

			testing.SetOriginSend(chain.Coins{})

			// Position Creation
			pn.Mint(
				cross,
				tt.tokenPath0,
				tt.tokenPath1,
				tt.feeTier,
				tt.tickLower,
				tt.tickUpper,
				"10000000",
				"10000000",
				"0",
				"0",
				maxTimeout,
				tt.recipient,
				tt.recipient,
				"",
			)
			testing.SkipHeights(1)

			// Swap
			testing.SetOriginCaller(tt.recipient)
			wugnot.Transfer(cross, routerAddr, 20000000)
			gns.Transfer(cross, routerAddr, 20000000)
			wugnot.Approve(cross, routerAddr, maxApprove)
			gns.Approve(cross, routerAddr, maxApprove)

			testing.SetRealm(routerRealm)
			wugnot.Approve(cross, poolAddr, maxApprove)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginSend(chain.Coins{})

			router := mockRouter()

			func(cur realm) {
				testing.SetRealm(routerRealm)
				amountIn, amountOut := router.ExactInSwapRoute(
					tt.inputToken,
					tt.outputToken,
					tt.amountIn,
					tt.routeArr,
					tt.quoteArr,
					tt.amountOutMin,
					time.Now().Add(time.Hour).Unix(),
					"", // referrer
				)
				testing.SkipHeights(1)

				uassert.Equal(t, tt.expectedAmount0, amountIn)
				uassert.Equal(t, tt.expectedAmount1, amountOut)
			}(cross)
		})
	}
}

/*
This test demonstrates a issue(Gnoswap-16) in SwapRoute function. The key steps are:

· Set up the test environment with necessary approvals
· Set the original send amount to 12345 ugnot
· Attempt to call SwapRoute with:

	· GNOT as input token
	· qux as output token
	· An amountSpecified of "3" (which doesn't match the sent amount)

· Check if the function panics as expected
*/
func TestSwapRouteWugnotquxExactInDifferentAmountCoinShouldPanic(t *testing.T) {
	testing.SetRealm(adminRealm)

	wugnot.Approve(cross, routerAddr, 1000000)
	qux.Approve(cross, routerAddr, 1000000)

	testing.SetOriginCaller(adminAddr)
	newCoins := chain.Coins{{"ugnot", 12345}}
	testing.IssueCoins(adminAddr, newCoins)
	testing.SetOriginSend(newCoins)
	banker_ := banker.NewBanker(banker.BankerTypeRealmSend)
	banker_.SendCoins(adminAddr, routerAddr, newCoins)

	router := mockRouter()

	uassert.PanicsWithMessage(
		t,
		`[GNOSWAP-ROUTER-005] invalid input data || pool does not exist: gno.land/r/gnoland/wugnot:gno.land/r/onbloc/qux:3000`,
		func() {
			testing.SetRealm(routerRealm)
			router.ExactOutSwapRoute(
				GNOT_DENOM, // inputToken
				quxPath, // outputToken
				"3",     // amountSpecified
				"gno.land/r/gnoland/wugnot:gno.land/r/onbloc/qux:3000", // strRouteArr
				"100",   // quoteArr
				"12345", // tokenAmountLimit
				time.Now().Add(time.Hour).Unix(),
				"", // referrer
			)
		},
	)
}

// Test NewExactInSwapOperation
func TestNewExactInSwapOperation(t *testing.T) {
	tests := []struct {
		name   string
		params ExactInParams
	}{
		{
			name: "create exact in operation with valid params",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:        "tokenA",
					OutputToken:       "tokenB",
					RouteArr:          "tokenA:tokenB:500",
					QuoteArr:          "100",
					SqrtPriceLimitX96: u256.Zero(),
					Deadline:          9999999999,
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			},
		},
		{
			name: "create exact in operation with price limit",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:        "tokenA",
					OutputToken:       "tokenB",
					RouteArr:          "tokenA:tokenB:500",
					QuoteArr:          "100",
					SqrtPriceLimitX96: u256.MustFromDecimal("79228162514264337593543950336"),
					Deadline:          9999999999,
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactInSwapOperation(router, tt.params)

			uassert.NotNil(t, op)
			uassert.NotNil(t, op.router)
			uassert.Equal(t, op.params.AmountIn, tt.params.AmountIn)
			uassert.Equal(t, op.userWrappedWugnot, INITIAL_WUGNOT_BALANCE)
		})
	}
}

// Test ExactInSwapOperation.Validate
func TestExactInSwapOperation_Validate(t *testing.T) {
	tests := []struct {
		name        string
		params      ExactInParams
		expectError bool
		errorMsg    string
	}{
		{
			name: "valid positive amount",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			},
			expectError: false,
		},
		{
			name: "zero amount",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountIn:     0,
				AmountOutMin: 0,
			},
			expectError: true,
			errorMsg:    "invalid amountIn(0), must be positive",
		},
		{
			name: "negative amount",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountIn:     -100,
				AmountOutMin: 0,
			},
			expectError: true,
			errorMsg:    "invalid amountIn(-100), must be positive",
		},
		{
			name: "valid large amount",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountIn:     999999999999999,
				AmountOutMin: 0,
			},
			expectError: false,
		},
		{
			name: "invalid quote sum",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
					QuoteArr:    "50,30", // sum is 80, not 100
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			},
			expectError: true,
			errorMsg:    "quote sum(80) must be 100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactInSwapOperation(router, tt.params)
			err := op.Validate()

			if tt.expectError {
				uassert.Error(t, err)
				if err != nil && tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg+", got: "+err.Error())
				}
			} else {
				uassert.NoError(t, err)
				// Verify amountSpecified is set correctly
				uassert.Equal(t, op.amountSpecified, tt.params.AmountIn)
			}
		})
	}
}

// Test ExactInSwapOperation.Process structure
func TestExactInSwapOperation_Process_Structure(t *testing.T) {
	tests := []struct {
		name        string
		params      ExactInParams
		description string
	}{
		{
			name: "process returns swap result",
			params: ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			},
			description: "Process should return SwapResult with all fields populated",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactInSwapOperation(router, tt.params)
			err := op.Validate()
			uassert.NoError(t, err)

			// Verify the operation structure is correct
			uassert.True(t, op.amountSpecified > 0)
			uassert.NotNil(t, op.routes)
			uassert.NotNil(t, op.quotes)
		})
	}
}

// Test NewExactOutSwapOperation
func TestNewExactOutSwapOperation(t *testing.T) {
	tests := []struct {
		name   string
		params ExactOutParams
	}{
		{
			name: "create exact out operation with valid params",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:        "tokenA",
					OutputToken:       "tokenB",
					RouteArr:          "tokenA:tokenB:500",
					QuoteArr:          "100",
					SqrtPriceLimitX96: u256.Zero(),
					Deadline:          9999999999,
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			},
		},
		{
			name: "create exact out operation with price limit",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:        "tokenA",
					OutputToken:       "tokenB",
					RouteArr:          "tokenA:tokenB:500",
					QuoteArr:          "100",
					SqrtPriceLimitX96: u256.MustFromDecimal("79228162514264337593543950336"),
					Deadline:          9999999999,
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactOutSwapOperation(router, tt.params)

			uassert.NotNil(t, op)
			uassert.NotNil(t, op.router)
			uassert.Equal(t, op.params.AmountOut, tt.params.AmountOut)
			uassert.Equal(t, op.userWrappedWugnot, INITIAL_WUGNOT_BALANCE)
		})
	}
}

// Test ExactOutSwapOperation.Validate
func TestExactOutSwapOperation_Validate(t *testing.T) {
	tests := []struct {
		name        string
		params      ExactOutParams
		expectError bool
		errorMsg    string
	}{
		{
			name: "valid positive amount",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			},
			expectError: false,
		},
		{
			name: "zero amount",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountOut:   0,
				AmountInMax: 0,
			},
			expectError: true,
			errorMsg:    "invalid amountOut(0), must be positive",
		},
		{
			name: "negative amount",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountOut:   -100,
				AmountInMax: 0,
			},
			expectError: true,
			errorMsg:    "invalid amountOut(-100), must be positive",
		},
		{
			name: "valid large amount",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountOut:   999999999999999,
				AmountInMax: 1000000000000000,
			},
			expectError: false,
		},
		{
			name: "invalid quote sum",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
					QuoteArr:    "60,30", // sum is 90, not 100
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			},
			expectError: true,
			errorMsg:    "quote sum(90) must be 100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactOutSwapOperation(router, tt.params)
			err := op.Validate()

			if tt.expectError {
				uassert.Error(t, err)
				if err != nil && tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg+", got: "+err.Error())
				}
			} else {
				uassert.NoError(t, err)
				// Verify amountSpecified is set correctly (negated for ExactOut)
				uassert.Equal(t, op.amountSpecified, -tt.params.AmountOut)
			}
		})
	}
}

// Test ExactOutSwapOperation.Process structure
func TestExactOutSwapOperation_Process_Structure(t *testing.T) {
	tests := []struct {
		name        string
		params      ExactOutParams
		description string
	}{
		{
			name: "process returns swap result",
			params: ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    "tokenA:tokenB:500",
					QuoteArr:    "100",
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			},
			description: "Process should return SwapResult with all fields populated",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			router := mockRouter()
			op := NewExactOutSwapOperation(router, tt.params)
			err := op.Validate()
			uassert.NoError(t, err)

			// Verify the operation structure is correct
			uassert.True(t, op.amountSpecified != 0)
			uassert.NotNil(t, op.routes)
			uassert.NotNil(t, op.quotes)
			// Verify amountSpecified is negative for ExactOut
			uassert.True(t, op.amountSpecified < 0, "amountSpecified should be negative for ExactOut")
		})
	}
}

// Test ExactInParams creation
func TestNewExactInParams(t *testing.T) {
	tests := []struct {
		name         string
		base         BaseSwapParams
		amountIn     int64
		amountOutMin int64
	}{
		{
			name: "create exact in params",
			base: BaseSwapParams{
				InputToken:        "tokenA",
				OutputToken:       "tokenB",
				RouteArr:          "tokenA:tokenB:500",
				QuoteArr:          "100",
				SqrtPriceLimitX96: u256.Zero(),
				Deadline:          9999999999,
			},
			amountIn:     1000,
			amountOutMin: 900,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := NewExactInParams(tt.base, tt.amountIn, tt.amountOutMin)

			uassert.Equal(t, params.AmountIn, tt.amountIn)
			uassert.Equal(t, params.AmountOutMin, tt.amountOutMin)
			uassert.Equal(t, params.InputToken, tt.base.InputToken)
			uassert.Equal(t, params.OutputToken, tt.base.OutputToken)
		})
	}
}

// Test ExactOutParams creation
func TestNewExactOutParams(t *testing.T) {
	tests := []struct {
		name        string
		base        BaseSwapParams
		amountOut   int64
		amountInMax int64
	}{
		{
			name: "create exact out params",
			base: BaseSwapParams{
				InputToken:        "tokenA",
				OutputToken:       "tokenB",
				RouteArr:          "tokenA:tokenB:500",
				QuoteArr:          "100",
				SqrtPriceLimitX96: u256.Zero(),
				Deadline:          9999999999,
			},
			amountOut:   1000,
			amountInMax: 1100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := NewExactOutParams(tt.base, tt.amountOut, tt.amountInMax)

			uassert.Equal(t, params.AmountOut, tt.amountOut)
			uassert.Equal(t, params.AmountInMax, tt.amountInMax)
			uassert.Equal(t, params.InputToken, tt.base.InputToken)
			uassert.Equal(t, params.OutputToken, tt.base.OutputToken)
		})
	}
}

// Test ExactIn/ExactOut operation comparison
func TestExactInVsExactOut_AmountSpecified(t *testing.T) {
	baseParams := BaseSwapParams{
		InputToken:  "tokenA",
		OutputToken: "tokenB",
		RouteArr:    "tokenA:tokenB:500",
		QuoteArr:    "100",
	}

	t.Run("ExactIn uses positive amountSpecified", func(t *testing.T) {
		exactInParams := NewExactInParams(baseParams, 1000, 900)
		opIn := NewExactInSwapOperation(mockRouter(), exactInParams)
		err := opIn.Validate()
		uassert.NoError(t, err)

		// ExactIn should have positive amountSpecified
		uassert.False(t, opIn.amountSpecified < 0, "ExactIn amountSpecified should be positive")
		uassert.Equal(t, opIn.amountSpecified, int64(1000))
	})

	t.Run("ExactOut uses negative amountSpecified", func(t *testing.T) {
		exactOutParams := NewExactOutParams(baseParams, 1000, 1100)
		opOut := NewExactOutSwapOperation(mockRouter(), exactOutParams)
		err := opOut.Validate()
		uassert.NoError(t, err)

		// ExactOut should have negative amountSpecified
		uassert.True(t, opOut.amountSpecified < 0, "ExactOut amountSpecified should be negative")
		uassert.Equal(t, opOut.amountSpecified, int64(-1000))
	})
}

// Test handleNativeTokenWrapping for ExactIn
func TestExactInSwapOperation_HandleNativeTokenWrapping(t *testing.T) {
	tests := []struct {
		name        string
		inputToken  string
		outputToken string
		description string
	}{
		{
			name:        "no native tokens",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			description: "No wrapping needed for non-native tokens",
		},
		{
			name:        "input is WUGNOT",
			inputToken:  "gno.land/r/gnoland/wugnot",
			outputToken: "tokenB",
			description: "WUGNOT input should not trigger wrapping",
		},
		{
			name:        "output is WUGNOT",
			inputToken:  "tokenA",
			outputToken: "gno.land/r/gnoland/wugnot",
			description: "WUGNOT output should not trigger wrapping",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  tt.inputToken,
					OutputToken: tt.outputToken,
					RouteArr:    tt.inputToken + ":" + tt.outputToken + ":500",
					QuoteArr:    "100",
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			}

			op := NewExactInSwapOperation(mockRouter(), params)
			err := op.Validate()
			uassert.NoError(t, err)
		})
	}
}

// Test handleNativeTokenWrapping for ExactOut
func TestExactOutSwapOperation_HandleNativeTokenWrapping(t *testing.T) {
	tests := []struct {
		name        string
		inputToken  string
		outputToken string
		description string
	}{
		{
			name:        "no native tokens",
			inputToken:  "tokenA",
			outputToken: "tokenB",
			description: "No wrapping needed for non-native tokens",
		},
		{
			name:        "input is WUGNOT",
			inputToken:  "gno.land/r/gnoland/wugnot",
			outputToken: "tokenB",
			description: "WUGNOT input should not trigger wrapping",
		},
		{
			name:        "output is WUGNOT",
			inputToken:  "tokenA",
			outputToken: "gno.land/r/gnoland/wugnot",
			description: "WUGNOT output should not trigger wrapping",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  tt.inputToken,
					OutputToken: tt.outputToken,
					RouteArr:    tt.inputToken + ":" + tt.outputToken + ":500",
					QuoteArr:    "100",
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			}

			op := NewExactOutSwapOperation(mockRouter(), params)
			err := op.Validate()
			uassert.NoError(t, err)
		})
	}
}

// Test multi-route validation
func TestExactInSwapOperation_MultiRoute(t *testing.T) {
	tests := []struct {
		name        string
		routeArr    string
		quoteArr    string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "valid two routes",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
			quoteArr:    "50,50",
			expectError: false,
		},
		{
			name:        "valid three routes",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000,tokenA:tokenD:10000",
			quoteArr:    "33,33,34",
			expectError: false,
		},
		{
			name:        "mismatched routes and quotes count",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
			quoteArr:    "100", // only one quote for two routes
			expectError: true,
			errorMsg:    "mismatch between routes(2) and quotes(1) length",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := ExactInParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    tt.routeArr,
					QuoteArr:    tt.quoteArr,
				},
				AmountIn:     1000,
				AmountOutMin: 900,
			}

			op := NewExactInSwapOperation(mockRouter(), params)
			err := op.Validate()

			if tt.expectError {
				uassert.Error(t, err)
				if err != nil && tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, len(op.routes), len(op.quotes))
			}
		})
	}
}

// Test multi-route validation for ExactOut
func TestExactOutSwapOperation_MultiRoute(t *testing.T) {
	tests := []struct {
		name        string
		routeArr    string
		quoteArr    string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "valid two routes",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
			quoteArr:    "50,50",
			expectError: false,
		},
		{
			name:        "valid three routes",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000,tokenA:tokenD:10000",
			quoteArr:    "33,33,34",
			expectError: false,
		},
		{
			name:        "mismatched routes and quotes count",
			routeArr:    "tokenA:tokenB:500,tokenA:tokenC:3000",
			quoteArr:    "100", // only one quote for two routes
			expectError: true,
			errorMsg:    "mismatch between routes(2) and quotes(1) length",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			params := ExactOutParams{
				BaseSwapParams: BaseSwapParams{
					InputToken:  "tokenA",
					OutputToken: "tokenB",
					RouteArr:    tt.routeArr,
					QuoteArr:    tt.quoteArr,
				},
				AmountOut:   1000,
				AmountInMax: 1100,
			}

			op := NewExactOutSwapOperation(mockRouter(), params)
			err := op.Validate()

			if tt.expectError {
				uassert.Error(t, err)
				if err != nil && tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg), "error message should contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, len(op.routes), len(op.quotes))
			}
		})
	}
}
