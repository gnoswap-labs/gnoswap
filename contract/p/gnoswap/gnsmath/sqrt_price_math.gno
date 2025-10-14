package gnsmath

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"
)

const (
	Q96_RESOLUTION  uint = 96
	Q160_RESOLUTION uint = 160
)

var (
	q96        = u256.Zero().Lsh(u256.One(), 96)                               // 2^96
	max160     = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One()) // 2^160 - 1
	maxInt256  = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 255), u256.One()) // 2^255 - 1
	maxUint128 = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 128), u256.One())

	MIN_SQRT_RATIO = u256.MustFromDecimal("4295128739")
	MAX_SQRT_RATIO = u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")
)

// GetAmount0Delta calculates the token0 amount difference within a price range, returning
// a signed int256 value that is negative when liquidity is negative. Rounds down for
// negative liquidity and up for positive liquidity.
// Panics if any input is nil or if the result overflows int256.
func GetAmount0Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	if sqrtRatioAX96 == nil || sqrtRatioBX96 == nil || liquidity == nil {
		panic(errGetAmount0DeltaNilInput)
	}

	if liquidity.IsNeg() {
		u := getAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(maxInt256) {
			// if u > (2**255 - 1), cannot cast to int256
			panic(errAmount0DeltaOverflow)
		}

		// Convert to i256 and negate properly
		return i256.Zero().Neg(i256.FromUint256(u))
	}

	u := getAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	if u.Gt(maxInt256) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount0DeltaOverflow)
	}

	return i256.FromUint256(u)
}

// GetAmount1Delta calculates the token1 amount difference within a price range, returning
// a signed int256 value that is negative when liquidity is negative. Rounds down for
// negative liquidity and up for positive liquidity.
// Panics if any input is nil or if the result overflows int256.
func GetAmount1Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	if sqrtRatioAX96 == nil || sqrtRatioBX96 == nil || liquidity == nil {
		panic(errGetAmount1DeltaNilInput)
	}

	if liquidity.IsNeg() {
		u := getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(maxInt256) {
			// if u > (2**255 - 1), cannot cast to int256
			panic(errAmount1DeltaOverflow)
		}

		// Convert to i256 and negate properly
		return i256.Zero().Neg(i256.FromUint256(u))
	}

	u := getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	if u.Gt(maxInt256) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount1DeltaOverflow)
	}

	return i256.FromUint256(u)
}

func GetAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint) (string, string) {
	if liquidity.IsZero() {
		return "0", "0"
	}

	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	amount0 := u256.Zero()
	amount1 := u256.Zero()

	if sqrtRatioX96.Lte(sqrtRatioAX96) {
		amount0 = getAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity, true)
	} else if sqrtRatioX96.Lt(sqrtRatioBX96) {
		amount0 = getAmount0DeltaHelper(sqrtRatioX96, sqrtRatioBX96, liquidity, true)
		amount1 = getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioX96, liquidity, true)
	} else {
		amount1 = getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity, true)
	}

	if amount0.Gt(maxInt256) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount1DeltaOverflow)
	}

	if amount1.Gt(maxInt256) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount1DeltaOverflow)
	}

	return amount0.ToString(), amount1.ToString()
}

