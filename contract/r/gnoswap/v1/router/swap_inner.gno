package router

import (
	"std"

	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoswap/v1/common"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/v1/pool"
)

const (
	MIN_SQRT_RATIO string = "4295128739"                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342" // same as TickMathGetSqrtRatioAtTick(MAX_TICK)
)

// swapInner executes the core swap logic by interacting with the pool contract.
// Returns poolRecv (tokens received by pool) and poolOut (tokens sent by pool).
func swapInner(
	amountSpecified *i256.Int,
	recipient std.Address,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (poolRecv, poolOut *u256.Uint) {
	zeroForOne := data.tokenIn < data.tokenOut

	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	amount0Str, amount1Str := pl.Swap(
		cross,
		data.tokenIn,
		data.tokenOut,
		data.fee,
		recipient,
		zeroForOne,
		amountSpecified.ToString(),
		sqrtPriceLimitX96.ToString(),
		data.payer,
	)

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)

	poolOut, poolRecv = i256MinMax(amount0, amount1)
	if poolRecv.IsOverflow() || poolOut.IsOverflow() {
		panic("overflow in swapInner")
	}

	// approves pool as spender
	if data.hasNext {
		common.Approve(cross, data.tokenOut, poolAddr, poolOut.Int64())
	}

	return poolRecv, poolOut
}

// RealSwapExecutor implements SwapExecutor for actual swaps.
type RealSwapExecutor struct{}

// execute performs the actual swap execution.
func (e *RealSwapExecutor) execute(p *SingleSwapParams) (amountIn, amountOut *u256.Uint) {
	caller := std.PreviousRealm().Address()
	recipient := routerAddr

	return swapInner(
		p.amountSpecified,
		recipient, // if single swap => user will receive
		zero,      // sqrtPriceLimitX96
		newSwapCallbackData(p, caller, false),
	)
}

// swapDryInner performs a dry-run of a swap operation without executing it.
func swapDryInner(
	amountSpecified *i256.Int,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (poolRecv, poolOut *u256.Uint) {
	zeroForOne := data.tokenIn < data.tokenOut
	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	// check possible
	amount0Str, amount1Str, ok := pl.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,
		zeroForOne,
		amountSpecified.ToString(),
		sqrtPriceLimitX96.ToString(),
	)
	if !ok {
		return zero, zero
	}

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)

	poolOut, poolRecv = i256MinMax(amount0, amount1)
	if poolRecv.IsOverflow() || poolOut.IsOverflow() {
		panic("overflow in swapDryInner")
	}

	return poolRecv, poolOut
}

// DrySwapExecutor implements SwapExecutor for dry swaps.
type DrySwapExecutor struct{}

// execute performs the dry swap execution.
func (e *DrySwapExecutor) execute(p *SingleSwapParams) (amountIn, amountOut *u256.Uint) {
	previousRealmAddr := std.PreviousRealm().Address()

	return swapDryInner(
		p.amountSpecified,
		zero,
		newSwapCallbackData(p, previousRealmAddr, false),
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
