package router

import (
	ufmt "gno.land/p/nt/ufmt/v0"
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

var (
	sqrtPriceLimitForward  = u256.MustFromDecimal(MIN_SQRT_RATIO_PLUS_ONE)
	sqrtPriceLimitBackward = u256.MustFromDecimal(MAX_SQRT_RATIO_MINUS_ONE)
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

	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	amount0Str, amount1Str := pl.Swap(
		cross(rlm),
		token0Path,
		token1Path,
		data.fee,
		recipient,
		zeroForOne,
		utils.FormatInt(amountSpecified),
		sqrtPriceLimitX96.ToString(),
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

	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	// check possible
	amount0Str, amount1Str, err := pl.DrySwap(
		token0Path,
		token1Path,
		data.fee,
		zeroForOne,
		utils.FormatInt(amountSpecified),
		sqrtPriceLimitX96.ToString(),
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

// calculateSqrtPriceLimitForSwap returns the price limit for a swap operation.
// If a non-zero limit is provided by the caller, it is returned as-is.
// Otherwise, it returns the global TickMath boundary for the swap direction.
// The returned pointer is shared (read-only — callers must not mutate it).
func calculateSqrtPriceLimitForSwap(zeroForOne bool, fee uint32, sqrtPriceLimitX96 *u256.Uint) *u256.Uint {
	if !sqrtPriceLimitX96.IsZero() {
		return sqrtPriceLimitX96
	}

	assertKnownPoolFeeTier(fee)
	if zeroForOne {
		return sqrtPriceLimitForward
	}
	return sqrtPriceLimitBackward
}

func assertKnownPoolFeeTier(fee uint32) {
	switch fee {
	case 100, 500, 3000, 10000:
		return
	default:
		panic(makeErrorWithDetails(
			errInvalidPoolFeeTier,
			ufmt.Sprintf("unknown fee(%d)", fee),
		))
	}
}
