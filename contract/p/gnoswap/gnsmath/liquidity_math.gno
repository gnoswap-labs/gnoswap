package gnsmath

import (
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/p/gnoswap/consts"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// computeLiquidityForAmount0 calculates the liquidity supported by a token0 amount.
//
// It sorts the two Q64.96 square-root price bounds before applying the token0
// liquidity formula. Equal bounds are rejected because their difference is zero.
//
// Parameters:
//   - sqrtRatioAX96: Lower endpoint of the price range, encoded as a Q64.96 square-root ratio.
//   - sqrtRatioBX96: Upper endpoint of the price range, encoded as a Q64.96 square-root ratio.
//   - amount0: Available token0 amount to convert into liquidity.
//
// Returns:
//   - liquidity: Liquidity supported by amount0, constrained to the uint128 range.
//
// Panics if the bounds are identical or the calculated liquidity exceeds uint128.
func computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	intermediate := u256.MulDiv(sqrtRatioAX96, sqrtRatioBX96, consts.Q96())

	diff := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)
	if diff.IsZero() {
		panic(newErrorWithDetail(
			errLiquidityIdenticalTicks,
			ufmt.Sprintf("sqrtRatioAX96 (%s) and sqrtRatioBX96 (%s) are identical", sqrtRatioAX96.ToString(), sqrtRatioBX96.ToString()),
		))
	}
	res := u256.MulDiv(amount0, intermediate, diff)
	return SafeConvertToUint128(res)
}

// computeLiquidityForAmount1 calculates the liquidity supported by a token1 amount.
//
// It sorts the two Q96 square-root price bounds and divides the token1 amount
// by their difference. Equal bounds are rejected because their difference is zero.
//
// Parameters:
//   - sqrtRatioAX96: Lower endpoint of the price range, encoded as a Q64.96 square-root ratio.
//   - sqrtRatioBX96: Upper endpoint of the price range, encoded as a Q64.96 square-root ratio.
//   - amount1: Available token1 amount to convert into liquidity.
//
// Returns:
//   - liquidity: Liquidity supported by amount1, constrained to the uint128 range.
//
// Panics if the bounds are identical or the calculated liquidity exceeds uint128.
func computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	diff := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)
	if diff.IsZero() {
		panic(newErrorWithDetail(
			errLiquidityIdenticalTicks,
			ufmt.Sprintf("sqrtRatioAX96 (%s) and sqrtRatioBX96 (%s) are identical", sqrtRatioAX96.ToString(), sqrtRatioBX96.ToString()),
		))
	}
	res := u256.MulDiv(amount1, consts.Q96(), diff)
	return SafeConvertToUint128(res)
}

// GetLiquidityForAmounts calculates the maximum liquidity supported by two token amounts.
//
// The current square-root price determines which token amounts are active. Below
// the range only token0 is used, above it only token1 is used, and inside it the
// smaller of the token0- and token1-derived liquidities is returned.
//
// Parameters:
//   - sqrtRatioX96: Current square-root price, encoded as a Q64.96 ratio.
//   - sqrtRatioAX96: First price-range endpoint, encoded as a Q64.96 ratio.
//   - sqrtRatioBX96: Second price-range endpoint, encoded as a Q64.96 ratio; the endpoints are sorted.
//   - amount0: Available token0 amount.
//   - amount1: Available token1 amount.
//
// Returns:
//   - liquidity: Maximum liquidity supported by the amounts, constrained to uint128.
//
// Panics if a selected amount/range calculation has identical bounds or exceeds uint128.
func GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) (liquidity *u256.Uint) {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

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

// computeAmount0ForLiquidity calculates the token0 amount represented by liquidity.
//
// The price endpoints are sorted before applying the Q64.96 token0 formula.
// Zero liquidity, a zero endpoint, or identical endpoints produces zero rather
// than attempting a division by zero.
//
// Parameters:
//   - sqrtRatioAX96: First price-range endpoint, encoded as a Q64.96 square-root ratio.
//   - sqrtRatioBX96: Second price-range endpoint, encoded as a Q64.96 square-root ratio.
//   - liquidity: Non-negative liquidity to value.
//
// Returns:
//   - amount0: Token0 amount represented by liquidity over the ordered range; zero for the stated degenerate inputs.
func computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	if sqrtRatioAX96.IsZero() || sqrtRatioBX96.IsZero() || liquidity.IsZero() || sqrtRatioAX96.Eq(sqrtRatioBX96) {
		return u256.Zero()
	}

	val1 := u256.Zero().Lsh(liquidity, Q96_RESOLUTION)
	val2 := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)

	res := u256.MulDiv(val1, val2, sqrtRatioBX96)
	res = res.Div(res, sqrtRatioAX96)

	return res
}

// computeAmount1ForLiquidity calculates the token1 amount represented by liquidity.
//
// The price endpoints are sorted before computing liquidity times their Q64.96
// difference divided by Q96. Zero liquidity or identical endpoints produces zero.
//
// Parameters:
//   - sqrtRatioAX96: First price-range endpoint, encoded as a Q64.96 square-root ratio.
//   - sqrtRatioBX96: Second price-range endpoint, encoded as a Q64.96 square-root ratio.
//   - liquidity: Non-negative liquidity to value.
//
// Returns:
//   - amount1: Token1 amount represented by liquidity over the ordered range; zero for the stated degenerate inputs.
func computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	if liquidity.IsZero() || sqrtRatioAX96.Eq(sqrtRatioBX96) {
		return u256.Zero()
	}

	diff := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)
	res := u256.MulDiv(liquidity, diff, consts.Q96())

	return res
}

