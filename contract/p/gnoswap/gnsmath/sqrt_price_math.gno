package gnsmath

import (
	"gno.land/p/gnoswap/consts"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// MIN_SQRT_RATIO returns the minimum valid Q64.96 square-root price ratio.
//
// Returns:
//   - minSqrtRatio: A fresh *u256.Uint containing 4,295,128,739, the lower
//     boundary accepted by the pool's square-root price math.
func MIN_SQRT_RATIO() *u256.Uint { return consts.MinSqrtRatio() }

// MAX_SQRT_RATIO returns the upper boundary used by Q64.96 square-root price math.
//
// Returns:
//   - maxSqrtRatio: A fresh *u256.Uint containing
//     1461446703485210103287273052203988822378723970342. Inverse tick conversion
//     treats this boundary as exclusive.
func MAX_SQRT_RATIO() *u256.Uint { return consts.MaxSqrtRatio() }

// getNextPriceAmount0Add computes the next Q64.96 square-root price after adding token0.
// It uses conservative rounding and a fallback formula when the token0-price product overflows.
//
// Parameters:
//   - currentSqrtPriceX96: Current pool square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used in the price update.
//   - amountToAdd: Raw token0 amount being added to the pool.
//
// Returns:
//   - nextSqrtPriceX96: Updated square-root price, rounded up for conservative pricing.
//
// Panics if the fallback denominator overflows or the arithmetic cannot produce a valid price.
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
	denominator, overflow := u256.Zero().AddOverflow(divValue, amountToAdd)
	if overflow {
		panic(errSafeMathOverflow)
	}
	return u256.DivRoundingUp(liquidityShifted, denominator)
}

// getNextPriceAmount0Remove computes the next Q64.96 square-root price after removing token0.
// The subtraction requires the shifted liquidity to remain strictly greater than the
// token0-price product so the resulting denominator is positive.
//
// Parameters:
//   - currentSqrtPriceX96: Current pool square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used in the price update.
//   - amountToRemove: Raw token0 amount being removed from the pool.
//
// Returns:
//   - nextSqrtPriceX96: Updated square-root price, rounded up for conservative pricing.
//
// Panics if the product quotient does not recover the current price or the denominator
// would be non-positive.
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

// getNextSqrtPriceFromAmount0RoundingUp computes the next price for a token0 amount.
// A zero amount returns the input price; otherwise the add flag selects the add or
// remove formula and the result is rounded up.
//
// Parameters:
//   - sqrtPX96: Current square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used by the formula.
//   - amount: Raw token0 amount to add or remove.
//   - add: True to add token0 (price decreases); false to remove token0 (price increases).
//
// Returns:
//   - nextSqrtPriceX96: Updated Q64.96 square-root price, or sqrtPX96 when amount is zero.
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

// getNextPriceAmount1Add computes the next Q64.96 square-root price after adding token1.
// It rounds the quotient down and rejects results above the uint160 price bound.
//
// Parameters:
//   - sqrtPX96: Current square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used as the quotient divisor.
//   - amount: Raw token1 amount being added to the pool.
//
// Returns:
//   - nextSqrtPriceX96: Updated square-root price after adding amount / liquidity in Q96 units.
//
// Panics if the updated price overflows uint160.
func getNextPriceAmount1Add(
	sqrtPX96, liquidity, amount *u256.Uint,
) *u256.Uint {
	var quotient *u256.Uint

	if amount.Lte(consts.Max160()) {
		// Use local variables to avoid allocation conflicts
		shifted := u256.Zero().Lsh(amount, Q96_RESOLUTION)
		quotient = u256.Zero().Div(shifted, liquidity)
	} else {
		quotient = u256.MulDiv(amount, consts.Q96(), liquidity)
	}

	result, overflow := u256.Zero().AddOverflow(sqrtPX96, quotient)
	if overflow || result.Gt(consts.Max160()) {
		panic(errSqrtPriceOverflow)
	}

	return result
}

// getNextPriceAmount1Remove computes the next Q64.96 square-root price after removing token1.
// The quotient is rounded up and must be strictly less than the current price.
//
// Parameters:
//   - sqrtPX96: Current square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used as the quotient divisor.
//   - amount: Raw token1 amount being removed from the pool.
//
// Returns:
//   - nextSqrtPriceX96: Updated square-root price after subtracting the rounded quotient.
//
// Panics if the rounded quotient is greater than or equal to sqrtPX96.
func getNextPriceAmount1Remove(
	sqrtPX96, liquidity, amount *u256.Uint,
) *u256.Uint {
	var quotient *u256.Uint

	if amount.Lte(consts.Max160()) {
		shifted := u256.Zero().Lsh(amount, Q96_RESOLUTION)
		quotient = u256.DivRoundingUp(shifted, liquidity)
	} else {
		quotient = u256.MulDivRoundingUp(amount, consts.Q96(), liquidity)
	}

	if !sqrtPX96.Gt(quotient) {
		panic(errSqrtPriceExceedsQuotient)
	}

	return u256.Zero().Sub(sqrtPX96, quotient)
}

// getNextSqrtPriceFromAmount1RoundingDown computes the next price for a token1 amount.
// A zero amount returns the input price; otherwise the add flag selects the add or
// remove formula and the result uses the token1 rounding direction.
//
// Parameters:
//   - sqrtPX96: Current square-root price in Q64.96 format.
//   - liquidity: Active non-negative liquidity used by the formula.
//   - amount: Raw token1 amount to add or remove.
//   - add: True to add token1 (price increases); false to remove token1 (price decreases).
//
// Returns:
//   - nextSqrtPriceX96: Updated Q64.96 square-root price, or sqrtPX96 when amount is zero.
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

