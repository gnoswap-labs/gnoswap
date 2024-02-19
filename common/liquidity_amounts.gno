package position

import (
	"gno.land/r/demo/consts"
)

// toAscendingOrder checkes if the first value is greater than
// the second then swaps two values.
func toAscendingOrder(a, b bigint) (bigint, bigint) {
	if a > b {
		return b, a
	}

	return a, b
}

// calcIntermediateValue computes the intermediate value
// used in liquidity calculations.
func calcIntermediateValue(sqrtRatioAX96, sqrtRatioBX96 bigint) bigint {
	return (sqrtRatioAX96 * sqrtRatioBX96) / consts.Q96
}

// computeLiquidityForAmount0 calculates liquidity for a given amount of token 0.
func computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0 bigint) bigint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	intermediate := calcIntermediateValue(sqrtRatioAX96, sqrtRatioBX96)
	diff := sqrtRatioBX96 - sqrtRatioAX96

	// we don't need to care about division by zero here.
	return amount0 * intermediate / diff
}

// computeLiquidityForAmount1 calculates liquidity for a given amount of token 1.
func computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1 bigint) bigint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := sqrtRatioBX96 - sqrtRatioAX96

	return (amount1 * consts.Q96) / diff
}

// GetLiquidityForAmounts calculates the liquidity for given amounts od token 0 and token 1.
func GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 bigint) bigint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	var liquidity bigint

	if sqrtRatioX96 <= sqrtRatioAX96 {
		liquidity = computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0)
	} else if sqrtRatioX96 < sqrtRatioBX96 {
		liquidity0 := computeLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0)
		liquidity1 := computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1)

		if liquidity0 < liquidity1 {
			liquidity = liquidity0
		} else {
			liquidity = liquidity1
		}

	} else {
		liquidity = computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1)
	}

	return liquidity
}

// computeAmount0ForLiquidity calculates the amount of token 0 for a given liquidity.
func computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity bigint) bigint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := sqrtRatioBX96 - sqrtRatioAX96

	return (liquidity << 96) * diff / (sqrtRatioBX96 * sqrtRatioAX96)
}

// computeAmount1ForLiquidity calculates the amount of token 1 for a given liquidity.
func computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity bigint) bigint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := sqrtRatioBX96 - sqrtRatioAX96

	return liquidity * diff / consts.Q96
}

// GetAmountsForLiquidity calculates the amounts of token 0 and token 1 for a given liquidity.
func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity bigint) (bigint, bigint) {
	var amount0, amount1 bigint

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	if sqrtRatioX96 <= sqrtRatioAX96 {
		amount0 = computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	} else if sqrtRatioX96 < sqrtRatioBX96 {
		amount0 = computeAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity)
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity)
	} else {
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	}

	return amount0, amount1
}
