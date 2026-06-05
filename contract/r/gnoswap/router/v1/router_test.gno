package v1

import (
	"chain"
	"math"
	"strconv"
	"strings"
	"testing"
	"time"

	testutils "gno.land/p/nt/testutils/v0"
	uassert "gno.land/p/nt/uassert/v0"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/gns"
	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/baz"
	"gno.land/r/onbloc/foo"
	"gno.land/r/onbloc/qux"
)

func TestFinalizeSwap(cur realm, t *testing.T) {
	initRouterTest(cur, t)

	tests := []struct {
		name             string
		inputToken       string
		outputToken      string
		resultAmountIn   int64
		resultAmountOut  int64
		swapType         SwapType
		tokenAmountLimit int64
		amountSpecified  int64
		swapCount        int64
		expectPanic      bool
		errorMessage     string
	}{
		{
			name:             "Pass: ExactIn",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   100,
			resultAmountOut:  90,
			swapType:         ExactIn,
			tokenAmountLimit: 85,
			amountSpecified:  100,
			swapCount:        1,
			expectPanic:      false,
		},
		{
			name:             "Pass: ExactOut",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   110,
			resultAmountOut:  100,
			swapType:         ExactOut,
			tokenAmountLimit: 120,
			amountSpecified:  100,
			swapCount:        1,
			expectPanic:      false,
		},
		{
			name:             "ExactOut: exactOutAmount slippage error",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   100,
			resultAmountOut:  90,
			swapType:         ExactOut,
			tokenAmountLimit: 100,
			amountSpecified:  100,
			swapCount:        1,
			expectPanic:      true,
			errorMessage:     "received more than requested in requested=100, actual=90",
		},
		{
			name:             "ExactIn: Slippage error - too few received",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   100,
			resultAmountOut:  80,
			swapType:         ExactIn,
			tokenAmountLimit: 85,
			amountSpecified:  100,
			swapCount:        1,
			expectPanic:      true,
			errorMessage:     "ExactIn: too few received (min:85, got:80)",
		},
		{
			name:             "ExactOut: Real world amounts pass",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   843455035,
			resultAmountOut:  600901351,
			swapType:         ExactOut,
			tokenAmountLimit: 843455036,
			amountSpecified:  600901352,
			swapCount:        1,
			expectPanic:      false,
		},
		{
			name:             "ExactOut: Slippage error - spent too much",
			inputToken:       fooPath,
			outputToken:      quxPath,
			resultAmountIn:   150,
			resultAmountOut:  100,
			swapType:         ExactOut,
			tokenAmountLimit: 140,
			amountSpecified:  100,
			swapCount:        1,
			expectPanic:      true,
			errorMessage:     "ExactOut: too much spent (max:140, used:150)",
		},
		{
			name:             "ExactIn: Large amounts pass",
			inputToken:       barPath,
			outputToken:      bazPath,
			resultAmountIn:   1000000000,
			resultAmountOut:  999000000,
			swapType:         ExactIn,
			tokenAmountLimit: 998000000,
			amountSpecified:  1000000000,
			swapCount:        1,
			expectPanic:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			router := mockRouter()
			// set swap fee to 0 to focus on slippage validation
			testing.SetRealm(adminRealm)
			func(cur realm) {
				router.SetSwapFee(0, cur, 0)
			}(cross(cur))

			if tt.expectPanic {
				uassert.PanicsContains(t, cur, tt.errorMessage, func() {
					router.finalizeSwap(0, cur,
						tt.inputToken,
						tt.outputToken,
						tt.resultAmountIn,
						tt.resultAmountOut,
						tt.swapType,
						tt.tokenAmountLimit,
						tt.amountSpecified,
						tt.swapCount,
						false,
					)
				})
			} else {
				amountIn, amountOut := router.finalizeSwap(0, cur,
					tt.inputToken,
					tt.outputToken,
					tt.resultAmountIn,
					tt.resultAmountOut,
					tt.swapType,
					tt.tokenAmountLimit,
					tt.amountSpecified,
					tt.swapCount,
					false,
				)

				uassert.True(t, amountIn > 0, "amountIn should be positive")
				uassert.True(t, amountOut > 0, "amountOut should be positive")
				uassert.Equal(t, tt.resultAmountIn, amountIn)
				uassert.Equal(t, tt.resultAmountOut, amountOut)
			}
		})
	}
}

