package router

import (
	"errors"
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


const POOL_SEP = "*POOL*"

type RouteParams struct {
	inputToken string
	outputToken string
	amountSpecified *i256.Int
	swapType string
	routes []string
	quotes []int
}

// NewRouteParams creates a new RouteParams instance
func newRouteParams(
	inputToken, outputToken, amountSpecified string,
	swapType string,
	strRouteArr string,
	quoteArr string,
) (*RouteParams, error) {
    amount, err := i256.FromDecimal(amountSpecified)
    if err != nil {
        return nil, err
    }

    routes := strings.Split(strRouteArr, ",")
    quotes := make([]int, len(strings.Split(quoteArr, ",")))

    for i, q := range strings.Split(quoteArr, ",") {
        quote, err := strconv.Atoi(q)
		if err != nil {
			return nil, errors.New("invalid quote")
		}
        quotes[i] = quote
    }

    return &RouteParams{
        inputToken:      inputToken,
        outputToken:     outputToken,
        amountSpecified: amount,
        swapType:        swapType,
        routes:          routes,
        quotes:          quotes,
    }, nil
}

func (rp *RouteParams) validate() error {
	if rp.swapType != ExactIn && rp.swapType != ExactOut {
		return ufmt.Errorf("invalid swap type: %s", rp.swapType)
	}

	if rp.amountSpecified.IsZero() || rp.amountSpecified.IsNeg() {
		return ufmt.Errorf("invalid amount specified: %s", rp.amountSpecified)
	}

	if len(rp.routes) < 1 || len(rp.routes) > 7 {
		return ufmt.Errorf("route length must be between 1~7, got %d", len(rp.routes))
	}

	if len(rp.routes) != len(rp.quotes) {
		return ufmt.Errorf("length mismatch: routes(%d) != quotes(%d)", len(rp.routes), len(rp.quotes))
	}

	var quoteSum int
	for _, quote := range rp.quotes {
		quoteSum += quote
	}

	if quoteSum != 100 {
		return ufmt.Errorf("quote sum must be 100, got %d", quoteSum)
	}

	return nil
}

// SwapRoute swaps the input token to the output token and returns the result amount
// If swapType is EXACT_IN, it returns the amount of output token ≈ amount of user to receive
// If swapType is EXACT_OUT, it returns the amount of input token ≈ amount of user to pay
// Returns amountIn, amountOut
// ref: https://docs.gnoswap.io/contracts/router/router.gno#swaproute
func SwapRoute(
    inputToken string,
    outputToken string,
    amountSpecified string,
    swapType string,
    strRouteArr string,
    quoteArr string,
    tokenAmountLimit string,
) (string, string) {
    common.IsHalted()

    if common.GetLimitCaller() && std.PrevRealm().PkgPath() != "" {
        panic(addDetailToError(
            errNoPermission,
            "router.gno__SwapRoute() || only user can call this function",
        ))
    }

    // Initialize emission and staking calculations
    en.MintAndDistributeGns()
    if consts.EMISSION_REFACTORED {
        sr.CalcPoolPositionRefactor()
    } else {
        sr.CalcPoolPosition()
    }

    // Parse and validate route parameters
    params, err := newRouteParams(inputToken, outputToken, amountSpecified, swapType, strRouteArr, quoteArr)
    if err != nil {
        panic(err)
    }

	if err := params.validate(); err != nil {
		panic(err)
	}

    // Handle WUGNOT wrapping if necessary
    userBeforeWugnotBalance, userWrappedWugnot, err := handleWugnotPreSwap(inputToken, outputToken, params)
	if err != nil {
		panic(err)
	}

    // Process routes
    resultAmountIn, resultAmountOut, err := processRoutes(params, false)
    if err != nil {
        panic(err)
    }

	limit := u256.MustFromDecimal(tokenAmountLimit)

    // Finalize swap and handle WUGNOT unwrapping
    amountIn, amountOut, err := finalizeSwap(
        inputToken,
        outputToken,
        resultAmountIn,
        resultAmountOut,
        swapType,
        limit,
        userBeforeWugnotBalance,
        userWrappedWugnot,
        params.amountSpecified.Abs(),
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
		"amountSpecified", params.amountSpecified.ToString(),
		"route", strRouteArr,
		"quote", quoteArr,
		"internal_amountIn", amountIn,
		"internal_amountOut", amountOut,
		"internal_amountOutWithoutFee", resultAmountOut.ToString(),
	)

	return amountIn, amountOut
}

func DrySwapRoute(
    inputToken string,
    outputToken string,
    amountSpecified string,
    swapType string,
    strRouteArr string,
    quoteArr string,
) string {
	params, err := newRouteParams(inputToken, outputToken, amountSpecified, swapType, strRouteArr, quoteArr)
	if err != nil {
		panic(err)
	}

	if err := params.validate(); err != nil {
		panic(err)
	}

	resultAmountIn, resultAmountOut, err := processRoutes(params, true)
	if err != nil {
		panic(err)
	}

	result, err := processResult(params.swapType, resultAmountIn, resultAmountOut, params.amountSpecified)
	if err != nil {
		panic(err)
	}

	return result
}

func processRoutes(params *RouteParams, isDry bool) (*u256.Uint, *u256.Uint, error) {
	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range params.routes {
		numHops := strings.Count(route, POOL_SEP) + 1
		if numHops < 1 || numHops > 3 {
			return nil, nil, ufmt.Errorf("invalid numHops: %d", numHops)
		}

		toSwap := i256.Zero().Mul(params.amountSpecified, i256.NewInt(int64(params.quotes[i])))
		toSwap = toSwap.Div(toSwap, i256.NewInt(int64(100)))

		var amountIn, amountOut *u256.Uint
		if numHops == 1 {
			amountIn, amountOut = handleSingleSwap(route, toSwap, isDry)
		} else {
			amountIn, amountOut = handleMultiSwap(params.swapType, route, numHops, toSwap, isDry)
		}

		resultAmountIn = resultAmountIn.Add(resultAmountIn, amountIn)
		resultAmountOut = resultAmountOut.Add(resultAmountOut, amountOut)
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

func finalizeSwap(
	inputToken, outputToken string,
	resultAmountIn, resultAmountOut *u256.Uint,
	swapType string,
	tokenAmountLimit *u256.Uint,
	userBeforeWugnotBalance, userWrappedWugnot uint64,
	amountSpecified *u256.Uint,
) (string, string, error) {
	if swapType == ExactOut && resultAmountOut.Lt(amountSpecified) {
		return "", "", ufmt.Errorf(
			"%s: not enough amounts received. minimum: %s, actual: %s",
			errSlippage, amountSpecified.ToString(), resultAmountOut.ToString(),
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
				errSlippage, userWrappedWugnot, spend,
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
	if swapType == ExactIn {
		if !tokenAmountLimit.Lte(afterFee) {
			return "", "", ufmt.Errorf(
				"%s: minimum amount not received (minimim: %s, actual: %s, swapType: %s)",
				errSlippage, tokenAmountLimit.ToString(), afterFee.ToString(), swapType,
			)
		}
	} else {
		if !resultAmountIn.Lte(tokenAmountLimit) {
			return "", "", ufmt.Errorf(
				"%s: maximum amount exceeded (maximum: %s, actual: %s, swapType: %s)",
				errSlippage, tokenAmountLimit.ToString(), resultAmountIn.ToString(), swapType,
			)
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
	case ExactIn:
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

	case ExactOut:
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

// handleWugnotPreSwap handles WUGNOT wrapping before swap
func handleWugnotPreSwap(inputToken, outputToken string, params *RouteParams) (uint64, uint64, error) {
    if inputToken != consts.GNOT && outputToken != consts.GNOT {
        return 0, 0, nil
    }

    userBeforeWugnotBalance := wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))
    var userWrappedWugnot uint64

    if params.swapType == ExactIn && inputToken == consts.GNOT {
        sent := std.GetOrigSend()
        ugnotSentByUser := uint64(sent.AmountOf("ugnot"))
        u64AmountSpecified := params.amountSpecified.Uint64()

        if ugnotSentByUser != u64AmountSpecified {
			return 0, 0, ufmt.Errorf(
				"%s: ugnot sent by user(%d) is not equal to amountSpecified(%d)",
				errInvalidInput, ugnotSentByUser, u64AmountSpecified,
			)
        }

        if ugnotSentByUser > 0 {
            wrap(ugnotSentByUser)
        }
        userWrappedWugnot = ugnotSentByUser
    }

    return userBeforeWugnotBalance, userWrappedWugnot, nil
}

func processResult(
	swapType string,
	resultAmountIn, resultAmountOut *u256.Uint,
	amountSpecified *i256.Int,
) (string, error) {
	switch swapType {
	case ExactIn:
		if !i256.FromUint256(resultAmountIn).Eq(amountSpecified) {
			return "-1", errors.New("amount mismatch in ExactIn")
		}
		return resultAmountOut.ToString(), nil
	case ExactOut:
		if i256.FromUint256(resultAmountOut).Lt(amountSpecified) {
			return "-1", errors.New("insufficient output amount in ExactOut")
		}
		return resultAmountIn.ToString(), nil
	default:
		return "", ufmt.Errorf("%s: unknown swapType(%s)", errInvalidSwapType, swapType)
	}
}