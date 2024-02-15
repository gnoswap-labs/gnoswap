package position

import (
	"gno.land/p/demo/ufmt"
	"gno.land/r/demo/consts"
)

func sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) bigint {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || sqrtPX96(%s) >= 0", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || liquidity(%s) >= 0", liquidity))
	requireUnsigned(amount, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || amount(%s) >= 0", amount))
	if amount == 0 {
		return sqrtPX96
	}

	numerator1 := liquidity << 96
	requireUnsigned(numerator1, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1(%s) >= 0", numerator1))

	product := amount * sqrtPX96
	requireUnsigned(product, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || product(%s) >= 0", product))

	var denominator bigint

	if add {
		if product/amount == sqrtPX96 {
			denominator = numerator1 + product
			requireUnsigned(denominator, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || denominator(%s) >= 0", denominator))

			if denominator >= numerator1 {
				requireUnsigned(numerator1*sqrtPX96/denominator, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 * sqrtPX96 / denominator(%s) >= 0", numerator1*sqrtPX96/denominator))
				return numerator1 * sqrtPX96 / denominator
			}
		}

		requireUnsigned(numerator1/((numerator1/sqrtPX96)+amount), ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 / ( (numerator1 / sqrtPX96) + amount(%s) >= 0", (numerator1/((numerator1/sqrtPX96)+amount))))
		return numerator1 / ((numerator1 / sqrtPX96) + amount)
	}
	require(product/amount == sqrtPX96 && numerator1 > product, "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || condition must return true")

	denominator = numerator1 - product
	requireUnsigned(denominator, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || denominator(%s) >= 0", denominator))

	requireUnsigned(numerator1*sqrtPX96/denominator, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || numerator1 * sqrtPX96 / denominator(%s) >= 0", numerator1*sqrtPX96/denominator))
	return numerator1 * sqrtPX96 / denominator
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) bigint {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || sqrtPX96(%s) >= 0", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || liquidity(%s) >= 0", liquidity))
	requireUnsigned(amount, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || amount(%s) >= 0", amount))

	var quotient bigint
	if add {
		if amount <= consts.MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * consts.Q96 / liquidity
		}
		requireUnsigned(quotient, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || quotient(%s) >= 0", quotient))
		return sqrtPX96 + quotient
	} else {
		if amount <= consts.MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * consts.Q96 / liquidity
		}
		requireUnsigned(quotient, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || quotient(%s) >= 0", quotient))

		require(sqrtPX96 > quotient, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || sqrtPX96(%s) must be greater than quotient(%s)", sqrtPX96, quotient))
		return sqrtPX96 - quotient
	}
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || sqrtPX96(%s) >= 0", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || liquidity(%s) >= 0", liquidity))
	requireUnsigned(amountIn, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || amountIn(%s) >= 0", amountIn))

	if zeroForOne {
		requireUnsigned(sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true), "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || condition must return `v` >= 0__#1")
		return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	}

	requireUnsigned(sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true), "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || condition must return `v` >= 0__#2")
	return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountOut bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(sqrtPX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || sqrtPX96(%s) >= 0", sqrtPX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || liquidity(%s) >= 0", liquidity))

	if zeroForOne {
		requireUnsigned(sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false), "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || condition must return `v` >= 0__#1")
		return sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	}

	requireUnsigned(sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false), "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || condition must return `v` >= 0__#2")
	return sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioAX96(%s) >= 0", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioBX96(%s) >= 0", sqrtRatioBX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || liquidity(%s) >= 0", liquidity))

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || sqrtRatioAX96(%s) >= 0", sqrtRatioAX96))

	numerator1 := liquidity << 96
	requireUnsigned(numerator1, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || numerator1(%s) >= 0", numerator1))

	numerator2 := sqrtRatioBX96 - sqrtRatioAX96
	requireUnsigned(numerator2, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || numerator2(%s) >= 0", numerator2))

	requireUnsigned((numerator1*numerator2/sqrtRatioBX96)/sqrtRatioAX96, "[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || condition must return `v` >= 0")
	return (numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || sqrtRatioAX96(%s) >= 0", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || sqrtRatioBX96(%s) >= 0", sqrtRatioBX96))
	requireUnsigned(liquidity, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || liquidity(%s) >= 0", liquidity))

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / consts.Q96
}

func sqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0Delta() || sqrtRatioAX96(%s) >= 0", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount0Delta() || sqrtRatioBX96(%s) >= 0", sqrtRatioBX96))

	if liquidity < 0 {
		return -sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity)
	}

	return sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(sqrtRatioAX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount1Delta() || sqrtRatioAX96(%s) >= 0", sqrtRatioAX96))
	requireUnsigned(sqrtRatioBX96, ufmt.Sprintf("[POSITION] sqrt_price_math.gno__sqrtPriceMathGetAmount1Delta() || sqrtRatioBX96(%s) >= 0", sqrtRatioBX96))

	if liquidity < 0 {
		return -sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity)
	}

	return sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func requireUnsigned(x bigint, msg string) {
	if x < 0 {
		panic(msg)
	}
}
