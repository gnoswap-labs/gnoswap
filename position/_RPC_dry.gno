package position

import (
	"gno.land/r/gnoswap/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// DryMint simulates a mint and returns the amount0, amount1 that would be minted
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
	var amount0, amount1 *i256.Int
	if !(liquidity.IsZero()) { // != 0
		if tickCurrent < tickLower {
			amount0Str := common.SqrtPriceMathGetAmount0DeltaStr(
				sqrtLowerX96,
				sqrtUpperX96,
				i256Liquidity,
			)
			amount0 = i256.MustFromDecimal(amount0Str)
		} else if tickCurrent < tickUpper {
			amount0Str := common.SqrtPriceMathGetAmount0DeltaStr(
				sqrtRatioX96,
				sqrtUpperX96,
				i256Liquidity,
			)
			amount0 = i256.MustFromDecimal(amount0Str)

			amount1Str := common.SqrtPriceMathGetAmount1DeltaStr(
				sqrtLowerX96,
				sqrtRatioX96,
				i256Liquidity,
			)
			amount1 = i256.MustFromDecimal(amount1Str)
		} else {
			amount1Str := common.SqrtPriceMathGetAmount1DeltaStr(
				sqrtLowerX96,
				sqrtUpperX96,
				i256Liquidity,
			)
			amount1 = i256.MustFromDecimal(amount1Str)
		}
	}
	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()

	return amount0.ToString(), amount1.ToString()
}
