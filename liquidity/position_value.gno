package liquidity

import (
	"std"
	pool "gno.land/r/pool" // XXX from pool, dynamic import
)


func PositionValueTotal(
	positionManager INonfungiblePositionManager,
	tokenId bigint,
	sqrtRatioX96 bigint,
) (bigint, bigint) {
	amount0Principal, amount1Principal := PositionValuePrincipal(positionManager, tokenId, sqrtRatioX96)
	amount0Fee, amount1Fee := PositionValueFees(positionManager, tokenId)

	return amount0Principal + amount0Fee, amount1Principal + amount1Fee
}


func PositionValuePrincipal(
	positionManager INonfungiblePositionManager,
	tokenId bigint,
	sqrtRatioX96 bigint,
) (bigint, bigint) {
	_, _, _, _, _, tickLower, tickUpper, liquidity, _, _, _, _ := Positions(string(tokenId))

	return LiquidityAmountsGetAmountsForLiquidity(
		sqrtRatioX96,
		pool.TickMathGetSqrtRatioAtTick(tickLower),
		pool.TickMathGetSqrtRatioAtTick(tickUpper),
		liquidity,
	)
}


type FeeParams struct {
	token0 std.Address
	token1 std.Address
	fee bigint
	tickLower bigint
	tickUpper bigint
	liquidity bigint
	positionFeeGrowthInside0LastX128 bigint
	positionFeeGrowthInside1LastX128 bigint
	tokensOwed0 bigint
	tokensOwed1 bigint
}

func PositionValueFees(positionManager INonfungiblePositionManager, tokenId bigint) (bigint, bigint) {
	_, _, token0, token1, fee, tickLower, tickUpper, liquidity, positionFeeGrowthInside0LastX128, positionFeeGrowthInside1LastX128, tokensOwed0, tokensOwed1 := Positions(string(tokenId))

	return _fees(positionManager, FeeParams{
		token0: token0,
		token1: token1,
		fee: fee,
		tickLower: tickLower,
		tickUpper: tickUpper,
		liquidity: liquidity,
		positionFeeGrowthInside0LastX128: positionFeeGrowthInside0LastX128,
		positionFeeGrowthInside1LastX128: positionFeeGrowthInside1LastX128,
		tokensOwed0: tokensOwed0,
		tokensOwed1: tokensOwed1,
	})
}

func _fees(positionManager INonfungiblePositionManager, feeParams FeeParams) (bigint, bigint) {
	poolFeeGrowthInside0LastX128, poolFeeGrowthInside1LastX128 := _getFeeGrowthInside(
		// IUniswapV3Pool( // XXX
		// 	PoolAddressComputeAddress(
		// 		positionManager.factory(),
		// 		PoolKey{token0: feeParams.token0, token1: feeParams.token1, fee: feeParams.fee},
		// 	),
		// ),
		feeParams.tickLower,
		feeParams.tickUpper,
	)

	amount0 := ( (poolFeeGrowthInside0LastX128 - feeParams.positionFeeGrowthInside0LastX128) * feeParams.liquidity / Q128) + feeParams.tokensOwed0
	amount1 := ( (poolFeeGrowthInside1LastX128 - feeParams.positionFeeGrowthInside1LastX128) * feeParams.liquidity / Q128) + feeParams.tokensOwed1
}


func _getFeeGrowthInside(
	// pool IUniswapV3Pool, // XXX dynamic import
	tickLower bigint,
	tickUpper bigint,
) (bigint, bigint) {
	// _pool := pool.GetSlot0()
	// tickCurrent := _pool.tickCurrent
	tickCurrent := pool.GetPoolSlot0Tick()

	_poolTickLower := pool.GetPoolTicks(tickLower)
	_poolTickUpper := pool.GetPoolTicks(tickUpper)

	// lowerFeeGrowthOutSide0X128, lowerFeeGrowthOutSide1X128 := pool.GetPoolTickFeeGrowthOutside0X128(tickLower), _poolTickLower.feeGrowthOutside1X128
	// upperFeeGrowthOutSide0X128, upperFeeGrowthOutSide1X128 := _poolTickUpper.feeGrowthOutside0X128, _poolTickUpper.feeGrowthOutside1X128

	lowerFeeGrowthOutSide0X128, lowerFeeGrowthOutSide1X128 := pool.GetPoolTickFeeGrowthOutside0X128(tickLower), pool.GetPoolTickFeeGrowthOutside1X128(tickLower)
	upperFeeGrowthOutSide0X128, upperFeeGrowthOutSide1X128 := pool.GetPoolTickFeeGrowthOutside0X128(tickUpper), pool.GetPoolTickFeeGrowthOutside1X128(tickUpper)

	var feeGrowthInside0X128, feeGrowthInside1X128 bigint
	if (tickCurrent < tickLower) {
		feeGrowthInside0X128 = lowerFeeGrowthOutSide0X128 - upperFeeGrowthOutSide0X128
		feeGrowthInside1X128 = lowerFeeGrowthOutSide1X128 - upperFeeGrowthOutSide1X128
	} else if (tickCurrent < tickUpper) {
		feeGrowthGlobal0X128 := pool.GetFeeGrowthGlobal0X128()
		feeGrowthGlobal1X128 := pool.GetFeeGrowthGlobal1X128()

		feeGrowthInside0X128 = feeGrowthGlobal0X128 - lowerFeeGrowthOutSide0X128 - upperFeeGrowthOutSide0X128
		feeGrowthInside1X128 = feeGrowthGlobal1X128 - lowerFeeGrowthOutSide1X128 - upperFeeGrowthOutSide1X128

	} else {
		feeGrowthInside0X128 = upperFeeGrowthOutSide0X128 - lowerFeeGrowthOutSide0X128
		feeGrowthInside1X128 = upperFeeGrowthOutSide1X128 - lowerFeeGrowthOutSide1X128
	}

	return feeGrowthInside0X128, feeGrowthInside1X128
}