// GetLiquidityForAmounts calculates the maximum liquidity given the current price (sqrtRatioX96),
// upper and lower price bounds (sqrtRatioAX96 and sqrtRatioBX96), and token amounts (amount0, amount1).
//
// This function evaluates how much liquidity can be obtained for specified amounts of token0 and token1
// within the provided price range. It returns the lesser liquidity based on available token0 or token1
// to ensure the pool remains balanced.
//
// Parameters:
// - sqrtRatioX96: The current price as a square root ratio in Q64.96 format (*u256.Uint).
// - sqrtRatioAX96: The lower bound of the price range as a square root ratio in Q64.96 format (*u256.Uint).
// - sqrtRatioBX96: The upper bound of the price range as a square root ratio in Q64.96 format (*u256.Uint).
// - amount0: The amount of token0 available to provide liquidity (*u256.Uint).
// - amount1: The amount of token1 available to provide liquidity (*u256.Uint).
//
// Returns:
// - *u256.Uint: The maximum possible liquidity that can be minted.
//
// Notes:
//   - The `Clone` method is used to prevent modification of the original values during computation.
//   - The function ensures that liquidity calculations handle edge cases when the current price
//     is outside the specified range by returning liquidity based on the dominant token.
func GetLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1 *u256.Uint) (liquidity *u256.Uint) {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96.Clone(), sqrtRatioBX96.Clone())

	if sqrtRatioX96.Lte(sqrtRatioAX96) {
		liquidity = computeLiquidityForAmount0(sqrtRatioAX96.Clone(), sqrtRatioBX96.Clone(), amount0.Clone())
	} else if sqrtRatioX96.Lt(sqrtRatioBX96) {
		liquidity0 := computeLiquidityForAmount0(sqrtRatioX96.Clone(), sqrtRatioBX96.Clone(), amount0.Clone())
		liquidity1 := computeLiquidityForAmount1(sqrtRatioAX96.Clone(), sqrtRatioX96.Clone(), amount1.Clone())

		if liquidity0.Lt(liquidity1) {
			liquidity = liquidity0
		} else {
			liquidity = liquidity1
		}
	} else {
		liquidity = computeLiquidityForAmount1(sqrtRatioAX96.Clone(), sqrtRatioBX96.Clone(), amount1.Clone())
	}
	return liquidity
}

// AddLiquidityDelta calculates the new liquidity by applying the delta liquidity to the current liquidity.
// If delta liquidity is negative, it subtracts the absolute value of delta liquidity from the current liquidity.
// If delta liquidity is positive, it adds the absolute value of delta liquidity to the current liquidity.
// Returns the new liquidity as a uint256 value.
func AddLiquidityDelta(x *u256.Uint, y *i256.Int) *u256.Uint {
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

		return z
	}

	z := u256.Zero().Add(x, yAbs)
	if z.Lt(x) {
		panic(ufmt.Sprintf(
			"liquidity_math: overflow (x: %s, y: %s, z:%s)",
			x.ToString(), y.ToString(), z.ToString()))
	}

	return z
}

// getNextPriceAmount0Add calculates the next sqrt price when adding token0 liquidity,
// rounding up to ensure conservative pricing for the protocol.
// This internal function handles the case where token0 is being added to the pool.
func getNextPriceAmount0Add(
	currentSqrtPriceX96, liquidity, amountToAdd *u256.Uint,
) *u256.Uint {
	// liquidityShifted = liquidity << 96
	liquidityShifted := u256.Zero().Lsh(liquidity, Q96_RESOLUTION)
	// amountTimesSqrtPrice = amount * sqrtPrice
	amountTimesSqrtPrice := u256.Zero().Mul(amountToAdd, currentSqrtPriceX96)

	// Overflow check: Ensure (amountTimesSqrtPrice / amountToAdd) == currentSqrtPriceX96
	quotientCheck := u256.Zero().Div(amountTimesSqrtPrice, amountToAdd)
	if quotientCheck.Eq(currentSqrtPriceX96) {
		// denominator = liquidityShifted + amountTimesSqrtPrice
		denominator := u256.Zero().Add(liquidityShifted, amountTimesSqrtPrice)
		// only take this path when denominator >= liquidityShifted
		if denominator.Gte(liquidityShifted) {
			return u256.MulDivRoundingUp(liquidityShifted, currentSqrtPriceX96, denominator)
		}
	}

	// fallback: liquidityShifted / ((liquidityShifted / sqrtPrice) + amount)
	divValue := u256.Zero().Div(liquidityShifted, currentSqrtPriceX96)
	denominator := u256.Zero().Add(divValue, amountToAdd)
	return u256.DivRoundingUp(liquidityShifted, denominator)
}

