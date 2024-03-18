package pool

import (
	"gno.land/r/gnoswap/common"

	i256 "gno.land/p/big/int256"
)

func (pool *Pool) modifyPosition(params ModifyPositionParams) (PositionInfo, *i256.Int, *i256.Int) {
	position := pool.updatePosition(
		params.owner,
		params.tickLower,
		params.tickUpper,
		params.liquidityDelta,
		pool.slot0.tick,
	)
	var amount0, amount1 *i256.Int

	if !(params.liquidityDelta.IsZero()) {
		if pool.slot0.tick < params.tickLower {
			amount0 = sqrtPriceMathGetAmount0Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		} else if pool.slot0.tick < params.tickUpper {
			liquidityBefore := pool.liquidity

			amount0 = sqrtPriceMathGetAmount0Delta(
				pool.slot0.sqrtPriceX96,
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)

			amount1 = sqrtPriceMathGetAmount1Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPriceX96,
				params.liquidityDelta,
			)

			pool.liquidity = liquidityMathAddDelta(liquidityBefore, params.liquidityDelta)

		} else {
			amount1 = sqrtPriceMathGetAmount1Delta(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
		}
	}

	// if position is out of range, one of amount0 or amount1 can be nil
	// handle as 0
	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()

	return position, amount0, amount1
}
