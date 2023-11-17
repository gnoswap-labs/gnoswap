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
	swapType string,
	strPoolArr string,
	divideBy int,
) string {
	require(amountSpecified != 0, "[ROUTER] _RPC_call.gno__EstimateRouteQuotes() || amountSpecified == 0")

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
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
			if numHops == 1 {
				// SINGLE
				input, output, fee := getDataForSinglePath(possiblePath)
				singleParams := SingleSwapParams{
					tokenIn:         input,
					tokenOut:        output,
					fee:             fee,
					amountSpecified: amountSpecified / bigint(100) * bigint(i),
				}
				amountResult := singleSwapDry(singleParams)
				outputEstimated = amountResult
			} else if 2 <= numHops && numHops <= 3 {
				// MULTI
				if swapType == "EXACT_IN" { // EXACT_IN
					input, output, fee := getDataForMultiPath(possiblePath, 0) // first data
					swapParams := SwapParams{
						tokenIn:         input,
						tokenOut:        output,
						fee:             fee,
						recipient:       std.GetOrigCaller(),
						amountSpecified: amountSpecified / bigint(100) * bigint(i),
					}
					amountResult := multiSwapDry( // iterate here
						swapParams,   // SwapParams
						0,            // currentPoolIndex
						numHops,      // numPools
						possiblePath, // swapPath
					)
					outputEstimated = amountResult

				} else { // EXACT_OUT
					input, output, fee := getDataForMultiPath(possiblePath, numHops-1) // last data
					swapParams := SwapParams{
						tokenIn:         input,
						tokenOut:        output,
						fee:             fee,
						recipient:       std.GetOrigCaller(),
						amountSpecified: amountSpecified / bigint(100) * bigint(i),
					}
					amountResult := multiSwapNegativeDry( // iterate here
						swapParams,   // SwapParams
						numHops-1,    // currentPoolIndex (backward)
						possiblePath, // swapPath
					)
					outputEstimated = amountResult
				}
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