// GetAmountsForLiquidity calculates the amounts of token0 and token1 represented
// by a specified liquidity within a price range.
//
// If the current price is below the lower bound, only token0 is required. If the
// current price is above the upper bound, only token1 is required. When the
// price is within the range, both token0 and token1 are calculated.
//
// Parameters:
//   - sqrtRatioX96: Current square-root price in Q64.96 format.
//   - sqrtRatioAX96: First price-range endpoint in Q64.96 format.
//   - sqrtRatioBX96: Second price-range endpoint in Q64.96 format; the endpoints are ordered internally.
//   - liquidity: Non-negative liquidity amount to value.
//
// Returns:
//   - amount0: Token0 amount represented by liquidity; zero when the current price is at or above the upper endpoint.
//   - amount1: Token1 amount represented by liquidity; zero when the current price is at or below the lower endpoint.
//     Call ToString() on either value for decimal display.
//
// Notes:
//   - If liquidity is zero, the function returns zero values for both tokens.
//   - At a boundary, the corresponding out-of-range token amount is zero.
//
// Example:
// ```
// amount0, amount1 := GetAmountsForLiquidity(
//
//	u256.MustFromDecimal("79228162514264337593543950336"),  // sqrtRatioX96 (1.0 in Q64.96)
//	u256.MustFromDecimal("39614081257132168796771975168"),  // sqrtRatioAX96 (0.5 in Q64.96)
//	u256.MustFromDecimal("158456325028528675187087900672"), // sqrtRatioBX96 (2.0 in Q64.96)
//	u256.MustFromDecimal("1000000"),                        // Liquidity
//
// )
//
// println("Token0:", amount0.ToString(), "Token1:", amount1.ToString())
//
// // Output:
// Token0: 500000, Token1: 500000
// ```
func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (*u256.Uint, *u256.Uint) {
	if liquidity.IsZero() {
		return u256.Zero(), u256.Zero()
	}

	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	amount0 := u256.Zero()
	amount1 := u256.Zero()

	if sqrtRatioX96.Lte(sqrtRatioAX96) {
		amount0 = computeAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	} else if sqrtRatioX96.Lt(sqrtRatioBX96) {
		amount0 = computeAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity)
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity)
	} else {
		amount1 = computeAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	}

	return amount0, amount1
}

// LiquidityMathAddDelta calculates the new liquidity after applying a signed delta.
// A negative delta subtracts its magnitude; a non-negative delta adds its magnitude.
//
// Parameters:
//   - x: Current non-negative liquidity value.
//   - y: Signed liquidity delta; positive values add and negative values subtract.
//
// Returns:
//   - liquidity: Updated liquidity, constrained to the uint128 range.
//
// Panics if x or y is nil, subtraction underflows, addition overflows uint256,
// or the resulting liquidity exceeds MaxUint128.
func LiquidityMathAddDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
	if x == nil || y == nil {
		panic("liquidity_math: x or y is nil")
	}

	yAbs := y.Abs()

	// Subtract or add based on the sign of y
	if y.Lt(i256.Zero()) {
		z := u256.Zero().Sub(x, yAbs)
		if z.Gte(x) {
			panic(ufmt.Sprintf(
				"liquidity_math: underflow (x: %s, y: %s, z:%s)",
				x.ToString(), y.ToString(), z.ToString()))
		}
		if z.Gt(consts.MaxUint128()) {
			panic(ufmt.Sprintf(
				"liquidity_math: result exceeds uint128 range (z: %s)",
				z.ToString()))
		}
		return z
	}

	z := u256.Zero().Add(x, yAbs)
	if z.Lt(x) {
		panic(ufmt.Sprintf(
			"liquidity_math: overflow (x: %s, y: %s, z:%s)",
			x.ToString(), y.ToString(), z.ToString()))
	}
	if z.Gt(consts.MaxUint128()) {
		panic(ufmt.Sprintf(
			"liquidity_math: result exceeds uint128 range (z: %s)",
			z.ToString()))
	}
	return z
}

// toAscendingOrder returns the two unsigned values ordered from lower to higher.
//
// Parameters:
//   - a: First value to compare.
//   - b: Second value to compare.
//
// Returns:
//   - lower: The lesser of a and b; a is returned on ties.
//   - upper: The greater of a and b; b is returned on ties.
func toAscendingOrder(a, b *u256.Uint) (*u256.Uint, *u256.Uint) {
	if a.Gt(b) {
		return b, a
	}

	return a, b
}

// SafeConvertToUint128 verifies that value fits in the uint128 range.
//
// No representation conversion is performed: the original pointer is returned
// when its value is at most 2^128 - 1.
//
// Parameters:
//   - value: Non-nil unsigned 256-bit value to validate.
//
// Returns:
//   - converted: The same *u256.Uint pointer when value fits in uint128.
//
// Panics if value is nil or exceeds the maximum uint128 value.
func SafeConvertToUint128(value *u256.Uint) *u256.Uint {
	if value.Gt(consts.MaxUint128()) {
		panic(ufmt.Sprintf(
			"%v: amount(%s) overflows uint128 range",
			errLiquidityOverflow, value.ToString()))
	}
	return value
}
