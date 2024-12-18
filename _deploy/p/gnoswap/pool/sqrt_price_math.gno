package pool

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

var (
	Q96_RESOLUTION  = uint(96)
	Q160_RESOLUTION = uint(160)
)

// sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp calculates the next square root price
// based on the amount of token0 added or removed from the pool.
// NOTE: Always rounds up, because in the exact output case (increasing price) we need to move the price at least
// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
// price less in order to not send too much output.
// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96),
// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- amount).
//
// Parameters:
// - sqrtPX96: The current square root price as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - amount: The amount of token0 to be added or removed from the pool (uint256).
// - add: A boolean indicating whether the amount of token0 is being added (true) or removed (false).
//
// Returns:
// - The price after adding or removing amount, depending on add
//
// Notes:
// - When `add` is true, the function calculates the new square root price after adding `amount` of token0.
// - When `add` is false, the function calculates the new square root price after removing `amount` of token0.
// - The function uses high-precision math (MulDivRoundingUp, DivRoundingUp) to handle division rounding issues.
// - The function validates input conditions and panics if the state is invalid.
func sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amount *u256.Uint,
	add bool,
) *u256.Uint {
	// we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
	if amount.IsZero() {
		return sqrtPX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, Q96_RESOLUTION)
	product := new(u256.Uint).Mul(amount, sqrtPX96)

	if add {
		if new(u256.Uint).Div(product, amount).Eq(sqrtPX96) {
			denominator := new(u256.Uint).Add(numerator1, product)

			if denominator.Gte(numerator1) {
				return u256.MulDivRoundingUp(numerator1, sqrtPX96, denominator)
			}
		}

		divValue := new(u256.Uint).Div(numerator1, sqrtPX96)
		addValue := new(u256.Uint).Add(divValue, amount)
		return u256.DivRoundingUp(numerator1, addValue)
	} else {
		cond1 := new(u256.Uint).Div(product, amount).Eq(sqrtPX96)
		cond2 := numerator1.Gt(product)

		if !(cond1 && cond2) {
			panic("invalid pool sqrt price calculation: product/amount != sqrtPX96 or numerator1 <= product")
		}

		denominator := new(u256.Uint).Sub(numerator1, product)
		nextSqrtPrice := u256.MulDivRoundingUp(numerator1, sqrtPX96, denominator)
		max160 := u256.MustFromDecimal(MAX_UINT160)
		if nextSqrtPrice.Gt(max160) {
			panic("nextSqrtPrice overflows uint160")
		}
		return nextSqrtPrice
	}
}

// sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown calculates the next square root price
// based on the amount of token1 added or removed from the pool, with rounding down.
// NOTE: Always rounds down, because in the exact output case (decreasing price) we need to move the price at least
// far enough to get the desired output amount, and in the exact input case (increasing price) we need to move the
// price less in order to not send too much output.
// The formula we compute is within <1 wei of the lossless version: sqrtPX96 +- amount / liquidity
//
// Parameters:
// - sqrtPX96: The current square root price as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - amount: The amount of token1 to be added or removed from the pool (uint256).
// - add: A boolean indicating whether the amount of token1 is being added (true) or removed (false).
//
// Returns:
// - The next square root price as a Q96 fixed-point number (uint160).
//
// Notes:
// - When `add` is true, the function calculates the new square root price after adding `amount` of token1.
// - When `add` is false, the function calculates the new square root price after removing `amount` of token1.
// - The function uses high-precision math (MulDiv and DivRoundingUp) to handle division and prevent precision loss.
// - The function validates input conditions and panics if the state is invalid.
func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint, // uint160
	liquidity *u256.Uint, // uint1288
	amount *u256.Uint, // uint256
	add bool,
) *u256.Uint { // uint160
	quotient := u256.Zero()
	max160 := u256.MustFromDecimal(MAX_UINT160)

	// if we're adding (subtracting), rounding down requires rounding the quotient down (up)
	// in both cases, avoid a mulDiv for most inputs
	if add {
		if amount.Lte(u256.MustFromDecimal(MAX_UINT160)) {
			value := new(u256.Uint).Lsh(amount, Q96_RESOLUTION)
			quotient = new(u256.Uint).Div(value, liquidity)
		} else {
			quotient = u256.MulDiv(amount, u256.MustFromDecimal(Q96), liquidity)
		}

		res := new(u256.Uint).Add(sqrtPX96, quotient)
		if res.Gt(max160) {
			panic("GetNextSqrtPriceFromAmount1RoundingDown sqrtPx96 + quotient overflow uint160")
		}
		return res
	} else {
		if amount.Lte(u256.MustFromDecimal(MAX_UINT160)) {
			value := new(u256.Uint).Lsh(amount, Q96_RESOLUTION)
			quotient = u256.DivRoundingUp(value, liquidity)
		} else {
			quotient = u256.MulDivRoundingUp(amount, u256.MustFromDecimal(Q96), liquidity)
		}

		if !(sqrtPX96.Gt(quotient)) {
			panic("sqrt price exceeds calculated quotient")
		}

		res := new(u256.Uint).Sub(sqrtPX96, quotient)
		if res.Gt(max160) {
			mask := new(u256.Uint).Lsh(u256.One(), Q160_RESOLUTION)
			mask = mask.Sub(mask, u256.One())
			res = res.And(res, mask)
		}
		return res
	}
}

