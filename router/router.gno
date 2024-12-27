package router

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v1/common"
	"gno.land/r/gnoswap/v1/consts"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/v1/emission"
	sr "gno.land/r/gnoswap/v1/staker"
)

// Common validation and setup logic extracted from SwapRoute
func commonSwapSetup() {
	common.IsHalted()
	assertDirectCallOnly()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		sr.CalcPoolPositionRefactor()
	} else {
		sr.CalcPoolPosition()
	}
}

func handleSingleSwap(route string, amountSpecified *i256.Int) (*u256.Uint, *u256.Uint) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	return singleSwap(singleParams)
}

func handleMultiSwap(
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
			recipient:       std.PrevRealm().Addr(),
			amountSpecified: amountSpecified,
		}
		return multiSwap(swapParams, 0, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       std.PrevRealm().Addr(),
			amountSpecified: amountSpecified,
		}
		return multiSwapNegative(swapParams, numHops-1, route)
	default:
		// Any invalid `SwapType` is caught in the `SwapRoute` function,
		// so no invalid values can get in here.
		panic("should not reach here")
	}
}

func finalizeSwap(
	inputToken, outputToken string,
	resultAmountIn, resultAmountOut *u256.Uint,
	swapType SwapType,
	tokenAmountLimit *u256.Uint,
	userBeforeWugnotBalance, userWrappedWugnot uint64,
	amountSpecified *u256.Uint,
) (string, string) {
	if swapType == ExactOut && resultAmountOut.Lt(amountSpecified) {
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("too few received for user (expected minimum: %s, actual: %s, swapType: %s)", amountSpecified.ToString(), resultAmountOut.ToString(), swapType.String()),
		))
	}

	afterFee := handleSwapFee(outputToken, resultAmountOut)

	userNewWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))
	if inputToken == consts.GNOT {
		totalBefore := userBeforeWugnotBalance + userWrappedWugnot
		spend := totalBefore - userNewWugnotBalance

		if spend > userWrappedWugnot {
			// used existing wugnot
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("too much wugnot spent (wrapped: %d, spend: %d)", userWrappedWugnot, spend),
			))
		}

		// unwrap left amount
		toUnwrap := userWrappedWugnot - spend
		unwrap(toUnwrap)
	} else if outputToken == consts.GNOT {
		userRecvWugnot := uint64(userNewWugnotBalance - userBeforeWugnotBalance - userWrappedWugnot)
		unwrap(userRecvWugnot)
	}

	if swapType == ExactIn {
		if !tokenAmountLimit.Lte(afterFee) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("too few received for user (expected minimum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), afterFee.ToString(), swapType.String()),
			))
		}
	} else {
		if !resultAmountIn.Lte(tokenAmountLimit) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("too much spent for user (expected maximum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), resultAmountIn.ToString(), swapType.String()),
			))
		}
	}

	intAmountOut := i256.FromUint256(afterFee)
	return resultAmountIn.ToString(), i256.Zero().Neg(intAmountOut).ToString()
}

func validateRoutesAndQuotes(routes, quotes []string) error {
	if len(routes) < 1 || len(routes) > 7 {
		return ufmt.Errorf("route length(%d) must be 1~7", len(routes))
	}

	if len(routes) != len(quotes) {
		return ufmt.Errorf("mismatch between routes(%d) and quotes(%d) length", len(routes), len(quotes))
	}

	var quotesSum int

	for i, quote := range quotes {
		intQuote, err := strconv.Atoi(quote)
		if err != nil {
			return ufmt.Errorf("invalid quote(%s) at index(%d)", quote, i)
		}

		quotesSum += intQuote
	}

	if quotesSum != 100 {
		return ufmt.Errorf("quote sum(%d) must be 100", quotesSum)
	}

	return nil
}

func tryParseRoutes(routes, quotes string) ([]string, []string, error) {
	routesArr := splitSingleChar(routes, ',')
	quotesArr := splitSingleChar(quotes, ',')

	if err := validateRoutesAndQuotes(routesArr, quotesArr); err != nil {
		return nil, nil, err
	}

	return routesArr, quotesArr, nil
}
