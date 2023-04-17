package gnoswap

func SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(
	sqrtP bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	if (amount == 0) {
		require(sqrtP >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
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
				require(numerator1 * sqrtP / denominator >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
				return numerator1 * sqrtP / denominator
			}
		}

		// XXX round ?
		require(numerator1 / ((numerator1 / sqrtP) + amount) >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
		return numerator1 / ((numerator1 / sqrtP) + amount)
	}	
	require(product / amount == sqrtP && numerator1 > product, "SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
	denominator = numerator1 - product
	require(numerator1 * sqrtP / denominator >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp")
	return numerator1 * sqrtP / denominator
}

func SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(
	sqrtPrice bigint,
	liquidity bigint,
	amount bigint,
	add bool,
) (bigint) {
	require(sqrtPrice > 0, "[X] sqrtPrice > 0 // SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")
	require(liquidity > 0, "[X] liquidity > 0 // SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")
	require(amount > 0, "[X] amount > 0 // SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")

	quotient := amount / liquidity

	if add {
		require(quotient >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")
		return sqrtPrice + quotient
	} else {
		require(sqrtPrice > quotient, "sqrtPrice > quotient")
		require(sqrtPrice - quotient >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown")
		return sqrtPrice - quotient
	}

}

func SqrtPriceMathGetNextSqrtPriceFromInput(
	sqrtPrice bigint,
	liquidity bigint,
	amountIn bigint,
	zeroForOne bool,
) (sqrtQ bigint) {
	require(sqrtPrice > 0, "[X] sqrtPrice > 0 // SqrtPriceMathGetNextSqrtPriceFromInput")
	require(liquidity > 0, "[X] liquidity > 0// SqrtPriceMathGetNextSqrtPriceFromInput")
	require(amountIn > 0, "[X] amountIn > 0 // SqrtPriceMathGetNextSqrtPriceFromInput")

	if zeroForOne {
		require(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountIn, true) >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromInput")
		return SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountIn, true)
	} 

	require(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountIn, true) >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromInput")
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
		require(SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountOut, false) >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromOutput #1")
		return SqrtPriceMathGetNextSqrtPriceFromAmount1RoundingDown(sqrtPrice, liquidity, amountOut, false)
	} 

	require(SqrtPriceMathGetNextSqrtPriceFromAmount0RoundingUp(sqrtPrice, liquidity, amountOut, false) >= 0, "FIX MINUS // SqrtPriceMathGetNextSqrtPriceFromOutput #2")
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
		require((numerator1 * numerator2 / sqrtRatioB) / sqrtRatioA >= 0, "FIX MINUS // SqrtPriceMathGetAmount0DeltaHelper #1")
		return (numerator1 * numerator2 / sqrtRatioB) / sqrtRatioA
		// return liquidity / sqrtRatioA - liquidity / sqrtRatioB
	}

	require(((numerator1 * numerator2) / sqrtRatioB) / sqrtRatioA >= 0, "FIX MINUS // SqrtPriceMathGetAmount0DeltaHelper #2")
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