package router

import (
	"std"
)

type SwapParams struct {
	tokenIn  string
	tokenOut string
	fee      uint16

	recipient       std.Address
	amountSpecified bigint
	minAmountOut    bigint
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

		params.amountSpecified = _swap(
			params.amountSpecified, // amountSpecified
			recipient,              // recipient
			0,                      // sqrtPriceLimitX96
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
			amountOut = params.amountSpecified
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

		params.amountSpecified = _swapDry(
			params.amountSpecified, // amountSpecified
			recipient,              // recipient
			0,                      // sqrtPriceLimitX96
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
			amountOut = params.amountSpecified
			return amountOut
		}
	}

	if amountOut < params.minAmountOut {
		panic("Too few receive")
	}
}

func multiSwapNegativeDry(params SwapParams, currentPoolIndex int, swapPath string) (amountOut bigint) {
	payer := std.DerivePkgAddr("gno.land/r/router")

	params.tokenIn, params.tokenOut, params.fee = getSwapData(swapPath, currentPoolIndex)

	numPools := currentPoolIndex
	for {
		var recipient std.Address
		currentPoolIndex--

		if currentPoolIndex == numPools-1 {
			recipient = params.recipient
		} else {
			recipient = std.DerivePkgAddr("gno.land/r/router")
		}

		params.amountSpecified = _swapDry(
			params.amountSpecified, // amountSpecified
			recipient,              // recipient
			0,                      // sqrtPriceLimitX96
			SwapCallbackData{
				params.tokenIn,  // tokenIn
				params.tokenOut, // tokenOut
				params.fee,      // fee
				payer,           // payer
			},
		)

		if currentPoolIndex != -1 {
			nextInput, nextOutput, nextFee := getSwapData(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee

			// input amounts derived in the last stage must be used again as the n-1th output amounts
			// >> must be negative
			params.amountSpecified = -params.amountSpecified

		} else {
			amountOut = params.amountSpecified
			return amountOut
		}
	}

	if amountOut < params.minAmountOut {
		panic("Too few receive")
	}
}
