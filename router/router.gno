package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/emission"
)

// SwapRoute swaps the input token to the output token and returns the result amount
// If swapType is EXACT_IN, it returns the amount of output token ≈ amount of user to receive
// If swapType is EXACT_OUT, it returns the amount of input token ≈ amount of user to pay
//
// Panics if any of the following conditions are met:
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
	en.MintAndDistributeGns()

	if common.GetLimitCaller() {
		isUserCalled := std.PrevRealm().PkgPath() == ""
		if !isUserCalled {
			panic("[ROUTER] router.gno__SwapRoute() || only user can call this function")
		}
	}

	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	if amountSpecified.IsZero() {
		panic("[ROUTER] router.gno__SwapRoute() || amountSpecified == 0")
	}
	if amountSpecified.IsNeg() {
		panic("[ROUTER] router.gno__SwapRoute() || amountSpecified < 0")
	}

	tokenAmountLimit := u256.MustFromDecimal(_tokenAmountLimit)

	switch swapType {
	case "EXACT_IN":
		// do nothing
	case "EXACT_OUT":
		amountSpecified = i256.Zero().Neg(amountSpecified)
	default:
		panic("[ROUTER] router.gno__SwapRoute() || unknown swapType")
	}

	// check route length ( should be 1 ~ 7 )
	routes := strings.Split(strRouteArr, ",")
	isValidRouteLength := (1 <= len(routes)) && (len(routes) <= 7)
	if !isValidRouteLength {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || len(routes) should be 1 ~ 7 (len(routes)[%d])", len(routes)))
	}

	// check if routes length and quotes length are same
	quotes := strings.Split(quoteArr, ",")
	if len(routes) != len(quotes) {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || len(routes[%d]) != len(quotes[%d])", len(routes), len(quotes)))
	}

	// check if quotes are up to 100%
	quotesSum := int64(0)
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}
	if quotesSum != 100 {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || quotesSum != 100 (quotesSum)[%d]", quotesSum))
	}

	// if input is gnot, wrap it
	userOldWugnotBalance := uint64(0)
	if inputToken == consts.GNOT {
		sent := std.GetOrigSend()
		ugnotSentByUser := uint64(sent.AmountOf("ugnot"))

		wrap(ugnotSentByUser)
		userOldWugnotBalance = wugnot.BalanceOf(a2u(std.GetOrigCaller()))
	} else if outputToken == consts.GNOT { // if output is gnot unwrap later (save user's current wugnot balance)
		userOldWugnotBalance = wugnot.BalanceOf(a2u(std.GetOrigCaller()))
	}

	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, _ := strconv.Atoi(quotes[i])

		if numHops < 1 || numHops > 3 {
			panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3 (numHops)[%d]", numHops))
		}

		toSwap := i256.Zero().Mul(amountSpecified, i256.NewInt(int64(quote)))
		toSwap = toSwap.Div(toSwap, i256.NewInt(100))

		if numHops == 1 { // SINGLE
			amountIn, amountOut := handleSingleSwap(route, toSwap, false)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else if numHops == 2 || numHops == 3 { // MULTI
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, false)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else {
			panic("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3")
		}
	}

	// PROTOCOL FEE (router swap fee)
	afterFee := handleSwapFee(outputToken, resultAmountOut, false)

	// UNWRAP IF NECESSARY
	// if input was gnot, refund left over wugnot
	if inputToken == consts.GNOT {
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
		unwrap(userNewWugnotBalance)
	} else if outputToken == consts.GNOT { // if output was gnot, unwrap result
		userNewWugnotBalance := wugnot.BalanceOf(a2u(std.GetOrigCaller()))
		userRecvWugnot := uint64(userNewWugnotBalance - userOldWugnotBalance) // received wugnot
		unwrap(userRecvWugnot)
	}

	if swapType == "EXACT_IN" {
		if !(tokenAmountLimit.Lte(afterFee)) {
			panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too few received for user (expected minimum received:%s, actual received:%s)", _tokenAmountLimit, afterFee.ToString()))
		}
	} else { // EXACT_OUT
		if !(resultAmountIn.Lte(tokenAmountLimit)) {
			panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too much spend for user (expected maximum spend:%s, actual spend:%s)", _tokenAmountLimit, resultAmountIn.ToString()))
		}
	}

	intAmountOut := i256.FromUint256(afterFee)

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
		"amountIn", resultAmountIn.ToString(),
		"amountOut", i256.Zero().Neg(intAmountOut).ToString(),
		"amountOutWithoutFee", resultAmountOut.ToString(),
	)

	return resultAmountIn.ToString(), i256.Zero().Neg(intAmountOut).ToString()
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
