package router

import (
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
	require(1 <= len(routes) && len(routes) <= 7, ufmt.Sprintf("[ROUTER] router.gno__DrySwapRoute() || len(routes) should be 1 ~ 7 (len(routes)[%d])", len(routes)))

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	require(len(routes) == len(quotes), ufmt.Sprintf("[ROUTER] router.gno__DrySwapRoute() || len(routes[%d]) != len(quotes[%d])", len(routes), len(quotes)))

	// check if quotes are up to 100%
	quotesSum := 0
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += intQuote
	}
	require(quotesSum == 100, "[ROUTER] router.gno__DrySwapRoute() || quotesSum != 100")

	var resultAmountIn, resultAmountOut bigint
	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router.gno__DrySwapRoute() || numHops > 3")

		toSwap := amountSpecified * bigint(quote) / bigint(100)

		if numHops == 1 { // SINGLE
			amountIn, amountOut := handleSingleSwap(route, toSwap, true)
			resultAmountIn += amountIn
			resultAmountOut += amountOut
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, true)
			resultAmountIn += amountIn
			resultAmountOut += amountOut
		} else {
			panic("[ROUTER] router.gno__DrySwapRoute() || numHops should be 1 ~ 3")
		}
	}

	// PROTOCOL FEE
	// resultAmountOut = handleProtocolFee(outputToken, resultAmountOut, true)
	// DrySwap should return raw resultAmountOut( ≈ with protocol fee )
	// Interface needs to calculate 0.15 protocol fee

	if swapType == ExactIn {
		if resultAmountIn != amountSpecified {
			return -1 // if pool doesn't have enough output token amount to swap against input token amount
		}
		return resultAmountOut
	}

	if swapType == ExactOut {
		if resultAmountOut < amountSpecified { // if pool doesn't user wanted amount of output token
			return -1
		}
		return resultAmountIn
	}
}