// getNextPriceAmount0Remove calculates the next sqrt price when removing token0 liquidity,
// rounding up to ensure conservative pricing for the protocol.
// This internal function handles the case where token0 is being removed from the pool.
// Panics if validation checks fail (invalid pool sqrt price calculation).
func getNextPriceAmount0Remove(
	currentSqrtPriceX96, liquidity, amountToRemove *u256.Uint,
) *u256.Uint {
	// liquidityShifted = liquidity << 96
	liquidityShifted := u256.Zero().Lsh(liquidity, Q96_RESOLUTION)
	// amountTimesSqrtPrice = amountToRemove * currentSqrtPriceX96
	amountTimesSqrtPrice := u256.Zero().Mul(amountToRemove, currentSqrtPriceX96)

	// Validation checks
	quotientCheck := u256.Zero().Div(amountTimesSqrtPrice, amountToRemove)
	if !quotientCheck.Eq(currentSqrtPriceX96) || !liquidityShifted.Gt(amountTimesSqrtPrice) {
		panic(errInvalidPoolSqrtPrice)
	}

	denominator := u256.Zero().Sub(liquidityShifted, amountTimesSqrtPrice)
	return u256.MulDivRoundingUp(liquidityShifted, currentSqrtPriceX96, denominator)
}

// getNextSqrtPriceFromAmount0RoundingUp calculates the next sqrt price based on token0 amount,
// always rounding up to ensure conservative pricing in both exact output and exact input cases.
// The add parameter determines whether liquidity is being added (true) or removed (false).
func getNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amount *u256.Uint,
	add bool,
) *u256.Uint {
	// Shortcut: if no amount, return original price
	if amount.IsZero() {
		return sqrtPX96
	}

	if add {
		return getNextPriceAmount0Add(sqrtPX96, liquidity, amount)
	}
	return getNextPriceAmount0Remove(sqrtPX96, liquidity, amount)
}

// getNextPriceAmount1Add calculates the next sqrt price when adding token1,
// preserving rounding-down logic for the final result.
// This internal function handles the case where token1 is being added to the pool.
func getNextPriceAmount1Add(
	sqrtPX96, liquidity, amount *u256.Uint,
) *u256.Uint {
	var quotient *u256.Uint

	if amount.Lte(max160) {
		// Use local variables to avoid allocation conflicts
		shifted := u256.Zero().Lsh(amount, Q96_RESOLUTION)
		quotient = u256.Zero().Div(shifted, liquidity)
	} else {
		quotient = u256.MulDiv(amount, q96, liquidity)
	}

	return u256.Zero().Add(sqrtPX96, quotient)
}

// getNextPriceAmount1Remove calculates the next sqrt price when removing token1,
// preserving rounding-down logic for the final result.
// This internal function handles the case where token1 is being removed from the pool.
// Panics if sqrt price would exceed quotient.
func getNextPriceAmount1Remove(
	sqrtPX96, liquidity, amount *u256.Uint,
) *u256.Uint {
	var quotient *u256.Uint

	if amount.Lte(max160) {
		shifted := u256.Zero().Lsh(amount, Q96_RESOLUTION)
		quotient = u256.DivRoundingUp(shifted, liquidity)
	} else {
		quotient = u256.MulDivRoundingUp(amount, q96, liquidity)
	}

	if !sqrtPX96.Gt(quotient) {
		panic(errSqrtPriceExceedsQuotient)
	}

	return u256.Zero().Sub(sqrtPX96, quotient)
}

// getNextSqrtPriceFromAmount1RoundingDown calculates the next sqrt price based on token1 amount,
// always rounding down to ensure conservative pricing in both exact output and exact input cases.
// The add parameter determines whether liquidity is being added (true) or removed (false).
func getNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96,
	liquidity,
	amount *u256.Uint,
	add bool,
) *u256.Uint {
	// Shortcut: if no amount, return original price
	if amount.IsZero() {
		return sqrtPX96
	}

	if add {
		return getNextPriceAmount1Add(sqrtPX96, liquidity, amount)
	}
	return getNextPriceAmount1Remove(sqrtPX96, liquidity, amount)
}

