package gnoswap

import "gno.land/p/demo/ufmt"

func SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) bigint {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || sqrtPX96(%s) must be positive", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(amount, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || amount(%s) must be positive", amount))
	if amount == 0 {
		return sqrtPX96
	}

	numerator1 := liquidity << 96
	requireUnsigned(numerator1, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1(%s) must be positive", numerator1))

	product := amount * sqrtPX96
	requireUnsigned(product, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || product(%s) must be positive", product))

	var denominator bigint

	if add {
		if product/amount == sqrtPX96 {
			denominator = numerator1 + product
			requireUnsigned(denominator, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || denominator(%s) must be positive", denominator))

			if denominator >= numerator1 {
				requireUnsigned(numerator1*sqrtPX96/denominator, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 * sqrtPX96 / denominator(%s) must be positive", numerator1*sqrtPX96/denominator))
				return numerator1 * sqrtPX96 / denominator
			}
		}

		requireUnsigned(numerator1/((numerator1/sqrtPX96)+amount), ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 / ( (numerator1 / sqrtPX96) + amount(%s) must be positive", (numerator1/((numerator1/sqrtPX96)+amount))))
		return numerator1 / ((numerator1 / sqrtPX96) + amount)
	}
	require(product/amount == sqrtPX96 && numerator1 > product, "[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || condition must return true")

	denominator = numerator1 - product
	requireUnsigned(denominator, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || denominator(%s) must be positive", denominator))

	requireUnsigned(numerator1*sqrtPX96/denominator, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 * sqrtPX96 / denominator(%s) must be positive", numerator1*sqrtPX96/denominator))
	return numerator1 * sqrtPX96 / denominator
}

func SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) bigint {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || sqrtPX96(%s) must be positive", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(amount, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || amount(%s) must be positive", amount))

	var quotient bigint
	if add {
		if amount <= MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * Q96 / liquidity
		}
		requireUnsigned(quotient, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || quotient(%s) must be positive", quotient))
		return sqrtPX96 + quotient
	} else {
		if amount <= MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * Q96 / liquidity
		}
		requireUnsigned(quotient, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || quotient(%s) must be positive", quotient))

		require(sqrtPX96 > quotient, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || sqrtPX96(%s) must be greater than quotient(%s)", sqrtPX96, quotient))
		return sqrtPX96 - quotient
	}
}

func SqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromInput() || sqrtPX96(%s) must be positive", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromInput() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(amountIn, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromInput() || amountIn(%s) must be positive", amountIn))

	if zeroForOne {
		requireUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true), "[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromInput() || condition must be positive #1")
		return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	}

	requireUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true), "[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromInput() || condition must be positive #2")
	return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

func SqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountOut bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromOutput() || sqrtPX96(%s) must be positive", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromOutput() || liquidity(%s) must be positive", liquidity))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromOutput() || liquidity(%s) must be positive", liquidity))

	if zeroForOne {
		requireUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false), "[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromOutput() || condition must be positive #1")
		return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	}

	requireUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false), "[POOL] sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromOutput() || condition must be positive #2")
	return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

func SqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioAX96(%s) must be positive", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioBX96(%s) must be positive", sqrtRatioBX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || liquidity(%s) must be positive", liquidity))

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioAX96(%s) must be positive", sqrtRatioAX96))

	numerator1 := liquidity << 96
	requireUnsigned(numerator1, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || numerator1(%s) must be positive", numerator1))

	numerator2 := sqrtRatioBX96 - sqrtRatioAX96
	requireUnsigned(numerator2, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || numerator2(%s) must be positive", numerator2))

	requireUnsigned((numerator1*numerator2/sqrtRatioBX96)/sqrtRatioAX96, "[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper() || condition must be positive")
	return (numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96
}

func SqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper() || sqrtRatioAX96(%s) must be positive", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper() || sqrtRatioBX96(%s) must be positive", sqrtRatioBX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper() || liquidity(%s) must be positive", liquidity))

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / Q96
}

func SqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0Delta() || sqrtRatioAX96(%s) must be positive", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount0Delta() || sqrtRatioBX96(%s) must be positive", sqrtRatioBX96))

	if liquidity < 0 {
		return -SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity)
	}

	return SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func SqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount1Delta() || sqrtRatioAX96(%s) must be positive", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POOL] sqrt_price_math.gno__SqrtPriceMathGetAmount1Delta() || sqrtRatioBX96(%s) must be positive", sqrtRatioBX96))

	if liquidity < 0 {
		return -SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity)
	}

	return SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}
