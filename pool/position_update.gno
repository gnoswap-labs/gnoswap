package pool

import (
	"std"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func (pool *Pool) updatePosition(
	owner std.Address,
	tickLower int32,
	tickUpper int32,
	liquidityDelta *i256.Int, // int128
	tick int32,
) PositionInfo {
	_feeGrowthGlobal0X128 := u256.MustFromDecimal(pool.feeGrowthGlobal0X128.ToString())
	_feeGrowthGlobal1X128 := u256.MustFromDecimal(pool.feeGrowthGlobal1X128.ToString())

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
		u256.MustFromDecimal(feeGrowthInside0X128.ToString()),
		u256.MustFromDecimal(feeGrowthInside1X128.ToString()),
	)

	if liquidityDelta.IsNeg() {
		if flippedLower {
			delete(pool.ticks, tickLower)
		}

		if flippedUpper {
			delete(pool.ticks, tickUpper)
		}
	}

	return position
}
