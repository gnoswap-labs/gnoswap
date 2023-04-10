package gnoswap


func SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtPrice bigdec,
	liquidity bigdec,
	amount bigdec,
	add bool,
) (bigdec) {
	if (amount == 0) {
		return sqrtPrice
	}

	var numerator1 bigdec = liquidity
	var denominator bigdec
	var product bigdec = amount * sqrtPrice
	
	if add {
		if product / amount == sqrtPrice {
			denominator = numerator1 + product

			if denominator >= numerator1 {
				return numerator1 * sqrtPrice / denominator
			}

			return numerator1 / ((numerator1 / sqrtPrice) + amount)
		} else {
			require(product / amount == sqrtPrice && numerator1 > product, "NOPE#25")
			denominator = numerator1 - product
			return numerator1 * sqrtPrice / denominator
		}
	}
}

func SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPrice bigdec,
	liquidity bigdec,
	amount bigdec,
	add bool,
) (bigdec) {
	var quotient bigdec = amount / liquidity

	if add {
		return sqrtPrice + quotient
	} else {
		require(sqrtPrice > quotient, "NOPE#46")
		return sqrtPrice - quotient
	}

}

func SqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPrice bigdec,
	liquidity bigdec,
	amountIn bigdec,
	zeroForOne bool,
) (sqrtQ bigdec) {
	require(sqrtPrice > 0, "NOPE#58")
	require(liquidity > 0, "NOPE#59")

	if zeroForOne {
		return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountIn, true)
	} 

	return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountIn, true)
}

func SqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPrice bigdec,
	liquidity bigdec,
	amountOut bigdec,
	zeroForOne bool,
) (sqrtQ bigdec) {
	require(sqrtPrice > 0, "NOPE#58")
	require(liquidity > 0, "NOPE#59")

	if zeroForOne {
		return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountOut, false)
	} 

	return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountOut, false)
}

func SqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioA bigdec,
	sqrtRatioB bigdec,
	liquidity bigdec,
) (amount0 bigdec) {
	if (sqrtRatioA > sqrtRatioB) {
		tempValue := sqrtRatioA
		sqrtRatioA = sqrtRatioB
		sqrtRatioB = tempValue
	}

	var numerator1 bigdec = liquidity
	var numerator2 bigdec = sqrtRatioB - sqrtRatioA

	require(sqrtRatioA > 0, "NOPE#98")
	return ((numerator1 * numerator2) / (sqrtRatioB) / sqrtRatioA)
}

func SqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioA bigdec,
	sqrtRatioB bigdec,
	liquidity bigdec,
) (amount1 bigdec) {
	if (sqrtRatioA > sqrtRatioB) {
		tempValue := sqrtRatioA
		sqrtRatioA = sqrtRatioB
		sqrtRatioB = tempValue
	}

	return liquidity * (sqrtRatioB - sqrtRatioA)
}

func SqrtPriceMathGetAmount0Delta(
	sqrtRatioAX96 bigdec,
	sqrtRatioBX96 bigdec,
	liquidity bigdec,
) (amount0 bigdec) {
	if liquidity < 0 {
		return -(SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity))
	} 
	
	return SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}

func SqrtPriceMathGetAmount1Delta(
	sqrtRatioAX96 bigdec,
	sqrtRatioBX96 bigdec,
	liquidity bigdec,
) (amount1 bigdec) {
	if liquidity < 0 {
		return -(SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, -liquidity))
	}

	return SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioAX96, sqrtRatioBX96, liquidity)
}