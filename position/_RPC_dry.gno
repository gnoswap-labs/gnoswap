package position

import (
	p "gno.land/r/demo/pool"
)

func DryMint(
	tickCurrent int32,
	tickLower int32,
	tickUpper int32,
	amount0Desired bigint,
	amount1Desired bigint,
) (amount0, amount1 bigint) {
	sqrtRatioX96 := p.TickMathGetSqrtRatioAtTick(tickCurrent)
	sqrtLowerX96 := p.TickMathGetSqrtRatioAtTick(tickLower)
	sqrtUpperX96 := p.TickMathGetSqrtRatioAtTick(tickUpper)

	liquidity := liquidityAmountsGetLiquidityForAmounts(
		sqrtRatioX96,
		sqrtLowerX96,
		sqrtUpperX96,
		amount0Desired,
		amount1Desired,
	)

	if liquidity != 0 {
		if tickCurrent < tickLower {
			amount0 = sqrtPriceMathGetAmount0Delta(
				sqrtLowerX96,
				sqrtUpperX96,
				liquidity,
			)
		} else if tickCurrent < tickUpper {
			amount0 = sqrtPriceMathGetAmount0Delta(
				sqrtRatioX96,
				sqrtUpperX96,
				liquidity,
			)

			amount1 = sqrtPriceMathGetAmount1Delta(
				sqrtLowerX96,
				sqrtRatioX96,
				liquidity,
			)
		} else {
			amount1 = sqrtPriceMathGetAmount1Delta(
				sqrtLowerX96,
				sqrtUpperX96,
				liquidity,
			)
		}
	}
	return amount0, amount1
}
