package router

import (
	"std"

	"gno.land/p/demo/ufmt"
)

type SingleSwapParams struct {
	tokenIn           string
	tokenOut          string
	fee               uint16
	amountSpecified   bigint
	minOrMax          bigint
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

	if params.amountSpecified > 0 {
		// amountSpecified > 0 == sent
		// minOrMax == min recv
		if amountOut < params.minOrMax {
			panic(ufmt.Sprintf("[ROUTER] singleSwapDry() || Too few receive(expectedMin:%d, actual:%d)", params.minOrMax, amountOut))
		}
	} else {
		// amountSpecified < 0 == recv
		// minOrMax == max sent
		if amountOut > params.minOrMax {
			panic(ufmt.Sprintf("[ROUTER] singleSwapDry() || Too many request(expectedMax:%d, actual:%d)", params.minOrMax, amountOut))
		}
	}

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
	// it is dry swap => no need to check slippage
	return amountOut
}
