package gnoswap

func SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	isUnsigned(sqrtPX96, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__sqrtPX96")
	isUnsigned(liquidity, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__liquidity")
	isUnsigned(amount, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__amount")
	if (amount == 0) {
		return sqrtPX96
	}

	numerator1 := liquidity << 96
	isUnsigned(numerator1, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__numerator1")

	product := amount * sqrtPX96
	isUnsigned(product, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__product")

	var denominator bigint
	
	if add {
		if product / amount == sqrtPX96 {
			denominator = numerator1 + product
			isUnsigned(denominator, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__denominator")

			if denominator >= numerator1 {
				isUnsigned(numerator1 * sqrtPX96 / denominator, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__numerator1 * sqrtPX96 / denominator")
				return numerator1 * sqrtPX96 / denominator
			}
		}
		
		isUnsigned(numerator1 / ( (numerator1 / sqrtPX96) + amount ), "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__numerator1 / ( (numerator1 / sqrtPX96) + amount ")
		return numerator1 / ( (numerator1 / sqrtPX96) + amount )
	}	
	require(product / amount == sqrtPX96 && numerator1 > product, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__COND")

	denominator = numerator1 - product
	isUnsigned(denominator, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__denominator")

	isUnsigned(numerator1 * sqrtPX96 / denominator, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp__numerator1 * sqrtPX96 / denominator")
	return numerator1 * sqrtPX96 / denominator
}

func SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPX96 bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	isUnsigned(sqrtPX96, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown__sqrtPX96")
	isUnsigned(liquidity, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown__liquidity")
	isUnsigned(amount, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown__amount")


	var quotient bigint
	if add {
		if amount <= MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * Q96 / liquidity
		}
		isUnsigned(quotient, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown__quotient")
		return sqrtPX96 + quotient
	} else {
		if amount <= MAX_UINT160 {
			quotient = (amount << 96) / liquidity
		} else {
			quotient = amount * Q96 / liquidity
		}
		isUnsigned(quotient, "sqrt_price_math.gno__SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown__quotient")

		require(sqrtPX96 > quotient, "SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")
		return sqrtPX96 - quotient
	}
}

func SqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	require(sqrtPX96 > 0, "SqrtPriceMathGetNextSqrtPriceFromInput sqrtPX96 > 0")
	require(liquidity > 0, "SqrtPriceMathGetNextSqrtPriceFromInput liquidity > 0")
	isUnsigned(amountIn, "SqrtPriceMathGetNextSqrtPriceFromInput amountIn")

	if zeroForOne {
		isUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true), "SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true")
		return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
	} 

	isUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true), "SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true")
	return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true)
}

func SqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPX96 bigint,
	liquidity bigint,
	amountOut bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	require(sqrtPX96 > 0, "SqrtPriceMathGetNextSqrtPriceFromInput sqrtPX96 > 0")
	require(liquidity > 0, "SqrtPriceMathGetNextSqrtPriceFromInput liquidity > 0")
	isUnsigned(amountOut, "SqrtPriceMathGetNextSqrtPriceFromInput amountOut")

	if zeroForOne {
		isUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false), "SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false")
		return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
	} 

	isUnsigned(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false), "SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false")
	return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false)
}

func SqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
	roundUp bool,
) (bigint) {
	isUnsigned(sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__sqrtRatioAX96")
	isUnsigned(sqrtRatioBX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__sqrtRatioBX96")
	isUnsigned(liquidity, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__liquidity")

	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := liquidity << 96
	isUnsigned(numerator1, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__numerator1")
	numerator2 := sqrtRatioBX96 - sqrtRatioAX96
	isUnsigned(numerator2, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__numerator2")

	require(sqrtRatioAX96 > 0, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__sqrtRatioAX96")

	// XXX remove roundUp??
	if roundUp {
		isUnsigned((numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__(numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96")
		return (numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96
	}

	isUnsigned((numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0DeltaHelper__(numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96")
	return (numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96
}

func SqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
	roundUp bool,
) (bigint) {
	isUnsigned(sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper__sqrtRatioAX96")
	isUnsigned(sqrtRatioBX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper__sqrtRatioBX96")
	isUnsigned(liquidity, "sqrt_price_math.gno__SqrtPriceMathGetAmount1DeltaHelper__liquidity")

	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}


	// XXX remove roundUp?
	if roundUp {
		return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / Q96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / Q96
}

func SqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) (bigint) {
	isUnsigned(sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0Delta__sqrtRatioAX96")
	isUnsigned(sqrtRatioBX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount0Delta__sqrtRatioBX96")
	
	if liquidity < 0 {
		return -SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
	} 
	
	return SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity, true)
}

func SqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) (bigint) {
	isUnsigned(sqrtRatioAX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount1Delta__sqrtRatioAX96")
	isUnsigned(sqrtRatioBX96, "sqrt_price_math.gno__SqrtPriceMathGetAmount1Delta__sqrtRatioBX96")
	
	if liquidity < 0 {
		return -SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity, false)
	}

	return SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity, true)
}