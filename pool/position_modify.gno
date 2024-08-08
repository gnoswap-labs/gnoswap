package pool

import (
	"gno.land/r/gnoswap/v2/common"

	i256 "gno.land/p/gnoswap/int256"

	plp "gno.land/p/gnoswap/pool" // pool package
)

// modifyPosition updates a position in the pool and calculates the amount of tokens to be added or removed.
//
// This function performs the following operations:
// 1. Updates the position based on the given parameters.
// 2. Calculates the amount of token0 and token1 to be added or removed based on the current tick and the position's tick range.
// 3. Updates the pool's liquidity if the position is within the current tick range.
//
// Note:
//   - If the position is out of the current price range, either amount0 or amount1 may be zero.
//   - The function handles nil values for amount0 and amount1 by converting them to zero.
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
			_amount0Str := plp.SqrtPriceMathGetAmount0DeltaStr(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
			amount0 = i256.MustFromDecimal(_amount0Str)
		} else if pool.slot0.tick < params.tickUpper {
			liquidityBefore := pool.liquidity

			_amount0Str := plp.SqrtPriceMathGetAmount0DeltaStr(
				pool.slot0.sqrtPriceX96,
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
			amount0 = i256.MustFromDecimal(_amount0Str)

			_amount1Str := plp.SqrtPriceMathGetAmount1DeltaStr(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				pool.slot0.sqrtPriceX96,
				params.liquidityDelta,
			)
			amount1 = i256.MustFromDecimal(_amount1Str)

			pool.liquidity = liquidityMathAddDelta(liquidityBefore, params.liquidityDelta)

		} else {
			_amount1Str := plp.SqrtPriceMathGetAmount1DeltaStr(
				common.TickMathGetSqrtRatioAtTick(params.tickLower),
				common.TickMathGetSqrtRatioAtTick(params.tickUpper),
				params.liquidityDelta,
			)
			amount1 = i256.MustFromDecimal(_amount1Str)
		}
	}

	// if position is out of range, one of amount0 or amount1 can be nil
	// > handle as 0
	amount0 = amount0.NilToZero()
	amount1 = amount1.NilToZero()

	return position, amount0, amount1
}
