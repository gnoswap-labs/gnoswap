package gnoswap

func SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtP bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	if (amount == 0) {
		return sqrtP
	}

	numerator1 := liquidity

	var denominator bigint
	product := amount * sqrtP
	
	if add {
		if product / amount == sqrtP {
			denominator = numerator1 + product

			if denominator >= numerator1 {
				/// XXX round ?
				return numerator1 * sqrtP / denominator
			}
		}

		// XXX round ?
		return numerator1 / ((numerator1 / sqrtP) + amount)
	}	
	require(product / amount == sqrtP && numerator1 > product, "SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
	denominator = numerator1 - product
	return numerator1 * sqrtP / denominator
}

func SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPrice bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	quotient := amount / liquidity

	if add {
		return quotient
	} else {
		require(sqrtPrice > quotient, "sqrtPrice > quotient")
		return sqrtPrice - quotient
	}

}

func SqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPrice bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	require(sqrtPrice > 0, "sqrtPrice > 0")
	require(liquidity > 0, "liquidity > 0")

	if zeroForOne {
		return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountIn, true)
	} 

	return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountIn, true)
}

func SqrtPriceMathGetNextSqrtPriceFromOutput(
	sqrtPrice bigint,
	liquidity bigint,
	amountOut bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	require(sqrtPrice > 0, "sqrtPrice > 0")
	require(liquidity > 0, "liquidity > 0")

	if zeroForOne {
		return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountOut, false)
	} 

	return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountOut, false)
}

func SqrtPriceMathGetAmount0DeltaHelper(
	sqrtRatioA bigint,
	sqrtRatioB bigint,
	liquidity bigint,
	roundUp bool,
) (bigint) {
	if (sqrtRatioA > sqrtRatioB) {
		tempValue := sqrtRatioA
		sqrtRatioA = sqrtRatioB
		sqrtRatioB = tempValue
	}

	numerator1 := liquidity
	numerator2 := sqrtRatioB - sqrtRatioA

	require(sqrtRatioA > 0, "[X] sqrtRatioA > 0")

	if roundUp {
		return (numerator1 * numerator2 / sqrtRatioB) / sqrtRatioA
		// return liquidity / sqrtRatioA - liquidity / sqrtRatioB
	}

	return ((numerator1 * numerator2) / sqrtRatioB) / sqrtRatioA
}

func SqrtPriceMathGetAmount1DeltaHelper(
	sqrtRatioA bigint,
	sqrtRatioB bigint,
	liquidity bigint,
	roundUp bool,
) (bigint) {
	if (sqrtRatioA > sqrtRatioB) {
		tempValue := sqrtRatioA
		sqrtRatioA = sqrtRatioB
		sqrtRatioB = tempValue
	}

	if roundUp {
		return liquidity * (sqrtRatioB - sqrtRatioA)
	}

	return liquidity * (sqrtRatioB - sqrtRatioA)
}

func SqrtPriceMathGetAmount0Delta(
	sqrtRatioA bigint,
	sqrtRatioB bigint,
	liquidity bigint,
) (bigint) {
	if liquidity < 0 {
		return bigint(-SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioA, sqrtRatioB, bigint(-liquidity), false))
	} 
	
	return bigint(SqrtPriceMathGetAmount0DeltaHelper(sqrtRatioA, sqrtRatioB, bigint(liquidity), true))
}

func SqrtPriceMathGetAmount1Delta(
	sqrtRatioA bigint,
	sqrtRatioB bigint,
	liquidity bigint,
) (bigint) {
	if liquidity < 0 {
		return bigint(-SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioA, sqrtRatioB, bigint(-liquidity), false))
	}

	return bigint(SqrtPriceMathGetAmount1DeltaHelper(sqrtRatioA, sqrtRatioB, bigint(liquidity), true))
}