package router

import (
	"sort"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func quoteForAllPath(
	inputTokenPath string,
	outputTokenPath string,

	amountSpecified bigint,
	sqrtPriceLimitX96 bigint,
) (quoterTargets []QuoterTarget) {
	swapPaths := findSwapPaths(inputTokenPath, outputTokenPath)
	swapPcts := calculatePercentages(amountSpecified) // 5% - 100, 10% - 200, ...., 100% - 2000

	for _, swapPath := range swapPaths {
		for pct, pctAmount := range swapPcts {
			quoterTarget := QuoterTarget{
				pct:            pct,
				pctAmount:      pctAmount,
				targetPath:     swapPath,
				resultRatioX96: bigint(0), // will update later
			}
			quoterTargets = append(quoterTargets, quoterTarget)
		}
	}

	// DrySwap to calculate
	for i, quoterTarget := range quoterTargets {
		numPools := strings.Count(quoterTarget.targetPath, ",") / 2
		require(numPools > 1 && numPools < 3, ufmt.Sprintf("[ROUTER] router.gno__quoteForAllPath() || numPools should 1 ~ 3, but found %d", numPools))

		if numPools == 1 {
			input, output, fee := getSwapData(quoterTarget.targetPath, 0)

			singleParams := SingleSwapParams{
				tokenIn:           input,
				tokenOut:          output,
				fee:               fee,
				amountSpecified:   quoterTarget.pctAmount,
				sqrtPriceLimitX96: sqrtPriceLimitX96,
			}

			estimatedResult := singleSwapDry(singleParams)
			if estimatedResult > 0 {
				if amountSpecified > 0 {
					resultRatioX96 := estimatedResult * Q96 / quoterTarget.pctAmount * Q96 / Q96
					quoterTarget.resultRatioX96 = resultRatioX96
					quoterTargets[i] = quoterTarget
				} else {
					resultRatioX96 := -quoterTarget.pctAmount * Q96 / estimatedResult * Q96 / Q96
					quoterTarget.resultRatioX96 = resultRatioX96
					quoterTargets[i] = quoterTarget
				}
			} else {
				panic("[ROUTER] quotation.gno__quoteForAllPath() || SINGLE__estimateResult < 0")
			}
		}

		if numPools > 1 && numPools <= 3 {
			input, output, fee := getSwapData(quoterTarget.targetPath, 0)

			swapParams := SwapParams{
				tokenIn:  input,
				tokenOut: output,
				fee:      fee,

				recipient:       std.GetOrigCaller(),
				amountSpecified: quoterTarget.pctAmount,
				minAmountOut:    1, // r3v4_xx: sqrtPriceLimitX96
			}

			// if amountSpecified > 0, proceed forward
			// if not, proceed with backward
			if amountSpecified > 0 {
				estimatedResult := multiSwapDry(swapParams, 0, numPools, quoterTarget.targetPath) // will iterate here to cover multi pools
				if estimatedResult > 0 {
					resultRatioX96 := estimatedResult * Q96 / quoterTarget.pctAmount * Q96 / Q96
					quoterTarget.resultRatioX96 = resultRatioX96
					quoterTargets[i] = quoterTarget
				} else {
					panic("[ROUTER] quotation.gno__quoteForAllPath() || MULTI__PositiveAmountSpecified__estimateResult < 0")
				}
			} else {
				estimatedResult := multiSwapNegativeDry(swapParams, numPools-1, quoterTarget.targetPath) // will iterate here to cover multi pools
				if estimatedResult > 0 {
					resultRatioX96 := -quoterTarget.pctAmount * Q96 / estimatedResult * Q96 / Q96

					quoterTarget.resultRatioX96 = resultRatioX96
					quoterTargets[i] = quoterTarget
				} else {
					panic("[ROUTER] quotation.gno__quoteForAllPath() || MULTI__NegativeAmountSpecified__estimateResult < 0")
				}
			}

		}
	}

	// it contains outputRatio with 0 which is impossible path
	// > remove path with 0 ratio
	var finalTargets []QuoterTarget
	for _, quote := range quoterTargets {
		if quote.resultRatioX96 != 0 {
			finalTargets = append(finalTargets, quote)
		}
	}

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

func findBestPaths(quotes []QuoterTarget) (bestSwaps []QuoterTarget) {
	bestSwaps = make([]QuoterTarget, 0)

	totalPct := 100
	for _, quote := range quotes {
		quotePct := quote.pct
		resultRatioX96 := quote.resultRatioX96

		totalPct -= quotePct

		bestSwaps = append(bestSwaps, quote)

		if totalPct <= 0 {
			break
		}
	}

	return bestSwaps
}

func removeDuplication(bestSwaps []QuoterTarget) (finalSwaps []QuoterTarget) {
	finalSwaps = make([]QuoterTarget, 0) // return
	insertedPath := []string{}           // tmp
	pctToSwap := 0
	for _, bestSwap := range bestSwaps {
		pctToSwap += bestSwap.pct
		if !containsString(insertedPath, bestSwap.targetPath) {
			insertedPath = append(insertedPath, bestSwap.targetPath)
			finalSwaps = append(finalSwaps, bestSwap)
		} else {
			for i, finalSwap := range finalSwaps {
				if finalSwap.targetPath == bestSwap.targetPath {
					finalSwap.pctAmount += bestSwap.pctAmount // can be exceed

					if pctToSwap > 100 {
						finalSwap.pct += (bestSwap.pct - (pctToSwap - 100))
					} else {
						finalSwap.pct += bestSwap.pct
					}

					finalSwaps[i] = finalSwap
				}
			}
		}
	}

	return finalSwaps
}

func containsString(slice []string, target string) bool {
	for _, s := range slice {
		if s == target {
			return true
		}
	}
	return false
}
