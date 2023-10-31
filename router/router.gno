package router

import (
	"std"
	"strconv"
	"strings"

	p "gno.land/r/pool"
)

func SwapRoute(
	inputTokenPath string,
	outputTokenPath string,

	amountIn bigint,
	recipient std.Address,
	sqrtPriceLimitX96 bigint,
) (amountOut bigint) {
	numSwaps := findSwapPaths(inputTokenPath, outputTokenPath)

	for i, swapPath := range numSwaps {
		numPools := strings.Count(swapPath, ",") / 2

		for j := i; j < numPools; j++ {
			if numPools < 1 {
				panic("CAN NOT FIND SWAP PATH")
			} else if numPools == 1 {
				// single Swap
				input, output, fee := getSwapData(swapPath, j)

				singleParams := SingleSwapParams{
					tokenIn:           input,
					tokenOut:          output,
					fee:               fee,
					amountIn:          amountIn,
					sqrtPriceLimitX96: sqrtPriceLimitX96,
				}

				amountOut = singleSwap(singleParams)
			} else {
				// multiple Swap
				input, output, fee := getSwapData(swapPath, j-1)
				swapParams := SwapParams{
					tokenIn:  input,
					tokenOut: output,
					fee:      fee,

					recipient:    std.GetOrigCaller(),
					amountIn:     amountIn,
					minAmountOut: amountIn * 5, // r3v4_xxx: need usd price I think
				}

				amountOut = multiSwap(swapParams, i, numPools, swapPath)
			}
		}
	}

	return amountOut
}

func findSwapPaths(
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	tokenPairs := TokenPairs{}
	poolList := p.GetPoolList()

	for i, poolPath := range poolList {
		token0Path, token1Path, pFee := poolPathWithFeeDivide(poolPath)

		{
			k := token0Path
			v := token1Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}

		{
			k := token1Path
			v := token0Path + ":" + strconv.Itoa(pFee)

			tokenPairs[k] = append(tokenPairs[k], v)
		}
	}

	swapPaths = getSwapPaths(tokenPairs, inputTokenPath, outputTokenPath)
	return swapPaths
}

func getSwapPaths(
	tokenPairs TokenPairs,
	inputTokenPath string,
	outputTokenPath string,
) (swapPaths SwapPaths) {
	swapPaths = make(SwapPaths, 0)

	// check if there is path that starts with input
	if len(tokenPairs[inputTokenPath]) == 0 {
		panic("NO POOL")
	}

	// find direct path
	for _, output := range tokenPairs[inputTokenPath] {
		if strings.HasPrefix(output, outputTokenPath) {
			outputPath, outputFee := singlePoolPathWithFeeDivide(output)
			directPath := inputTokenPath + "," + outputFee + "," + outputPath
			swapPaths[len(swapPaths)] = directPath

			tokenPairs[inputTokenPath] = removeItemFromStringArray(tokenPairs[inputTokenPath], output)
		}
	}

	// find nested path
	// r3v4_xx: handle more than three time swap ??
	swapPaths = findTwicePath(tokenPairs, inputTokenPath, outputTokenPath, swapPaths)
	swapPaths = findThreeTimePath(tokenPairs, inputTokenPath, outputTokenPath, swapPaths)

	return
}