func TestCompareExactInAndDrySwapWithNoLiquidityChanged(cur realm, t *testing.T) {
	t.Skip("interrealm v2: integration payer/balance setup needs rework")

	initRouterTest(cur, t)

	const barTokenPath = "gno.land/r/onbloc/bar"
	const gnsTokenPath = "gno.land/r/gnoswap/gns"
	const maxTimeout int64 = 9999999999
	const barGnsPoolPath = "gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:500"

	routerContract := routerAddr
	poolContract := poolAddr

	alice := testutils.TestAddress("alice")
	positionOwner := admin

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
		expectPanic      bool
	}{
		{
			name:             "success - bar -> gns",
			tokenPath0:       barTokenPath,
			tokenPath1:       gnsTokenPath,
			feeTier:          uint32(500),
			recipient:        alice,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100000000",
			amount1Requested: "100000000",
			feeProtocol0:     10,
			feeProtocol1:     10,
			inputToken:       barTokenPath,
			outputToken:      gnsTokenPath,
			amountIn:         "100000000",
			routeArr:         barGnsPoolPath,
			quoteArr:         "100",
			amountOutMin:     "85000000",
			expectedAmount0:  "100000000",
			expectedAmount1:  "-98817367",
			expectPanic:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SkipHeights(100)

			// Pool Creation
			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross(cur), 0)
			if !pl.ExistsPoolPath(pl.GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
				pl.CreatePool(cross(cur), tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
			}

			if tt.feeProtocol0 != 0 || tt.feeProtocol1 != 0 {
				pl.SetFeeProtocol(cross(cur), tt.feeProtocol0, tt.feeProtocol1)
			}

			testing.SetOriginCaller(positionOwner)
			if tt.recipient != positionOwner {
				testing.SetRealm(testing.NewUserRealm(positionOwner))
				bar.Transfer(cross(cur), tt.recipient, 10000000000)
			}
			testing.SetRealm(testing.NewUserRealm(positionOwner))
			gns.Transfer(cross(cur), tt.recipient, 10000000000)

			TokenFaucet(cur, t, barTokenPath, tt.recipient)
			TokenFaucet(cur, t, gnsTokenPath, tt.recipient)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			bar.Approve(cross(cur), poolContract, maxApprove)
			gns.Approve(cross(cur), poolContract, maxApprove)

			// Position Creation
			pn.Mint(
				cross(cur),
				tt.tokenPath0,
				tt.tokenPath1,
				tt.feeTier,
				tt.tickLower,
				tt.tickUpper,
				tt.amount0Requested,
				tt.amount1Requested,
				"0",
				"0",
				maxTimeout,
				tt.recipient,
				"",
			)
			testing.SkipHeights(1)

			// Swap
			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginCaller(tt.recipient)
			bar.Approve(cross(cur), routerContract, maxApprove)
			gns.Approve(cross(cur), routerContract, maxApprove)

			testing.SetRealm(adminRealm)
			TokenFaucet2(cur, t, barTokenPath, routerContract)
			TokenFaucet2(cur, t, gnsTokenPath, routerContract)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			swapAmount := safeParseInt64(tt.amountIn)
			bar.Transfer(cross(cur), routerContract, swapAmount)

			beforeBarBalance := bar.BalanceOf(tt.recipient)

			testing.SetRealm(routerRealm)
			bar.Approve(cross(cur), poolContract, maxApprove)

			router := mockRouter()

			_, drySwapAmountOut, _ := router.DrySwapRoute(
				tt.inputToken,
				tt.outputToken,
				tt.amountIn,
				"EXACT_IN",
				tt.routeArr,
				tt.quoteArr,
				tt.amountOutMin,
			)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginSend(chain.Coins{})

			swapFn := func(cur realm) {
				testing.SetRealm(routerRealm)
				router.ExactInSwapRoute(0, cur,
					tt.inputToken,
					tt.outputToken,
					tt.amountIn,
					tt.routeArr,
					tt.quoteArr,
					tt.amountOutMin,
					time.Now().Add(time.Hour).Unix(),
					"", // referrer
				)
			}

			if tt.expectPanic {
				uassert.PanicsContains(t, cur, "GNOSWAP", func() {
					swapFn(cross(cur))
				})
				return
			}

			func(cur realm) {
				testing.SetRealm(routerRealm)
				amountIn, amountOut := router.ExactInSwapRoute(0, cur,
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
				afterBarBalance := bar.BalanceOf(tt.recipient)

				drySwapAmountOutInt := safeParseInt64(drySwapAmountOut)
				amountOutInt := safeParseInt64(amountOut)
				if drySwapAmountOutInt < 0 {
					drySwapAmountOutInt = -drySwapAmountOutInt
				}
				if amountOutInt < 0 {
					amountOutInt = -amountOutInt
				}

				uassert.Equal(t, strconv.FormatInt(drySwapAmountOutInt, 10), strconv.FormatInt(amountOutInt, 10), "amountOut is not equal to drySwapAmountOut")
				uassert.Equal(t, tt.expectedAmount0, amountIn, "amountIn is not equal to expectedAmount0")
				uassert.Equal(t, tt.expectedAmount1, amountOut, "amountOut is not equal to expectedAmount1")
				uassert.Equal(t, tt.expectedAmount0, strconv.FormatInt(int64(beforeBarBalance-afterBarBalance), 10), "amountIn is not equal to expectedAmount0")
			}(cross(cur))
		})
	}
}

