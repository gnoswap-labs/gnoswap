package router

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// DrySwapRoute simulates the swap route and returns the result amount
// If swapType is EXACT_IN, it returns the amount of output token ≈ amount of user to receive
// If swapType is EXACT_OUT, it returns the amount of input token ≈ amount of user to pay
// If swap it not possible, it returns -1
//
// Panics if any of the following conditions are met:
// - amountSpecified is zero or is not numeric
// - swapType is not EXACT_IN or EXACT_OUT
// - length of route and quotes are not the same
// - length of routes is not 1 ~ 7
// - sum of quotes is not 100
// - number of hops is not 1 ~ 3
func DrySwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType string,
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
	if amountSpecified.IsNeg() {
		panic("[ROUTER] router.gno__SwapRoute() || amountSpecified < 0")
	}

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
	case "EXACT_OUT":
		amountSpecified = i256.Zero().Neg(amountSpecified)
	default:
		panic("[ROUTER] router_dry.gno__DrySwapRoute() || unknown swapType")
	}

	// check route length ( should be 1 ~ 7 )
	routes := strings.Split(strRouteArr, ",")
	isValidRouteLength := (1 <= len(routes)) && (len(routes) <= 7)
	if !isValidRouteLength {
		panic(ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || len(routes) should be 1 ~ 7 (len(routes)[%d])", len(routes)))
	}

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	if len(routes) != len(quotes) {
		panic(ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || len(routes[%d]) != len(quotes[%d])", len(routes), len(quotes)))
	}

	// check if quotes are up to 100%
	quotesSum := int64(0)
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}
	if quotesSum != 100 {
		panic(ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || quotesSum != 100 (quotesSum)[%d]", quotesSum))
	}

	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		if numHops < 1 || numHops > 3 {
			panic(ufmt.Sprintf("[ROUTER] router_dry.gno__DrySwapRoute() || numHops should be 1 ~ 3 (numHops)[%d]", numHops))
		}

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
	// DrySwap should return raw resultAmountOut( ≈ with protocol fee )
	if swapType == "EXACT_IN" {
		if !(i256.FromUint256(resultAmountIn).Eq(amountSpecified)) {
			return "-1" // if pool doesn't have enough output token amount to swap against input token amount
		}
		return resultAmountOut.ToString()
	}

	if swapType == "EXACT_OUT" {
		if i256.FromUint256(resultAmountOut).Lt(amountSpecified) { // if pool doesn't have enough user wanted amount of output token
			return "-1"
		}
		return resultAmountIn.ToString()
	}

	panic("[ROUTER] router_dry.gno__DrySwapRoute() || unknown swapType")
}