// getNextSqrtPriceFromInput computes the next price after an exact input amount.
// It selects the token0 or token1 update from zeroForOne and applies the corresponding
// conservative rounding direction.
//
// Parameters:
//   - sqrtPX96: Current non-zero square-root price in Q64.96 format.
//   - liquidity: Current non-zero active liquidity.
//   - amountIn: Raw amount of the input token added to the pool.
//   - zeroForOne: True for token0-to-token1 swaps; false for token1-to-token0 swaps.
//
// Returns:
//   - nextSqrtPriceX96: Square-root price after applying amountIn to the selected swap direction.
//
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

// getNextSqrtPriceFromOutput computes the next price needed for an exact output amount.
// It selects the token1 or token0 removal formula from zeroForOne and applies the
// corresponding conservative rounding direction.
//
// Parameters:
//   - sqrtPX96: Current non-zero square-root price in Q64.96 format.
//   - liquidity: Current non-zero active liquidity.
//   - amountOut: Raw amount of the output token removed from the pool.
//   - zeroForOne: True for token0-to-token1 swaps; false for token1-to-token0 swaps.
//
// Returns:
//   - nextSqrtPriceX96: Square-root price after accounting for amountOut in the selected direction.
//
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

// getAmount0DeltaHelper computes the absolute token0 amount represented between two prices.
// The bounds are ordered internally, and roundUp selects the final conservative rounding.
//
// Parameters:
//   - sqrtRatioAX96: First price endpoint in Q64.96 square-root format.
//   - sqrtRatioBX96: Second price endpoint in Q64.96 square-root format.
//   - liquidity: Non-negative liquidity represented over the range.
//   - roundUp: True to round the amount up; false to round it down.
//
// Returns:
//   - amount0: Absolute token0 amount for the ordered range and liquidity.
//
// Panics if the lower ordered endpoint is zero.
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

// getAmount1DeltaHelper computes the absolute token1 amount represented between two prices.
// The bounds are ordered internally, and roundUp selects whether the quotient is rounded up.
//
// Parameters:
//   - sqrtRatioAX96: First price endpoint in Q64.96 square-root format.
//   - sqrtRatioBX96: Second price endpoint in Q64.96 square-root format.
//   - liquidity: Non-negative liquidity represented over the range.
//   - roundUp: True to round the amount up; false to round it down.
//
// Returns:
//   - amount1: Absolute token1 amount equal to liquidity times the Q96 price difference.
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
		return u256.MulDivRoundingUp(liquidity, difference, consts.Q96())
	}

	return u256.MulDiv(liquidity, difference, consts.Q96())
}

// GetAmount0Delta computes the signed token0 amount represented between two prices.
// Positive liquidity rounds the amount up; negative liquidity returns a negative amount
// rounded down after applying the magnitude.
//
// Parameters:
//   - sqrtRatioAX96: First price endpoint in Q64.96 square-root format.
//   - sqrtRatioBX96: Second price endpoint in Q64.96 square-root format.
//   - liquidity: Signed liquidity value; its sign determines the result sign and rounding.
//
// Returns:
//   - amount0Delta: Signed int256 token0 amount represented by the range.
//
// Panics if an input is nil or the computed magnitude cannot be represented by int256.
func GetAmount0Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	if sqrtRatioAX96 == nil || sqrtRatioBX96 == nil || liquidity == nil {
		panic(errGetAmount0DeltaNilInput)
	}

	if liquidity.IsNeg() {
		u := getAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(consts.MaxInt256()) {
			// if u > (2**255 - 1), cannot cast to int256
			panic(errAmount0DeltaOverflow)
		}

		// Convert to i256 and negate properly
		return i256.Zero().Neg(i256.FromUint256(u))
	}

	u := getAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	if u.Gt(consts.MaxInt256()) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount0DeltaOverflow)
	}

	return i256.FromUint256(u)
}

// GetAmount1Delta computes the signed token1 amount represented between two prices.
// Positive liquidity rounds the amount up; negative liquidity returns a negative amount
// rounded down after applying the magnitude.
//
// Parameters:
//   - sqrtRatioAX96: First price endpoint in Q64.96 square-root format.
//   - sqrtRatioBX96: Second price endpoint in Q64.96 square-root format.
//   - liquidity: Signed liquidity value; its sign determines the result sign and rounding.
//
// Returns:
//   - amount1Delta: Signed int256 token1 amount represented by the range.
//
// Panics if an input is nil or the computed magnitude cannot be represented by int256.
func GetAmount1Delta(
	sqrtRatioAX96, sqrtRatioBX96 *u256.Uint,
	liquidity *i256.Int,
) *i256.Int {
	if sqrtRatioAX96 == nil || sqrtRatioBX96 == nil || liquidity == nil {
		panic(errGetAmount1DeltaNilInput)
	}

	if liquidity.IsNeg() {
		u := getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), false)
		if u.Gt(consts.MaxInt256()) {
			// if u > (2**255 - 1), cannot cast to int256
			panic(errAmount1DeltaOverflow)
		}

		// Convert to i256 and negate properly
		return i256.Zero().Neg(i256.FromUint256(u))
	}

	u := getAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity.Abs(), true)
	if u.Gt(consts.MaxInt256()) {
		// if u > (2**255 - 1), cannot cast to int256
		panic(errAmount1DeltaOverflow)
	}

	return i256.FromUint256(u)
}
