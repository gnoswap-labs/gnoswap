package position

import (
	"gno.land/r/demo/consts"
)

// swapIfGreater checkes if the first value is greater than
// the second then swaps two values.
func swapIfGreater(a, b bigint) (bigint, bigint) {
	if a > b {
		return b, a
	}

	return a, b
}

// calcIntermediateValue computes the intermediate value
// used in liquidity calculations.
func calcIntermediateValue(sqrtRatioA, sqrtRatioB bigint) bigint {
	return (sqrtRatioA * sqrtRatioB) / consts.Q96
}

// GetLiquidityForAmount0 calculates liquidity for a given amount of token 0.
func computeLiquidityForAmount0(sqrtRatioA, sqrtRatioB, amount0 bigint) bigint {
	sqrtRatioA, sqrtRatioB = swapIfGreater(sqrtRatioA, sqrtRatioB)
	intermediate := calcIntermediateValue(sqrtRatioA, sqrtRatioB)
	diff := sqrtRatioB - sqrtRatioA

	// we don't need to care about division by zero here.
	return amount0 * intermediate / diff
}

// computeLiquidityForAmount1 calculates liquidity for a given amount of token 1.
func computeLiquidityForAmount1(sqrtRatioA, sqrtRatioB, amount1 bigint) bigint {
	sqrtRatioA, sqrtRatioB = swapIfGreater(sqrtRatioA, sqrtRatioB)
	diff := sqrtRatioB - sqrtRatioA

	return (amount1 * consts.Q96) / diff
}

// GetLiquidityForAmounts calculates the liquidity for given amounts od token 0 and token 1.
func GetLiquidityForAmounts(sqrtRatioX, sqrtRatioA, sqrtRatioB, amount0, amount1 bigint) bigint {
	sqrtRatioA, sqrtRatioB = swapIfGreater(sqrtRatioA, sqrtRatioB)
	var liquidity bigint

	if sqrtRatioX <= sqrtRatioA {
		liquidity = computeLiquidityForAmount0(sqrtRatioA, sqrtRatioB, amount0)
	} else if sqrtRatioX < sqrtRatioB {
		liquidity0 := computeLiquidityForAmount0(sqrtRatioX, sqrtRatioB, amount0)
		liquidity1 := computeLiquidityForAmount1(sqrtRatioA, sqrtRatioX, amount1)

		if liquidity0 < liquidity1 {
			liquidity = liquidity0
		} else {
			liquidity = liquidity1
		}

	} else {
		liquidity = computeLiquidityForAmount1(sqrtRatioA, sqrtRatioB, amount1)
	}

	return liquidity
}

// computeAmount0ForLiquidity calculates the amount of token 0 for a given liquidity.
func computeAmount0ForLiquidity(sqrtRatioA, sqrtRatioB, liquidity bigint) bigint {
	sqrtRatioA, sqrtRatioB = swapIfGreater(sqrtRatioA, sqrtRatioB)
	diff := sqrtRatioB - sqrtRatioA

	return (liquidity << 96) * diff / (sqrtRatioB * sqrtRatioA)
}

// computeAmount1ForLiquidity calculates the amount of token 1 for a given liquidity.
func computeAmount1ForLiquidity(sqrtRatioA, sqrtRatioB, liquidity bigint) bigint {
	sqrtRatioA, sqrtRatioB = swapIfGreater(sqrtRatioA, sqrtRatioB)
	diff := sqrtRatioB - sqrtRatioA

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
