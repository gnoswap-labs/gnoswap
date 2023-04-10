package liquidity

import (
	"std"

	pool "gno.land/p/demo/pool" //
)

func addLiquidity(
	token0 std.Address, 
	token1 std.Address, 
	fee bigint, 
	recipient std.Address,
	tickLower int, 
	tickUpper int, 
	amount0Desired bigint, 
	amount1Desired bigint,
	amount0Min bigint, 
	amount1Min bigint,
) {
	// PoolAddress.PoolKey memory poolKey =
	//         PoolAddress.PoolKey({token0: params.token0, token1: params.token1, fee: params.fee});
	// pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, poolKey));
	// pool := pool.GetPool(token0, token1, fee)

	// {
	// 	(uint160 sqrtPriceX96, , , , , , ) = pool.slot0();
	// 	uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(params.tickLower);
	// 	uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(params.tickUpper);

	// 	liquidity = LiquidityAmounts.getLiquidityForAmounts(
	// 		sqrtPriceX96,
	// 		sqrtRatioAX96,
	// 		sqrtRatioBX96,
	// 		params.amount0Desired,
	// 		params.amount1Desired
	// 	);
	// }
	liquidity := bigint(0)

	// (amount0, amount1) = pool.mint(
	// 	params.recipient,
	// 	params.tickLower,
	// 	params.tickUpper,
	// 	liquidity,
	// 	abi.encode(MintCallbackData({poolKey: poolKey, payer: msg.sender}))
	// );
	pool.Mint(GetOrigCaller(), recipient, tickLower, tickUpper, liquidity)

	// require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Price slippage check');
	amount0 := 0
	amount1 := 0
	if amount0.Cmp(amount0Min) < 0 || amount1.Cmp(amount1Min) < 0 {
		panic("Price slippage check")
	}
}