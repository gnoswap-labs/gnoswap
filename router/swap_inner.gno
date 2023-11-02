package router

import (
	"std"

	p "gno.land/r/pool"
)

func _swap(
	amountIn bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountOut bigint) {
	// prepare
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96 == 0 {
		if zeroForOne {
			sqrtPriceLimitX96 = MIN_PRICE
		} else {
			sqrtPriceLimitX96 = MAX_PRICE
		}
	}

	// dry swap -> esteimate amount -> approve exact amount
	// r3v4_xx: or little bit more
	approveAmount0, approveAmount1, _ := p.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountIn,
		sqrtPriceLimitX96,
	)

	// ROUTER approves POOL as spender
	approveByRegisterCall(data.tokenIn, ADDR_POOL, abs(approveAmount0))  // r3v4_xxx
	approveByRegisterCall(data.tokenOut, ADDR_POOL, abs(approveAmount1)) // r3v4_xxx

	amount0, amount1 := p.Swap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountIn,
		sqrtPriceLimitX96,

		data.payer,
	)

	if zeroForOne {
		amountOut = -amount1
	} else {
		amountOut = -amount0
	}

	return amountOut
}

func _swapDry(
	amountIn bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountOut bigint) {
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96 == 0 {
		if zeroForOne {
			sqrtPriceLimitX96 = MIN_PRICE
		} else {
			sqrtPriceLimitX96 = MAX_PRICE
		}
	}

	// check possible
	amount0, amount1, ok := p.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountIn,
		sqrtPriceLimitX96,
	)
	if !ok {
		return 0
	}

	// if success
	if zeroForOne {
		amountOut = -amount1
	} else {
		amountOut = -amount0
	}

	return amountOut
}

func abs(x bigint) uint64 {
	if x < 0 {
		return uint64(-x)
	}

	return uint64(x)
}
