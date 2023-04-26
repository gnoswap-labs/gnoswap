package liquidity

import (
	"std"
	pool "gno.land/r/pool"
)


type AddLiquidityParams struct {
	token0 std.Address
	token1 std.Address
	fee bigint
	tickLower bigint
	tickUpper bigint
	amount0Desired bigint
	amount1Desired bigint
	amount0Min bigint
	amount1Min bigint
	recipient std.Address // XXX de facto: hardcoded to nft manager contract address
}


func addLiquidity(params AddLiquidityParams) (bigint, bigint, bigint) {
	poolKey := PoolKey{token0: params.token0, token1: params.token1, fee: params.fee};
	// pool := PoolAddressComputeAddress(factory, poolKey)

	// _slot0 := pool.GetSlot0()
	// sqrtPriceX96 := _slot0.sqrtPriceX96
	sqrtPriceX96 := pool.GetPoolSlot0SqrtPriceX96()
	sqrtRatioAX96 := pool.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioBX96 := pool.TickMathGetSqrtRatioAtTick(params.tickUpper)

	liquidity := LiquidityAmountsGetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		params.amount0Desired,
		params.amount1Desired,
	)

	amount0, amount1 := pool.Mint(
		params.recipient,
		params.tickLower,
		params.tickUpper,
		liquidity,
	)
	
	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "LM_Price Slippage Check")

	return liquidity, amount0, amount1
}