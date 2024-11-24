package pool

import (
	"gno.land/r/gnoswap/v1/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	plp "gno.land/p/gnoswap/pool"
)

// modifyPosition updates a position in the pool and calculates the amount of tokens to be added or removed.
// Returns positionInfo, amount0, amount1
func (pool *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, *i256.Int, *i256.Int) {
	position := pool.updatePosition(params)
	liqDelta := params.liquidityDelta

	amount0, amount1 := i256.Zero(), i256.Zero()

	if liqDelta.IsZero() {
		return position, amount0, amount1
	}

	tick := pool.slot0.tick
	sqrtRatioLower := common.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioUpper := common.TickMathGetSqrtRatioAtTick(params.tickUpper)
	sqrtPriceX96 := pool.slot0.sqrtPriceX96

	// calculate amount0, amount1 based on the current tick position
	switch {
	case tick < params.tickLower:
		amount0 = calculateToken0Amount(sqrtRatioLower, sqrtRatioUpper, liqDelta)

	case tick < params.tickUpper:
		liquidityBefore := pool.liquidity

		amount0 = calculateToken0Amount(sqrtPriceX96, sqrtRatioUpper, liqDelta)
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtPriceX96, liqDelta)

		pool.liquidity = liquidityMathAddDelta(liquidityBefore, liqDelta)

	default:
		amount1 = calculateToken1Amount(sqrtRatioLower, sqrtRatioUpper, liqDelta)
	}

	return position, amount0, amount1
}

func calculateToken0Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	res := plp.SqrtPriceMathGetAmount0DeltaStr(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
	return i256.MustFromDecimal(res)
}

func calculateToken1Amount(sqrtPriceLower, sqrtPriceUpper *u256.Uint, liquidityDelta *i256.Int) *i256.Int {
	res := plp.SqrtPriceMathGetAmount1DeltaStr(sqrtPriceLower, sqrtPriceUpper, liquidityDelta)
	return i256.MustFromDecimal(res)
}
