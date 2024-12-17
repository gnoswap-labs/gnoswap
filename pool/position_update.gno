package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

func (p *Pool) updatePosition(positionParams ModifyPositionParams, tick int32) PositionInfo {
	feeGrowthGlobal0X128 := p.FeeGrowthGlobal0X128().Clone()
	feeGrowthGlobal1X128 := p.FeeGrowthGlobal1X128().Clone()

	var flippedLower, flippedUpper bool
	if !(positionParams.liquidityDelta.IsZero()) {
		flippedLower = p.tickUpdate(
			positionParams.tickLower,
			tick,
			positionParams.liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			false,
			p.maxLiquidityPerTick,
		)

		flippedUpper = p.tickUpdate(
			positionParams.tickUpper,
			tick,
			positionParams.liquidityDelta,
			feeGrowthGlobal0X128,
			feeGrowthGlobal1X128,
			true,
			p.maxLiquidityPerTick,
		)

		if flippedLower {
			p.tickBitmapFlipTick(positionParams.tickLower, p.tickSpacing)
		}

		if flippedUpper {
			p.tickBitmapFlipTick(positionParams.tickUpper, p.tickSpacing)
		}
	}

	feeGrowthInside0X128, feeGrowthInside1X128 := p.calculateFeeGrowthInside(
		positionParams.tickLower,
		positionParams.tickUpper,
		tick,
		feeGrowthGlobal0X128,
		feeGrowthGlobal1X128,
	)

	positionKey := positionGetKey(positionParams.owner, positionParams.tickLower, positionParams.tickUpper)
	position := p.positionUpdateWithKey(
		positionKey,
		positionParams.liquidityDelta,
		u256.MustFromDecimal(feeGrowthInside0X128.ToString()),
		u256.MustFromDecimal(feeGrowthInside1X128.ToString()),
	)

	// clear any tick data that is no longer needed
	if positionParams.liquidityDelta.IsNeg() {
		if flippedLower {
			delete(p.ticks, positionParams.tickLower)
		}
		if flippedUpper {
			delete(p.ticks, positionParams.tickUpper)
		}
	}

	return position
}
