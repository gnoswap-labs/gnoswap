package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	i256 "gno.land/p/big/int256"
	u256 "gno.land/p/big/uint256"

	"gno.land/r/demo/wugnot"
)

func SwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType string,
	strRouteArr string, // []string
	quoteArr string, // []int
	_tokenAmountLimit string, // uint256
) string { // uint256
	amountSpecified, err := i256.FromDecimal(_amountSpecified)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || i256.FromDecimal(_amountSpecified(%s) failed", _amountSpecified))
	}
	if amountSpecified.IsZero() {
		panic("[ROUTER] router.gno__SwapRoute() || amountSpecified == 0")
	}

	tokenAmountLimit := u256.MustFromDecimal(_tokenAmountLimit)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || u256.FromDecimal(_tokenAmountLimit(%s) failed", _tokenAmountLimit))
	}

	switch swapType {
	case "EXACT_IN":
		amountSpecified = amountSpecified
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

	// check if quotes are up to 100%
	quotesSum := int64(0)
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}
	if quotesSum != 100 {
		panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || quotesSum != 100 (quotesSum)[%d]", quotesSum))
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
		} else if 2 <= numHops && numHops <= 3 { // MULTI
			amountIn, amountOut := handleMultiSwap(swapType, route, numHops, toSwap, false)
			resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
			resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
		} else {
			panic("[ROUTER] router.gno__SwapRoute() || numHops should be 1 ~ 3")
		}
	}

	// PROTOCOL FEE
	resultAmountOut = handleProtocolFee(outputToken, resultAmountOut, false)

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
		if !(tokenAmountLimit.Lte(resultAmountOut)) {
			panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too few received for user (expected minimum received:%s, actual received:%s)", _tokenAmountLimit, resultAmountOut.ToString()))
		}
		return resultAmountOut.ToString()
	} else { // EXACT_OUT
		if !(resultAmountIn.Lte(tokenAmountLimit)) {
			panic(ufmt.Sprintf("[ROUTER] router.gno__SwapRoute() || too much spend for user (expected maximum spend:%s, actual spend:%s)", _tokenAmountLimit, resultAmountIn.ToString()))
		}
		return resultAmountIn.ToString()
	}
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

func handleProtocolFee(outputToken string, amount *u256.Uint, isDry bool) *u256.Uint {
	if consts.PROTOCOL_FEE_ROUTER <= 0 { // r3v4_xxx: CHANGABLE BY GOV
		return amount
	}

	feeAmount := new(u256.Uint).Mul(amount, u256.NewUint(consts.PROTOCOL_FEE_ROUTER))
	feeAmount.Div(feeAmount, u256.NewUint(10000))

	if !isDry {
		ok := transferFromByRegisterCall(outputToken, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount.Uint64())
		if !ok {
			panic(ufmt.Sprintf("[ROUTER] router.gno__handleProtocolFee() || expected transferFromByRegisterCall(%s, %s, %s, %s) == true", outputToken, std.GetOrigCaller(), consts.FEE_COLLECTOR, feeAmount.ToString()))
		}
	}

	return new(u256.Uint).Sub(amount, feeAmount)
}
