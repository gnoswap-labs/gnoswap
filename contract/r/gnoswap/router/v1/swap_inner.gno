package v1

import (
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/router"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/pool"
)

const (
	MIN_SQRT_RATIO string = "4295128739"                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342" // same as TickMathGetSqrtRatioAtTick(MAX_TICK)
)

// swapInner executes the core swap logic by interacting with the pool contract.
// Returns poolRecv (tokens received by pool) and poolOut (tokens sent by pool).
func (r *routerV1) swapInner(
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
		cross,
		token0Path,
		token1Path,
		data.fee,
		recipient,
		zeroForOne,
		formatInt64(amountSpecified),
		sqrtPriceLimitX96.ToString(),
		data.payer,
		func(cur realm, amount0Delta, amount1Delta int64, _ *pl.CallbackMarker) error {
			return router.SwapCallback(token0Path, token1Path, amount0Delta, amount1Delta, data.payer)
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
	zeroForOne := data.tokenIn < data.tokenOut
	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	// check possible
	amount0Str, amount1Str, ok := pl.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,
		zeroForOne,
		formatInt64(amountSpecified),
		sqrtPriceLimitX96.ToString(),
	)
	if !ok {
		return 0, 0
	}

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)

	poolOut, poolRecv := i256MinMax(amount0, amount1)
	if poolRecv.IsOverflow() || poolOut.IsOverflow() {
		panic("overflow in swapDryInner")
	}

	return poolRecv.Int64(), poolOut.Int64()
}

// RealSwapExecutor implements SwapExecutor for actual swaps.
type RealSwapExecutor struct {
	router *routerV1
}

// execute performs the actual swap execution.
func (e *RealSwapExecutor) execute(p *SingleSwapParams) (int64, int64) {
	caller := runtime.PreviousRealm().Address()
	recipient := routerAddr

	return e.router.swapInner(
		p.amountSpecified,
		recipient,             // if single swap => user will receive
		p.SqrtPriceLimitX96(), // sqrtPriceLimitX96
		newSwapCallbackData(p, caller),
	)
}

// DrySwapExecutor implements SwapExecutor for dry swaps.
type DrySwapExecutor struct {
	router *routerV1
}

// execute performs the dry swap execution.
func (e *DrySwapExecutor) execute(p *SingleSwapParams) (int64, int64) {
	previousRealmAddr := runtime.PreviousRealm().Address()

	return e.router.swapDryInner(
		p.amountSpecified,
		zero,
		newSwapCallbackData(p, previousRealmAddr),
	)
}

// calculateSqrtPriceLimitForSwap calculates the price limit for a swap operation.
func calculateSqrtPriceLimitForSwap(zeroForOne bool, fee uint32, sqrtPriceLimitX96 *u256.Uint) *u256.Uint {
	if !sqrtPriceLimitX96.IsZero() {
		return sqrtPriceLimitX96
	}

	if zeroForOne {
		minTick := getMinTick(fee) + 1
		sqrtPriceLimitX96 = u256.Zero().Set(common.TickMathGetSqrtRatioAtTick(minTick))
		if sqrtPriceLimitX96.IsZero() {
			sqrtPriceLimitX96 = u256.MustFromDecimal(MIN_SQRT_RATIO)
		}
		return u256.Zero().Add(sqrtPriceLimitX96, one)
	}

	maxTick := getMaxTick(fee) - 1
	sqrtPriceLimitX96 = u256.Zero().Set(common.TickMathGetSqrtRatioAtTick(maxTick))
	if sqrtPriceLimitX96.IsZero() {
		sqrtPriceLimitX96 = u256.MustFromDecimal(MAX_SQRT_RATIO)
	}
	return u256.Zero().Sub(sqrtPriceLimitX96, one)
}

// getMinTick returns the minimum tick value for a given fee tier.
// The implementation follows Uniswap V3's tick spacing rules where
// lower fee tiers allow for finer price granularity.
func getMinTick(fee uint32) int32 {
	switch fee {
	case 100:
		return -887272
	case 500:
		return -887270
	case 3000:
		return -887220
	case 10000:
		return -887200
	default:
		panic(addDetailToError(
			errInvalidPoolFeeTier,
			ufmt.Sprintf("unknown fee(%d)", fee),
		))
	}
}

// getMaxTick returns the maximum tick value for a given fee tier.
// The max tick values are the exact negatives of min tick values.
func getMaxTick(fee uint32) int32 {
	switch fee {
	case 100:
		return 887272
	case 500:
		return 887270
	case 3000:
		return 887220
	case 10000:
		return 887200
	default:
		panic(addDetailToError(
			errInvalidPoolFeeTier,
			ufmt.Sprintf("unknown fee(%d)", fee),
		))
	}
}
