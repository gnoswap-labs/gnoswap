package router

import (
	"std"

	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

func multiSwap(params SwapParams, currentPoolIndex, numPools int, swapPath string) (*u256.Uint, *u256.Uint) { // firstAmountIn, lastAmountOut
	firstAmountIn := u256.Zero()

	payer := std.PrevRealm().Addr() // user

	for {
		var recipient std.Address
		currentPoolIndex++

		if currentPoolIndex < numPools {
			recipient = consts.ROUTER_ADDR
		} else {
			recipient = params.recipient
		}

		amountIn, amountOut := swapInner(
			params.amountSpecified,
			recipient,
			u256.Zero(),
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

		if currentPoolIndex >= numPools {
			return firstAmountIn, amountOut
		}

		payer = consts.ROUTER_ADDR

		nextInput, nextOutput, nextFee := getDataForMultiPath(swapPath, currentPoolIndex)
		params.tokenIn = nextInput
		params.tokenOut = nextOutput
		params.fee = nextFee

		params.amountSpecified = i256.FromUint256(amountOut)
	}
}

func multiSwapNegative(params SwapParams, numPools int, swapPath string) (*u256.Uint, *u256.Uint) { // firstAmountIn, lastAmountOut
	firstAmountIn := u256.Zero()

	swapInfo := []SingleSwapParams{}
	currentPoolIndex := numPools

	// CALCULATE BACKWARD INFO
	for {
		amountIn, _ := singleSwap(
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
			intAmountIn := i256.FromUint256(amountIn)

			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee
			params.amountSpecified = i256.Zero().Neg(intAmountIn)
		}
	}

	// PROCESS FORWARD INFO
	currentPoolIndex = len(swapInfo)
	payer := std.PrevRealm().Addr() // first payer ≈ user
	for {
		var recipient std.Address
		currentPoolIndex--
		if currentPoolIndex == 0 {
			recipient = std.PrevRealm().Addr() // params.recipient ≈ user
		} else {
			recipient = consts.ROUTER_ADDR
		}

		amountIn, amountOut := swapInner(
			swapInfo[currentPoolIndex].amountSpecified,
			recipient,
			u256.Zero(),
			SwapCallbackData{
				swapInfo[currentPoolIndex].tokenIn,
				swapInfo[currentPoolIndex].tokenOut,
				swapInfo[currentPoolIndex].fee,
				payer,
			},
		)

		// save route's first hop's amountIn to check whether crossed limit or not
		if currentPoolIndex == len(swapInfo)-1 {
			firstAmountIn = amountIn
		}

		if currentPoolIndex == 0 {
			return firstAmountIn, amountOut
		}

		payer = consts.ROUTER_ADDR
		swapInfo[currentPoolIndex-1].amountSpecified = i256.FromUint256(amountOut)
	}
}
