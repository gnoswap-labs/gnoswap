package router

import (
	"encoding/json"
	"strings"

	"gno.land/p/demo/ufmt"
)

func BestSwapDry(
	inputToken string,
	outputToken string,

	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) string {
	// get quotes
	quotes := quoteForAllPath( // sored by Ratio DESC
		inputToken,        // inputToken
		outputToken,       // outputToken
		amountSpecified,   // amountIn
		sqrtPriceLimitX96, // sqrtPriceLimitX96
	)
	if len(quotes) == 0 {
		panic("rpc_call.gno__THERE IS NO QUOTE")
	}

	bestSwaps := findBestPaths(quotes)
	if len(bestSwaps) == 0 {
		panic("rpc_call.gno__CAN'T MAKE BestSwapRoute")
	}

	finalSwaps := removeDuplication(bestSwaps)
	if len(bestSwaps) == 0 {
		panic("rpc_call.gno__CAN'T MAKE FinalSwapRoute")
	}

	rpcReturnBestSwap := RpcReturnBestSwap{}
	rpcReturnBestSwap.TotalRoutes = len(finalSwaps)

	rpcRoutes := []RpcRoute{}

	for i, finalSwap := range finalSwaps {
		numSwaps := strings.Count(finalSwap.targetPath, ",") / 2
		splitPaths := multiTargetPathToList(finalSwap.targetPath)

		rpcRoute := RpcRoute{
			SwapPct:   finalSwap.pct,
			NumSwaps:  numSwaps,
			SwapPaths: splitPaths,
		}
		rpcRoutes = append(rpcRoutes, rpcRoute)

		rpcReturnBestSwap.TotalPct += finalSwap.pct

		if rpcReturnBestSwap.TotalPct == 100 {
			rpcReturnBestSwap.Possible = true
		}
	}
	rpcReturnBestSwap.RpcRoutes = rpcRoutes

	rr, err := json.Marshal(rpcReturnBestSwap)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] rpc_call.gno__BestSwapDry() || %v", err))
	}

	return string(rr)
}

type RpcRoute struct {
	SwapPct   int      `json:"swapPct"`
	NumSwaps  int      `json:"numSwaps"`
	SwapPaths []string `json:"swapPaths"`
}

type RpcReturnBestSwap struct {
	TotalRoutes int        `json:"totalRoutes"`
	TotalPct    int        `json:"totalPct"`
	Possible    bool       `json:"possible"`
	AmountIn    bigint     `json:"amountIn"`
	AmountOut   bigint     `json:"amountOut"`
	RpcRoutes   []RpcRoute `json:"rpcRoutes"`
}

func multiTargetPathToList(path string) []string {
	numSwaps := strings.Count(path, ",") / 2
	splitData := strings.Split(path, ",")

	fullPaths := []string{}
	for i := 0; i < numSwaps; i++ {
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
