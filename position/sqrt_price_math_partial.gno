package position

func SqrtPriceMathPartialGetAmount0Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	numerator1 := (liquidity) << 96
	numerator2 := sqrtRatioBX96 - sqrtRatioAX96

	require(sqrtRatioAX96 > 0, "sqrt_price_math_partial.gno__SqrtPriceMathPartialGetAmount0Delta__sqrtRatioAX96")

	return (numerator1 * numerator2 / sqrtRatioBX96) / sqrtRatioAX96
}

func SqrtPriceMathPartialGetAmount1Delta(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / Q96
}
