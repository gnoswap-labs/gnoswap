package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"
)

func sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amount *u256.Uint, // uint256
	add bool,
) *u256.Uint { // uint160
	if amount.IsZero() {
		return sqrtPX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)
	product := new(u256.Uint).Mul(amount, sqrtPX96)

	if add {
		if new(u256.Uint).Div(product, amount).Eq(sqrtPX96) {
			denominator := new(u256.Uint).Add(numerator1, product)

			if denominator.Gte(numerator1) {
				return u256.MulDivRoundingUp(numerator1, sqrtPX96, denominator)
			}
		}

		div := new(u256.Uint).Div(numerator1, sqrtPX96)
		add := new(u256.Uint).Add(div, amount)
		return u256.DivRoundingUp(numerator1, add)
	} else {
		cond1 := new(u256.Uint).Div(product, amount).Eq(sqrtPX96)
		cond2 := numerator1.Gt(product)

		if !(cond1 && cond2) {
			panic("pool_sqrt price math #1")
		}

		denominator := new(u256.Uint).Sub(numerator1, product)
		return u256.MulDivRoundingUp(numerator1, sqrtPX96, denominator)
	}
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint1288
	amount *u256.Uint, // uint256
	add bool,
) *u256.Uint { // uint160
	quotient := u256.Zero()

	if add {
		if amount.Lte(u256.MustFromDecimal(MAX_UINT160)) {
			value1 := new(u256.Uint).Lsh(amount, 96)
			quotient = new(u256.Uint).Div(value1, liquidity)
		} else {
			quotient = u256.MulDiv(amount, u256.MustFromDecimal(consts.Q96), liquidity)
		}

		res := new(u256.Uint).Add(sqrtPX96, quotient)
		max160 := u256.MustFromDecimal("1461501637330902918203684832716283019655932542975")

		if res.Gt(max160) {
			panic("sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown sqrtPx96 + quotient overflow uint160")
		}
		return res

	} else {
		if amount.Lte(u256.MustFromDecimal(MAX_UINT160)) {
			value1 := new(u256.Uint).Lsh(amount, 96)
			quotient = u256.DivRoundingUp(value1, liquidity)
		} else {
			quotient = u256.MulDivRoundingUp(amount, u256.MustFromDecimal(consts.Q96), liquidity)
		}

		if !(sqrtPX96.Gt(quotient)) {
			panic("pool_sqrt price math #2")
		}

		return new(u256.Uint).Sub(sqrtPX96, quotient)
	}
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountIn *u256.Uint, // uint256
	zeroForOne bool, // bool
) *u256.Uint { // uint160
	if sqrtPX96.IsZero() {
		panic("sqrtPX96 should not be zero")
	}

	if liquidity.IsZero() {
		panic("pool_sqrtPriceMathGetNextSqrtPriceFromInput_liquidity should not be zero")
	}

	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	}
	return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountOut *u256.Uint, // uint256
	zeroForOne bool, // bool
) *u256.Uint { // uint160
	if sqrtPX96.IsZero() {
		panic("pool_sqrtPriceMathGetNextSqrtPriceFromOutput_sqrtPX96 should not be zero")
	}

	if liquidity.IsZero() {
		panic("pool_sqrtPriceMathGetNextSqrtPriceFromOutput_liquidity should not be zero")
	}

	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	}

	return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint160
	roundUp bool,
) *u256.Uint { // uint256
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)
	numerator2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	if !(sqrtRatioAX96.Gt(u256.Zero())) {
		panic("pool_sqrt price math #3")
	}

	if roundUp {
		value1 := u256.MulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96)
		return u256.DivRoundingUp(value1, sqrtRatioAX96)
	} else {
		value1 := u256.MulDiv(numerator1, numerator2, sqrtRatioBX96)
		return new(u256.Uint).Div(value1, sqrtRatioAX96)
	}
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint160
	roundUp bool,
) *u256.Uint { // uint256
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	if roundUp {
		diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
		return u256.MulDivRoundingUp(liquidity, diff, u256.MustFromDecimal(consts.Q96))
	} else {
		diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
		return u256.MulDiv(liquidity, diff, u256.MustFromDecimal(consts.Q96))
	}
}

func SqrtPriceMathGetAmount0DeltaStr(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) string { // int256
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i).ToString()
	}

	u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	return i256.FromUint256(u).ToString()
}

func SqrtPriceMathGetAmount1DeltaStr(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) string { // int256
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i).ToString()
	}

	u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	return i256.FromUint256(u).ToString()
}