// sqrtPriceMathGetNextSqrtPriceFromInput calculates the next square root price
// based on the amount of token0 or token1 added to the pool.
// NOTE: Always rounds up, because in the exact output case (increasing price) we need to move the price at least
// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
// price less in order to not send too much output.
// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96),
// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- amount).
//
// Parameters:
// - sqrtPX96: The current square root price as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - amountIn: The amount of token0 or token1 to be added to the pool (uint256).
// - zeroForOne: A boolean indicating whether the amount is being added to token0 (true) or token1 (false).
//
// Returns:
// - The price after adding amountIn, depending on zeroForOne
func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountIn *u256.Uint,
	zeroForOne bool,
) *u256.Uint {
	if sqrtPX96.IsZero() {
		panic("sqrtPX96 should not be zero")
	}

	if liquidity.IsZero() {
		panic("liquidity should not be zero")
	}

	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	} else {
		return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
	}
}

// sqrtPriceMathGetNextSqrtPriceFromOutput calculates the next square root price
// based on the amount of token0 or token1 removed from the pool.
//
// NOTE:
// - For zeroForOne == true (Token0 -> Token1): The calculation uses rounding down.
// - For zeroForOne == false (Token1 -> Token0): The calculation uses rounding up.
//
// The most precise formula for this is:
// - liquidity * sqrtPX96 / (liquidity ± amount * sqrtPX96)
// If overflow occurs, it falls back to:
// - liquidity / (liquidity / sqrtPX96 ± amount)
//
// Parameters:
// - sqrtPX96: The current square root price as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - amountOut: The amount of token0 or token1 to be removed from the pool (uint256).
// - zeroForOne: A boolean indicating whether the amount is being removed from token0 (true) or token1 (false).
//
// Returns:
// - The price after removing amountOut, depending on zeroForOne.
//
// Notes:
// - Rounding direction depends on the swap direction (zeroForOne).
// - Relies on helper functions:
//   - `sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown` for Token0 -> Token1.
//   - `sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp` for Token1 -> Token0.
func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountOut *u256.Uint,
	zeroForOne bool,
) *u256.Uint {
	if sqrtPX96.IsZero() {
		panic("sqrtPX96 should not be zero")
	}

	if liquidity.IsZero() {
		panic("liquidity should not be zero")
	}

	if zeroForOne {
		return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	} else {
		return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
	}
}

// sqrtPriceMathGetAmount0DeltaHelper calculates the absolute difference between the amounts of token0 in two
// liquidity ranges defined by the square root prices sqrtRatioAX96 and sqrtRatioBX96. The difference is
// calculated relative to the range [sqrtRatioAX96, sqrtRatioBX96].
//
// If sqrtRatioAX96 > sqrtRatioBX96, their values are swapped to ensure sqrtRatioAX96 is the lower bound.
//
// Parameters:
// - sqrtRatioAX96: The lower bound of the range as a Q96 fixed-point number (uint160).
// - sqrtRatioBX96: The upper bound of the range as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - roundUp: A boolean indicating whether the result should be rounded up (true) or down (false).
//
// Returns:
// - The absolute difference between the amounts of token0 in the two ranges as a uint256.
//
// Notes:
// - If sqrtRatioAX96 is zero or negative, the function panics.
// - The result is calculated using high-precision fixed-point arithmetic.
// - Rounding is applied based on the roundUp parameter.
func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
	roundUp bool,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := new(u256.Uint).Lsh(liquidity, Q96_RESOLUTION)
	numerator2 := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)

	if !(sqrtRatioAX96.Gt(u256.Zero())) {
		panic("sqrtRatioAX96 must be greater than zero")
	}

	if roundUp {
		value := u256.MulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96)
		return u256.DivRoundingUp(value, sqrtRatioAX96)
	} else {
		value := u256.MulDiv(numerator1, numerator2, sqrtRatioBX96)
		return new(u256.Uint).Div(value, sqrtRatioAX96)
	}
}

