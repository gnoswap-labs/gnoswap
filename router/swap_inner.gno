package router

import (
	"std"

	p "gno.land/r/pool"
)

func _swap(
	amountSpecified bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountResult bigint) {
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
	approveAmount0, approveAmount1, _ := p.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
	)

	// ROUTER approves POOL as spender
	approveByRegisterCall(data.tokenIn, ADDR_POOL, abs(approveAmount0))
	approveByRegisterCall(data.tokenOut, ADDR_POOL, abs(approveAmount1))

	amount0, amount1 := p.Swap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,

		data.payer,
	)

	if amountSpecified > 0 {
		if zeroForOne {
			amountResult = -amount1
		} else {
			amountResult = -amount0
		}
	} else {
		if zeroForOne {
			amountResult = amount0
		} else {
			amountResult = amount1
		}
	}

	return amountResult
}

func _swapDry(
	amountSpecified bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountResult bigint) {
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
		amountSpecified,
		sqrtPriceLimitX96,
	)
	if !ok {
		return 0
	}

	if amountSpecified > 0 {
		if zeroForOne {
			amountResult = -amount1
		} else {
			amountResult = -amount0
		}
	} else {
		if zeroForOne {
			amountResult = amount0
		} else {
			amountResult = amount1
		}
	}

	return amountResult
}

func abs(x bigint) uint64 {
	if x < 0 {
		return uint64(-x)
	}

	return uint64(x)
}
