package position

import (
	"gno.land/r/demo/consts"

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
		denominator := new(u256.Uint).Add(numerator1, product)

		if denominator.IsZero() {
			panic("position_sqrt price math #1")
		}

		res := new(u256.Uint).Mul(numerator1, sqrtPX96)
		res = res.Div(res, denominator)
		return res
	}

	denominator := new(u256.Uint).Sub(numerator1, product)

	if !(denominator.Gt(u256.Zero())) {
		panic("position_sqrt price math #2")
	}

	_tmp := new(u256.Uint).Div(numerator1, sqrtPX96)
	_tmp = _tmp.Add(_tmp, amount)
	return new(u256.Uint).Div(numerator1, _tmp)
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint1288
	amount *u256.Uint, // uint256
	add bool,
) *u256.Uint { // uint160
	quotient := u256.Zero()
	if amount.Lte(u256.UnsafeFromDecimal(consts.MAX_UINT160)) {
		quotient = quotient.Lsh(amount, 96)
		quotient = quotient.Div(quotient, liquidity)
	} else {
		_tmp := new(u256.Uint).Div(u256.UnsafeFromDecimal(consts.Q96), liquidity)
		quotient = new(u256.Uint).Mul(amount, _tmp)
	}

	// quotient mutst be positive when amount and liquidity are positive
	if add {
		result := new(u256.Uint).Add(sqrtPX96, quotient)

		if !(result.Gte(sqrtPX96)) {
			panic("position_sqrt price math #3")
		}

		return result
	}

	result := new(u256.Uint).Sub(sqrtPX96, quotient)
	if !(result.Gte(u256.Zero())) {
		panic("position_sqrt price math #4")
	}

	return result
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountIn *u256.Uint, // uint256
	zeroForOne bool, // bool
) *u256.Uint { // uint160
	if zeroForOne {
		amount0Result := sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
		return amount0Result
	}

	amount1Result := sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
	return amount1Result
}

func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint128
	amountOut *u256.Uint, // uint256
	zeroForOne bool, // bool
) *u256.Uint { // uint160
	if zeroForOne {
		amount1Result := sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
		return amount1Result
	}

	amount0Result := sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
	return amount0Result
}

func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint160
) *u256.Uint { // uint256
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, 96)
	numerator2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := new(u256.Uint).Mul(numerator1, numerator2)
	res = res.Div(res, sqrtRatioBX96)
	res = res.Div(res, sqrtRatioAX96)

	return res
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint160
) *u256.Uint { // uint256
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	_tmp := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
	res := new(u256.Uint).Mul(liquidity, _tmp)
	res = res.Div(res, u256.UnsafeFromDecimal(consts.Q96))

	return res
}

func sqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) *i256.Int { // int256
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs())
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i)
	}
	u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs())
	return i256.FromUint256(u)
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 *u256.Uint, // uint160
	sqrtRatioBX96 *u256.Uint, // uint160
	liquidity *i256.Int, // int128
) *i256.Int { // int256
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs())
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i)
	}

	u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs())
	return i256.FromUint256(u)
}
