package position

import (
	"gno.land/p/gnoswap/gnsmath"
	u256 "gno.land/p/gnoswap/uint256"
)

func GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) *u256.Uint {
	return gnsmath.GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1)
}

func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (*u256.Uint, *u256.Uint) {
	return gnsmath.GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func TickMathGetSqrtRatioAtTick(tick int32) *u256.Uint {
	return gnsmath.TickMathGetSqrtRatioAtTick(tick)
}