func TestCompareExactInAndDrySwapWithWhenLiquidityAdded(cur realm, t *testing.T) {
	t.Skip("interrealm v2: integration payer/balance setup needs rework")

	initRouterTest(cur, t)

	const barTokenPath = "gno.land/r/onbloc/bar"
	const gnsTokenPath = "gno.land/r/gnoswap/gns"
	const maxTimeout int64 = 9999999999
	const barGnsPoolPath = "gno.land/r/onbloc/bar:gno.land/r/gnoswap/gns:500"

	routerContract := routerAddr
	poolContract := poolAddr

	alice := testutils.TestAddress("alice")
	positionOwner := admin

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
		expectPanic      bool
	}{
		{
			name:             "success - bar -> gns",
			tokenPath0:       barTokenPath,
			tokenPath1:       gnsTokenPath,
			feeTier:          uint32(500),
			recipient:        alice,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100000000",
			amount1Requested: "100000000",
			feeProtocol0:     10,
			feeProtocol1:     10,
			inputToken:       barTokenPath,
			outputToken:      gnsTokenPath,
			amountIn:         "50000000",
			routeArr:         barGnsPoolPath,
			quoteArr:         "100",
			amountOutMin:     "20000000",
			expectedAmount0:  "50000000",
			expectedAmount1:  "-49776285",
			expectPanic:      true,
		},
	}

	// Fund alice with bar tokens for IncreaseLiquidity
	TokenFaucet(cur, t, barPath, alice)

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SkipHeights(100)

			// Pool Creation
			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross(cur), 0)
			if !pl.ExistsPoolPath(pl.GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
				pl.CreatePool(cross(cur), tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
			}

			if tt.feeProtocol0 != 0 || tt.feeProtocol1 != 0 {
				pl.SetFeeProtocol(cross(cur), tt.feeProtocol0, tt.feeProtocol1)
			}

			testing.SetOriginCaller(positionOwner)
			if tt.recipient != positionOwner {
				testing.SetRealm(testing.NewUserRealm(positionOwner))
				bar.Transfer(cross(cur), tt.recipient, 10000000000)
			}
			testing.SetRealm(testing.NewUserRealm(positionOwner))
			gns.Transfer(cross(cur), tt.recipient, 10000000000)

			TokenFaucet(cur, t, barTokenPath, tt.recipient)
			TokenFaucet(cur, t, gnsTokenPath, tt.recipient)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			bar.Approve(cross(cur), poolContract, maxApprove)
			gns.Approve(cross(cur), poolContract, maxApprove)

			// Position Creation
			positionId, _, _, _ := pn.Mint(
				cross(cur),
				tt.tokenPath0,
				tt.tokenPath1,
				tt.feeTier,
				tt.tickLower,
				tt.tickUpper,
				tt.amount0Requested,
				tt.amount1Requested,
				"0",
				"0",
				maxTimeout,
				tt.recipient,
				"",
			)
			testing.SkipHeights(1)

			// Add Liquidity
			testing.SetOriginCaller(tt.recipient)
			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			bar.Approve(cross(cur), poolContract, maxApprove)
			bar.Approve(cross(cur), positionAddr, maxApprove)
			gns.Approve(cross(cur), poolContract, maxApprove)

			pn.IncreaseLiquidity(
				cross(cur),
				positionId,
				tt.amount0Requested,
				tt.amount1Requested,
				"0",
				"0",
				maxTimeout,
			)

			// Swap
			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginCaller(tt.recipient)
			bar.Approve(cross(cur), routerContract, maxApprove)
			gns.Approve(cross(cur), routerContract, maxApprove)

			testing.SetRealm(adminRealm)
			TokenFaucet(cur, t, barTokenPath, routerContract)
			TokenFaucet(cur, t, gnsTokenPath, routerContract)

			testing.SetRealm(routerRealm)
			bar.Approve(cross(cur), poolContract, maxApprove)

			router := mockRouter()

			router.DrySwapRoute(
				tt.inputToken,
				tt.outputToken,
				tt.amountIn,
				"EXACT_IN",
				tt.routeArr,
				tt.quoteArr,
				tt.amountOutMin,
			)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginSend(chain.Coins{})

			if tt.expectPanic {
				uassert.PanicsContains(t, cur, "GNOSWAP", func() {
					func(cur realm) {
						testing.SetRealm(routerRealm)
						router.ExactInSwapRoute(0, cur,
							tt.inputToken,
							tt.outputToken,
							tt.amountIn,
							tt.routeArr,
							tt.quoteArr,
							tt.amountOutMin,
							time.Now().Add(time.Hour).Unix(),
							"", // referrer
						)
					}(cross(cur))
				})
				return
			}

			func(cur realm) {
				testing.SetRealm(routerRealm)
				_, amountOut := router.ExactInSwapRoute(0, cur,
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

				uassert.Equal(t, tt.expectedAmount1, amountOut)
			}(cross(cur))
		})
	}
}

func TestCompareExactInAndDrySwapWithWhenZeroForOneIsFalse(cur realm, t *testing.T) {
	t.Skip("interrealm v2: integration payer/balance setup needs rework")

	initRouterTest(cur, t)

	const barTokenPath = "gno.land/r/onbloc/bar"
	const gnsTokenPath = "gno.land/r/gnoswap/gns"
	const maxTimeout int64 = 9999999999
	const gnsBarPoolPath = "gno.land/r/gnoswap/gns:gno.land/r/onbloc/bar:10000"

	routerContract := routerAddr
	poolContract := poolAddr

	alice := testutils.TestAddress("alice")
	positionOwner := admin

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
		expectPanic      bool
	}{
		{
			name:             "success - gns -> bar",
			tokenPath0:       barTokenPath,
			tokenPath1:       gnsTokenPath,
			feeTier:          uint32(10000),
			recipient:        alice,
			tickLower:        -200,
			tickUpper:        200,
			amount0Requested: "100000000",
			amount1Requested: "100000000",
			feeProtocol0:     10,
			feeProtocol1:     10,
			inputToken:       gnsTokenPath,
			outputToken:      barTokenPath,
			amountIn:         "10000000",
			routeArr:         gnsBarPoolPath,
			quoteArr:         "100",
			amountOutMin:     "850000",
			expectedAmount0:  "10000000",
			expectedAmount1:  "-9875422",
			expectPanic:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SkipHeights(100)

			// Pool Creation
			testing.SetRealm(adminRealm)
			pl.SetPoolCreationFee(cross(cur), 0)
			if !pl.ExistsPoolPath(pl.GetPoolPath(tt.tokenPath0, tt.tokenPath1, tt.feeTier)) {
				pl.CreatePool(cross(cur), tt.tokenPath0, tt.tokenPath1, tt.feeTier, "79228162514264337593543950336")
			}

			if tt.feeProtocol0 != 0 || tt.feeProtocol1 != 0 {
				pl.SetFeeProtocol(cross(cur), tt.feeProtocol0, tt.feeProtocol1)
			}

			testing.SetOriginCaller(positionOwner)
			if tt.recipient != positionOwner {
				testing.SetRealm(testing.NewUserRealm(positionOwner))
				bar.Transfer(cross(cur), tt.recipient, 10000000000)
			}
			testing.SetRealm(testing.NewUserRealm(positionOwner))
			gns.Transfer(cross(cur), tt.recipient, 10000000000)

			TokenFaucet(cur, t, barTokenPath, tt.recipient)
			TokenFaucet(cur, t, gnsTokenPath, tt.recipient)

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			bar.Approve(cross(cur), poolContract, maxApprove)
			gns.Approve(cross(cur), poolContract, maxApprove)

			// Position Creation
			pn.Mint(
				cross(cur),
				tt.tokenPath0,
				tt.tokenPath1,
				tt.feeTier,
				tt.tickLower,
				tt.tickUpper,
				tt.amount0Requested,
				tt.amount1Requested,
				"0",
				"0",
				maxTimeout,
				tt.recipient,
				"",
			)
			testing.SkipHeights(1)

			// Swap
			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginCaller(tt.recipient)
			bar.Approve(cross(cur), routerContract, maxApprove)
			gns.Approve(cross(cur), routerContract, maxApprove)

			testing.SetRealm(adminRealm)
			TokenFaucet(cur, t, barTokenPath, routerContract)
			TokenFaucet(cur, t, gnsTokenPath, routerContract)

			testing.SetRealm(routerRealm)
			bar.Approve(cross(cur), poolContract, maxApprove)

			router := mockRouter()

			_, drySwapAmountOut, _ := router.DrySwapRoute(
				tt.inputToken,
				tt.outputToken,
				tt.amountIn,
				"EXACT_IN",
				tt.routeArr,
				tt.quoteArr,
				tt.amountOutMin,
			)
			router.handleSwapFee(0, cur, tt.outputToken, safeParseInt64(drySwapAmountOut))

			testing.SetRealm(testing.NewUserRealm(tt.recipient))
			testing.SetOriginSend(chain.Coins{})

			if tt.expectPanic {
				uassert.PanicsContains(t, cur, "GNOSWAP", func() {
					func(cur realm) {
						testing.SetRealm(routerRealm)
						router.ExactInSwapRoute(0, cur,
							tt.inputToken,
							tt.outputToken,
							tt.amountIn,
							tt.routeArr,
							tt.quoteArr,
							tt.amountOutMin,
							time.Now().Add(time.Hour).Unix(),
							"", // referrer
						)
					}(cross(cur))
				})
				return
			}

			func(cur realm) {
				testing.SetRealm(routerRealm)
				amountIn, amountOut := router.ExactInSwapRoute(0, cur,
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
			}(cross(cur))
		})
	}
}

