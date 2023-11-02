package router

import (
	"std"
	"strings"
)

func BestSwap(
	inputToken string,
	outputTokenPath string,

	amountIn bigint,
	sqrtPriceLimitX96 bigint,
) {
	// get quotes
	quotes := quoteForAllPath( // sored by Ratio DESC
		inputToken,        // inputToken
		outputTokenPath,   // outputToken
		amountIn,          // amountIn
		sqrtPriceLimitX96, // sqrtPriceLimitX96
	)
	if len(quotes) == 0 {
		panic("router.gno__THERE IS NO QUOTE")
	}

	bestSwaps := []QuoterTarget{}
	totalPct := 100

	for i, quote := range quotes {
		quotePct := quote.pct
		outputRatioX96 := quote.outputRatioX96

		totalPct -= quotePct
		bestSwaps = append(bestSwaps, quote)

		if totalPct <= 0 {
			break
		}
	}

	if len(bestSwaps) == 0 {
		panic("router.gno__CAN'T MAKE BestSwapRoute")
	}

	// DEBUG
	println("DEBUG router.gno__len(bestSwaps):", len(bestSwaps))

	remainingAmount := amountIn
	for i, bestSwap := range bestSwaps {
		numPools := strings.Count(bestSwap.targetPath, ",") / 2

		if numPools < 1 {
			panic("router.gno__CAN NOT FIND SWAP PATH")
		}

		if numPools > 3 {
			panic("router.gno__TOO MANY SWAP PATH")
		}

		// SINGLE
		if numPools == 1 {
			input, output, fee := getSwapData(bestSwap.targetPath, 0)

			singleParams := SingleSwapParams{
				tokenIn:           input,
				tokenOut:          output,
				fee:               fee,
				amountIn:          bestSwap.pctAmount,
				sqrtPriceLimitX96: sqrtPriceLimitX96,
			}
			amountOut := singleSwap(singleParams)
			remainingAmount -= bestSwap.pctAmount
		}

		// MULTI
		if numPools > 1 && numPools <= 3 {
			toSwap := bigint(0)

			// isFinal
			if i == len(bestSwaps)-1 { // last swap routes
				toSwap = remainingAmount
			} else {
				remainingAmount -= bestSwap.pctAmount
				toSwap = bestSwap.pctAmount
			}

			input, output, fee := getSwapData(bestSwap.targetPath, 0)

			swapParams := SwapParams{
				tokenIn:  input,
				tokenOut: output,
				fee:      fee,

				recipient:    std.GetOrigCaller(),
				amountIn:     toSwap,
				minAmountOut: 1, // r3v4_xx: sqrtPriceLimitX96
			}
			amountOut := multiSwap(swapParams, 0, numPools, bestSwap.targetPath) // iterate here
		}
	}
}
