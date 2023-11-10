package router

import (
	"encoding/json"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func BestSwapDry(
	inputToken string,
	outputToken string,
	swapType string,
	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,

	distributionPercent int,
	maxRoutes int,
	maxHops int,
) string {

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] _RPC_call.gno__BestSwapDry() || unknown swapType")
	}

	// get quotes
	quotes := quoteForAllPath( // sored by Ratio DESC
		inputToken,
		outputToken,
		amountSpecified,
		sqrtPriceLimitX96,

		distributionPercent,
		maxRoutes,
		maxHops,
	)
	require(len(quotes) > 0, ufmt.Sprintf("[ROUTER] _RPC_call.gno__gno__BestSwapDry() || len(quotes) == 0, inputToken:%s, outputToken:%s", inputToken, outputToken))

	bestSwaps := findBestPaths(quotes)
	require(len(bestSwaps) > 0, "[ROUTER] _RPC_call.gno__BestSwapDry() || len(bestSwaps) == 0")

	finalSwaps := removeDuplication(bestSwaps)
	require(len(finalSwaps) > 0, "[ROUTER] _RPC_call.gno__BestSwapDry() || len(finalSwaps) == 0")

	rpcReturnBestSwap := RpcReturnBestSwap{}
	rpcReturnBestSwap.SwapType = swapType

	rpcRoutes := []RpcRoute{}

	remainingAmount := amountSpecified
	outputEstimated := bigint(0)
	for i, finalSwap := range finalSwaps {
		numPools := strings.Count(finalSwap.targetPath, ",") / 2
		splitPaths := multiTargetPathToList(finalSwap.targetPath)

		rpcRoute := RpcRoute{
			SwapPct:   finalSwap.pct,
			NumPools:  numPools,
			SwapPaths: splitPaths,
		}
		rpcRoutes = append(rpcRoutes, rpcRoute)

		rpcReturnBestSwap.TotalPct += finalSwap.pct

		if rpcReturnBestSwap.TotalPct == 100 {
			rpcReturnBestSwap.Possible = true
		}

		// ESTIMATE Amount
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
			amountOut := singleSwapDry(singleParams)
			outputEstimated += amountOut
		}

		// MULTI
		if numPools >= 1 && numPools <= 3 {
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
			amountOut := multiSwapDry(swapParams, 0, numPools, finalSwap.targetPath) // iterate here
			outputEstimated += amountOut
		}

		if maxRoutes == 0 {
			break
		}

		maxRoutes -= 1
	}

	rpcReturnBestSwap.RpcRoutes = rpcRoutes
	rpcReturnBestSwap.TotalRoutes = len(rpcRoutes)

	if rpcReturnBestSwap.Possible == true {
		rpcReturnBestSwap.AmountResult = outputEstimated

		if rpcReturnBestSwap.SwapType == "EXACT_IN" {
			rpcReturnBestSwap.AmountSpecified = amountSpecified
		} else {
			rpcReturnBestSwap.AmountSpecified = -amountSpecified
		}
	}

	rr, err := json.Marshal(rpcReturnBestSwap)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_call.gno__BestSwapDry() || json.Marshal error with %v", err))
	}

	return string(rr)
}

func multiTargetPathToList(path string) []string {
	numPools := strings.Count(path, ",") / 2
	splitData := strings.Split(path, ",")

	fullPaths := []string{}
	for i := 0; i < numPools; i++ {
		j := 0
		if i == 0 {
			j = i
		} else {
			j = i * 2
		}

		token0Path := splitData[j]   // 0 > 2 > 4
		fee := splitData[j+1]        // 1 > 3 > 5
		token1Path := splitData[j+2] // 2 > 4 > 6

		fullPath := token0Path + ":" + token1Path + ":" + fee

		fullPaths = append(fullPaths, fullPath)
	}

	return fullPaths
}