// getNextSqrtPriceFromInput calculates the next sqrt price after adding tokens to the pool,
// rounding up for conservative pricing in both swap directions.
// The zeroForOne parameter indicates swap direction (token0 for token1 when true).
// Panics if sqrtPX96 or liquidity is zero.
func getNextSqrtPriceFromInput(
	sqrtPX96, liquidity, amountIn *u256.Uint,
	zeroForOne bool,
) *u256.Uint {
	if sqrtPX96.IsZero() {
		panic(errSqrtPriceZero)
	}

	if liquidity.IsZero() {
		panic(errLiquidityZero)
	}

	if zeroForOne {
		return getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	}

	return getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

// getNextSqrtPriceFromOutput calculates the next sqrt price after removing tokens from the pool,
// using different rounding directions based on swap direction.
// The zeroForOne parameter indicates swap direction (token0 for token1 when true).
// Panics if sqrtPX96 or liquidity is zero.
func getNextSqrtPriceFromOutput(
	sqrtPX96, liquidity, amountOut *u256.Uint,
	zeroForOne bool,
) *u256.Uint {
	if sqrtPX96.IsZero() {
		panic(errSqrtPriceZero)
	}

	if liquidity.IsZero() {
		panic(errLiquidityZero)
	}

	if zeroForOne {
		return getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	}

	return getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

// getAmount0DeltaHelper calculates the absolute token0 amount difference between two price ranges,
// automatically swapping inputs to ensure correct ordering. The roundUp parameter controls
// rounding direction for the final result to ensure conservative AMM calculations.
// Panics if sqrtRatioAX96 is zero.
func getAmount0DeltaHelper(
	sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint,
	roundUp bool,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	// Use local variables for thread safety
	numerator := u256.Zero().Lsh(liquidity, Q96_RESOLUTION)
	difference := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)

	if sqrtRatioAX96.IsZero() {
		panic(errSqrtRatioAX96Zero)
	}

	if roundUp {
		intermediate := u256.MulDivRoundingUp(numerator, difference, sqrtRatioBX96)
		return u256.DivRoundingUp(intermediate, sqrtRatioAX96)
	}

	intermediate := u256.MulDiv(numerator, difference, sqrtRatioBX96)
	return u256.Zero().Div(intermediate, sqrtRatioAX96)
}

// getAmount1DeltaHelper calculates the absolute token1 amount difference between two price ranges,
// automatically swapping inputs to ensure correct ordering. The roundUp parameter controls
// rounding direction for the final result to ensure conservative AMM calculations.
func getAmount1DeltaHelper(
	sqrtRatioAX96, sqrtRatioBX96, liquidity *u256.Uint,
	roundUp bool,
) *u256.Uint {
	if sqrtRatioAX96.Gt(sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	// amount1 = liquidity * (sqrtB - sqrtA) / 2^96
	// Use local variable for thread safety
	difference := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)

	if roundUp {
		return u256.MulDivRoundingUp(liquidity, difference, q96)
	}

	return u256.MulDiv(liquidity, difference, q96)
}

// computeLiquidityForAmount0 calculates the liquidity for a given amount of token0.
//
// This function computes the maximum possible liquidity that can be provided for `token0`
// based on the provided price boundaries (sqrtRatioAX96 and sqrtRatioBX96) in Q64.96 format.
//
// Parameters:
//   - sqrtRatioAX96: *u256.Uint - The square root price at the lower tick boundary (Q64.96).
//   - sqrtRatioBX96: *u256.Uint - The square root price at the upper tick boundary (Q64.96).
//   - amount0: *u256.Uint - The amount of token0 to be converted to liquidity.
//
// Returns:
//   - *u256.Uint: The calculated liquidity, represented as an unsigned 128-bit integer (uint128).
//
// Panics:
//   - If the resulting liquidity exceeds the uint128 range, `safeConvertToUint128` will trigger a panic.
func computeLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)
	intermediate := u256.MulDiv(sqrtRatioAX96, sqrtRatioBX96, q96)

	diff := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)
	if diff.IsZero() {
		panic(ufmt.Sprintf("sqrtRatioAX96 (%s) and sqrtRatioBX96 (%s) are identical", sqrtRatioAX96.ToString(), sqrtRatioBX96.ToString()))
	}

	res := u256.MulDiv(amount0, intermediate, diff)
	return safeConvertToUint128(res)
}