// sqrtPriceMathGetAmount1DeltaHelper calculates the absolute difference between the amounts of token1 in two
// liquidity ranges defined by the square root prices sqrtRatioAX96 and sqrtRatioBX96. The difference is
// calculated relative to the range [sqrtRatioAX96, sqrtRatioBX96].
//
// If sqrtRatioAX96 > sqrtRatioBX96, their values are swapped to ensure sqrtRatioAX96 is the lower bound.
//
// Parameters:
// - sqrtRatioAX96: The lower bound of the range as a Q96 fixed-point number (uint160).
// - sqrtRatioBX96: The upper bound of the range as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a Q128 fixed-point number (uint128).
// - roundUp: A boolean indicating whether the result should be rounded up (true) or down (false).
//
// Returns:
// - The absolute difference between the amounts of token1 in the two ranges as a uint256.
//
// Notes:
// - Rounding is applied based on the roundUp parameter.
// - The function swaps sqrtRatioAX96 and sqrtRatioBX96 if sqrtRatioAX96 > sqrtRatioBX96.
func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
	roundUp bool,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	diff := new(u256.Uint).Sub(sqrtRatioBX96, sqrtRatioAX96)
	if roundUp {
		return u256.MulDivRoundingUp(liquidity, diff, u256.MustFromDecimal(Q96))
	} else {
		return u256.MulDiv(liquidity, diff, u256.MustFromDecimal(Q96))
	}
}

// SqrtPriceMathGetAmount0DeltaStr calculates the difference in the amount of token0
// within a specified liquidity range defined by two square root prices (sqrtRatioAX96 and sqrtRatioBX96).
// This function returns the result as a string representation of an int256 value.
//
// If the liquidity is negative, the result is also negative.
//
// Parameters:
// - sqrtRatioAX96: The lower bound of the range as a Q96 fixed-point number (uint160).
// - sqrtRatioBX96: The upper bound of the range as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a signed Q128 fixed-point number (int128).
//
// Returns:
//   - A string representation of the int256 value representing the difference in token0 amounts
//     within the specified range. The value is negative if the liquidity is negative.
//
// Notes:
// - This function relies on the helper function `sqrtPriceMathGetAmount0DeltaHelper` to perform the core calculation.
//   - The helper function calculates the absolute difference between token0 amounts within the range.
//   - If the computed result exceeds the maximum allowable value for int256 (2**255 - 1), the function will panic
//     with an appropriate overflow error.
//   - The rounding behavior of the result is controlled by the `roundUp` parameter passed to the helper function:
//   - For negative liquidity, rounding is always down.
//   - For positive liquidity, rounding is always up.
func SqrtPriceMathGetAmount0DeltaStr(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) string {
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(u256.MustFromDecimal(MAX_INT256)) {
			// if u > (2**255 - 1), cannot cast to int256
			panic("SqrtPriceMathGetAmount0DeltaStr: overflow")
		}
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i).ToString()
	} else {
		u := sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
		if u.Gt(u256.MustFromDecimal(MAX_INT256)) {
			// if u > (2**255 - 1), cannot cast to int256
			panic("SqrtPriceMathGetAmount0DeltaStr: overflow")
		}
		return i256.FromUint256(u).ToString()
	}
}

// SqrtPriceMathGetAmount1DeltaStr calculates the difference in the amount of token1
// within a specified liquidity range defined by two square root prices (sqrtRatioAX96 and sqrtRatioBX96).
// This function returns the result as a string representation of an int256 value.
//
// If the liquidity is negative, the result is also negative.
//
// Parameters:
// - sqrtRatioAX96: The lower bound of the range as a Q96 fixed-point number (uint160).
// - sqrtRatioBX96: The upper bound of the range as a Q96 fixed-point number (uint160).
// - liquidity: The pool's active liquidity as a signed Q128 fixed-point number (int128).
//
// Returns:
//   - A string representation of the int256 value representing the difference in token1 amounts
//     within the specified range. The value is negative if the liquidity is negative.
//
// Notes:
// - This function relies on the helper function `sqrtPriceMathGetAmount1DeltaHelper` to perform the core calculation.
// - The rounding behavior of the result is controlled by the `roundUp` parameter passed to the helper function:
//   - For negative liquidity, rounding is always down.
//   - For positive liquidity, rounding is always up.
func SqrtPriceMathGetAmount1DeltaStr(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) string {
	if liquidity.IsNeg() {
		u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(u256.MustFromDecimal(MAX_INT256)) {
			// if u > (2**255 - 1), cannot cast to int256
			panic("SqrtPriceMathGetAmount1DeltaStr: overflow")
		}
		i := i256.FromUint256(u)
		return i256.Zero().Neg(i).ToString()
	} else {
		u := sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
		if u.Gt(u256.MustFromDecimal(MAX_INT256)) {
			// if u > (2**255 - 1), cannot cast to int256
			panic("SqrtPriceMathGetAmount1DeltaStr: overflow")
		}
		return i256.FromUint256(u).ToString()
	}
}
