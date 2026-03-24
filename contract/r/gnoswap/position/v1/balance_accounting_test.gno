package v1

import (
	"strconv"
	"testing"

	uassert "gno.land/p/nt/uassert/v0"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/pool"
)

const (
	testMinPriceLimitZeroForOne  = "39614081257132168796771975168"
	testMaxPriceLimitNotZeroForOne = "158456325028528675187087900674"
	testMockSwapperPath          = "gno.land/r/gnoswap/test/mock_swapper"
)

func movePoolPriceForPositionTest(t *testing.T, zeroForOne bool, amountSpecified string) {
	t.Helper()

	testing.SetRealm(testing.NewUserRealm(adminAddr))
	common.SafeGRC20Approve(cross, barPath, poolAddr, maxApprove)
	common.SafeGRC20Approve(cross, fooPath, poolAddr, maxApprove)

	sqrtPriceLimitX96 := testMinPriceLimitZeroForOne
	if !zeroForOne {
		sqrtPriceLimitX96 = testMaxPriceLimitNotZeroForOne
	}

	swapCallback := func(cur realm, amount0Delta, amount1Delta int64, _ *pool.CallbackMarker) error {
		func(cur realm) {
			testing.SetRealm(testing.NewUserRealm(adminAddr))
			if amount0Delta > 0 {
				common.SafeGRC20Transfer(cross, barPath, poolAddr, amount0Delta)
			}
			if amount1Delta > 0 {
				common.SafeGRC20Transfer(cross, fooPath, poolAddr, amount1Delta)
			}
		}(cross)

		return nil
	}

	func(cur realm) {
		testing.SetRealm(testing.NewCodeRealm(testMockSwapperPath))
		pool.Swap(
			cross,
			barPath,
			fooPath,
			fee500,
			adminAddr,
			zeroForOne,
			amountSpecified,
			sqrtPriceLimitX96,
			adminAddr,
			swapCallback,
		)
	}(cross)
}

func assertDecimalStringsWithinOne(t *testing.T, want string, got string, message string) {
	t.Helper()

	wantInt, err := strconv.ParseInt(want, 10, 64)
	if err != nil {
		t.Fatalf("parse want %q: %v", want, err)
	}

	gotInt, err := strconv.ParseInt(got, 10, 64)
	if err != nil {
		t.Fatalf("parse got %q: %v", got, err)
	}

	delta := wantInt - gotInt
	if delta < 0 {
		delta = -delta
	}

	if delta > 1 {
		t.Fatalf("%s: want %s, got %s", message, want, got)
	}
}

func TestDecreaseLiquidityRefreshesPriceDerivedTokenBalances(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)

	_, _, _, _ = mockInstanceMint(
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	storedBeforeSwap := mockInstance.mustGetPosition(1)
	storedToken0BeforeSwap := storedBeforeSwap.Token0Balance().ToString()
	storedToken1BeforeSwap := storedBeforeSwap.Token1Balance().ToString()

	movePoolPriceForPositionTest(t, false, "300000")

	positionAfterSwap := mockInstance.mustGetPosition(1)
	calculatedToken0AfterSwap, calculatedToken1AfterSwap := calculatePositionBalances(positionAfterSwap)
	assertDecimalStringsWithinOne(t, calculatedToken0AfterSwap.ToString(), positionAfterSwap.Token0Balance().ToString(), "position reads should derive token0 balance from current price")
	assertDecimalStringsWithinOne(t, calculatedToken1AfterSwap.ToString(), positionAfterSwap.Token1Balance().ToString(), "position reads should derive token1 balance from current price")

	uassert.True(
		t,
		storedToken0BeforeSwap != calculatedToken0AfterSwap.ToString() || storedToken1BeforeSwap != calculatedToken1AfterSwap.ToString(),
		"price movement should change current position composition before any liquidity action",
	)
	testing.SetOriginCaller(adminAddr)

	_, _, _, _, _, _, _ = mockInstanceDecreaseLiquidity(
		1,
		"1000000",
		"0",
		"0",
		max_timeout,
	)

	positionAfterBurn := mockInstance.mustGetPosition(1)
	calculatedToken0AfterBurn, calculatedToken1AfterBurn := calculatePositionBalances(positionAfterBurn)

	assertDecimalStringsWithinOne(t, calculatedToken0AfterBurn.ToString(), positionAfterBurn.Token0Balance().ToString(), "burn reads should return token0 balance from current-price accounting")
	assertDecimalStringsWithinOne(t, calculatedToken1AfterBurn.ToString(), positionAfterBurn.Token1Balance().ToString(), "burn reads should return token1 balance from current-price accounting")
}

func TestRepositionResetsBalancesFromClearedPosition(t *testing.T) {
	initPositionTest(t)
	createPoolWithoutFee(barPath, fooPath, fee500, 0)

	_, _, _, _ = mockInstanceMint(
		barPath,
		fooPath,
		fee500,
		-10000,
		10000,
		"1000000",
		"1000000",
		"0",
		"0",
		max_timeout,
		adminAddr,
		adminAddr,
		"",
	)

	movePoolPriceForPositionTest(t, false, "300000")

	positionBeforeFullBurn := mockInstance.mustGetPosition(1)
	liquidityToRemove := positionBeforeFullBurn.Liquidity().ToString()
	testing.SetOriginCaller(adminAddr)

	_, _, _, _, _, _, _ = mockInstanceDecreaseLiquidity(
		1,
		liquidityToRemove,
		"0",
		"0",
		max_timeout,
	)

	clearedPosition := mockInstance.mustGetPosition(1)
	uassert.True(t, clearedPosition.IsClear(), "position should be clear before reposition")
	uassert.Equal(t, "0", clearedPosition.Token0Balance().ToString())
	uassert.Equal(t, "0", clearedPosition.Token1Balance().ToString())
	testing.SetOriginCaller(adminAddr)

	_, _, _, _, _, _ = mockInstanceReposition(
		1,
		-5000,
		5000,
		"500000",
		"1000000",
		"0",
		"0",
		max_timeout,
		adminAddr,
	)

	repositioned := mockInstance.mustGetPosition(1)
	calculatedToken0AfterReposition, calculatedToken1AfterReposition := calculatePositionBalances(repositioned)

	uassert.True(t, repositioned.Token0Balance().ToString() != "0" || repositioned.Token1Balance().ToString() != "0", "reposition should rebuild non-zero balances from new liquidity")
	assertDecimalStringsWithinOne(t, calculatedToken0AfterReposition.ToString(), repositioned.Token0Balance().ToString(), "reposition reads should return current-price token0 accounting")
	assertDecimalStringsWithinOne(t, calculatedToken1AfterReposition.ToString(), repositioned.Token1Balance().ToString(), "reposition reads should return current-price token1 accounting")
}
