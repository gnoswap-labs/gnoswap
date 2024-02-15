package position

import (
	"gno.land/p/demo/common"

	p "gno.land/r/demo/pool"
)

func addLiquidity(params AddLiquidityParams) (bigint, bigint, bigint) {
	pool := p.GetPoolFromPoolPath(params.poolKey)

	sqrtPriceX96 := pool.PoolGetSlot0SqrtPriceX96()
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(params.tickUpper)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		params.amount0Desired,
		params.amount1Desired,
	)
	liquidity += 1 // adjust for rounding errors

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

	require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, "[POSITION] liquidity_management.gno__addLiquidity() || LM_Price Slippage Check")

	return liquidity, amount0, amount1
}
