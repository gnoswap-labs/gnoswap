package pool

import (
	"std"

	i256 "gno.land/p/demo/big/int256"
)

func (pool *Pool) updatePosition(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityDelta *i256.Int, // int128
	tick int32,
) PositionInfo {
	_feeGrowthGlobal0X128 := pool.feeGrowthGlobal0X128
	_feeGrowthGlobal1X128 := pool.feeGrowthGlobal1X128

	var flippedLower, flippedUpper bool
	if !(liquidityDelta.IsZero()) {
		flippedLower = pool.tickUpdate(
			tickLower,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			pool.maxLiquidityPerTick,
		)

		flippedUpper = pool.tickUpdate(
			tickUpper,
			tick,
			liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			true,
			pool.maxLiquidityPerTick,
		)

		if flippedLower {
			pool.tickBitmapFlipTick(tickLower, pool.tickSpacing)
		}

		if flippedUpper {
			pool.tickBitmapFlipTick(tickUpper, pool.tickSpacing)
		}
	}

	// NO LIQ, ONLY BURN 0

	feeGrowthInside0X128, feeGrowthInside1X128 := pool.tickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	positionKey := positionGetKey(owner, tickLower, tickUpper)

	position := pool.positionUpdateWithKey(
		positionKey,
		liquidityDelta,
		feeGrowthInside0X128,
		feeGrowthInside1X128,
	)

	if liquidityDelta.IsNeg() {
		if flippedLower {
			pool.tickClear(tickLower)
		}

		if flippedUpper {
			pool.tickClear(tickUpper)
		}
	}

	return position
}
