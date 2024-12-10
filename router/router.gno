package router

import (
	"std"
	"strconv"
	"strings"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/v1/emission"
	sr "gno.land/r/gnoswap/v1/staker"
)

// SwapRoute swaps the input token to the output token and returns the result amount
// If swapType is EXACT_IN, it returns the amount of output token ≈ amount of user to receive
// If swapType is EXACT_OUT, it returns the amount of input token ≈ amount of user to pay
// Returns amountIn, amountOut
// ref: https://docs.gnoswap.io/contracts/router/router.gno#swaproute
func SwapRoute(
	inputToken string,
	outputToken string,
	_amountSpecified string, // int256
	swapType string,
	strRouteArr string, // []string
	quoteArr string, // []int
	_tokenAmountLimit string, // uint256
) (string, string) { // tokneIn, tokenOut
	common.IsHalted()

	if swapType != "EXACT_IN" && swapType != "EXACT_OUT" {
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("router.gno__SwapRoute() || unknown swapType(%s)", swapType),
		))
	}

	if common.GetLimitCaller() && std.PrevRealm().PkgPath() != "" {
		panic(addDetailToError(
			errNoPermission,
			"router.gno__SwapRoute() || only user can call this function",
		))
	}

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		sr.CalcPoolPositionRefactor()
	} else {
		sr.CalcPoolPosition()
	}

	// TODO: extract as an function
	amountSpecified := i256.MustFromDecimal(_amountSpecified)
	tokenAmountLimit := u256.MustFromDecimal(_tokenAmountLimit)

	routes := strings.Split(strRouteArr, ",")
	quotes := strings.Split(quoteArr, ",")

	if err := validateInput(amountSpecified, swapType, routes, quotes); err != nil {
		panic(err)
	}
	//

	if swapType == "EXACT_OUT" {
		amountSpecified = i256.Zero().Neg(amountSpecified)
	}

	// TODO: extract as an function
	var userBeforeWugnotBalance uint64
	var userWrappedWugnot uint64
	if inputToken == consts.GNOT || outputToken == consts.GNOT {
		userBeforeWugnotBalance = wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))

		if swapType == "EXACT_IN" && inputToken == consts.GNOT {
			sent := std.GetOrigSend()
			ugnotSentByUser := uint64(sent.AmountOf("ugnot"))
			i256AmountSpecified := i256.MustFromDecimal(_amountSpecified)
			u64AmountSpecified := i256AmountSpecified.Uint64()

			if ugnotSentByUser != u64AmountSpecified {
				panic(addDetailToError(
					errInvalidInput,
					ufmt.Sprintf("router.gno__SwapRoute() || ugnot sent by user(%d) is not equal to amountSpecified(%d)", ugnotSentByUser, u64AmountSpecified),
				))
			}

			if ugnotSentByUser > 0 {
				wrap(ugnotSentByUser)
			}
			userWrappedWugnot = ugnotSentByUser
		}
	}
	//

	resultAmountIn, resultAmountOut, err := processRoutes(routes, quotes, amountSpecified, swapType)
	if err != nil {
		panic(err)
	}

	amountIn, amountOut, err := finalizeSwap(
		inputToken,
		outputToken,
		resultAmountIn,
		resultAmountOut,
		swapType,
		tokenAmountLimit,
		userBeforeWugnotBalance,
		userWrappedWugnot,
		amountSpecified.Abs(), // if swap type is EXACT_OUT, compare with this value to see user can actually receive this amount
	)
	if err != nil {
		panic(err)
	}

	prevAddr, prevRealm := getPrev()

	std.Emit(
		"SwapRoute",
		"prevAddr", prevAddr,
		"prevRealm", prevRealm,
		"input", inputToken,
		"output", outputToken,
		"swapType", swapType,
		"amountSpecified", _amountSpecified,
		"route", strRouteArr,
		"quote", quoteArr,
		"internal_amountIn", amountIn,
		"internal_amountOut", amountOut,
		"internal_amountOutWithoutFee", resultAmountOut.ToString(),
	)

	return amountIn, amountOut
}

