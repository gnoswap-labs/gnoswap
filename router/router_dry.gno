package router

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"
)

func DrySwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType SwapType,
	strRouteArr string, // []string
	quoteArr string, // []int
) string { // uint256
	amountSpecified, err := i256.FromDecimal(_amountSpecified)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router_dry.gno__SwapRoute() || i256.FromDecimal(_amountSpecified(%s) failed", _amountSpecified))
	}
	if amountSpecified.IsZero() {
		panic("[ROUTER] router_dry.gno__SwapRoute() || amountSpecified == 0")
	}

	switch swapType {
	case ExactIn:
		amountSpecified = amountSpecified
	case ExactOut:
		amountSpecified = i256.Zero().Neg(amountSpecified)
	default:
		panic("[ROUTER] router_dry.gno__DrySwapRoute() || unknown swapType")
	}

	// check route length ( should be 1 ~ 7 )
	routes := strings.Split(strRouteArr, ",")
	require(1 <= len(routes) && len(routes) <= 7, ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || len(routes) should be 1 ~ 7 (len(routes)[%d])", len(routes)))

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	require(len(routes) == len(quotes), ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || len(routes[%d]) != len(quotes[%d])", len(routes), len(quotes)))

	// check if quotes are up to 100%
	quotesSum := int64(0)
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}
	require(quotesSum == 100, "[ROUTER] router_dry.gno__DrySwapRoute() || quotesSum != 100")

	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		// check if route hop is up to 3
		require(numHops <= 3, "[ROUTER] router_dry.gno__DrySwapRoute() || numHops > 3")

		toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
		toSwap = toSwap.Div(toSwap, i256.NewInt(100))

		if numHops == 1 { // SINGLE
			amountIn, amountOut := handleSingleSwap(route, toSwap, true)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, true)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else {
			panic("[ROUTER] router_dry.gno__DrySwapRoute() || numHops should be 1 ~ 3")
		}
	}

	// PROTOCOL FEE
	// resultAmountOut = handleProtocolFee(outputToken, resultAmountOut, true)
	// DrySwap should return raw resultAmountOut( ≈ with protocol fee )
	// Interface needs to calculate 0.15 protocol fee

	if swapType == ExactIn {
		if !(i256.FromUint256(resultAmountIn).Eq(amountSpecified)) {
			return "-1" // if pool doesn't have enough output token amount to swap against input token amount
		}
		return resultAmountOut.ToString()
	}

	if swapType == ExactOut {
		if i256.FromUint256(resultAmountOut).Lt(amountSpecified) { // if pool doesn't have enough user wanted amount of output token
			return "-1"
		}
		return resultAmountIn.ToString()
	}
}
