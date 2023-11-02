package router

import (
	"std"
)

type SwapParams struct {
	tokenIn  string
	tokenOut string
	fee      uint16

	recipient    std.Address
	amountIn     bigint
	minAmountOut bigint
}

func multiSwap(params SwapParams, currentPoolIndex, numPool int, swapPath string) (amountOut bigint) {
	payer := std.GetOrigCaller() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPool {
			recipient = std.DerivePkgAddr("gno.land/r/router")
		} else {
			recipient = params.recipient // user ~= std.GetOrigCaller()
		}

		params.amountIn = _swap(
			params.amountIn, // amountIn
			recipient,       // recipient
			0,               // sqrtPriceLimitX96
			SwapCallbackData{
				params.tokenIn,  // tokenIn
				params.tokenOut, // tokenOut
				params.fee,      // fee
				payer,           // payer
			},
		)

		if currentPoolIndex < numPool {
			payer = std.DerivePkgAddr("gno.land/r/router")

			nextInput, nextOutput, nextFee := getSwapData(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
		} else {
			amountOut = params.amountIn
			return amountOut
		}
	}

	if amountOut < params.minAmountOut {
		panic("Too few receive")
}
}

func multiSwapDry(params SwapParams, currentPoolIndex, numPool int, swapPath string) (amountOut bigint) {
	payer := std.GetOrigCaller() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPool {
			recipient = std.DerivePkgAddr("gno.land/r/router")
		} else {
			recipient = params.recipient // user ~= std.GetOrigCaller()
		}

		params.amountIn = _swapDry(
			params.amountIn, // amountIn
			recipient,       // recipient
			0,               // sqrtPriceLimitX96
			SwapCallbackData{
				params.tokenIn,  // tokenIn
				params.tokenOut, // tokenOut
				params.fee,      // fee
				payer,           // payer
			},
		)

		if currentPoolIndex < numPool {
			payer = std.DerivePkgAddr("gno.land/r/router")

			nextInput, nextOutput, nextFee := getSwapData(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
		} else {
			amountOut = params.amountIn
			return amountOut
		}
	}

	if amountOut < params.minAmountOut {
		panic("Too few receive")
	}
}
