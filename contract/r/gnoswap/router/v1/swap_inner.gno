package router

import (
	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/router"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"

	pl "gno.land/r/gnoswap/pool"
)

const (
	MIN_SQRT_RATIO_PLUS_ONE  string = "4295128740"
	MAX_SQRT_RATIO_MINUS_ONE string = "1461446703485210103287273052203988822378723970341"
)

// swapInner executes the core swap logic by interacting with the pool contract.
// Returns poolRecv (tokens received by pool) and poolOut (tokens sent by pool).
func (r *routerV1) swapInner(
	_ int,
	rlm realm,
	amountSpecified int64,
	recipient address,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (int64, int64) {
	token0Path, token1Path := data.tokenIn, data.tokenOut
	zeroForOne := data.tokenIn < data.tokenOut

	if !zeroForOne {
		token0Path, token1Path = token1Path, token0Path
	}

	sqrtPriceLimitStr := calculateSqrtPriceLimitToStr(zeroForOne, sqrtPriceLimitX96)

	amount0Str, amount1Str := pl.Swap(
		cross(rlm),
		token0Path,
		token1Path,
		data.fee,
		recipient,
		zeroForOne,
		utils.FormatInt(amountSpecified),
		sqrtPriceLimitStr,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
			// assert is pool to prevent unauthorized callback
			caller := cur.Previous().Address()
			access.AssertIsPool(caller)

			return router.SwapCallback(cross(cur), token0Path, token1Path, amount0Delta, amount1Delta, data.payer)
		},
	)

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)

	poolOut, poolRecv := i256MinMax(amount0, amount1)
	if poolRecv.IsOverflow() || poolOut.IsOverflow() {
		panic("overflow in swapInner")
	}

	return poolRecv.Int64(), poolOut.Int64()
}

// swapDryInner performs a dry-run of a swap operation without executing it.
func (r *routerV1) swapDryInner(
	amountSpecified int64,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (int64, int64) {
	token0Path, token1Path := data.tokenIn, data.tokenOut
	zeroForOne := data.tokenIn < data.tokenOut

	if !zeroForOne {
		token0Path, token1Path = token1Path, token0Path
	}

	sqrtPriceLimitStr := calculateSqrtPriceLimitToStr(zeroForOne, sqrtPriceLimitX96)

	// check possible
	amount0Str, amount1Str, err := pl.DrySwap(
		token0Path,
		token1Path,
		data.fee,
		zeroForOne,
		utils.FormatInt(amountSpecified),
		sqrtPriceLimitStr,
	)
	if err != nil {
		panic(err)
	}

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)
	if amount0.Sign() <= 0 && amount1.Sign() <= 0 {
		panic(makeErrorWithDetails(
			errInsufficientLiquidity,
			"swap entirely within 0-liquidity region",
		))
	}

	poolOut, poolRecv := i256MinMax(amount0, amount1)
	if poolRecv.IsOverflow() || poolOut.IsOverflow() {
		panic("overflow in swapDryInner")
	}

	return poolRecv.Int64(), poolOut.Int64()
}

// calculateSqrtPriceLimitToStr returns the price-limit string for a swap operation.
// A non-zero caller limit is formatted as-is; a zero limit uses the global
// TickMath boundary for the swap direction.
func calculateSqrtPriceLimitToStr(zeroForOne bool, sqrtPriceLimitX96 *u256.Uint) string {
	if !sqrtPriceLimitX96.IsZero() {
		return sqrtPriceLimitX96.ToString()
	}

	if zeroForOne {
		return MIN_SQRT_RATIO_PLUS_ONE
	}
	return MAX_SQRT_RATIO_MINUS_ONE
}
