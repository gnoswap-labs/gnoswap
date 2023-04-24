package position

func LiquidityAmountsGetLiquidityForAmount0(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	amount0 bigint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	intermediate := sqrtRatioAX96 * sqrtRatioBX96 / Q96

	return amount0 * intermediate / (sqrtRatioBX96 - sqrtRatioAX96)
}

func LiquidityAmountsGetLiquidityForAmount1(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	amount1 bigint,
) bigint {
	if sqrtRatioAX96 > sqrtRatioBX96 {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return amount1 * Q96 / (sqrtRatioBX96 - sqrtRatioAX96)
}

func LiquidityAmountsGetLiquidityForAmounts(
	sqrtRatioX96 bigint,
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	amount0 bigint,
	amount1 bigint,
) bigint {
	var liquidity bigint

	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	if (sqrtRatioX96 <= sqrtRatioAX96) {
		liquidity = LiquidityAmountsGetLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0)
	} else if (sqrtRatioX96 < sqrtRatioBX96) {
		liquidity0 := LiquidityAmountsGetLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0)
		liquidity1 := LiquidityAmountsGetLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1)
	
		if liquidity0 < liquidity1 {
			liquidity = liquidity0
		} else {
			liquidity = liquidity1
		}

	} else {
		liquidity = LiquidityAmountsGetLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1)
	}

	return liquidity
}


func LiquidityAmountsGetAmount0ForLiquidity(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return ((liquidity << 96) * (sqrtRatioBX96 - sqrtRatioAX96) / sqrtRatioBX96) / sqrtRatioAX96
}


func LiquidityAmountsGetAmount1ForLiquidity(
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) bigint {
	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}

	return liquidity * (sqrtRatioBX96 - sqrtRatioAX96) / Q96
}

func LiquidityAmountsGetAmountsForLiquidity(
	sqrtRatioX96 bigint,
	sqrtRatioAX96 bigint,
	sqrtRatioBX96 bigint,
	liquidity bigint,
) (bigint, bigint) {
	var amount0, amount1 bigint

	if (sqrtRatioAX96 > sqrtRatioBX96) {
		sqrtRatioAX96, sqrtRatioBX96 = sqrtRatioBX96, sqrtRatioAX96
	}
	
	if (sqrtRatioX96 <= sqrtRatioAX96) {
		amount0 = LiquidityAmountsGetAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	} else if (sqrtRatioX96 < sqrtRatioBX96) {
		amount0 = LiquidityAmountsGetAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity)
		amount1 = LiquidityAmountsGetAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity)
	} else {
		amount1 = LiquidityAmountsGetAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity)
	}

	return amount0, amount1
}