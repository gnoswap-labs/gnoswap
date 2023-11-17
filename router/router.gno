package router

import (
	"std"
	"strings"

	"gno.land/p/demo/ufmt"
)

func DrySwapRoute(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType string,
	strRouteArr string,
	quotes []int,
) bigint {
	require(amountSpecified != 0, "[ROUTER] router.gno__DrySwapRoute() || amountSpecified == 0")

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] router.gno__DrySwapRoute() || unknown swapType")
	}

	// check route length
	routes := strings.Split(strRouteArr, ",")
	require(len(routes) != 0, "[ROUTER] router.gno__DrySwapRoute() || len(routes) == 0")

	// check if routes are up to 7
	require(len(routes) <= 7, "[ROUTER] router.gno__DrySwapRoute() || len(routes) > 7")

	// check quotes length
	require(len(quotes) != 0, "[ROUTER] router.gno__DrySwapRoute() || len(quotes) == 0")

	// check if routes length and quotes length are same
	require(len(routes) == len(quotes), "[ROUTER] router.gno__DrySwapRoute() || len(routes) != len(quotes)")

	// check if quotes are up to 100%
	quotesSum := 0
	for _, quote := range quotes {
		quotesSum += quote
	}
	require(quotesSum == 100, "[ROUTER] router.gno__DrySwapRoute() || quotesSum != 100")

	resultAmount := bigint(0)
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__DrySwapRoute() || numHops > 3")

		toSwap := amountSpecified / bigint(100) * bigint(quotes[i])

		if numHops == 1 {
			// SINGLE
			input, output, fee := getDataForSinglePath(route)
			singleParams := SingleSwapParams{
				tokenIn:         input,
				tokenOut:        output,
				fee:             fee,
				amountSpecified: toSwap,
			}
			amountResult := singleSwapDry(singleParams)
			resultAmount += amountResult
		} else if 2 <= numHops && numHops <= 3 {
			// MULTI
			if swapType == "EXACT_IN" { // EXACT_IN
				input, output, fee := getDataForMultiPath(route, 0) // first data
				swapParams := SwapParams{
					tokenIn:         input,
					tokenOut:        output,
					fee:             fee,
					recipient:       std.GetOrigCaller(),
					amountSpecified: toSwap,
				}
				amountResult := multiSwapDry( // iterate here
					swapParams, // SwapParams
					0,          // currentPoolIndex
					numHops,    // numPools
					route,      // swapPath
				)
				resultAmount += amountResult
			} else {
				input, output, fee := getDataForMultiPath(route, numHops-1) // last data
				swapParams := SwapParams{
					tokenIn:         input,
					tokenOut:        output,
					fee:             fee,
					recipient:       std.GetOrigCaller(),
					amountSpecified: toSwap,
				}
				amountResult := multiSwapNegativeDry( // iterate here
					swapParams, // SwapParams
					numHops-1,  // currentPoolIndex (backward)
					route,      // swapPath
				)
				resultAmount += amountResult
			}
		} else {
			panic("[ROUTER] router.gno__DrySwapRoute() || numHops should be 1 ~ 3")
		}
	}
	return resultAmount
}

func SwapRoute(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType string,
	strRouteArr string,
	quotes []int,
	tokenAmountLimit bigint,
) bigint {
	require(amountSpecified != 0, "[ROUTER] router.gno__SwapRoute() || amountSpecified == 0")

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] router.gno__SwapRoute() || unknown swapType")
	}

	// check route length
	routes := strings.Split(strRouteArr, ",")
	require(len(routes) != 0, "[ROUTER] router.gno__SwapRoute() || len(routes) == 0")

	// check if routes are up to 7
	require(len(routes) <= 7, "[ROUTER] router.gno__SwapRoute() || len(routes) > 7")

	// check quotes length
	require(len(quotes) != 0, "[ROUTER] router.gno__SwapRoute() || len(quotes) == 0")

	// check if routes length and quotes length are same
	require(len(routes) == len(quotes), "[ROUTER] router.gno__SwapRoute() || len(routes) != len(quotes)")

	// check if quotes are up to 100%
	quotesSum := 0
	for _, quote := range quotes {
		quotesSum += quote
	}
	require(quotesSum == 100, "[ROUTER] router.gno__SwapRoute() || quotesSum != 100")

	resultAmount := bigint(0)
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__SwapRoute() || numHops > 3")

		toSwap := amountSpecified / bigint(100) * bigint(quotes[i])

		if numHops == 1 {
			// SINGLE
			input, output, fee := getDataForSinglePath(route)
			singleParams := SingleSwapParams{
				tokenIn:         input,
				tokenOut:        output,
				fee:             fee,
				amountSpecified: toSwap,
			}
			amountResult := singleSwap(singleParams)
			resultAmount += amountResult
		} else if 2 <= numHops && numHops <= 3 {
			// MULTI
			if swapType == "EXACT_IN" { // EXACT_IN
				input, output, fee := getDataForMultiPath(route, 0) // first data
				swapParams := SwapParams{
					tokenIn:         input,
					tokenOut:        output,
					fee:             fee,
					recipient:       std.GetOrigCaller(),
					amountSpecified: toSwap,
				}
				amountResult := multiSwap( // iterate here
					swapParams, // SwapParams
					0,          // currentPoolIndex
					numHops,    // numPools
					route,      // swapPath
				)
				resultAmount += amountResult
			} else {
				input, output, fee := getDataForMultiPath(route, numHops-1) // last data
				swapParams := SwapParams{
					tokenIn:         input,
					tokenOut:        output,
					fee:             fee,
					recipient:       std.GetOrigCaller(),
					amountSpecified: toSwap,
				}
				amountResult := multiSwapNegative( // iterate here
					swapParams, // SwapParams
					numHops-1,  // currentPoolIndex (backward)
					route,      // swapPath
				)
				resultAmount += amountResult
			}
		} else {
			panic("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3")
		}
	}

	if swapType == "EXACT_IN" {
		require(tokenAmountLimit <= resultAmount, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too few received (expected minimum output:%d, actual output:%d)", tokenAmountLimit, resultAmount))
	} else { // EXACT_OUT
		require(resultAmount <= tokenAmountLimit, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too much spend (expected maximum input:%d, actual input:%d)", tokenAmountLimit, resultAmount))
	}
	return resultAmount
}
