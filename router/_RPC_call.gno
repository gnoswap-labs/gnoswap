package router

import (
	"encoding/json"
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func EstimateRouteQuotes(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType SwapType,
	strPoolArr string,
	divideBy int,
) string {
	require(amountSpecified != 0, "[ROUTER] _RPC_call.gno__EstimateRouteQuotes() || amountSpecified == 0")

	switch swapType {
	case ExactIn:
		amountSpecified = amountSpecified
	case ExactOut:
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] _RPC_call.gno__EstimateRouteQuotes() || unknown swapType")
	}

	if 100%divideBy != 0 && divideBy%5 == 0 {
		panic("[ROUTER] _RPC_call.gno__EstimateRouteQuotes() || divideBy should be 5, 10, 20, 25, 50, 100")
	}

	estimatedRoutes := []EstimatedRoute{}

	possiblePaths := strings.Split(strPoolArr, ",")
	for _, possiblePath := range possiblePaths {
		numHops := strings.Count(possiblePath, "*POOL*") + 1

		outputEstimated := bigint(0)
		estimatedRoute := EstimatedRoute{}
		for i := divideBy; i <= 100; i += divideBy { // 5%, 10%, 15%, ... 100%
			if numHops == 1 { // SINGLE
				outputEstimated = estimateSingleSwap(possiblePath, amountSpecified, i)
			} else if 2 <= numHops && numHops <= 3 { // MULTI
				outputEstimated = estimateMultiSwap(swapType, possiblePath, numHops, amountSpecified, i)
			} else {
				// more than 4 hops
				// do nothing
			}

			estimatedRoute = EstimatedRoute{
				Pools:        possiblePath,
				Quote:        i,
				InputAmount:  amountSpecified / bigint(100) * bigint(i),
				OutputAmount: outputEstimated,
			}
			estimatedRoutes = append(estimatedRoutes, estimatedRoute)
		}
	}

	rr, err := json.Marshal(estimatedRoutes)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_call.gno__EstimateRouteQuotes() || json.Marshal error with %v", err))
	}

	return string(rr)
}

func estimateSingleSwap(possiblePath string, amountSpecified bigint, i int) bigint {
	input, output, fee := getDataForSinglePath(possiblePath)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: calculateAmount(amountSpecified, i),
	}
	return singleSwapDry(singleParams)
}

func estimateMultiSwap(swapType SwapType, possiblePath string, numHops int, amountSpecified bigint, i int) bigint {
	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(possiblePath, 0) // first data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: calculateAmount(amountSpecified, i),
		}
		return multiSwapDry(swapParams, 0, numHops, possiblePath)
	case ExactOut:
		input, output, fee := getDataForMultiPath(possiblePath, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: calculateAmount(amountSpecified, i),
		}
		return multiSwapNegativeDry(swapParams, numHops-1, possiblePath)
	default:
		// some adequate error handling
		panic("[ROUTER] _RPC_call.gno__estimateMultiSwap() || swapType should be EXACT_IN or EXACT_OUT")
	}
}

func calculateAmount(amountSpecified bigint, i int) bigint {
	return amountSpecified / bigint(100) * bigint(i)
}
