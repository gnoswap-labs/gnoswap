package router

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func BestSwap(
	inputToken string,
	outputToken string,
	swapType string,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) {
	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
		amountSpecified = -amountSpecified
	default:
		panic("UNKNOWN TYPE")
	}

	// get quotes
	quotes := quoteForAllPath( // sorted by ratio DESC
		inputToken,
		outputToken,
		amountSpecified,
		sqrtPriceLimitX96,
	)
	require(len(quotes) != 0, ufmt.Sprintf("[ROUTER] router.gno__BestSwap() || len(quotes) == 0, inputToken:%s, outputToken:%s", inputToken, outputToken))

	bestSwaps := findBestPaths(quotes)
	require(len(bestSwaps) != 0, "[ROUTER] router.gno__BestSwap() || len(bestSwaps) == 0")

	finalSwaps := removeDuplication(bestSwaps)
	require(len(finalSwaps) != 0, "[ROUTER] router.gno__BestSwap() || len(finalSwaps) == 0")

	remainingAmount := amountSpecified

	for i, finalSwap := range finalSwaps {
		numPools := strings.Count(finalSwap.targetPath, ",") / 2
		require(numPools >= 1 && numPools < 3, ufmt.Sprintf("[ROUTER] router.gno__BestSwap() || numPools should 1 ~ 3, but found %d", numPools))

		// SINGLE
		if numPools == 1 {
			toSwap := bigint(0)

			// isFinal
			if i == len(finalSwaps)-1 { // last swap routes
				toSwap = remainingAmount
			} else {
				remainingAmount -= finalSwap.pctAmount
				toSwap = finalSwap.pctAmount
			}

			input, output, fee := getSwapData(finalSwap.targetPath, 0)
			singleParams := SingleSwapParams{
				tokenIn:           input,
				tokenOut:          output,
				fee:               fee,
				amountSpecified:   toSwap,
				sqrtPriceLimitX96: sqrtPriceLimitX96,
			}
			amountOut := singleSwap(singleParams)
		}

		// MULTI
		if numPools >= 2 && numPools <= 3 {
			toSwap := bigint(0)

			// isFinal
			if i == len(finalSwaps)-1 { // last swap routes
				toSwap = remainingAmount
			} else {
				remainingAmount -= finalSwap.pctAmount
				toSwap = finalSwap.pctAmount
			}

			input, output, fee := getSwapData(finalSwap.targetPath, 0)
			swapParams := SwapParams{
				tokenIn:         input,
				tokenOut:        output,
				fee:             fee,
				recipient:       std.GetOrigCaller(),
				amountSpecified: toSwap,
				minAmountOut:    1,
			}
			amountOut := multiSwap(swapParams, 0, numPools, finalSwap.targetPath) // iterate here
		}
	}
}
