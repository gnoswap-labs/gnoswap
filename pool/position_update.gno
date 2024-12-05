package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

func (pool *Pool) updatePosition(positionParams ModifyPositionParams) PositionInfo {
	_feeGrowthGlobal0X128 := u256.MustFromDecimal(pool.feeGrowthGlobal0X128.ToString())
	_feeGrowthGlobal1X128 := u256.MustFromDecimal(pool.feeGrowthGlobal1X128.ToString())

	var flippedLower, flippedUpper bool
	if !(positionParams.liquidityDelta.IsZero()) {
		flippedLower = pool.tickUpdate(
			positionParams.tickLower,
			pool.slot0.tick,
			positionParams.liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			false,
			pool.maxLiquidityPerTick,
		)

		flippedUpper = pool.tickUpdate(
			positionParams.tickUpper,
			pool.slot0.tick,
			positionParams.liquidityDelta,
			_feeGrowthGlobal0X128,
			_feeGrowthGlobal1X128,
			true,
			pool.maxLiquidityPerTick,
		)

		if flippedLower {
			pool.tickBitmapFlipTick(positionParams.tickLower, pool.tickSpacing)
		}

		if flippedUpper {
			pool.tickBitmapFlipTick(positionParams.tickUpper, pool.tickSpacing)
		}
	}

	feeGrowthInside0X128, feeGrowthInside1X128 := pool.calculateFeeGrowthInside(
		positionParams.tickLower,
		positionParams.tickUpper,
		pool.slot0.tick,
		_feeGrowthGlobal0X128,
		_feeGrowthGlobal1X128,
	)

	positionKey := positionGetKey(positionParams.owner, positionParams.tickLower, positionParams.tickUpper)

	position := pool.positionUpdateWithKey(
		positionKey,
		positionParams.liquidityDelta,
		u256.MustFromDecimal(feeGrowthInside0X128.ToString()),
		u256.MustFromDecimal(feeGrowthInside1X128.ToString()),
	)

	if positionParams.liquidityDelta.IsNeg() {
		if flippedLower {
			delete(pool.ticks, positionParams.tickLower)
		}

		if flippedUpper {
			delete(pool.ticks, positionParams.tickUpper)
		}
	}

	return position
}