// computeLiquidityForAmount1 calculates liquidity based on the provided token1 amount and price range.
//
// This function computes the liquidity for a given amount of token1 by using the difference
// between the upper and lower square root price ratios. The calculation uses Q96 fixed-point
// arithmetic to maintain precision.
//
// Parameters:
//   - sqrtRatioAX96: *u256.Uint - The square root ratio of price at the lower tick, represented in Q96 format.
//   - sqrtRatioBX96: *u256.Uint - The square root ratio of price at the upper tick, represented in Q96 format.
//   - amount1: *u256.Uint - The amount of token1 to calculate liquidity for.
//
// Returns:
//   - *u256.Uint: The calculated liquidity based on the provided amount of token1 and price range.
//
// Notes:
//   - The result is not directly limited to uint128, as liquidity values can exceed uint128 bounds.
//   - If `sqrtRatioAX96 == sqrtRatioBX96`, the function will panic due to division by zero.
//   - Q96 is a constant representing `2^96`, ensuring that precision is maintained during division.
//
// Panics:
//   - If the resulting liquidity exceeds the uint128 range, `safeConvertToUint128` will trigger a panic.
func computeLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1 *u256.Uint) *u256.Uint {
	sqrtRatioAX96, sqrtRatioBX96 = toAscendingOrder(sqrtRatioAX96, sqrtRatioBX96)

	diff := u256.Zero().Sub(sqrtRatioBX96, sqrtRatioAX96)
	if diff.IsZero() {
		panic(ufmt.Sprintf("sqrtRatioAX96 (%s) and sqrtRatioBX96 (%s) are identical", sqrtRatioAX96.ToString(), sqrtRatioBX96.ToString()))
	}
	res := u256.MulDiv(amount1, q96, diff)
	return safeConvertToUint128(res)
}

// toAscendingOrder returns the two values in ascending order.
func toAscendingOrder(a, b *u256.Uint) (*u256.Uint, *u256.Uint) {
	if a.Gt(b) {
		return b, a
	}

	return a, b
}

// safeConvertToUint128 safely ensures a *u256.Uint value fits within the uint128 range.
//
// This function verifies that the provided unsigned 256-bit integer does not exceed the maximum value for uint128 (`2^128 - 1`).
// If the value is within the uint128 range, it is returned as is; otherwise, the function triggers a panic.
//
// Parameters:
// - value (*u256.Uint): The unsigned 256-bit integer to be checked.
//
// Returns:
// - *u256.Uint: The same value if it is within the uint128 range.
//
// Panics:
//   - If the value exceeds the maximum uint128 value (`2^128 - 1`), the function will panic with a descriptive error
//     indicating the overflow and the original value.
//
// Notes:
// - The constant `MAX_UINT128` is defined as `340282366920938463463374607431768211455` (the largest uint128 value).
// - No actual conversion occurs since the function works directly with *u256.Uint types.
//
// Example:
// validUint128 := safeConvertToUint128(u256.MustFromDecimal("340282366920938463463374607431768211455")) // Valid
// safeConvertToUint128(u256.MustFromDecimal("340282366920938463463374607431768211456")) // Panics due to overflow
func safeConvertToUint128(value *u256.Uint) *u256.Uint {
	if value.Gt(maxUint128) {
		panic(ufmt.Sprintf("amount(%s) overflows uint128 range", value.ToString()))
	}
	return value
}
