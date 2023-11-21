package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
)

func DrySwapRoute(
	inputToken string,
	outputToken string,
	amountSpecified bigint,
	swapType SwapType,
	strRouteArr string, // []string
	quoteArr string, // []int
) bigint {
	require(amountSpecified != 0, "[ROUTER] router.gno__DrySwapRoute() || amountSpecified == 0")

	switch swapType {
	case ExactIn:
		amountSpecified = amountSpecified
	case ExactOut:
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] router.gno__DrySwapRoute() || unknown swapType")
	}

	// check route length ( should be 1 ~ 7 )
	routes := strings.Split(strRouteArr, ",")
	require(1 <= len(routes) && len(routes) <= 7, ufmt.Sprintf("[ROUTER] router.gno__DrySwapRoute() || len(routes) should be 1 ~ 7 (len(routes):%d)", len(routes)))

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	require(len(routes) == len(quotes), "[ROUTER] router.gno__DrySwapRoute() || len(routes) != len(quotes)")

	// check if quotes are up to 100%
	quotesSum := 0
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += intQuote
	}
	require(quotesSum == 100, "[ROUTER] router.gno__DrySwapRoute() || quotesSum != 100")

	resultAmount := bigint(0)
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__DrySwapRoute() || numHops > 3")

		toSwap := amountSpecified / bigint(100) * bigint(quote)

		if numHops == 1 { // SINGLE
			resultAmount += handleSingleSwap(route, toSwap, true)
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			resultAmount += handleMultiSwap(swapType, route, numHops, toSwap, true)
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
	swapType SwapType,
	strRouteArr string, // []string
	quoteArr string, // []int
	tokenAmountLimit bigint,
) bigint {
	require(amountSpecified != 0, "[ROUTER] router.gno__SwapRoute() || amountSpecified == 0")

	switch swapType {
	case ExactIn:
		amountSpecified = amountSpecified
	case ExactOut:
		amountSpecified = -amountSpecified
	default:
		panic("[ROUTER] router.gno__SwapRoute() || unknown swapType")
	}

	// check route length ( should be 1 ~ 7 )
	routes := strings.Split(strRouteArr, ",")
	require(1 <= len(routes) && len(routes) <= 7, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || len(routes) should be 1 ~ 7 (len(routes):%d)", len(routes)))

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	require(len(routes) == len(quotes), "[ROUTER] router.gno__SwapRoute() || len(routes) != len(quotes)")

	// check if quotes are up to 100%
	quotesSum := 0
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += intQuote
	}
	require(quotesSum == 100, "[ROUTER] router.gno__SwapRoute() || quotesSum != 100")

	resultAmount := bigint(0)
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__SwapRoute() || numHops > 3")

		toSwap := amountSpecified / bigint(100) * bigint(quote)

		if numHops == 1 { // SINGLE
			resultAmount += handleSingleSwap(route, toSwap, false)
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			resultAmount += handleMultiSwap(swapType, route, numHops, toSwap, false)
		} else {
			panic("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3")
		}
	}

	if swapType == ExactIn {
		require(tokenAmountLimit <= resultAmount, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too few received (expected minimum output:%d, actual output:%d)", tokenAmountLimit, resultAmount))
	} else { // EXACT_OUT
		require(resultAmount <= tokenAmountLimit, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too much spend (expected maximum input:%d, actual input:%d)", tokenAmountLimit, resultAmount))
	}
	return resultAmount
}

func handleSingleSwap(route string, amountSpecified bigint, isDry bool) bigint {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	if isDry {
		return singleSwapDry(singleParams)
	}
	return singleSwap(singleParams)
}

func handleMultiSwap(swapType SwapType, route string, numHops int, amountSpecified bigint, isDry bool) bigint {
	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: amountSpecified,
		}

		if isDry {
			return multiSwapDry(swapParams, 0, numHops, route) // iterate here
		}
		return multiSwap(swapParams, 0, numHops, route) // iterate here

	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.GetOrigCaller(),
			amountSpecified: amountSpecified,
		}

		if isDry {
			return multiSwapNegativeDry(swapParams, numHops-1, route) // iterate here
		}
		return multiSwapNegative(swapParams, numHops-1, route) // iterate here

	default:
		panic("[ROUTER] router.gno__handleMultiSwap() || unknown swapType")
	}
}
