package router

import (
	"std"
)

type SingleSwapParams struct {
	tokenIn           string
	tokenOut          string
	fee               uint16
	amountSpecified   bigint
	sqrtPriceLimitX96 bigint
}

func singleSwap(params SingleSwapParams) (amountOut bigint) {
	amountOut = _swap(
		params.amountSpecified,
		std.GetOrigCaller(), // if single swap => user will recieve
		params.sqrtPriceLimitX96,
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // payer ==> msg.sender,
		},
	)
	return amountOut
}

func singleSwapDry(params SingleSwapParams) (amountOut bigint) {
	amountOut = _swapDry(
		params.amountSpecified,
		std.GetOrigCaller(), // if single swap => user will recieve
		params.sqrtPriceLimitX96,
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // payer ==> msg.sender,
		},
	)
	return amountOut
}