func TestValidateQuoteSum(cur realm, t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name      string
		quotes    []string
		wantError bool
		errMsg    string
	}{
		{
			name:      "Valid quotes summing to 100",
			quotes:    []string{"30", "40", "30"},
			wantError: false,
		},
		{
			name:      "Single quote of 100",
			quotes:    []string{"100"},
			wantError: false,
		},
		{
			name:      "Sum not equal to 100",
			quotes:    []string{"30", "40", "20"},
			wantError: true,
			errMsg:    "quote sum(90) must be 100",
		},
		{
			name:      "Negative quote",
			quotes:    []string{"-10", "110"},
			wantError: true,
			errMsg:    "quote(-10) at index(0) must be positive value",
		},
		{
			name:      "Zero quote",
			quotes:    []string{"0", "100"},
			wantError: true,
			errMsg:    "quote(0) at index(0) must be positive value",
		},
		{
			name:      "Quote exceeding 100",
			quotes:    []string{"101", "-1"},
			wantError: true,
			errMsg:    "quote(101) at index(0) must be less than or equal to 100",
		},
		{
			name:      "Invalid number format",
			quotes:    []string{"abc", "100"},
			wantError: true,
			errMsg:    "invalid quote(abc) at index(0)",
		},
		{
			name:      "Empty quotes",
			quotes:    []string{},
			wantError: true,
			errMsg:    "quote sum(0) must be 100",
		},
		{
			name:      "Overflow check",
			quotes:    []string{"50", "60"},
			wantError: true,
			errMsg:    "quote sum exceeds 100 at index(1)",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := parser.ValidateQuoteSum(tt.quotes)
			if tt.wantError {
				if err == nil {
					t.Errorf("Expected error but got none")
					return
				}
				if !strings.Contains(err.Error(), tt.errMsg) {
					t.Errorf("Expected error message containing %q, got %q", tt.errMsg, err.Error())
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error: %v", err)
				}
			}
		})
	}
}

func TestHandleMultiSwap(cur realm, t *testing.T) {
	initRouterTest(cur, t)
	testing.SkipHeights(100)

	tests := []struct {
		name              string
		inputToken        string
		outputToken       string
		swapType          SwapType
		route             string
		numHops           int
		amountSpecified   string
		expectedAmountIn  string
		expectedAmountOut string
		shouldPanic       bool
		panicMsg          string
	}{
		{
			name:              "ExactIn - 2 hops",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/qux",
			swapType:          ExactIn,
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000",
			numHops:           2,
			amountSpecified:   "1000",
			expectedAmountIn:  "1000",
			expectedAmountOut: "7204",
		},
		{
			name:              "ExactOut - 2 hops",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/qux",
			swapType:          ExactOut,
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000",
			numHops:           2,
			amountSpecified:   "1000",
			expectedAmountIn:  "374",
			expectedAmountOut: "2668",
		},
		{
			name:              "ExactIn - 3 hops",
			inputToken:        "gno.land/r/onbloc/bar",
			outputToken:       "gno.land/r/onbloc/qux",
			swapType:          ExactIn,
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/foo:10000",
			numHops:           3,
			amountSpecified:   "1000",
			expectedAmountIn:  "1000",
			expectedAmountOut: "18950",
		},
		{
			name:            "Invalid SwapType",
			inputToken:      "gno.land/r/onbloc/bar",
			outputToken:     "gno.land/r/onbloc/qux",
			swapType:        SwapType(99),
			route:           "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000",
			numHops:         2,
			amountSpecified: "1000",
			shouldPanic:     true,
			panicMsg:        "[GNOSWAP-ROUTER-007] invalid swap type",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SkipHeights(100)
			createMultiHopPools(cur, t)

			testing.SetRealm(adminRealm)

			common.SafeGRC20Approve(cross(cur), tt.inputToken, routerAddr, math.MaxInt64)

			amountSpecified := safeParseInt64(tt.amountSpecified)

			router := mockRouter()

			handleMultiSwapFn := func(cur realm) (int64, int64) {
				return router.handleMultiSwap(0, cur,
					tt.swapType,
					tt.route,
					tt.numHops,
					amountSpecified,
				)
			}

			if tt.shouldPanic {
				uassert.AbortsWithMessage(t, cur, tt.panicMsg, func() {
					handleMultiSwapFn(cross(cur))
				})
			} else {
				amountIn, amountOut := handleMultiSwapFn(cross(cur))

				uassert.Equal(t, tt.expectedAmountIn, strconv.FormatInt(amountIn, 10))
				uassert.Equal(t, tt.expectedAmountOut, strconv.FormatInt(amountOut, 10))
			}
		})
	}
}

