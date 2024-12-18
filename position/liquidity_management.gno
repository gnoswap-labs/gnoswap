package position

import (
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	pl "gno.land/r/gnoswap/v1/pool"
)

// addLiquidity adds liquidity to the pool and checks for slippage.
// Returns liquidity, amount0, amount1
func addLiquidity(params AddLiquidityParams) (*u256.Uint, *u256.Uint, *u256.Uint) {
	pool := pl.GetPoolFromPoolPath(params.poolKey)

	sqrtPriceX96 := pool.GetSlot0SqrtPriceX96()
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(params.tickUpper)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		params.amount0Desired,
		params.amount1Desired,
	)

	pToken0, pToken1, pFee := splitOf(params.poolKey)
	amount0, amount1 := pl.Mint(
		pToken0,
		pToken1,
		pFee,
		consts.POSITION_ADDR,
		params.tickLower,
		params.tickUpper,
		liquidity.ToString(),
		params.caller,
	)

	amount0Uint := u256.MustFromDecimal(amount0)
	amount1Uint := u256.MustFromDecimal(amount1)

	amount0Cond := amount0Uint.Gte(params.amount0Min)
	amount1Cond := amount1Uint.Gte(params.amount1Min)

	if !(amount0Cond && amount1Cond) {
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("liquidity_management.gno__addLiquidity() || LM_Price Slippage Check(amount0(%s) >= params.amount0Min(%s), amount1(%s) >= params.amount1Min(%s))", amount0Uint.ToString(), params.amount0Min.ToString(), amount1Uint.ToString(), params.amount1Min.ToString()),
		))
	}

	return liquidity, amount0Uint, amount1Uint
}
