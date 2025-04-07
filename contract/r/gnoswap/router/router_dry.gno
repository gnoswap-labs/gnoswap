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

const (
	MAX_QUOTE_PERCENTAGE = 100
	MIN_QUOTE_PERCENTAGE = 0
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

	swapType := parseSwapType(swapTypeStr)
	amountSpecified := parseAmount(specifiedAmount)
	amountLimit := parseAmountLimit(tokenAmountLimit)
	routes, quotes := parseRoutes(strRouteArr, quoteArr)

	if swapType == ExactOut {
		amountSpecified = i256.Zero().Neg(amountSpecified)
	}

	zero := u256.Zero()

	amountIn, amountOut := zero, zero
	resultAmountIn, resultAmountOut := zero, zero

	for i, route := range routes {
		quote := parseQuote(quotes[i])
		toSwap := calculateSwapAmount(amountSpecified, quote)

		numHops := strings.Count(route, POOL_SEPARATOR) + 1
		assertHopsInRange(numHops)

		if numHops == 1 {
			amountIn, amountOut = handleSingleDrySwap(route, toSwap)
		} else {
			amountIn, amountOut = handleMultiDrySwap(swapType, route, numHops, toSwap)
		}

		resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
		if resultAmountIn.IsOverflow() {
			panic(addDetailToError(
				errInvalidInput,
				"overflow in resultAmountIn",
			))
		}

		resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		if resultAmountOut.IsOverflow() {
			panic(addDetailToError(
				errInvalidInput,
				"overflow in resultAmountOut",
			))
		}
	}

	return processDryswapResult(
		swapType, resultAmountIn, resultAmountOut,
		amountSpecified, amountLimit,
	)
}

func parseSwapType(swapTypeStr string) SwapType {
	swapType, err := trySwapTypeFromStr(swapTypeStr)
	if err != nil {
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapTypeStr),
		))
	}
	return swapType
}

func parseAmount(amount string) *i256.Int {
	parsedAmount := i256.MustFromDecimal(amount)
	if parsedAmount.Lt(i256.Zero()) {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amount(%s), must be positive", amount),
		))
	}
	return parsedAmount
}

func parseAmountLimit(amountLimit string) *i256.Int {
	parsedLimit := i256.MustFromDecimal(amountLimit)
	if parsedLimit.IsZero() {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid amountLimit(%s), should not be zero", amountLimit),
		))
	}
	return parsedLimit
}

func parseRoutes(strRouteArr, quoteArr string) ([]string, []string) {
	routes, quotes, err := validateRoutesAndQuotes(strRouteArr, quoteArr)
	if err != nil {
		panic(addDetailToError(
			errInvalidRoutesAndQuotes,
			err.Error()),
		)
	}
	return routes, quotes
}

func parseQuote(quote string) int {
	quoteValue, _ := strconv.Atoi(quote)
	if quoteValue < MIN_QUOTE_PERCENTAGE || quoteValue > MAX_QUOTE_PERCENTAGE {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("quote(%d) must be %d~%d", quoteValue, MIN_QUOTE_PERCENTAGE, MAX_QUOTE_PERCENTAGE),
		))
	}
	return quoteValue
}

func calculateSwapAmount(amountSpecified *i256.Int, quote int) *i256.Int {
	toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
	if toSwap.IsOverflow() {
		panic(addDetailToError(
			errInvalidInput,
			"overflow in calculateSwapAmount",
		))
	}
	return new(i256.Int).Div(toSwap, i256.NewInt(100))
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
	recipient := std.PreviousRealm().Address()
	pathIndex := getPathIndex(swapType, numHops)

	input, output, fee := getDataForMultiPath(route, pathIndex)
	swapParams := newSwapParams(input, output, fee, recipient, amountSpecified)

	return executeMultiSwap(swapType, swapParams, pathIndex, numHops, route)
}

func executeMultiSwap(
	swapType SwapType,
	params *SwapParams,
	pathIndex int,
	numHops int,
	route string,
) (*u256.Uint, *u256.Uint) {
	switch swapType {
	case ExactIn:
		return multiDrySwap(*params, pathIndex, numHops, route)
	case ExactOut:
		return multiDrySwapNegative(*params, pathIndex, route)
	default:
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapType),
		))
	}
}

func processDryswapResult(swapType SwapType, resultAmountIn, resultAmountOut *u256.Uint, amountSpecified, amountLimit *i256.Int) (string, string, bool) {
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

func getPathIndex(swapType SwapType, numHops int) int {
	if swapType == ExactIn {
		return 0 // first data
	}
	return numHops - 1 // last data
}
