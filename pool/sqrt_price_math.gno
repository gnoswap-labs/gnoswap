package pool

import (
	"gno.land/p/demo/u256"
	"gno.land/p/demo/ufmt"
)

func sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amount *u256.Uint,
	add bool,
) *u256.Uint {
	if amount.IsZero() {
		return sqrtPX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)

	product := new(u256.Uint).Mul(amount, sqrtPX96)

	var denominator *u256.Uint

	if add {
		if new(u256.Uint).Div(product, amount).Eq(sqrtPX96) {
			denominator = new(u256.Uint).Add(numerator1, product)
			if denominator.Gte(numerator1) {
				res := new(u256.Uint).Mul(numerator1, sqrtPX96)
				res.Div(res, denominator)
				return res
			}
		}

		denominator1 := new(u256.Uint).Div(numerator1, sqrtPX96)
		denominator1.Add(denominator1, amount)
		return new(u256.Uint).Div(numerator1, denominator1)
	}
	require(new(u256.Uint).Div(product, amount).Eq(sqrtPX96) && numerator1.Gt(product), "[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || condition must return true")

	denominator = new(u256.Uint).Sub(numerator1, product)

	res := new(u256.Uint).Mul(numerator1, sqrtPX96)
	res.Div(res, denominator)
	return res
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amount *u256.Uint,
	add bool,
) *u256.Uint {
	var quotient *u256.Uint
	if add {
		if amount.Gte(u256.FromBigint(consts.MAX_UINT160)) {
			scaledAmount := new(u256.Uint).Lsh(amount, 96)
			quotient = scaledAmount.Div(scaledAmount, liquidity)
		} else {
			scaledAmount := new(u256.Uint).Mul(amount, u256.FromBigint(consts.Q96))
			quotient = scaledAmount.Div(scaledAmount, liquidity)
		}
		return new(u256.Uint).Add(sqrtPX96, quotient)
	} else {
		if amount.Gte(u256.FromBigint(consts.MAX_UINT160)) {
			scaledAmount := new(u256.Uint).Lsh(amount, 96)
			quotient = scaledAmount.Div(scaledAmount, liquidity)
		} else {
			scaledAmount := new(u256.Uint).Mul(amount, u256.FromBigint(consts.Q96))
			quotient = scaledAmount.Div(scaledAmount, liquidity)
		}

		require(sqrtPX96.Gt(quotient), ufmt.Sprintf("[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || sqrtPX96(%d) must be greater than quotient(%d)", sqrtPX96, quotient))
		return new(u256.Uint).Sub(sqrtPX96, quotient)
	}
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountIn *u256.Uint,
	zeroForOne bool,
) (sqrtQ *u256.Uint) {
	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	}

	return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountOut *u256.Uint,
	zeroForOne bool,
) (sqrtQ *u256.Uint) {
	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	}

	return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)
	numerator2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := new(u256.Uint).Mul(numerator1, numerator2)
	res.Div(res, sqrtRatioBX96)
	res.Div(res, sqrtRatioAX96)
	return res
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	res := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
	res.Mul(res, liquidity)
	res.Div(res, u256.FromBigint(consts.Q96))
	return res
}

func sqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Int,
) *u256.Int {
	if liquidity.IsNeg() {
		return sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs()).Int().Neg()
	}

	return sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Uint()).Int()
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Int,
) *u256.Int {
	if liquidity.IsNeg() {
		return sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs()).Int().Neg()
	}

	return sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Uint()).Int()
}
