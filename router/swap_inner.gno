package router

import (
	"std"

	"gno.land/p/demo/ufmt"

	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func _swap(
	amountSpecified *i256.Int,
	recipient std.Address,
	sqrtPriceLimitX96 *u256.Uint,
	data SwapCallbackData,
) (*u256.Uint, *u256.Uint) { // poolRecv, poolOut
	// prepare
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96.IsZero() {
		if zeroForOne {
			sqrtPriceLimitX96 = common.TickMathGetSqrtRatioAtTick(getMinTick(data.fee))
			sqrtPriceLimitX96 = new(u256.Uint).Add(sqrtPriceLimitX96, u256.One())
		} else {
			sqrtPriceLimitX96 = common.TickMathGetSqrtRatioAtTick(getMaxTick(data.fee))
			sqrtPriceLimitX96 = new(u256.Uint).Sub(sqrtPriceLimitX96, u256.One())
		}
	}

	// ROUTER approves POOL as spender
	approveByRegisterCall(data.tokenIn, consts.POOL_ADDR, consts.UINT64_MAX)
	approveByRegisterCall(data.tokenOut, consts.POOL_ADDR, consts.UINT64_MAX)

	amount0Str, amount1Str := pl.Swap( // int256, int256
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient.String(),
		zeroForOne,
		amountSpecified.ToString(),
		sqrtPriceLimitX96.ToString(),

		data.payer.String(),
	)
	amount0, err := i256.FromDecimal(amount0Str)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__Swap() || i256.FromDecimal(amount0Str(%s) failed", amount0Str))
	}
	amount1, err := i256.FromDecimal(amount1Str)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__Swap() || i256.FromDecimal(amount1Str(%s) failed", amount1Str))
	}

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

	amount0, err := i256.FromDecimal(amount0Str)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__Swap() || i256.FromDecimal(amount0Str(%s) failed", amount0Str))
	}
	amount1, err := i256.FromDecimal(amount1Str)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__Swap() || i256.FromDecimal(amount1Str(%s) failed", amount1Str))
	}

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
		panic(ufmt.Sprintf("[ROUTER] router.gno__getMinTick() || unknown fee(%d)", fee))
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
		panic(ufmt.Sprintf("[ROUTER] router.gno__getMaxTick() || unknown fee(%d)", fee))
	}
}
