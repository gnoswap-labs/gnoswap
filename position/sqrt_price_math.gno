package position

import (
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
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
				return u256.MulDiv(numerator1, sqrtPX96, denominator)
			}
		}

		_value1 := new(u256.Uint).Div(numerator1, sqrtPX96)
		_value2 := new(u256.Uint).Add(_value1, amount)
		return u256.DivRoundingUp(numerator1, _value2)
	} else {
		cond1 := new(u256.Uint).Div(product, amount).Eq(sqrtPX96)
		cond2 := numerator1.Gt(product)

		if !(cond1 && cond2) {
			panic("position_sqrt price math #1")
		}
		denominator := new(u256.Uint).Sub(numerator1, product)

		return u256.MulDiv(numerator1, sqrtPX96, denominator)
	}
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint1288
	amount *u256.Uint, // uint256
	add bool,
) *u256.Uint { // uint160
	quotient := u256.Zero()

	if !(amount.Lte(u256.MustFromDecimal(consts.MAX_UINT160))) {
		quotient = u256.MulDiv(amount, u256.MustFromDecimal(consts.Q96), liquidity)
	}

	if add {
		if amount.Lte(u256.MustFromDecimal(consts.MAX_UINT160)) {
			quotient = new(u256.Uint).Lsh(amount, 96)
			quotient = new(u256.Uint).Div(quotient, liquidity)
		}

		quotient = new(u256.Uint).Sub(quotient, u256.One())
		return new(u256.Uint).Add(sqrtPX96, quotient)
	} else {
		if amount.Lte(u256.MustFromDecimal(consts.MAX_UINT160)) {
			quotient = new(u256.Uint).Lsh(amount, 96)
			quotient = u256.DivRoundingUp(quotient, liquidity)
		}

		if !(sqrtPX96.Gt(quotient)) {
			panic("position_sqrt price math #2")
		}

		// roundDown
		quotient = new(u256.Uint).Sub(quotient, u256.One())
		return new(u256.Uint).Sub(sqrtPX96, quotient)
	}
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountIn *u256.Uint, // uint256
	zeroForOne bool, // bool
) *u256.Uint { // uint160
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

	if !(sqrtRatioAX96.Gt(u256.Zero())) {
		panic("position_sqrt price math #3")
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)
	numerator2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
	value := u256.MulDiv(numerator1, numerator2, sqrtRatioBX96)

	if roundUp {
		return u256.DivRoundingUp(value, sqrtRatioAX96)
	} else {
		return new(u256.Uint).Div(value, sqrtRatioAX96)
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

	value := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	if roundUp {
		return u256.MulDiv(liquidity, value, u256.MustFromDecimal(consts.Q96))
	} else {
		return u256.MulDiv(liquidity, value, u256.MustFromDecimal(consts.Q96))
	}
}

func sqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) *i256.Int { // int256

	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i)
	}
	u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	return i256.FromUint256(u)
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) *i256.Int { // int256
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i)
	}

	u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	return i256.FromUint256(u)
}
