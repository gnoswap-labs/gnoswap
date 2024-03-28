package position

import (
	"gno.land/r/gnoswap/common"

	i256 "gno.land/p/demo/int256"
	u256 "gno.land/p/demo/uint256"
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
			amount0 = sqrtPriceMathGetAmount0Delta(
				sqrtLowerX96,
				sqrtUpperX96,
				i256Liquidity,
			)
		} else if tickCurrent < tickUpper {
			amount0 = sqrtPriceMathGetAmount0Delta(
				sqrtRatioX96,
				sqrtUpperX96,
				i256Liquidity,
			)

			amount1 = sqrtPriceMathGetAmount1Delta(
				sqrtLowerX96,
				sqrtRatioX96,
				i256Liquidity,
			)
		} else {
			amount1 = sqrtPriceMathGetAmount1Delta(
				sqrtLowerX96,
				sqrtUpperX96,
				i256Liquidity,
			)
		}
	}
	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()
	return amount0.ToString(), amount1.ToString()
}
