package router

import (
	"std"
)

func multiSwap(params SwapParams, currentPoolIndex, numPools int, swapPath string) (amountOut bigint) {
	payer := std.GetOrigCaller() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPools {
			recipient = std.DerivePkgAddr("gno.land/r/router")
		} else {
			recipient = params.recipient // user ~= std.GetOrigCaller()
		}

		params.amountSpecified = _swap(
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

		if currentPoolIndex < numPools {
			payer = std.DerivePkgAddr("gno.land/r/router")

			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
		} else {
			amountOut = params.amountSpecified
			return amountOut
		}
	}
}

func multiSwapNegative(params SwapParams, numPools int, swapPath string) (amountOut bigint) {
	swapInfo := []SingleSwapParams{}
	currentPoolIndex := numPools

	// CALCULATE BACKWARD INFO
	for {
		wantedSingle := singleSwapDry(
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
			params.amountSpecified = -wantedSingle
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
			recipient = std.DerivePkgAddr("gno.land/r/router")
		}

		resultAmount := _swap(
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

		if currentPoolIndex == 0 {
			return amountOut
		} else {
			payer = std.DerivePkgAddr("gno.land/r/router")
			amountOut = resultAmount // return first swap input amount
		}
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

		if currentPoolIndex < numPool {
			payer = std.DerivePkgAddr("gno.land/r/router")

			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
		} else {
			amountOut = params.amountSpecified
			return amountOut
		}
	}

}

func multiSwapNegativeDry(params SwapParams, currentPoolIndex int, swapPath string) (amountOut bigint) {
	payer := std.DerivePkgAddr("gno.land/r/router")
	numPools := currentPoolIndex

	for {
		var recipient std.Address

		if currentPoolIndex == numPools-1 {
			recipient = params.recipient
		} else {
			recipient = std.DerivePkgAddr("gno.land/r/router")
		}

		params.amountSpecified = _swapDry(
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
		currentPoolIndex--

		if currentPoolIndex != -1 {
			nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
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
}
