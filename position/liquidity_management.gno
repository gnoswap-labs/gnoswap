package position

import (
	"std"

	p "gno.land/r/pool"
)

func addLiquidity(params AddLiquidityParams) (bigint, bigint, bigint) {
	pool := p.GetPoolFromPoolKey(params.poolKey)

	sqrtPriceX96 := pool.GetPoolSlot0SqrtPriceX96()
	sqrtRatioAX96 := p.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioBX96 := p.TickMathGetSqrtRatioAtTick(params.tickUpper)

	liquidity := LiquidityAmountsGetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		params.amount0Desired,
		params.amount1Desired,
	)

	pToken0, pToken1, pFee := poolKeyDivide(params.poolKey)
	amount0, amount1 := p.Mint(
		pToken0,
		pToken1,
		pFee,
		params.recipient,
		params.tickLower,
		params.tickUpper,
		liquidity,
	)

	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "LM_Price Slippage Check")

	return liquidity, amount0, amount1
}
