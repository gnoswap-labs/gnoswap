package v1

import (
	"strings"
	"testing"
	"time"

	"gno.land/p/nt/uassert"

	pl "gno.land/r/gnoswap/pool"
	pn "gno.land/r/gnoswap/position"

	"gno.land/r/gnoswap/gns"
	"gno.land/r/onbloc/bar"
	"gno.land/r/onbloc/foo"

	u256 "gno.land/p/gnoswap/uint256"
)

func TestExactOutSwapOperation(t *testing.T) {
	testing.SetRealm(routerRealm)
	setupTestPool(t)

	t.Run("validate exact out params", func(t *testing.T) {
		router := mockRouter()

		op := NewExactOutSwapOperation(router, ExactOutParams{
			BaseSwapParams: BaseSwapParams{
				InputToken:  barPath,
				OutputToken: fooPath,
				RouteArr:    "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000",
				QuoteArr:    "100",
			},
			AmountOut:   100,
			AmountInMax: 150,
		})

		err := op.Validate()
		uassert.Equal(t, err, nil)

		// Invalid amount out
		invalidOp := NewExactOutSwapOperation(router, ExactOutParams{
			BaseSwapParams: BaseSwapParams{
				InputToken:  barPath,
				OutputToken: fooPath,
				RouteArr:    "gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000",
				QuoteArr:    "100",
			},
			AmountOut:   -100, // negative amount
			AmountInMax: 150,
		})

		err = invalidOp.Validate()
		uassert.NotEqual(t, err, nil)
	})

	t.Run("exact out swap with invalid route", func(t *testing.T) {
		router := mockRouter()

		uassert.PanicsContains(t, "invalid fee: format", func() {
			router.ExactOutSwapRoute(
				barPath,
				fooPath,
				"3",
				"invalid:route:format", // invalid route format
				"100",
				"5",
				time.Now().Add(time.Hour).Unix(),
				"",
			)
		})
	})

	t.Run("exact out swap with expired deadline", func(t *testing.T) {
		router := mockRouter()

		uassert.PanicsContains(t, "[GNOSWAP-ROUTER-004] transaction expired || transaction too old, now(1234567890) > deadline(1234564290)", func() {
			router.ExactOutSwapRoute(
				fooPath,
				barPath,
				"3",
				"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000",
				"100",
				"5",
				time.Now().Add(-time.Hour).Unix(), // expired deadline
				"",
			)
		})
	})
}

func TestExactOutSwapBoundary(t *testing.T) {
	t.Skip("run this test separately")
	testing.SetRealm(routerRealm)
	setupTestPool(t)

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	TokenFaucet2(t, fooPath, routerAddr)
	TokenFaucet2(t, barPath, routerAddr)

	testing.SetRealm(testing.NewUserRealm(routerAddr))
	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	// create position
	// a. Position 1: (-50%+50%)
	pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		-6960,
		6960,
		"3000000000",
		"3000000000",
		"0",
		"0",
		max_timeout,
		routerAddr,
		routerAddr,
		"",
	)

	// b. Position 2: (-10%+10%)
	pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		-1080,
		960,
		"1000000000",
		"1000000000",
		"0",
		"0",
		max_timeout,
		routerAddr,
		routerAddr,
		"",
	)

	// c. Position 3: (full range)
	pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		-887220,
		887220,
		"5000000000",
		"5000000000",
		"0",
		"0",
		max_timeout,
		routerAddr,
		routerAddr,
		"",
	)

	// d. Position 4: (lower out-range)
	pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		-44280,
		-19080,
		"1000000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		routerAddr,
		routerAddr,
		"",
	)

	// e. Position 5: (upper out-range)
	pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		62160,
		69060,
		"1000000",
		"1000000000",
		"0",
		"0",
		max_timeout,
		routerAddr,
		routerAddr,
		"",
	)

	t.Run("successful exact out swap at boundary", func(t *testing.T) {
		router := mockRouter()

		amountIn, amountOut := router.ExactOutSwapRoute(
			barPath,
			fooPath,
			"1000000",
			"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000",
			"100",
			"1100000",
			time.Now().Add(time.Hour).Unix(),
			"",
		)

		uassert.NotEqual(t, amountIn, "0")
		uassert.NotEqual(t, amountOut, "0")
	})

	t.Run("failed exact out swap at boundary", func(t *testing.T) {
		poolPath := pl.GetPoolPath(barPath, fooPath, 3000)
		balance0 := pl.GetBalanceToken0(poolPath)
		balance1 := pl.GetBalanceToken1(poolPath)

		token0Balance := u256.MustFromDecimal(balance0)
		token1Balance := u256.MustFromDecimal(balance1)
		println("token1Balance", token1Balance.ToString())

		overflowAmount := u256.Zero().Add(token0Balance, u256.One()).ToString()

		defer func() {
			if r := recover(); r == nil {
				if !strings.Contains(r.(string), "overflow") {
					t.Error("Expected panic for overflow at boundary")
				}
			}
		}()

		// request amount that slightly exceeds the pool balance
		router := mockRouter()

		router.ExactOutSwapRoute(
			barPath,
			fooPath,
			overflowAmount,
			"gno.land/r/onbloc/foo:gno.land/r/onbloc/bar:3000",
			"100",
			"50101690",
			time.Now().Add(time.Hour).Unix(),
			"",
		)
	})
}

