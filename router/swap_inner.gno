package router

import (
	"std"

	p "gno.land/r/demo/pool"
)

func _swap(
	amountSpecified bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountPoolRecv, amountPoolOut bigint) {
	// prepare
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96 == 0 {
		if zeroForOne {
			sqrtPriceLimitX96 = MIN_PRICE
		} else {
			sqrtPriceLimitX96 = MAX_PRICE
		}
	}

	// ROUTER approves POOL as spender
	toApproveAmount := MAX_UINT64
	approveByRegisterCall(data.tokenIn, ADDR_POOL, toApproveAmount)
	approveByRegisterCall(data.tokenOut, ADDR_POOL, toApproveAmount)

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

	return absBigint(maxBigint(amount0, amount1)), absBigint(minBigint(amount0, amount1))
}

func _swapDry(
	amountSpecified bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountPoolRecv, amountPoolOut bigint) {
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
		return 0, 0
	}

	return absBigint(maxBigint(amount0, amount1)), absBigint(minBigint(amount0, amount1))
}

func max(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}

func minBigint(a, b bigint) bigint {
	if a < b {
		return a
	}
	return b
}

func maxBigint(a, b bigint) bigint {
	if a > b {
		return a
	}
	return b
}
