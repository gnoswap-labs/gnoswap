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

	feeGrowthInside0X128, feeGrowthInside1X128 := pool.tickGetFeeGrowthInside(
		tickLower,
		tickUpper,
		tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	if liquidityDelta.IsZero() {
		return pool.updatePositionWithKey(owner, tickLower, tickUpper, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)
	}

	flippedLower := pool.updateTick(tickLower, tick, liquidityDelta, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128, false)
	flippedUpper := pool.updateTick(tickUpper, tick, liquidityDelta, _feeGrowthGlobal0X128, _feeGrowthGlobal1X128, true)

	if flippedLower {
		pool.tickBitmapFlipTick(tickLower, pool.tickSpacing)
	}

	if flippedUpper {
		pool.tickBitmapFlipTick(tickUpper, pool.tickSpacing)
	}

	position := pool.updatePositionWithKey(owner, tickLower, tickUpper, liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128)

	if liquidityDelta.IsNeg() {
		pool.cleanupFlippedTicks(flippedLower, flippedUpper, tickLower, tickUpper)
	}

	return position
}

// updateTick is a helper function to update a single tick.
func (pool *Pool) updateTick(
    tickToUpdate, currentTick int32,
    liquidityDelta *i256.Int,
    feeGrowthGlobal0X128, feeGrowthGlobal1X128 *u256.Uint,
    upper bool,
) bool {
    flipped := pool.tickUpdate(
        tickToUpdate,
        currentTick,
        liquidityDelta,
        feeGrowthGlobal0X128,
        feeGrowthGlobal1X128,
        upper,
        pool.maxLiquidityPerTick,
    )
    return flipped
}

func (pool *Pool) updatePositionWithKey(
	owner std.Address,
	tickLower, tickUpper int32,
	liquidityDelta *i256.Int,
	feeGrowthInside0X128, feeGrowthInside1X128 *u256.Uint,
) PositionInfo {
	positionKey := positionGetKey(owner, tickLower, tickUpper)
	return pool.positionUpdateWithKey(
		positionKey,
		liquidityDelta,
		u256.MustFromDecimal(feeGrowthInside0X128.ToString()),
		u256.MustFromDecimal(feeGrowthInside1X128.ToString()),
	)
}

func (pool *Pool) cleanupFlippedTicks(flippedLower, flippedUpper bool, tickLower, tickUpper int32) {
	if flippedLower {
		delete(pool.ticks, tickLower)
	}
	if flippedUpper {
		delete(pool.ticks, tickUpper)
	}
}
