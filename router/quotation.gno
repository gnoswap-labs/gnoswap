package router

import (
	"sort"
	"std"
	"strings"
)

func quoteForAllPath(
	inputTokenPath string,
	outputTokenPath string,

	amountIn bigint,
	sqrtPriceLimitX96 bigint,
) (quoterTargets []QuoterTarget) {
	swapPaths := findSwapPaths(inputTokenPath, outputTokenPath)
	swapPcts := calculatePercentages(amountIn) // 5% - 100, 10% - 200, ...., 100% - 2000

	for _, swapPath := range swapPaths {
		for pct, pctAmount := range swapPcts {
			quoterTarget := QuoterTarget{
				pct:            pct,
				pctAmount:      pctAmount,
				targetPath:     swapPath,
				outputRatioX96: bigint(0), // will update later
			}
			quoterTargets = append(quoterTargets, quoterTarget)
		}
	}

	// DrySwap to calculate
	for i, quoterTarget := range quoterTargets {
		numPools := strings.Count(quoterTarget.targetPath, ",") / 2

		if numPools < 1 {
			panic("quotation.gno__CAN NOT FIND SWAP PATH")
		}

		if numPools > 3 {
			panic("quotation.gno__TOO MANY SWAP PATH")
		}

		if numPools == 1 {
			input, output, fee := getSwapData(quoterTarget.targetPath, 0)

			singleParams := SingleSwapParams{
				tokenIn:           input,
				tokenOut:          output,
				fee:               fee,
				amountIn:          quoterTarget.pctAmount, // 5%, 10%, ... 100%
				sqrtPriceLimitX96: sqrtPriceLimitX96,
			}

			estimatedOut := singleSwapDry(singleParams)
			if estimatedOut > 0 {
				outputRatioX96 := estimatedOut * Q96 / quoterTarget.pctAmount * Q96 / Q96 // divide this value by Q96 => will get float ratio
				quoterTarget.outputRatioX96 = outputRatioX96
				quoterTargets[i] = quoterTarget
			}
		}

		if numPools > 1 && numPools <= 3 {
			input, output, fee := getSwapData(quoterTarget.targetPath, 0)

			swapParams := SwapParams{
				tokenIn:  input,
				tokenOut: output,
				fee:      fee,

				recipient:    std.GetOrigCaller(),
				amountIn:     quoterTarget.pctAmount, // 5%, 10%, ... 100%
				minAmountOut: 1,                      // r3v4_xx: sqrtPriceLimitX96
			}

			estimatedOut := multiSwapDry(swapParams, 0, numPools, quoterTarget.targetPath) // will iterate here to cover multi pools
			if estimatedOut > 0 {
				outputRatioX96 := estimatedOut * Q96 / quoterTarget.pctAmount * Q96 / Q96
				quoterTarget.outputRatioX96 = outputRatioX96
				quoterTargets[i] = quoterTarget
			}
		}
	}

	// it contains outputRatio with 0 which is impossible path
	// remove path with 0 ratio
	var finalTargets []QuoterTarget
	for _, quote := range quoterTargets {
		if quote.outputRatioX96 > 0 {
			finalTargets = append(finalTargets, quote)
		}
	}

	// sort this struct descending by ratio then return
	sort.Sort(ByOutputRatioDesc(finalTargets))
	return finalTargets
}

func calculatePercentages(amount bigint) map[int]bigint { // map[pct][value]
	percentages := make(map[int]bigint)

	for i := 5; i <= 100; i += 5 {
		percentage := (bigint(i) * amount) / 100
		percentages[i] = percentage
	}

	return percentages
}
