package router

import (
	"std"

	p "gno.land/r/pool"
)

type SingleSwapParams struct {
	tokenIn           string
	tokenOut          string
	fee               uint16
	amountIn          bigint
	sqrtPriceLimitX96 bigint
}

func singleSwap(params SingleSwapParams) (amountOut bigint) {
	amountOut = _swap(
		params.amountIn,
		std.PrevRealm().Addr(), // msg.sender
		params.sqrtPriceLimitX96,
		SwapCallbackData{
			params.tokenIn,
			params.tokenOut,
			params.fee,
			std.PrevRealm().Addr(), // msg.sender,
		},
	)

	return amountOut
}

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
	var hasMultiplePools bool

	for {
		hasMultiplePools = currentPoolIndex < numPool

		var recipient std.Address
		if hasMultiplePools {
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

		if hasMultiplePools {
			payer = std.DerivePkgAddr("gno.land/r/router")

			nextInput, nextOutput, nextFee := getSwapData(swapPath, currentPoolIndex)
			params.tokenIn = nextInput
			params.tokenOut = nextOutput
			params.fee = nextFee

			currentPoolIndex++
		} else {
			amountOut = params.amountIn
			return amountOut
		}
	}

	if amountOut < params.minAmountOut {
		panic("Too few receive")
	}
}

func _swap(
	amountIn bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
	data SwapCallbackData,
) (amountOut bigint) {
	// prepare
	zeroForOne := data.tokenIn < data.tokenOut

	if sqrtPriceLimitX96 == 0 {
		if zeroForOne {
			sqrtPriceLimitX96 = MIN_PRICE
		} else {
			sqrtPriceLimitX96 = MAX_PRICE
		}
	}

	// check possible
	_, _, ok := p.DrySwap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountIn,
		sqrtPriceLimitX96,
	)
	if !ok {
		return 0
	}

	amount0, amount1 := p.Swap(
		data.tokenIn,
		data.tokenOut,
		data.fee,

		recipient,
		zeroForOne,
		amountIn,
		sqrtPriceLimitX96,
	)

	// if success
	if zeroForOne {
		amountOut = -amount1
	} else {
		amountOut = -amount0
	}

	return amountOut
}
