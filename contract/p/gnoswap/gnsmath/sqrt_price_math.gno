package gnsmath

import (
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

const (
	Q96_RESOLUTION  uint = 96
	Q160_RESOLUTION uint = 160
)

var (
	q96       = u256.Zero().Lsh(u256.One(), 96)                               // 2^96
	max160    = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 160), u256.One()) // 2^160 - 1
	maxInt256 = u256.Zero().Sub(u256.Zero().Lsh(u256.One(), 255), u256.One()) // 2^255 - 1

	MIN_SQRT_RATIO = u256.MustFromDecimal("4295128739")
	MAX_SQRT_RATIO = u256.MustFromDecimal("1461446703485210103287273052203988822378723970342")
)

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
