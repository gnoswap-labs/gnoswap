package pool

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
	requireUnsigned(
		sqrtPX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || expected sqrtPX96 must be unsigned, got: %d",
			sqrtPX96,
	))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || expected liquidity must be unsigned, got: %d",
			liquidity,
	))

	requireUnsigned(
		amount,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp() || expected amount must be unsigned, got: %d",
			amount,
	))

	if amount == 0 {
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

	return numerator1 / ((sqrtPX96 / denominator) + amount)
}

func sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) bigint {
	requireUnsigned(
		sqrtPX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || expected sqrtPX96 must be unsigned, got: %d",
			sqrtPX96,
	))

	requireUnsigned(
		amount,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || expected amount must be unsigned, got: %d",
			amount,
	))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown() || expected liquidity must be unsigned, got: %d",
			liquidity,
	))

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
	sqrtPX96 bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(
		sqrtPX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || expected sqrtPX96 must be unsigned, got: %d",
			sqrtPX96,
		))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || expected liquidity must be unsigned, got: %d",
			liquidity,
	))

	requireUnsigned(
		amountIn,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromInput() || expected amountIn must be unsigned, got: %d",
			amountIn,
	))


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
	sqrtPX96 bigint,
	liquidity bigint,
	amountOut bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	requireUnsigned(
		sqrtPX96,
		ufmt.Sprintf("[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || expected sqrtPX96 >= 0, got: %s",
		sqrtPX96,
	))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf("[POOL] sqrt_price_math.gno__sqrtPriceMathGetNextSqrtPriceFromOutput() || expected liquidity >= 0, got: %d",
		liquidity,
	))

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
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(
		sqrtRatioAX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || expected sqrtRatioAX96 must be unsigned, got: %d",
			sqrtRatioAX96,
	))

	requireUnsigned(
		sqrtRatioBX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || expected sqrtRatioBX96 must be unsigned, got: %d",
			sqrtRatioBX96,
	))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount0DeltaHelper() || expected liquidity must be unsigned, got: %d",
			liquidity,
	))

	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := absBigint(liquidity) << 96
	numerator2 := sqrtRatioBX96 - sqrtRatioAX96

	return ((numerator1 * numerator2) / sqrtRatioBX96) / sqrtRatioAX96
}

func sqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(
		sqrtRatioAX96,
		ufmt.Sprintf("[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || expected sqrtRatioAX96 must be unsigned, got: %d",
		sqrtRatioAX96,
	))

	requireUnsigned(
		sqrtRatioBX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || expected sqrtRatioBX96 must be unsigned, got: %d",
			sqrtRatioBX96,
	))

	requireUnsigned(
		liquidity,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount1DeltaHelper() || expected liquidity must be unsigned, got: %d",
			liquidity,
	))

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
	requireUnsigned(
		sqrtRatioAX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount0Delta() || expected sqrtRatioAX96 must be unsigned, got: %d",
			sqrtRatioAX96,
	))

	requireUnsigned(
		sqrtRatioBX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount0Delta() || expected sqrtRatioBX96 must be unsigned, got: %d",
			sqrtRatioBX96,
	))

	if liquidity < 0 {
		return -sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, absBigint(-liquidity))
	}

	return sqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func sqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	requireUnsigned(
		sqrtRatioAX96,
		ufmt.Sprintf("[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount1Delta() || expected sqrtRatioAX96 must be unsigned, got: %d",
		sqrtRatioAX96,
	))

	requireUnsigned(
		sqrtRatioBX96,
		ufmt.Sprintf(
			"[POOL] sqrt_price_math.gno__sqrtPriceMathGetAmount1Delta() || expected sqrtRatioBX96 must be unsigned, got: %d",
			sqrtRatioBX96,
	))

	if liquidity < 0 {
		return -sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, absBigint(-liquidity))
	}

	return sqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}
