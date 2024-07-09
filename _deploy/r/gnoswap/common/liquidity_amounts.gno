package common

import (
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// toAscendingOrder checkes if the first value is greater than
// the second then swaps two values.
func toAscendingOrder(a, b *u256.Uint) (*u256.Uint, *u256.Uint) {
	if a.Gt(b) {
		return b, a
	}

	return a, b
}

// computeLiquidityForAmount0 calculates liquidity for a given amount of token 0.
func computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	intermediate := u256.MulDiv(sqrtRatioAX96, sqrtRatioBX96, u256.MustFromDecimal(consts.Q96))

	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := u256.MulDiv(amount0, intermediate, diff)
	return res
}

// computeLiquidityForAmount1 calculates liquidity for a given amount of token 1.
func computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := u256.MulDiv(amount1, u256.MustFromDecimal(consts.Q96), diff)
	return res
}

// GetLiquidityForAmounts calculates the liquidity for given amounts od token 0 and token 1.
func GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	var liquidity *u256.Uint

	if sqrtRatioX96.Lte(sqrtRatioAX96) {
		liquidity = computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0)
	} else if sqrtRatioX96.Lt(sqrtRatioBX96) {
		liquidity0 := computeLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0)
		liquidity1 := computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1)

		if liquidity0.Lt(liquidity1) {
			liquidity = liquidity0
		} else {
			liquidity = liquidity1
		}

	} else {
		liquidity = computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1)
	}

	return liquidity
}

// computeAmount0ForLiquidity calculates the amount of token0 for a given liquidity.
func computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	val1 := new(u256.Uint).Lsh(liquidity, 96)
	val2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := u256.MulDiv(val1, val2, sqrtRatioBX96)

	res = res.Div(res, sqrtRatioAX96)

	return res
}

// computeAmount1ForLiquidity calculates the amount of token1 for a given liquidity.
func computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	val2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := u256.MulDiv(liquidity, val2, u256.MustFromDecimal(consts.Q96))
	return res
}

// GetAmountsForLiquidity calculates the amounts of token0 and token1 for a given liquidity.
// FROM [POOL] position_modify.gno
func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96 *u256.Uint, liquidity *i256.Int) (string, string) {
	var amount0, amount1 *i256.Int

	if !(liquidity.IsZero()) {
		if sqrtRatioX96.Lt(sqrtRatioAX96) { // currentTick < tickLower
			_amount0Str := SqrtPriceMathGetAmount0DeltaStr(
				sqrtRatioAX96,
				sqrtRatioBX96,
				liquidity,
			)
			amount0 = i256.MustFromDecimal(_amount0Str)

		} else if sqrtRatioX96.Lt(sqrtRatioBX96) { // currentTick < tickUpper
			_amount0Str := SqrtPriceMathGetAmount0DeltaStr(
				sqrtRatioX96,
				sqrtRatioBX96,
				liquidity,
			)
			amount0 = i256.MustFromDecimal(_amount0Str)

			_amount1Str := SqrtPriceMathGetAmount1DeltaStr(
				sqrtRatioAX96,
				sqrtRatioX96,
				liquidity,
			)
			amount1 = i256.MustFromDecimal(_amount1Str)

		} else {
			_amount1Str := SqrtPriceMathGetAmount1DeltaStr(
				sqrtRatioAX96,
				sqrtRatioBX96,
				liquidity,
			)
			amount1 = i256.MustFromDecimal(_amount1Str)
		}

	}

	// if position is out of range, one of amount0 or amount1 can be nil
	// > handle as 0
	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()

	return amount0.ToString(), amount1.ToString()
}
