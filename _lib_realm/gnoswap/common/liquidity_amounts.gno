package common

import (
	"gno.land/r/gnoswap/consts"

	u256 "gno.land/p/demo/big/uint256"
)

// toAscendingOrder checkes if the first value is greater than
// the second then swaps two values.
func toAscendingOrder(a, b *u256.Uint) (*u256.Uint, *u256.Uint) {
	if a.Gt(b) {
		return b, a
	}

	return a, b
}

// calcIntermediateValue computes the intermediate value
// used in liquidity calculations.
func calcIntermediateValue(sqrtRatioAX96, sqrtRatioBX96 *u256.Uint) *u256.Uint {

	res := new(u256.Uint).Mul(sqrtRatioAX96, sqrtRatioBX96)
	res = res.Div(res, u256.MustFromDecimal(consts.Q96))
	return res
}

// computeLiquidityForAmount0 calculates liquidity for a given amount of token 0.
func computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	intermediate := calcIntermediateValue(sqrtRatioAX96, sqrtRatioBX96)
	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	// we don't need to care about division by zero here.
	res := new(u256.Uint).Mul(amount0, intermediate)
	res = res.Div(res, diff)
	return res
}

// computeLiquidityForAmount1 calculates liquidity for a given amount of token 1.
func computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := new(u256.Uint).Mul(amount1, u256.MustFromDecimal(consts.Q96))
	res = res.Div(res, diff)
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

// computeAmount0ForLiquidity calculates the amount of token 0 for a given liquidity.
func computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := new(u256.Uint).Lsh(liquidity, 96)
	res = res.Mul(res, diff)

	_tmp := new(u256.Uint).Mul(sqrtRatioBX96, sqrtRatioAX96)
	res = res.Div(res, _tmp)

	return res
}

// computeAmount1ForLiquidity calculates the amount of token 1 for a given liquidity.
func computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := new(u256.Uint).Mul(liquidity, diff)
	res = res.Div(res, u256.MustFromDecimal(consts.Q96))

	return res
}

// GetAmountsForLiquidity calculates the amounts of token 0 and token 1 for a given liquidity.
func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (*u256.Uint, *u256.Uint) {
	var amount0, amount1 *u256.Uint

	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	if sqrtRatioX96.Lte(sqrtRatioAX96) {
		amount0 = computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	} else if sqrtRatioX96.Lt(sqrtRatioBX96) {
		amount0 = computeAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity)
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity)
	} else {
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	}

	return amount0.NilToZero(), amount1.NilToZero()
}