func validateInput(amountSpecified *i256.Int, swapType string, routes, quotes []string) error {
	if amountSpecified.IsZero() || amountSpecified.IsNeg() {
		return ufmt.Errorf(
			"%s: amountSpecified(%s), must be positive",
			errInvalidInput.Error(), amountSpecified.ToString(),
		)
	}

	if len(routes) < 1 || len(routes) > 7 {
		return ufmt.Errorf(
			"%s: route length must be 1~7. got %d",
			errInvalidInput.Error(), len(routes),
		)
	}

	if len(routes) != len(quotes) {
		return ufmt.Errorf(
			"%s: length of routes (%d) and quotes (%d) are different",
			errInvalidInput.Error(), len(routes), len(quotes),
		)
	}

	// extract as an function
	var quotesSum int64
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}

	if quotesSum != 100 {
		ufmt.Errorf(
			"%s: quote sum must be 100. got %d",
			errInvalidInput.Error(), quotesSum,
		)
	}
	//

	return nil
}

func processRoutes(routes, quotes []string, amountSpecified *i256.Int, swapType string) (*u256.Uint, *u256.Uint, error) {
	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range routes {
		numHops := strings.Count(route, "*POOL*") + 1
		quote, err := strconv.Atoi(quotes[i])
		if err != nil {
			return nil, nil, err
		}

		if numHops < 1 || numHops > 3 {
			return nil, nil, ufmt.Errorf(
				"%s: number of hops must be in range 1 to 3. got %d",
				errInvalidInput.Error(), numHops,
			)
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

	return resultAmountIn, resultAmountOut, nil
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

// TODO: reduce number of params, update error message
func finalizeSwap(
	inputToken, outputToken string,
	resultAmountIn, resultAmountOut *u256.Uint,
	swapType string,
	tokenAmountLimit *u256.Uint,
	userBeforeWugnotBalance, userWrappedWugnot uint64,
	amountSpecified *u256.Uint,
) (string, string, error) {
	if swapType == "EXACT_OUT" && resultAmountOut.Lt(amountSpecified) {
		return "", "", ufmt.Errorf(
			"%s: not enough amounts received. minimum: %s, actual: %s, swapType: %s",
			errSlippage.Error(), amountSpecified.ToString(), resultAmountOut.ToString(), swapType,
		)
	}

	afterFee := handleSwapFee(outputToken, resultAmountOut, false)

	userNewWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))
	if inputToken == consts.GNOT {
		totalBefore := userBeforeWugnotBalance + userWrappedWugnot
		spend := totalBefore - userNewWugnotBalance

		if spend > userWrappedWugnot {
			return "", "", ufmt.Errorf(
				"%s: too much wugnot spent. wrapped: %d, spend: %d",
				errSlippage.Error(), userWrappedWugnot, spend,
			)
		}

		// unwrap left amount
		toUnwrap := userWrappedWugnot - spend
		unwrap(toUnwrap)
	} else if outputToken == consts.GNOT {
		userRecvWugnot := uint64(userNewWugnotBalance - userBeforeWugnotBalance - userWrappedWugnot)
		unwrap(userRecvWugnot)
	}

	// TODO: create separate error code
	if swapType == "EXACT_IN" {
		if !tokenAmountLimit.Lte(afterFee) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("router.gno__finalizeSwap() || too few received for user (expected minimum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), afterFee.ToString(), swapType),
			))
		}
	} else {
		if !resultAmountIn.Lte(tokenAmountLimit) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("router.gno__finalizeSwap() || too much spent for user (expected maximum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), resultAmountIn.ToString(), swapType),
			))
		}
	}

	intAmountOut := i256.FromUint256(afterFee)
	return resultAmountIn.ToString(), i256.Zero().Neg(intAmountOut).ToString(), nil
}

func handleMultiSwap(
	swapType string,
	route string,
	numHops int,
	amountSpecified *i256.Int,
	isDry bool,
) (*u256.Uint, *u256.Uint) {
	switch swapType {
	case "EXACT_IN":
		input, output, fee := getDataForMultiPath(route, 0) // first data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.PrevRealm().Addr(),
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
			recipient:       std.PrevRealm().Addr(),
			amountSpecified: amountSpecified,
		}

		if isDry {
			return multiSwapNegativeDry(swapParams, numHops-1, route) // iterate here
		}
		return multiSwapNegative(swapParams, numHops-1, route) // iterate here

	default:
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("router.gno__handleMultiSwap() || unknown swapType(%s)", swapType),
		))
	}
}
