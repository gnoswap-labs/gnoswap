package position

import (
	"gno.land/r/gnoswap/v2/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// DryMint simulates a mint and returns the amount0, amount1 that would be minted.
//
// It calculates the square root ratios at these ticks
// and determines the liquidity for the given amounts. Based on the current tick,
// it calculates and returns the amounts of the two assets that would be minted.
//
// Returns:
//
//	Two strings representing the amounts of the first and second assets
//	that would be minted.
func DryMint(
	tickCurrent int32,
	tickLower int32,
	tickUpper int32,
	_amount0Desired string,
	_amount1Desired string,
) (string, string) {
	// FROM: position__liquidity_management.gno
	sqrtRatioX96 := common.TickMathGetSqrtRatioAtTick(tickCurrent)
	sqrtLowerX96 := common.TickMathGetSqrtRatioAtTick(tickLower)
	sqrtUpperX96 := common.TickMathGetSqrtRatioAtTick(tickUpper)

	amount0Desired := u256.MustFromDecimal(_amount0Desired)
	amount1Desired := u256.MustFromDecimal(_amount1Desired)

	liquidity := common.GetLiquidityForAmounts(
		sqrtRatioX96,
		sqrtLowerX96,
		sqrtUpperX96,
		amount0Desired,
		amount1Desired,
	)
	i256Liquidity := i256.FromUint256(liquidity)

	// Calculate amounts based on the tick range and liquidity
	amount0, amount1 := calculateAmounts(tickCurrent, tickLower, tickUpper, sqrtRatioX96, sqrtLowerX96, sqrtUpperX96, i256Liquidity)

	return amount0.ToString(), amount1.ToString()
}

func calculateAmounts(
	tickCurrent, tickLower, tickUpper int32,
	sqrtRatioX96, sqrtLowerX96, sqrtUpperX96 *u256.Uint,
	i256Liquidity *i256.Int,
) (*i256.Int, *i256.Int) {
	var amount0, amount1 *i256.Int
	if !i256Liquidity.IsZero() {
		switch {
		case tickCurrent < tickLower:
			amount0 = getAmount0(sqrtLowerX96, sqrtUpperX96, i256Liquidity)
		case tickCurrent < tickUpper:
			amount0 = getAmount0(sqrtRatioX96, sqrtUpperX96, i256Liquidity)
			amount1 = getAmount1(sqrtLowerX96, sqrtRatioX96, i256Liquidity)
		default:
			amount1 = getAmount1(sqrtLowerX96, sqrtUpperX96, i256Liquidity)
		}
	}
	return amount0.NilToZero(), amount1.NilToZero()
}

func getAmount0(sqrtRatioStartX96, sqrtRatioEndX96 *u256.Uint, i256Liquidity *i256.Int) *i256.Int {
	amount0Str := common.SqrtPriceMathGetAmount0DeltaStr(sqrtRatioStartX96, sqrtRatioEndX96, i256Liquidity)
	return i256.MustFromDecimal(amount0Str)
}

func getAmount1(sqrtRatioStartX96, sqrtRatioEndX96 *u256.Uint, i256Liquidity *i256.Int) *i256.Int {
	amount1Str := common.SqrtPriceMathGetAmount1DeltaStr(sqrtRatioStartX96, sqrtRatioEndX96, i256Liquidity)
	return i256.MustFromDecimal(amount1Str)
}
