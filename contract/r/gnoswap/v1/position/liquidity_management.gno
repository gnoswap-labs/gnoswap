package position

import (
	"std"

	"gno.land/p/nt/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
	pl "gno.land/r/gnoswap/v1/pool"
)

type AddLiquidityParams struct {
	poolKey        string      // poolPath of the pool which has the position
	tickLower      int32       // lower end of the tick range for the position
	tickUpper      int32       // upper end of the tick range for the position
	amount0Desired *u256.Uint  // desired amount of token0 to be minted
	amount1Desired *u256.Uint  // desired amount of token1 to be minted
	amount0Min     *u256.Uint  // minimum amount of token0 to be minted
	amount1Min     *u256.Uint  // minimum amount of token1 to be minted
	caller         std.Address // address to call the function
}

// addLiquidity calculates liquidity amounts and mints position tokens to a pool.
func addLiquidity(params AddLiquidityParams) (*u256.Uint, *u256.Uint, *u256.Uint) {
	sqrtPriceX96 := pl.GetSlot0SqrtPriceX96(params.poolKey)
	sqrtRatioAX96 := common.TickMathGetSqrtRatioAtTick(params.tickLower)
	sqrtRatioBX96 := common.TickMathGetSqrtRatioAtTick(params.tickUpper)

	liquidity := common.GetLiquidityForAmounts(
		sqrtPriceX96,
		sqrtRatioAX96,
		sqrtRatioBX96,
		params.amount0Desired,
		params.amount1Desired,
	)

	token0, token1, fee := splitOf(params.poolKey)
	amount0Str, amount1Str := pl.Mint(
		cross,
		token0,
		token1,
		fee,
		positionAddr,
		params.tickLower,
		params.tickUpper,
		liquidity.ToString(),
		params.caller,
	)

	amount0 := u256.MustFromDecimal(amount0Str)
	amount1 := u256.MustFromDecimal(amount1Str)

	amount0Cond := amount0.Gte(params.amount0Min)
	amount1Cond := amount1.Gte(params.amount1Min)

	if !(amount0Cond && amount1Cond) {
		panic(newErrorWithDetail(
			errSlippage,
			ufmt.Sprintf(
				"Price Slippage Check(amount0(%s) >= amount0Min(%s), amount1(%s) >= amount1Min(%s))",
				amount0Str, params.amount0Min.ToString(), amount1Str, params.amount1Min.ToString()),
		))
	}

	return liquidity, amount0, amount1
}
