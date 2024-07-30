package position

import (
	"gno.land/r/gnoswap/common"

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
//   Two strings representing the amounts of the first and second assets
//   that would be minted.
// TODO: Write test
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

	// FROM: pool__position_modify.gno
	amount0Str := common.SqrtPriceMathGetAmount0DeltaStr(
		sqrtLowerX96,
		sqrtUpperX96,
		i256Liquidity,
	)

	amount1Str := common.SqrtPriceMathGetAmount1DeltaStr(
		sqrtLowerX96,
		sqrtRatioX96,
		i256Liquidity,
	)

	var amount0, amount1 *i256.Int
	switch {
	case liquidity.IsZero():
		amount0 = i256.Zero()
		amount1 = i256.Zero()
	case tickCurrent < tickLower:
		amount0 = i256.MustFromDecimal(amount0Str)
		amount1 = i256.Zero()
	case tickCurrent < tickUpper:
		amount0 = i256.MustFromDecimal(amount0Str)
		amount1 = i256.MustFromDecimal(amount1Str)
	default:
		amount0 = i256.Zero()
		amount1 = i256.MustFromDecimal(amount1Str)
	}

	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()

	return amount0.ToString(), amount1.ToString()
}
