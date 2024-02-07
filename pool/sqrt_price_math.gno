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
) bigint {
	if amount.IsZero() {
		return sqrtPX96
	}

	numerator1 := liquidity << 96
	product := amount * sqrtPX96

	if add {
		denominator := numerator1 + product

		require(
			denominator != 0,
			ufmt.Sprintf(
				"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || expected denominator != 0, got: %d",
				denominator,
			))

		return numerator1 * sqrtPX96 / denominator
	}

	denominator := numerator1 - product

	requireUnsigned(
		denominator,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || expected denominator >= 0, got: %d",
			denominator,
		))

	return numerator1 / ((numerator1 / sqrtPX96) + amount)
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amount *u256.Uint,
	add bool,
) bigint {
	var quotient bigint
	if amount <= consts.MAX_UINT160 {
		quotient = (amount << 96) / liquidity
	} else {
		quotient = amount * (consts.Q96 / liquidity)
	}

	// quotient mutst be positive when amount and liquidity are positive

	if add {
		result := sqrtPX96 + quotient

		require(
			result >= sqrtPX96,
			ufmt.Sprintf(
				"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || expected result >= sqrtPX96, got: %d",
				result,
			),
		)

		return result
	}

	result := sqrtPX96 - quotient

	require(
		result >= 0,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || expected sqrtPX96 >= quotient, got: %d, %d",
			sqrtPX96,
			quotient,
		),
	)

	return result
}

func sqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountIn *u256.Uint,
	zeroForOne bool,
) (sqrtQ bigint) {
	if zeroForOne {
		amount0Result := sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
		requireUnsigned(
			amount0Result,
			ufmt.Sprintf(
				"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() #1 || expected unsigned result, got: %d",
				amount0Result,
			),
		)

		return amount0Result
	}

	amount1Result := sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
	requireUnsigned(
		amount1Result,
		"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || condition must return `v` >= 0__#2",
	)

	return amount1Result
}

func sqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 *u256.Uint,
	liquidity *u256.Uint,
	amountOut *u256.Int,
	zeroForOne bool,
) (sqrtQ bigint) {
	if zeroForOne {
		amount1Result := sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
		requireUnsigned(
			amount1Result,
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || condition must return `v` >= 0__#1",
		)

		return amount1Result
	}

	amount0Result := sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
	requireUnsigned(
		amount0Result,
		"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || condition must return `v` >= 0__#2",
	)

	return amount0Result
}

func sqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := absBigint(liquidity) << 96
	numerator2 := sqrtRatioBX96 - sqrtRatioAX96

	return ((numerator1 * numerator2) / sqrtRatioBX96) / sqrtRatioAX96
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Uint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / consts.Q96
}

func sqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Int,
) u256.Int {
	if liquidity.IsNegative() {
		return -sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, absBigint(-liquidity))
	}

	return sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 *u256.Uint,
	sqrtRatioBX96 *u256.Uint,
	liquidity *u256.Int,
) bigint {
	if liquidity.IsNegative() {
		return -sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, absBigint(-liquidity))
	}

	return sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}
