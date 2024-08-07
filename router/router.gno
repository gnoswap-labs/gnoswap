package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"
	"gno.land/r/gnoswap/v2/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/v2/emission"
)

// SwapRoute swaps the input token to the output token and returns the result amount
// If swapType is EXACT_IN, it returns the amount of output token ≈ amount of user to receive
// If swapType is EXACT_OUT, it returns the amount of input token ≈ amount of user to pay
//
// Panics:
// - amountSpecified is zero or is not numeric
// - swapType is not EXACT_IN or EXACT_OUT
// - length of route and quotes are not the same
// - length of routes is not 1 ~ 7
// - sum of quotes is not 100
// - number of hops is not 1 ~ 3
// - too many token spend or too few token received
func SwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType string,
	strRouteArr string, // []string
	quoteArr string, // []int
	_tokenAmountLimit string, // uint256
) (string, string) { // tokneIn, tokenOut
	if swapType != "EXACT_IN" && swapType != "EXACT_OUT" {
		panic("[ROUTER] Unknown swapType")
	}

	if common.GetLimitCaller() && std.PrevRealm().PkgPath() != "" {
		panic("[ROUTER] router.gno__SwapRoute() || only user can call this function")
	}

	en.MintAndDistributeGns()

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	tokenAmountLimit := u256.MustFromDecimal(_tokenAmountLimit)

	routes := strings.Split(strRouteArr, ",")
	quotes := strings.Split(quoteArr, ",")

	validateInput(amountSpecified, swapType, routes, quotes)

	if swapType == "EXACT_OUT" {
		amountSpecified = i256.Zero().Neg(amountSpecified)
	}

	userOldWugnotBalance, _ := handleGNOT(inputToken, outputToken)

	resultAmountIn, resultAmountOut := processRoutes(routes, quotes, amountSpecified, swapType)

	amountIn, amountOut := finalizeSwap(inputToken, outputToken, resultAmountIn, resultAmountOut, swapType, tokenAmountLimit, userOldWugnotBalance)

	std.Emit(
		"GNOSWAP",
		"m_callType", callType(),
		"m_origCaller", origCaller(),
		"m_prevRealm", prevRealm(),
		"p_input", inputToken,
		"p_output", outputToken,
		"p_swapType", swapType,
		"p_amountSpecified", _amountSpecified,
		"p_route", strRouteArr,
		"p_quote", quoteArr,
		"amountIn", amountIn,
		"amountOut", amountOut,
		"amountOutWithoutFee", resultAmountOut.ToString(),
	)

	return amountIn, amountOut
}

func validateInput(amountSpecified *i256.Int, swapType string, routes, quotes []string) {
	if amountSpecified.IsZero() || amountSpecified.IsNeg() {
		panic("[ROUTER] Invalid amountSpecified")
	}

	if len(routes) < 1 || len(routes) > 7 {
		panic("[ROUTER] Invalid route length")
	}

	if len(routes) != len(quotes) {
		panic("[ROUTER] Mismatch between routes and quotes length")
	}

	var quotesSum int64
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}

	if quotesSum != 100 {
		panic("[ROUTER] Quote sum is not 100")
	}
}

func handleGNOT(inputToken, outputToken string) (uint64, uint64) {
	userOldWugnotBalance := uint64(0)
	if inputToken == consts.GNOT {
		sent := std.GetOrigSend()
		ugnotSentByUser := uint64(sent.AmountOf("ugnot"))
		wrap(ugnotSentByUser)
		userOldWugnotBalance = wugnot.BalanceOf(a2u(std.GetOrigCaller()))
	} else if outputToken == consts.GNOT {
		userOldWugnotBalance = wugnot.BalanceOf(a2u(std.GetOrigCaller()))
	}
	return userOldWugnotBalance, 0
}

func processRoutes(routes, quotes []string, amountSpecified *i256.Int, swapType string) (*u256.Uint, *u256.Uint) {
	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		if numHops < 1 || numHops > 3 {
			panic(ufmt.Sprintf("[ROUTER] Invalid number of hops: %d", numHops))
		}

		toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
		toSwap = toSwap.Div(toSwap, i256.NewInt(100))

		var amountIn, amountOut *u256.Uint
		if numHops == 1 {
			amountIn, amountOut = handleSingleSwap(route, toSwap, false)
		} else {
			amountIn, amountOut = handleMultiSwap(swapType, route, numHops, toSwap, false)
		}

		resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
		resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
	}

	return resultAmountIn, resultAmountOut
}

func handleSingleSwap(route string, amountSpecified *i256.Int, isDry bool) (*u256.Uint, *u256.Uint) {
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

func finalizeSwap(inputToken, outputToken string, resultAmountIn, resultAmountOut *u256.Uint, swapType string, tokenAmountLimit *u256.Uint, userOldWugnotBalance uint64) (string, string) {
	afterFee := handleSwapFee(outputToken, resultAmountOut, false)

	userNewWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
	if inputToken == consts.GNOT {
		unwrap(userNewWugnotBalance)
	} else if outputToken == consts.GNOT {
		userRecvWugnot := uint64(userNewWugnotBalance - userOldWugnotBalance)
		unwrap(userRecvWugnot)
	}

	if swapType == "EXACT_IN" {
		if !tokenAmountLimit.Lte(afterFee) {
			panic(ufmt.Sprintf("[ROUTER] Too few received for user (expected minimum: %s, actual: %s)", tokenAmountLimit.ToString(), afterFee.ToString()))
		}
	} else {
		if !resultAmountIn.Lte(tokenAmountLimit) {
			panic(ufmt.Sprintf("[ROUTER] Too much spent for user (expected maximum: %s, actual: %s)", tokenAmountLimit.ToString(), resultAmountIn.ToString()))
		}
	}

	intAmountOut := i256.FromUint256(afterFee)
	return resultAmountIn.ToString(), i256.Zero().Neg(intAmountOut).ToString()
}

func handleMultiSwap(swapType string, route string, numHops int, amountSpecified *i256.Int, isDry bool) (*u256.Uint, *u256.Uint) {
	switch swapType {
	case "EXACT_IN":
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

	case "EXACT_OUT":
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