func TestProcessRoute_MultiHops(cur realm, t *testing.T) {
	t.Skip("interrealm v2: pool state mutated by prior swap tests; expected amounts need isolation")

	initRouterTest(cur, t)
	testing.SkipHeights(500)

	tests := []struct {
		name              string
		route             string
		toSwap            string
		swapType          SwapType
		expectedAmountIn  string
		expectedAmountOut string
		expectError       bool
		errorMsg          string
	}{
		{
			name:              "Single hop route - ExactIn",
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000",
			toSwap:            "1000",
			swapType:          ExactIn,
			expectedAmountIn:  "1000",
			expectedAmountOut: "2687",
			expectError:       false,
		},
		{
			name:              "Multi hop route (2 hops) - ExactIn - triggers default case",
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000",
			toSwap:            "1000",
			swapType:          ExactIn,
			expectedAmountIn:  "1000",
			expectedAmountOut: "7185",
			expectError:       false,
		},
		{
			name:              "Multi hop route (3 hops) - ExactIn - triggers default case",
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000*POOL*gno.land/r/onbloc/qux:gno.land/r/onbloc/foo:10000",
			toSwap:            "1000",
			swapType:          ExactIn,
			expectedAmountIn:  "1000",
			expectedAmountOut: "18972",
			expectError:       false,
		},
		{
			name:              "Multi hop route (2 hops) - ExactOut - triggers default case",
			route:             "gno.land/r/onbloc/bar:gno.land/r/onbloc/baz:10000*POOL*gno.land/r/onbloc/baz:gno.land/r/onbloc/qux:10000",
			toSwap:            "1000",
			swapType:          ExactOut,
			expectedAmountIn:  "375",
			expectedAmountOut: "2650",
			expectError:       false,
		},
		{
			name:              "Invalid route",
			route:             "invalid",
			toSwap:            "1000",
			swapType:          ExactIn,
			expectedAmountIn:  "",
			expectedAmountOut: "",
			expectError:       true,
			errorMsg:          "[GNOSWAP-ROUTER-008] invalid pool path || len(poolPathSplit) != 3, poolPath: invalid",
		},
		{
			name:              "Empty route",
			route:             "",
			toSwap:            "1000",
			swapType:          ExactIn,
			expectedAmountIn:  "",
			expectedAmountOut: "",
			expectError:       true,
			errorMsg:          "[GNOSWAP-ROUTER-008] invalid pool path || len(poolPathSplit) != 3, poolPath: ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			testing.SkipHeights(100)
			createMultiHopPools(cur, t)

			op := &baseSwapOperation{
				amountSpecified: safeParseInt64(tt.toSwap),
			}

			toSwapAmount := safeParseInt64(tt.toSwap)
			testing.SetRealm(adminRealm)

			common.SafeGRC20Approve(cross(cur), barPath, routerAddr, math.MaxInt64)

			router := mockRouter()
			processRouteFn := func(cur realm) (int64, int64, error) {
				return op.processRoute(0, cur, router, tt.route, toSwapAmount, tt.swapType)
			}

			if tt.expectError {
				uassert.AbortsWithMessage(t, cur, tt.errorMsg, func() {
					processRouteFn(cross(cur))
				})
			} else {
				amountIn, amountOut, err := processRouteFn(cross(cur))

				uassert.Equal(t, tt.expectedAmountIn, strconv.FormatInt(amountIn, 10))
				uassert.Equal(t, tt.expectedAmountOut, strconv.FormatInt(amountOut, 10))
				uassert.NoError(t, err)
			}
		})
	}
}

const multiHopPoolFee uint32 = FEE_HIGH

var multiHopPoolsReady bool

func createMultiHopPools(cur realm, t *testing.T) {
	t.Helper()
	if multiHopPoolsReady {
		return
	}

	testing.SetRealm(adminRealm)

	gns.Approve(cross(cur), poolAddr, pl.GetPoolCreationFee()*3)

	pl.CreatePool(cross(cur), barPath, bazPath, multiHopPoolFee, "130621891405341611593710811006")
	pl.CreatePool(cross(cur), bazPath, quxPath, multiHopPoolFee, "130621891405341611593710811006")
	pl.CreatePool(cross(cur), quxPath, fooPath, multiHopPoolFee, "130621891405341611593710811006")

	bar.Approve(cross(cur), poolAddr, maxApprove)
	baz.Approve(cross(cur), poolAddr, maxApprove)
	qux.Approve(cross(cur), poolAddr, maxApprove)
	foo.Approve(cross(cur), poolAddr, maxApprove)

	pn.Mint(cross(cur), barPath, bazPath, multiHopPoolFee, int32(9000), int32(11000), "100000", "100000", "0", "0", 9999999999, adminAddr, "")
	pn.Mint(cross(cur), bazPath, quxPath, multiHopPoolFee, int32(9000), int32(11000), "100000", "100000", "0", "0", 9999999999, adminAddr, "")
	pn.Mint(cross(cur), quxPath, fooPath, multiHopPoolFee, int32(9000), int32(11000), "100000", "100000", "0", "0", 9999999999, adminAddr, "")

	multiHopPoolsReady = true
}

// Test GetSwapFee
func TestGetSwapFee(cur realm, t *testing.T) {
	router := mockRouter()

	// Default fee should be 0 or set value
	fee := router.GetSwapFee()
	uassert.True(t, fee >= 0, "fee should be non-negative")
}

