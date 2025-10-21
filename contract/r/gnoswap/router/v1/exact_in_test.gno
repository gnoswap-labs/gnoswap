package v1

import (
	"chain"
	"chain/banker"
	"testing"
	"time"

	"gno.land/p/nt/testutils"
	"gno.land/p/nt/uassert"

	prabc "gno.land/p/gnoswap/rbac"
	_ "gno.land/r/gnoswap/rbac"

	_ "gno.land/r/gnoswap/protocol_fee"
	_ "gno.land/r/gnoswap/protocol_fee/v1"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"

	pl "gno.land/r/gnoswap/v1/pool"
	pn "gno.land/r/gnoswap/v1/position"

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
		amountIn     string
		amountOutMin string
		routeArr     string
		quoteArr     string
		wantErr      bool
		errMsg       string
	}{
		{
			name:         "Pass: single pool path",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     "100",
			amountOutMin: "90",
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			wantErr:      false,
		},
		{
			name:         "Fail: amountIn is 0",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     "0",
			amountOutMin: "100",
			routeArr:     singlePoolPath,
			quoteArr:     "100",
			wantErr:      true,
			errMsg:       "invalid amountIn(0), must be positive",
		},
		{
			name:         "Fail: amountIn is negative",
			inputToken:   barPath,
			outputToken:  bazPath,
			amountIn:     "-100",
			amountOutMin: "10",
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
			name:             "success - gns -> gnot",
			tokenPath0:       wugnotPath,
			tokenPath1:       gnsPath,
			feeTier:          pl.FeeTier500,
			recipient:        alice,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100",
			amount1Requested: "100",
			feeProtocol0:     10,
			feeProtocol1:     10,
			inputToken:       gnsPath,
			outputToken:      "gnot",
			amountIn:         "100",
			routeArr:         BuildSingleHopRoutePath(gnsPath, wugnotPath, pl.FeeTier500),
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
				gnot,    // inputToken
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
