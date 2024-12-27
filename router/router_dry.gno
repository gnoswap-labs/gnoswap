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
// Returns the expected amount in or out
func DrySwapRoute(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	swapKind string,
	strRouteArr string,
	quoteArr string,
) string {
	swapType, err := trySwapTypeFromStr(swapKind)
	if err != nil {
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapKind),
		))
	}

	amountSpecified := i256.MustFromDecimal(specifiedAmount)

	if amountSpecified.IsZero() || amountSpecified.IsNeg() {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amountSpecified(%s), must be positive", amountSpecified.ToString()),
		))
	}

	routes, quotes, err := tryParseRoutes(strRouteArr, quoteArr)
	if err != nil {
		panic(err.Error())
	}

	if swapType == ExactOut {
		amountSpecified = i256.Zero().Neg(amountSpecified)
	}

	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, POOL_SEPARATOR) + 1
		// don't need to check error here
		quote, _ := strconv.Atoi(quotes[i])

		assertHopsInRange(numHops)

		toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
		toSwap = toSwap.Div(toSwap, i256.NewInt(100))

		if numHops == 1 { // SINGLE
			amountIn, amountOut := handleSingleSwap(route, toSwap)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else {
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		}
	}

	return processResult(swapType, resultAmountIn, resultAmountOut, amountSpecified)
}

func processResult(swapType SwapType, resultAmountIn, resultAmountOut *u256.Uint, amountSpecified *i256.Int) string {
	switch swapType {
	case ExactIn:
		if !i256.FromUint256(resultAmountIn).Eq(amountSpecified) {
			return "-1"
		}
		return resultAmountOut.ToString()
	case ExactOut:
		if i256.FromUint256(resultAmountOut).Lt(amountSpecified) {
			return "-1"
		}
		return resultAmountIn.ToString()
	default:
		// redundant case
		panic("should not reach here")
	}
}
