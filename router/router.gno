package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
)

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

	var resultAmountIn, resultAmountOut bigint
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__SwapRoute() || numHops > 3")

		toSwap := amountSpecified * bigint(quote) / bigint(100)

		if numHops == 1 { // SINGLE
			amountIn, amountOut := handleSingleSwap(route, toSwap, false)
			resultAmountIn += amountIn
			resultAmountOut += amountOut
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, false)
			resultAmountIn += amountIn
			resultAmountOut += amountOut
		} else {
			panic("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3")
		}
	}

	// PROTOCOL FEE
	resultAmountOut = handleProtocolFee(outputToken, resultAmountOut, false)

	if swapType == ExactIn {
		require(tokenAmountLimit <= resultAmountOut, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too few received (expected minimum output:%d, actual output:%d)", tokenAmountLimit, resultAmountOut))
		return resultAmountOut
	} else { // EXACT_OUT
		require(resultAmountIn <= tokenAmountLimit, ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too much spend (expected maximum input:%d, actual input:%d)", tokenAmountLimit, resultAmountIn))
		return resultAmountIn
	}
}

func handleSingleSwap(route string, amountSpecified bigint, isDry bool) (amountIn, amountOut bigint) {
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

func handleMultiSwap(swapType SwapType, route string, numHops int, amountSpecified bigint, isDry bool) (amountIn, amountOut bigint) {
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

func handleProtocolFee(outputToken string, amount bigint, isDry bool) bigint {
	if consts.PROTOCOL_FEE_ROUTER <= 0 { // r3v4_xxx: CHANGABLE BY GOV
		return amount
	}

	feeAmount := amount * bigint(consts.PROTOCOL_FEE_ROUTER) / 1e4
	if !isDry {
		ok := transferFromByRegisterCall(outputToken, std.GetOrigCaller(), consts.FEE_COLLECTOR, uint64(feeAmount))
		require(ok, "[ROUTER] router.gno__handleProtocolFee() || transferFromByRegisterCall failed")
	}

	amount -= feeAmount
	return amount
}