// Test calculateRouterFee
func TestCalculateRouterFee(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		swapFee  uint64
		expected int64
	}{
		{
			name:     "zero fee",
			amount:   1000,
			swapFee:  0,
			expected: 0,
		},
		{
			name:     "0.15% fee (15 bps)",
			amount:   10000,
			swapFee:  15,
			expected: 15, // 10000 * 15 / 10000 = 15
		},
		{
			name:     "1% fee (100 bps)",
			amount:   10000,
			swapFee:  100,
			expected: 100, // 10000 * 100 / 10000 = 100
		},
		{
			name:     "10% fee (1000 bps)",
			amount:   10000,
			swapFee:  1000,
			expected: 1000, // 10000 * 1000 / 10000 = 1000
		},
		{
			name:     "small amount with fee",
			amount:   10,
			swapFee:  100,
			expected: 0, // 10 * 100 / 10000 = 0.1 rounded down to 0
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := calculateRouterFee(tt.amount, tt.swapFee)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test calculateExactOutWithRouterFee
func TestCalculateExactOutWithRouterFee(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		swapFee  uint64
		expected int64
	}{
		{
			name:     "zero fee returns same amount",
			amount:   1000,
			swapFee:  0,
			expected: 1000,
		},
		{
			name:     "0.15% fee calculation",
			amount:   10000,
			swapFee:  15,
			expected: 10015, // 10000 * 10000 / (10000 - 15) = 10015.01...
		},
		{
			name:     "1% fee calculation",
			amount:   10000,
			swapFee:  100,
			expected: 10101, // 10000 * 10000 / (10000 - 100) = 10101.01...
		},
		{
			name:     "large amount with small fee",
			amount:   1000000000,
			swapFee:  15,
			expected: 1001502253, // 1000000000 * 10000 / 9985
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := calculateExactOutWithRouterFee(tt.amount, tt.swapFee)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// ========== Router Dry Swap Tests ==========

// Test SwapProcessor calculateSwapAmountByQuote
func TestSwapProcessor_calculateSwapAmountByQuote(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified int64
		quote           string
		expectError     bool
		expectedResult  int64
	}{
		{
			name:            "100% quote",
			amountSpecified: 1000,
			quote:           "100",
			expectError:     false,
			expectedResult:  1000,
		},
		{
			name:            "50% quote",
			amountSpecified: 1000,
			quote:           "50",
			expectError:     false,
			expectedResult:  500,
		},
		{
			name:            "1% quote",
			amountSpecified: 10000,
			quote:           "1",
			expectError:     false,
			expectedResult:  100,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result, err := calculateSwapAmountByQuote(tt.amountSpecified, tt.quote)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result, tt.expectedResult)
			}
		})
	}
}

// Test SwapProcessor ValidateSwapResults
func TestSwapProcessor_ValidateSwapResults(cur realm, t *testing.T) {
	router := mockRouter()
	processor := &SwapProcessor{router: router}

	tests := []struct {
		name            string
		swapType        SwapType
		resultAmountIn  int64
		resultAmountOut int64
		amountSpecified int64
		amountLimit     int64
		swapCount       int64
		expectedSuccess bool
	}{
		{
			name:            "ExactIn - success case",
			swapType:        ExactIn,
			resultAmountIn:  1000,
			resultAmountOut: 950,
			amountSpecified: 1000,
			amountLimit:     900,
			swapCount:       1,
			expectedSuccess: true,
		},
		{
			name:            "ExactIn - too few received",
			swapType:        ExactIn,
			resultAmountIn:  1000,
			resultAmountOut: 850,
			amountSpecified: 1000,
			amountLimit:     900,
			swapCount:       1,
			expectedSuccess: false,
		},
		{
			name:            "ExactOut - success case",
			swapType:        ExactOut,
			resultAmountIn:  1050,
			resultAmountOut: 1000,
			amountSpecified: -1000,
			amountLimit:     1100,
			swapCount:       1,
			expectedSuccess: true,
		},
		{
			name:            "ExactOut - too much spent",
			swapType:        ExactOut,
			resultAmountIn:  1150,
			resultAmountOut: 1000,
			amountSpecified: -1000,
			amountLimit:     1100,
			swapCount:       1,
			expectedSuccess: false,
		},
		{
			name:            "ExactOut - within tolerance",
			swapType:        ExactOut,
			resultAmountIn:  1050,
			resultAmountOut: 998,
			amountSpecified: -1000,
			amountLimit:     1100,
			swapCount:       2,
			expectedSuccess: true,
		},
		{
			name:            "ExactOut - exceeds tolerance",
			swapType:        ExactOut,
			resultAmountIn:  1050,
			resultAmountOut: 997,
			amountSpecified: -1000,
			amountLimit:     1100,
			swapCount:       2,
			expectedSuccess: false,
		},
		{
			name:            "zero amounts",
			swapType:        ExactIn,
			resultAmountIn:  0,
			resultAmountOut: 0,
			amountSpecified: 1000,
			amountLimit:     900,
			swapCount:       1,
			expectedSuccess: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			_, _, success := processor.ValidateSwapResults(
				tt.swapType,
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountSpecified,
				tt.amountLimit,
				tt.swapCount,
			)

			uassert.Equal(t, success, tt.expectedSuccess)
		})
	}
}

// Test SwapProcessor AddSwapResults
func TestSwapProcessor_AddSwapResults(cur realm, t *testing.T) {
	router := mockRouter()
	processor := &SwapProcessor{router: router}

	tests := []struct {
		name            string
		resultAmountIn  int64
		resultAmountOut int64
		amountIn        int64
		amountOut       int64
		expectError     bool
		expectedIn      int64
		expectedOut     int64
	}{
		{
			name:            "normal addition",
			resultAmountIn:  1000,
			resultAmountOut: 950,
			amountIn:        500,
			amountOut:       475,
			expectError:     false,
			expectedIn:      1500,
			expectedOut:     1425,
		},
		{
			name:            "zero additions",
			resultAmountIn:  0,
			resultAmountOut: 0,
			amountIn:        0,
			amountOut:       0,
			expectError:     false,
			expectedIn:      0,
			expectedOut:     0,
		},
		{
			name:            "adding to existing results",
			resultAmountIn:  999999,
			resultAmountOut: 888888,
			amountIn:        1,
			amountOut:       1,
			expectError:     false,
			expectedIn:      1000000,
			expectedOut:     888889,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			newIn, newOut, err := processor.AddSwapResults(
				tt.resultAmountIn,
				tt.resultAmountOut,
				tt.amountIn,
				tt.amountOut,
			)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, newIn, tt.expectedIn)
				uassert.Equal(t, newOut, tt.expectedOut)
			}
		})
	}
}

