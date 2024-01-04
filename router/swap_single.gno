package router

import (
	"std"
)

func singleSwap(params SingleSwapParams) (amountIn, amountOut bigint) {
	amountIn, amountOut = _swap(
		params.amountSpecified,
		std.GetOrigCaller(), // if single swap => user will recieve
		0,                   // sqrtPriceLimitX96
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // payer ==> msg.sender,
		},
	)

	return amountIn, amountOut
}

func singleSwapDry(params SingleSwapParams) (amountIn, amountOut bigint) {
	amountIn, amountOut = _swapDry(
		params.amountSpecified,
		std.GetOrigCaller(), // if single swap => user will recieve
		0,                   // sqrtPriceLimitX96
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // payer ==> msg.sender,
		},
	)

	return amountIn, amountOut
}