func setupTestPool(t *testing.T) {
	t.Helper()
	testing.SetRealm(adminRealm)
	gns.Approve(cross, poolAddr, pl.GetPoolCreationFee())

	foo.Approve(cross, poolAddr, maxApprove)
	bar.Approve(cross, poolAddr, maxApprove)

	pl.CreatePool(cross, barPath, fooPath, 3000, "79228162514264337593543950336") // encodePriceSqrt(1, 1)

	_, _, _, _ = pn.Mint(
		cross,
		barPath,
		fooPath,
		3000,
		minTick,
		maxTick,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	pool := pl.GetPoolPath(barPath, fooPath, FEE_MEDIUM)
	uassert.Equal(t, pl.GetLiquidity(pool), "1000000")
}

func TestExactOutAmountValidation(t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name            string
		resultAmount    int64
		specifiedAmount int64
		swapCount       int64
		shouldFail      bool
		errorContains   string
	}{
		{
			name:            "exact match",
			resultAmount:    1000,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "1 ugnot less - allowed",
			resultAmount:    999,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "2 ugnot less - not allowed",
			resultAmount:    998,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      true,
			errorContains:   "received more than requested",
		},
		{
			name:            "1 ugnot more - allowed",
			resultAmount:    1001,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "2 ugnot more - not allowed",
			resultAmount:    1002,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      true,
			errorContains:   "received more than requested",
		},
		{
			name:            "significantly less",
			resultAmount:    900,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      true,
			errorContains:   "received more than requested",
		},
		{
			name:            "significantly more - security issue",
			resultAmount:    1100,
			specifiedAmount: 1000,
			swapCount:       1,
			shouldFail:      true,
			errorContains:   "received more than requested",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validator.exactOutAmount(tt.resultAmount, tt.specifiedAmount, tt.swapCount)

			if tt.shouldFail {
				uassert.Error(t, err, "expected error for %s", tt.name)
				if tt.errorContains != "" && err != nil {
					uassert.ErrorContains(t, err, tt.errorContains,
						"error message should contain '%s'", tt.errorContains)
				}
			} else {
				uassert.NoError(t, err, "expected no error for %s", tt.name)
			}
		})
	}
}

// TestExactOutAmountValidationEdgeCases tests edge cases for the validation
func TestExactOutAmountValidationEdgeCases(t *testing.T) {
	validator := &SwapValidator{}

	tests := []struct {
		name            string
		resultAmount    int64
		specifiedAmount int64
		swapCount       int64
		shouldFail      bool
	}{
		{
			name:            "zero result, zero specified",
			resultAmount:    0,
			specifiedAmount: 0,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "zero result, non-zero specified",
			resultAmount:    0,
			specifiedAmount: 100,
			swapCount:       1,
			shouldFail:      true,
		},
		{
			name:            "large numbers exact match",
			resultAmount:    1000000000000000000,
			specifiedAmount: 1000000000000000000,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "large numbers 1 ugnot diff",
			resultAmount:    1000000000000000001,
			specifiedAmount: 1000000000000000000,
			swapCount:       1,
			shouldFail:      false,
		},
		{
			name:            "large numbers 2 ugnot diff",
			resultAmount:    1000000000000000002,
			specifiedAmount: 1000000000000000000,
			swapCount:       1,
			shouldFail:      true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validator.exactOutAmount(tt.resultAmount, tt.specifiedAmount, tt.swapCount)

			if tt.shouldFail {
				uassert.Error(t, err, "expected error for %s", tt.name)
			} else {
				uassert.NoError(t, err, "expected no error for %s", tt.name)
			}
		})
	}
}