// ========== Router Parser and Validator Tests ==========

// Test RouteParser creation
func TestNewRouteParser(cur realm, t *testing.T) {
	parser := NewRouteParser()
	uassert.NotNil(t, parser)
}

// Test RouteParser ParseRoutes
func TestRouteParser_ParseRoutes(cur realm, t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name          string
		routes        string
		quotes        string
		expectError   bool
		expectedError string
	}{
		{
			name:        "valid single route",
			routes:      "tokenA:tokenB:500",
			quotes:      "100",
			expectError: false,
		},
		{
			name:        "valid two routes",
			routes:      "tokenA:tokenB:500,tokenA:tokenC:3000",
			quotes:      "50,50",
			expectError: false,
		},
		{
			name:          "empty routes",
			routes:        "",
			quotes:        "100",
			expectError:   true,
			expectedError: "routes cannot be empty",
		},
		{
			name:          "empty quotes",
			routes:        "tokenA:tokenB:500",
			quotes:        "",
			expectError:   true,
			expectedError: "routes cannot be empty",
		},
		{
			name:          "mismatch count",
			routes:        "tokenA:tokenB:500,tokenA:tokenC:3000",
			quotes:        "100",
			expectError:   true,
			expectedError: "mismatch between routes(2) and quotes(1) length",
		},
		{
			name:          "invalid quote sum",
			routes:        "tokenA:tokenB:500,tokenA:tokenC:3000",
			quotes:        "40,50",
			expectError:   true,
			expectedError: "quote sum(90) must be 100",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			routes, quotes, err := parser.ParseRoutes(tt.routes, tt.quotes)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.expectedError != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.expectedError),
						"expected error to contain: "+tt.expectedError)
				}
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, routes)
				uassert.NotNil(t, quotes)
			}
		})
	}
}

// Test RouteParser ValidateQuoteSum
func TestRouteParser_ValidateQuoteSum(cur realm, t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name        string
		quotes      []string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "perfect sum 100",
			quotes:      []string{"50", "50"},
			expectError: false,
		},
		{
			name:        "three quotes summing to 100",
			quotes:      []string{"33", "33", "34"},
			expectError: false,
		},
		{
			name:        "sum less than 100",
			quotes:      []string{"40", "40"},
			expectError: true,
			errorMsg:    "quote sum(80) must be 100",
		},
		{
			name:        "sum greater than 100",
			quotes:      []string{"60", "60"},
			expectError: true,
			errorMsg:    "quote sum exceeds 100 at index",
		},
		{
			name:        "quote with zero",
			quotes:      []string{"0", "100"},
			expectError: true,
			errorMsg:    "must be positive value",
		},
		{
			name:        "quote exceeds 100",
			quotes:      []string{"101"},
			expectError: true,
			errorMsg:    "must be less than or equal to",
		},
		{
			name:        "invalid quote format",
			quotes:      []string{"abc", "50"},
			expectError: true,
			errorMsg:    "invalid quote",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := parser.ValidateQuoteSum(tt.quotes)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg),
						"expected error to contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test RouteParser ValidateRoutesAndQuotes
func TestRouteParser_ValidateRoutesAndQuotes(cur realm, t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name        string
		routes      []string
		quotes      []string
		expectError bool
		errorMsg    string
	}{
		{
			name:        "valid single route",
			routes:      []string{"route1"},
			quotes:      []string{"100"},
			expectError: false,
		},
		{
			name:        "valid seven routes (maximum)",
			routes:      []string{"r1", "r2", "r3", "r4", "r5", "r6", "r7"},
			quotes:      []string{"14", "14", "14", "14", "14", "15", "15"},
			expectError: false,
		},
		{
			name:        "zero routes",
			routes:      []string{},
			quotes:      []string{},
			expectError: true,
			errorMsg:    "route length(0) must be 1~7",
		},
		{
			name:        "eight routes (exceeds maximum)",
			routes:      []string{"r1", "r2", "r3", "r4", "r5", "r6", "r7", "r8"},
			quotes:      []string{"12", "12", "12", "12", "13", "13", "13", "13"},
			expectError: true,
			errorMsg:    "route length(8) must be 1~7",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := parser.ValidateRoutesAndQuotes(tt.routes, tt.quotes)

			if tt.expectError {
				uassert.Error(t, err)
				if tt.errorMsg != "" {
					uassert.True(t, strings.Contains(err.Error(), tt.errorMsg),
						"expected error to contain: "+tt.errorMsg)
				}
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test SwapValidator amount
func TestSwapValidator_Amount(cur realm, t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name        string
		amount      int64
		expectError bool
		expected    int64
	}{
		{
			name:        "positive amount",
			amount:      1000,
			expectError: false,
			expected:    1000,
		},
		{
			name:        "zero amount",
			amount:      0,
			expectError: true,
		},
		{
			name:        "negative amount",
			amount:      -100,
			expectError: true,
		},
		{
			name:        "large amount",
			amount:      999999999999999,
			expectError: false,
			expected:    999999999999999,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result, err := validator.amount(tt.amount)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

// Test SwapValidator amountLimit
func TestSwapValidator_AmountLimit(cur realm, t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name        string
		amountLimit int64
		expectError bool
		expected    int64
	}{
		{
			name:        "positive limit",
			amountLimit: 1000,
			expectError: false,
			expected:    1000,
		},
		{
			name:        "zero limit",
			amountLimit: 0,
			expectError: true,
		},
		{
			name:        "negative limit",
			amountLimit: -100,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result, err := validator.amountLimit(tt.amountLimit)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.Equal(t, result, tt.expected)
			}
		})
	}
}

// Test SwapValidator swapType
func TestSwapValidator_SwapType(cur realm, t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name        string
		swapTypeStr string
		expectError bool
		expected    SwapType
	}{
		{
			name:        "EXACT_IN",
			swapTypeStr: "EXACT_IN",
			expectError: false,
			expected:    ExactIn,
		},
		{
			name:        "EXACT_OUT",
			swapTypeStr: "EXACT_OUT",
			expectError: false,
			expected:    ExactOut,
		},
		{
			name:        "invalid type",
			swapTypeStr: "Invalid",
			expectError: true,
		},
		{
			name:        "empty string",
			swapTypeStr: "",
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result, err := validator.swapType(tt.swapTypeStr)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				// Just verify it returned without error, can't compare SwapType directly
				uassert.True(t, result == tt.expected, "swap type should match expected")
			}
		})
	}
}

