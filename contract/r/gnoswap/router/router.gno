package router

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/v1/emission"

	phalt "gno.land/p/gnoswap/halt"
	"gno.land/r/gnoswap/v1/halt"
)

var errExactOutAmountExceeded = "Received more than requested in [EXACT_OUT] requested=%s, actual=%s"

// commonSwapSetup Common validation and setup logic extracted from SwapRoute
func commonSwapSetup() {
	currentLevel := halt.GetCurrentHaltLevel()
	if currentLevel != halt.LvMainnetSafeMode {
		// Check if withdrawals are specifically halted, not just if the system is halted
		if err := halt.IsHalted(phalt.OpTypeWithdraw); err != nil {
			panic(err.Error())
		}

		if halt.IsContractHalted(phalt.OpTypeRouter) {
			panic("router contract operations are currently disabled")
		}
	}
	assertDirectCallOnly()

	en.MintAndDistributeGns()
}

// handleSingleSwap handles a single swap operation.
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
			recipient:       getPrevAddr(),
			amountSpecified: amountSpecified,
		}
		return multiSwap(swapParams, 0, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		swapParams := SwapParams{
			tokenIn:         input,
			tokenOut:        output,
			fee:             fee,
			recipient:       getPrevAddr(),
			amountSpecified: amountSpecified,
		}
		return multiSwapNegative(swapParams, numHops-1, route)
	default:
		// Any invalid `SwapType` is caught in the `SwapRoute` function,
		// so no invalid values can get in here.
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapType),
		))
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
	// Validate exact out amount if applicable
	if swapType == ExactOut {
		if err := validateExactOutAmount(resultAmountOut, amountSpecified); err != nil {
			panic(addDetailToError(errSlippage, err.Error()))
		}
	}

	// Handle swap fee
	resultAmountOutWithoutFee := handleSwapFee(outputToken, resultAmountOut)

	// Get current wugnot balance
	userNewWugnotBalance := wugnot.BalanceOf(std.PreviousRealm().Address())

	// Handle GNOT token unwrapping
	if inputToken == consts.GNOT {
		handleGnotInputSwap(userBeforeWugnotBalance, userWrappedWugnot, userNewWugnotBalance)
	} else if outputToken == consts.GNOT {
		handleGnotOutputSwap(userBeforeWugnotBalance, userWrappedWugnot, userNewWugnotBalance)
	}

	// Validate slippage
	validateSlippage(swapType, resultAmountIn, resultAmountOutWithoutFee, tokenAmountLimit)

	// Calculate final amounts
	intAmountOut := i256.FromUint256(resultAmountOutWithoutFee)
	negativeOut := i256.Zero().Neg(intAmountOut).ToString()

	return resultAmountIn.ToString(), negativeOut
}

// validateExactOutAmount validates if the output amount meets the specified requirements
func validateExactOutAmount(resultAmountOut, amountSpecified *u256.Uint) error {
	if resultAmountOut.Gte(amountSpecified) {
		return nil
	}

	diff := u256.Zero().Sub(amountSpecified, resultAmountOut)
	if diff.Gt(u256.NewUint(1)) {
		return ufmt.Errorf(errExactOutAmountExceeded, amountSpecified.ToString(), resultAmountOut.ToString())
	}
	return nil
}

// handleGnotInputSwap handles the unwrapping logic for GNOT input tokens
func handleGnotInputSwap(userBeforeWugnotBalance, userWrappedWugnot, userNewWugnotBalance uint64) {
	totalBefore := userBeforeWugnotBalance + userWrappedWugnot
	spend := totalBefore - userNewWugnotBalance

	if spend > userWrappedWugnot {
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("too much wugnot spent (wrapped: %d, spend: %d)",
				userWrappedWugnot, spend),
		))
	}

	toUnwrap := userWrappedWugnot - spend
	unwrap(toUnwrap)
}

// handleGnotOutputSwap handles the unwrapping logic for GNOT output tokens
func handleGnotOutputSwap(userBeforeWugnotBalance, userWrappedWugnot, userNewWugnotBalance uint64) {
	userRecvWugnot := uint64(userNewWugnotBalance - userBeforeWugnotBalance - userWrappedWugnot)
	unwrap(userRecvWugnot)
}

// validateSlippage checks if the swap amounts meet the slippage requirements
func validateSlippage(swapType SwapType, resultAmountIn, resultAmountOutWithoutFee, tokenAmountLimit *u256.Uint) {
	switch swapType {
	case ExactIn:
		if resultAmountOutWithoutFee.Lt(tokenAmountLimit) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("ExactIn: too few received (min:%s, got:%s)",
					tokenAmountLimit.ToString(), resultAmountOutWithoutFee.ToString()),
			))
		}
	case ExactOut:
		if resultAmountIn.Gt(tokenAmountLimit) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("ExactOut: too much spent (max:%s, used:%s)",
					tokenAmountLimit.ToString(), resultAmountIn.ToString()),
			))
		}
	default:
		panic("should not happen")
	}
}

// validateRoutesAndQuotes validates the routes and quotes slices based on specific criteria.
//
// Parameters:
// - routes: A slice of strings representing route identifiers.
// - quotes: A slice of strings representing quote percentages corresponding to each route.
//
// Returns:
// - error: An error if the validation fails; nil if all checks pass.
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

// tryParseRoutes parses and validates routes and quotes strings, returning them as slices.
//
// Parameters:
// - routes: A string containing route identifiers separated by commas (e.g., "route1,route2,route3").
// - quotes: A string containing quote identifiers separated by commas (e.g., "quote1,quote2,quote3").
//
// Returns:
// - []string: A slice of route identifiers parsed from the `routes` string.
// - []string: A slice of quote identifiers parsed from the `quotes` string.
// - error: An error if the validation between routes and quotes fails.
func tryParseRoutes(routes, quotes string) ([]string, []string, error) {
	routesArr := splitSingleChar(routes, ',')
	quotesArr := splitSingleChar(quotes, ',')

	if err := validateRoutesAndQuotes(routesArr, quotesArr); err != nil {
		return nil, nil, err
	}

	return routesArr, quotesArr, nil
}
