package v1

import (
	"chain/runtime"

	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/router"

	i256 "gno.land/p/gnoswap/int256"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"

	pl "gno.land/r/gnoswap/pool"
	plv1 "gno.land/r/gnoswap/pool/v1"
)

const (
	MIN_SQRT_RATIO string = "4295128739"                                        // same as TickMathGetSqrtRatioAtTick(MIN_TICK)
	MAX_SQRT_RATIO string = "1461446703485210103287273052203988822378723970342" // same as TickMathGetSqrtRatioAtTick(MAX_TICK)
)

// Precomputed sqrt price limits per fee tier and direction.
// TickMathGetSqrtRatioAtTick costs ~2M-2.4M gas per call and only depends on fee tier,
// so we compute all 8 values (4 fees × 2 directions) once at init and cache them.
// Callers use the cached pointer read-only (only .ToString() is called on the result).
var (
	sqrtPriceLimitForward  = make(map[uint32]*u256.Uint) // zeroForOne=true:  sqrtRatioAtTick(minTick+1) + 1
	sqrtPriceLimitBackward = make(map[uint32]*u256.Uint) // zeroForOne=false: sqrtRatioAtTick(maxTick-1) - 1
)

func init() {
	for _, fee := range []uint32{plv1.FeeTier100, plv1.FeeTier500, plv1.FeeTier3000, plv1.FeeTier10000} {
		// zeroForOne=true: price must stay above minimum
		minTick := getMinTick(fee) + 1
		fwd := common.TickMathGetSqrtRatioAtTick(minTick) // returns a fresh allocation
		if fwd.IsZero() {
			fwd = u256.MustFromDecimal(MIN_SQRT_RATIO)
		}
		fwd.Add(fwd, one) // fwd += 1 in-place
		sqrtPriceLimitForward[fee] = fwd

		// zeroForOne=false: price must stay below maximum
		maxTick := getMaxTick(fee) - 1
		bwd := common.TickMathGetSqrtRatioAtTick(maxTick) // returns a fresh allocation
		if bwd.IsZero() {
			bwd = u256.MustFromDecimal(MAX_SQRT_RATIO)
		}
		bwd.Sub(bwd, one) // bwd -= 1 in-place
		sqrtPriceLimitBackward[fee] = bwd
	}
}

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
			// assert is pool to prevent unauthorized callback
			caller := runtime.PreviousRealm().Address()
			access.AssertIsPool(caller)

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
	recipient := access.MustGetAddress(prbac.ROLE_ROUTER.String())

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

// calculateSqrtPriceLimitForSwap returns the price limit for a swap operation.
// If a non-zero limit is provided by the caller, it is returned as-is.
// Otherwise, returns the precomputed limit for the given fee tier and direction.
// The returned pointer is shared (read-only — callers must not mutate it).
func calculateSqrtPriceLimitForSwap(zeroForOne bool, fee uint32, sqrtPriceLimitX96 *u256.Uint) *u256.Uint {
	if !sqrtPriceLimitX96.IsZero() {
		return sqrtPriceLimitX96
	}

	if zeroForOne {
		return mustGetSqrtPriceLimit(sqrtPriceLimitForward, fee)
	}
	return mustGetSqrtPriceLimit(sqrtPriceLimitBackward, fee)
}

func mustGetSqrtPriceLimit(limits map[uint32]*u256.Uint, fee uint32) *u256.Uint {
	limit, ok := limits[fee]
	if !ok {
		panic(addDetailToError(
			errInvalidPoolFeeTier,
			ufmt.Sprintf("unknown fee(%d)", fee),
		))
	}
	return limit
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
