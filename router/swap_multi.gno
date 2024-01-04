package router

import (
	"std"
)

func multiSwap(params SwapParams, currentPoolIndex, numPools int, swapPath string) (firstAmountIn, lastAmountOut bigint) {
	payer := std.GetOrigCaller() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPools {
			recipient = std.DerivePkgAddr("gno.land/r/demo/router")
		} else {
			recipient = params.recipient // user ~= std.GetOrigCaller()
		}

		amountIn, amountOut := _swap(
			params.amountSpecified,
			recipient,
			0,
			SwapCallbackData{
				params.tokenIn,
				params.tokenOut,
				params.fee,
				payer,
			},
		)

		if currentPoolIndex == 1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex < numPools {
			payer = std.DerivePkgAddr("gno.land/r/demo/router")

			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee

			params.amountSpecified = amountOut

		} else {
			return firstAmountIn, amountOut
		}
	}
}

func multiSwapNegative(params SwapParams, numPools int, swapPath string) (fisrtAmountIn, lastAmountOut bigint) {
	swapInfo := []SingleSwapParams{}
	currentPoolIndex := numPools

	// CALCULATE BACKWARD INFO
	for {
		amountIn, amountOut := singleSwapDry(
			SingleSwapParams{
				tokenIn:         params.tokenIn,
				tokenOut:        params.tokenOut,
				fee:             params.fee,
				amountSpecified: params.amountSpecified,
			},
		)

		thisSwap := SingleSwapParams{
			tokenIn:         params.tokenIn,
			tokenOut:        params.tokenOut,
			fee:             params.fee,
			amountSpecified: params.amountSpecified,
		}
		swapInfo = append(swapInfo, thisSwap)

		if currentPoolIndex == 0 {
			break
		} else {
			currentPoolIndex--
			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
			params.amountSpecified = -amountIn
		}
	}

	// PROCESS FORWARD INFO
	currentPoolIndex = len(swapInfo)
	payer := std.GetOrigCaller() // first payer ~= user
	for {
		var recipient std.Address
		currentPoolIndex--
		if currentPoolIndex == 0 {
			recipient = std.GetOrigCaller() // params.recipient // user ~= std.GetOrigCaller()
		} else {
			recipient = std.DerivePkgAddr("gno.land/r/demo/router")
		}

		amountIn, amountOut := _swap(
			swapInfo[currentPoolIndex].amountSpecified,
			recipient,
			0,
			SwapCallbackData{
				swapInfo[currentPoolIndex].tokenIn,
				swapInfo[currentPoolIndex].tokenOut,
				swapInfo[currentPoolIndex].fee,
				payer,
			},
		)

		// save route's first hop's amountIn to check whether crossed limit or not
		if currentPoolIndex == len(swapInfo)-1 {
			fisrtAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return fisrtAmountIn, amountOut
		} else {
			payer = std.DerivePkgAddr("gno.land/r/demo/router")
			swapInfo[currentPoolIndex-1].amountSpecified = amountOut
		}
	}
}

func multiSwapDry(params SwapParams, currentPoolIndex, numPool int, swapPath string) (firstAmountIn, lastAmountOut bigint) {
	payer := std.GetOrigCaller() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPool {
			recipient = std.DerivePkgAddr("gno.land/r/demo/router")
		} else {
			recipient = params.recipient // user ~= std.GetOrigCaller()
		}

		amountIn, amountOut := _swapDry(
			params.amountSpecified,
			recipient,
			0,
			SwapCallbackData{
				params.tokenIn,
				params.tokenOut,
				params.fee,
				payer,
			},
		)

		if currentPoolIndex == 1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex < numPool {
			payer = std.DerivePkgAddr("gno.land/r/demo/router")

			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee

			params.amountSpecified = amountOut
		} else {
			return firstAmountIn, amountOut
		}
	}

}

func multiSwapNegativeDry(params SwapParams, currentPoolIndex int, swapPath string) (firstAmountIn, lastAmountOut bigint) {
	payer := std.DerivePkgAddr("gno.land/r/demo/router")
	numPools := currentPoolIndex

	for {
		var recipient std.Address

		if currentPoolIndex == numPools-1 {
			recipient = params.recipient
		} else {
			recipient = std.DerivePkgAddr("gno.land/r/demo/router")
		}

		amountIn, amountOut := _swapDry(
			params.amountSpecified,
			recipient,
			0,
			SwapCallbackData{
				params.tokenIn,
				params.tokenOut,
				params.fee,
				payer,
			},
		)

		if currentPoolIndex == 0 {
			// save for return
			firstAmountIn = amountIn
		}

		currentPoolIndex--

		if currentPoolIndex != -1 {
			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee

			params.amountSpecified = -amountIn
		} else {
			return firstAmountIn, amountOut
		}
	}
}
