package router

import (
	"std"

	"gno.land/p/demo/ufmt"

	pl "gno.land/r/gnoswap/v1/pool"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func calculateSqrtPriceLimitForSwap(zeroForOne bool, fee uint32, sqrtPriceLimitX96 *u256.Uint) *u256.Uint {
	if !sqrtPriceLimitX96.IsZero() {
		return sqrtPriceLimitX96
	}

	if zeroForOne {
		minTick := getMinTick(fee)
		sqrtPriceLimitX96 = common.TickMathGetSqrtRatioAtTick(minTick)
		return sqrtPriceLimitX96.Add(sqrtPriceLimitX96, u256.One())
	}

	maxTick := getMaxTick(fee)
	sqrtPriceLimitX96 = common.TickMathGetSqrtRatioAtTick(maxTick)
	return sqrtPriceLimitX96.Sub(sqrtPriceLimitX96, u256.One())
}

func _swap(
	amountSpecified *i256.Int,
	recipient std.Address,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (*u256.Uint, *u256.Uint) { // poolRecv, poolOut
	zeroForOne := data.tokenIn < data.tokenOut

	sqrtPriceLimitX96 = calculateSqrtPriceLimitForSwap(zeroForOne, data.fee, sqrtPriceLimitX96)

	// ROUTER approves POOL as spender
	approveByRegisterCall(data.tokenIn, consts.POOL_ADDR, consts.UINT64_MAX)
	approveByRegisterCall(data.tokenOut, consts.POOL_ADDR, consts.UINT64_MAX)

	amount0Str, amount1Str := pl.Swap( // int256, int256
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

	poolRecv := i256Max(amount0, amount1)
	poolOut := i256Min(amount0, amount1)

	return poolRecv.Abs(), poolOut.Abs()
}

func _swapDry(
	amountSpecified *i256.Int,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (*u256.Uint, *u256.Uint) { // poolRecv, poolOut
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96.IsZero() {
		if zeroForOne {
			sqrtPriceLimitX96 = u256.MustFromDecimal(consts.MIN_PRICE)
		} else {
			sqrtPriceLimitX96 = u256.MustFromDecimal(consts.MAX_PRICE)
		}
	}

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
		return u256.Zero(), u256.Zero()
	}

	amount0 := i256.MustFromDecimal(amount0Str)
	amount1 := i256.MustFromDecimal(amount1Str)

	poolRecv := i256Max(amount0, amount1)
	poolOut := i256Min(amount0, amount1)

	return poolRecv.Abs(), poolOut.Abs()
}

func i256Min(x, y *i256.Int) *i256.Int {
	if x.Lt(y) {
		return x
	}
	return y
}

func i256Max(x, y *i256.Int) *i256.Int {
	if x.Gt(y) {
		return x
	}
	return y
}

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
			ufmt.Sprintf("swap_inner.gno__getMaxTick() || unknown fee(%d)", fee),
		))
	}
}

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
			ufmt.Sprintf("swap_inner.gno__getMaxTick() || unknown fee(%d)", fee),
		))
	}
}
