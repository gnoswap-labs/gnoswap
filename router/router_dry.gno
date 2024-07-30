package router

import (
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

// DrySwapRoute simulates a token swap route without actually executing the swap.
// It calculates the expected outcome based on the current state of liquidity pools.
//
// The function supports multi-hop and split routes, with up to 7 routes and 3 hops per route.
// Panics:
//   - If _amountSpecified is zero, negative, or not a valid number
//   - If swapType is neither "EXACT_IN" nor "EXACT_OUT"
//   - If the number of routes doesn't match the number of quotes
//   - If there are less than 1 or more than 7 routes
//   - If the sum of quote percentages is not exactly 100
//   - If any route has less than 1 or more than 3 hops
//   - If any other validation or processing error occurs during the simulation
//
// Note: This function only simulates the swap and does not modify any state or execute any transactions.
func DrySwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType string,
	strRouteArr string, // []string
	quoteArr string, // []int
) string { // uint256
	if swapType != "EXACT_IN" && swapType != "EXACT_OUT" {
        panic("[ROUTER] Unknown swapType")
    }

	amountSpecified, err := i256.FromDecimal(_amountSpecified)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router_dry.gno__SwapRoute() || i256.FromDecimal(_amountSpecified(%s) failed", _amountSpecified))
	}

	routes := strings.Split(strRouteArr, ",")
	quotes := strings.Split(quoteArr, ",")

	validateInput(amountSpecified, swapType, routes, quotes)

	if swapType == "EXACT_OUT" {
		amountSpecified = i256.Zero().Neg(amountSpecified)
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
		} else {
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, true)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		}
	}

	return processResult(swapType, resultAmountIn, resultAmountOut, amountSpecified)
}

func processResult(swapType string, resultAmountIn, resultAmountOut *u256.Uint, amountSpecified *i256.Int) string {
    switch swapType {
    case "EXACT_IN":
        if !i256.FromUint256(resultAmountIn).Eq(amountSpecified) {
            return "-1"
        }
        return resultAmountOut.ToString()
    case "EXACT_OUT":
        if i256.FromUint256(resultAmountOut).Lt(amountSpecified) {
            return "-1"
        }
        return resultAmountIn.ToString()
    default:
        panic("[ROUTER] Unknown swapType")
    }
}
