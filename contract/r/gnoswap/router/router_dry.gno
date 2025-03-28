package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/common"
)

// DrySwapRoute simulates a token swap route without actually executing the swap.
// It calculates the expected outcome based on the current state of liquidity pools.
// Parameters:
// - inputToken: the symbol of the input token
// - outputToken: the symbol of the output token
// - specifiedAmount: the amount specified by the user (input or output, depending on swapKind)
// - swapTypeStr: the type of swap ("exactIn" or "exactOut")
// - strRouteArr: comma-separated swap route strings
// - quoteArr: comma-separated quote percentages for each route
// - tokenAmountLimit: a limit for token amount depending on swapKind
// Returns:
// - amountInStr: the calculated input amount as a string
// - amountOutStr: the calculated output amount as a string
// - success: true if the simulated swap meets all constraints
func DrySwapRoute(
	inputToken string,
	outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr string,
	quoteArr string,
	tokenAmountLimit string,
) (string, string, bool) {
	common.MustRegistered(inputToken)
	common.MustRegistered(outputToken)

	swapType, err := trySwapTypeFromStr(swapTypeStr)
	if err != nil {
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapTypeStr),
		))
	}

	amountSpecified := i256.MustFromDecimal(specifiedAmount)
	if amountSpecified.IsZero() || amountSpecified.IsNeg() {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amountSpecified(%s), must be positive", specifiedAmount),
		))
	}

	amountLimit := i256.MustFromDecimal(tokenAmountLimit)
	if amountLimit.IsZero() {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amountLimit(%s), should not be zero", tokenAmountLimit),
		))
	}

	routes, quotes, err := tryParseRoutes(strRouteArr, quoteArr)
	if err != nil {
		panic(addDetailToError(
			errInvalidRoutesAndQuotes,
			err.Error()),
		)
	}

	if swapType == ExactOut {
		amountSpecified = i256.Zero().Neg(amountSpecified)
	}

	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, POOL_SEPARATOR) + 1
		assertHopsInRange(numHops)
		// don't need to check error here
		quote, _ := strconv.Atoi(quotes[i])
		if quote < 0 || quote > 100 {
			panic(addDetailToError(
				errInvalidInput,
				ufmt.Sprintf("quote(%d) must be 0~100", quote),
			))
		}

		toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
		toSwap = new(i256.Int).Div(toSwap, i256.NewInt(100))

		if numHops == 1 {
			amountIn, amountOut := handleSingleDrySwap(route, toSwap)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else {
			amountIn, amountOut := handleMultiDrySwap(swapType, route, numHops, toSwap)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		}
	}

	return processResult(swapType, resultAmountIn, resultAmountOut, amountSpecified, amountLimit)
}

func handleSingleDrySwap(route string, amountSpecified *i256.Int) (*u256.Uint, *u256.Uint) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	return singleDrySwap(singleParams)
}

func handleMultiDrySwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified *i256.Int,
) (*u256.Uint, *u256.Uint) {
	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.PreviousRealm().Address(),
			amountSpecified: amountSpecified,
		}
		return multiDrySwap(swapParams, 0, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.PreviousRealm().Address(),
			amountSpecified: amountSpecified,
		}
		return multiDrySwapNegative(swapParams, numHops-1, route)
	default:
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapType),
		))
	}
}

func processResult(swapType SwapType, resultAmountIn, resultAmountOut *u256.Uint, amountSpecified, amountLimit *i256.Int) (string, string, bool) {
	switch swapType {
	case ExactIn:
		if i256.FromUint256(resultAmountIn).Gt(amountSpecified) {
			return resultAmountIn.ToString(), resultAmountOut.ToString(), false
		}
		if i256.FromUint256(resultAmountOut).Lt(amountLimit) {
			return resultAmountIn.ToString(), resultAmountOut.ToString(), false
		}
		return resultAmountIn.ToString(), resultAmountOut.ToString(), true

	case ExactOut:
		if i256.FromUint256(resultAmountOut).Lt(amountSpecified) {
			return resultAmountIn.ToString(), resultAmountOut.ToString(), false
		}
		if i256.FromUint256(resultAmountIn).Gt(amountLimit) {
			return resultAmountIn.ToString(), resultAmountOut.ToString(), false
		}
		return resultAmountIn.ToString(), resultAmountOut.ToString(), true
	default:
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapType),
		))
	}
}
