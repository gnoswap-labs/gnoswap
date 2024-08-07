package position

import (
	"gno.land/r/gnoswap/v2/common"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"

	u256 "gno.land/p/gnoswap/uint256"
)

func addLiquidity(params AddLiquidityParams) (*u256.Uint, *u256.Uint, *u256.Uint) { // uint128, uint256, uint256
	pool := pl.GetPoolFromPoolPath(params.poolKey)

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

	pToken0, pToken1, pFee := poolKeyDivide(params.poolKey)
	amount0, amount1 := pl.Mint( // string(uint256), string(uint256)
		pToken0,                       // token0Path string
		pToken1,                       // token1Path string
		pFee,                          // fee uint16
		consts.POSITION_ADDR.String(), // recipient std.Address
		params.tickLower,              // tickLower int32
		params.tickUpper,              // tickUpper int32
		liquidity.ToString(),          // _liquidityAmount string(uint128)
	)

	amount0Uint := u256.MustFromDecimal(amount0)
	amount1Uint := u256.MustFromDecimal(amount1)

	amount0Cond := amount0Uint.Gte(params.amount0Min)
	amount1Cond := amount1Uint.Gte(params.amount1Min)

	if !(amount0Cond && amount1Cond) {
		panic("[POSITION] liquidity_management.gno__addLiquidity() || LM_Price Slippage Check")
	}

	return liquidity, amount0Uint, amount1Uint
}