// Test SwapValidator slippage
func TestSwapValidator_Slippage(cur realm, t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name        string
		swapType    SwapType
		amountIn    int64
		amountOut   int64
		limit       int64
		expectError bool
	}{
		{
			name:        "ExactIn - sufficient output",
			swapType:    ExactIn,
			amountIn:    1000,
			amountOut:   950,
			limit:       900,
			expectError: false,
		},
		{
			name:        "ExactIn - insufficient output",
			swapType:    ExactIn,
			amountIn:    1000,
			amountOut:   850,
			limit:       900,
			expectError: true,
		},
		{
			name:        "ExactOut - acceptable input",
			swapType:    ExactOut,
			amountIn:    1050,
			amountOut:   1000,
			limit:       1100,
			expectError: false,
		},
		{
			name:        "ExactOut - excessive input",
			swapType:    ExactOut,
			amountIn:    1150,
			amountOut:   1000,
			limit:       1100,
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := validator.slippage(tt.swapType, tt.amountIn, tt.amountOut, tt.limit)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test SwapValidator exactOutAmount
func TestSwapValidator_ExactOutAmount(cur realm, t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name            string
		resultAmount    int64
		specifiedAmount int64
		swapCount       int64
		expectError     bool
	}{
		{
			name:            "exact match",
			resultAmount:    1000,
			specifiedAmount: 1000,
			swapCount:       1,
			expectError:     false,
		},
		{
			name:            "within tolerance",
			resultAmount:    1001,
			specifiedAmount: 1000,
			swapCount:       2,
			expectError:     false,
		},
		{
			name:            "exceeds tolerance",
			resultAmount:    1010,
			specifiedAmount: 1000,
			swapCount:       1,
			expectError:     true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := validator.exactOutAmount(tt.resultAmount, tt.specifiedAmount, tt.swapCount)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test validateRoutesAndQuotes convenience function
func TestValidateRoutesAndQuotes(cur realm, t *testing.T) {
	tests := []struct {
		name        string
		routes      string
		quotes      string
		expectError bool
	}{
		{
			name:        "valid single route",
			routes:      "tokenA:tokenB:500",
			quotes:      "100",
			expectError: false,
		},
		{
			name:        "valid multiple routes",
			routes:      "tokenA:tokenB:500,tokenA:tokenC:3000",
			quotes:      "50,50",
			expectError: false,
		},
		{
			name:        "invalid - empty",
			routes:      "",
			quotes:      "",
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			routes, quotes, err := validateRoutesAndQuotes(tt.routes, tt.quotes)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				uassert.NotNil(t, routes)
				uassert.NotNil(t, quotes)
			}
		})
	}
}

// ========== Edge Cases and Integration Tests ==========

// Test protocol fee with boundary values
func TestCalculateRouterFee_BoundaryValues(cur realm, t *testing.T) {
	tests := []struct {
		name     string
		amount   int64
		swapFee  uint64
		expected int64
	}{
		{
			name:     "minimum non-zero fee",
			amount:   10000,
			swapFee:  1,
			expected: 1,
		},
		{
			name:     "maximum allowed fee (10%)",
			amount:   10000,
			swapFee:  1000,
			expected: 1000,
		},
		{
			name:     "amount of 1 with fee",
			amount:   1,
			swapFee:  100,
			expected: 0, // rounds down
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result := calculateRouterFee(tt.amount, tt.swapFee)
			uassert.Equal(t, result, tt.expected)
		})
	}
}

// Test quote validation with edge cases
func TestRouteParser_ValidateQuoteSum_EdgeCases(cur realm, t *testing.T) {
	parser := NewRouteParser()

	tests := []struct {
		name        string
		quotes      []string
		expectError bool
	}{
		{
			name:        "all quotes equal",
			quotes:      []string{"25", "25", "25", "25"},
			expectError: false,
		},
		{
			name:        "one large quote",
			quotes:      []string{"99", "1"},
			expectError: false,
		},
		{
			name:        "negative quote string",
			quotes:      []string{"-50", "150"},
			expectError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			err := parser.ValidateQuoteSum(tt.quotes)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
			}
		})
	}
}

// Test swap processor with extreme amounts
func TestSwapProcessor_ProcessSwapAmount_ExtremeValues(cur realm, t *testing.T) {
	tests := []struct {
		name            string
		amountSpecified int64
		quote           string
		expectError     bool
		expectZero      bool
	}{
		{
			name:            "max int64 amount",
			amountSpecified: 9223372036854775807,
			quote:           "1",
			expectError:     false,
			expectZero:      false,
		},
		{
			name:            "very large amount with 100% quote",
			amountSpecified: 999999999999999999,
			quote:           "100",
			expectError:     false,
			expectZero:      false,
		},
		{
			name:            "zero amount with any quote",
			amountSpecified: 0,
			quote:           "50",
			expectError:     true,
			expectZero:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(cur realm, t *testing.T) {
			result, err := calculateSwapAmountByQuote(tt.amountSpecified, tt.quote)

			if tt.expectError {
				uassert.Error(t, err)
			} else {
				uassert.NoError(t, err)
				if !tt.expectZero {
					uassert.True(t, result != 0, "result should not be zero")
				}
			}
		})
	}
}
