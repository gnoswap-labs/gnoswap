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

const (
	POOL_SEPARATOR = "*POOL*"

	INITIAL_WUGNOT_BALANCE uint64 = 0

	SINGLE_HOP_ROUTE int = 1
)

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
	RouteArr string,
	quoteArr string,
	tokenAmountLimit string,
) (string, string) {
	common.IsHalted()
	assertNotASwapType(swapType)
	assertDirectCallOnly()

	en.MintAndDistributeGns()
	if consts.EMISSION_REFACTORED {
		sr.CalcPoolPositionRefactor()
	} else {
		sr.CalcPoolPosition()
	}

	baseParams := BaseSwapParams{
		InputToken:  inputToken,
		OutputToken: outputToken,
		RouteArr:    RouteArr,
		QuoteArr:    quoteArr,
	}

	// route to appropriate function based on swap type
	switch swapType {
	case ExactIn:
		pp := ExactInParams{
			BaseSwapParams: baseParams,
			AmountIn:       amountSpecified,
			AmountOutMin:   tokenAmountLimit,
		}
		return ExactInSwapRoute(pp)
	case ExactOut:
		pp := ExactOutParams{
			BaseSwapParams: baseParams,
			AmountOut:      amountSpecified,
			AmountInMax:    tokenAmountLimit,
		}
		return ExactOutSwapRoute(pp)
	default:
		// This should not happen due to validateSwapType,
		// but included for completeness
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swap type: %s", swapType),
		))
	}
}

type BaseSwapParams struct {
	InputToken  string
	OutputToken string
	RouteArr    string
	QuoteArr    string
	Deadline    int64
}

type ExactInParams struct {
	BaseSwapParams
	AmountIn     string
	AmountOutMin string
}

type ExactOutParams struct {
	BaseSwapParams
	AmountOut   string
	AmountInMax string
}

// common swap operation
type baseSwapOperation struct {
	routes                  []string
	quotes                  []string
	amountSpecified         *i256.Int
	userBeforeWugnotBalance uint64
	userWrappedWugnot       uint64
}

func (op *baseSwapOperation) handleNativeTokenWrapping(
	inputToken string,
	outputToken string,
	swapType string,
	specifiedAmount *i256.Int,
) error {
	// no native token
	if inputToken == consts.GNOT || outputToken == consts.GNOT {
		return nil
	}

	// save current user's WGNOT amount
	op.userBeforeWugnotBalance = wugnot.BalanceOf(a2u(std.PrevRealm().Addr()))

	if swapType == ExactIn && inputToken == consts.GNOT {
		sent := std.GetOrigSend()

		ugnotSentByUser := uint64(sent.AmountOf("ugnot"))
		amountSpecified := specifiedAmount.Uint64()

		if ugnotSentByUser != amountSpecified {
			return ufmt.Errorf("ugnot sent by user(%d) is not equal to amountSpecified(%d)", ugnotSentByUser, amountSpecified)
		}

		// wrap user's WUGNOT
		if ugnotSentByUser > 0 {
			wrap(ugnotSentByUser)
		}

		op.userWrappedWugnot = ugnotSentByUser
	}

	return nil
}

func (op *baseSwapOperation) validateRouteQuote(quote string, i int) (*i256.Int, error) {
	qt, err := strconv.Atoi(quote)
	if err != nil {
		return nil, ufmt.Errorf("invalid quote(%s) at index(%d)", quote, i)
	}

	// calculate amount to swap for this route
	toSwap := i256.Zero().Mul(op.amountSpecified, i256.NewInt(int64(qt)))
	toSwap = toSwap.Div(toSwap, i256.NewInt(100))

	return toSwap, nil
}

func (op *baseSwapOperation) processRoute(
	route string,
	toSwap *i256.Int,
	swapType string,
) (*u256.Uint, *u256.Uint, error) {
	numHops := strings.Count(route, POOL_SEPARATOR) + 1
	assertHopsInRange(numHops)

	var amountIn, amountOut *u256.Uint

	switch numHops {
	case SINGLE_HOP_ROUTE:
		amountIn, amountOut = handleSingleSwap(route, toSwap)
	default:
		amountIn, amountOut = handleMultiSwap(swapType, route, numHops, toSwap)
	}

	if amountIn == nil || amountOut == nil {
		return nil, nil, ufmt.Errorf("swap failed to process route(%s)", route)
	}

	return amountIn, amountOut, nil
}

type ExactInSwapOperation struct {
	baseSwapOperation
	params ExactInParams
}

func NewExactInSwapOperation(pp ExactInParams) *ExactInSwapOperation {
	return &ExactInSwapOperation{
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
		},
	}
}

type ExactOutSwapOperation struct {
	baseSwapOperation
	params ExactOutParams
}

func NewExactOutSwapOperation(pp ExactOutParams) *ExactOutSwapOperation {
	return &ExactOutSwapOperation{
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
		},
	}
}

type RouterOperation interface {
	Validate() error
	Process() (*SwapResult, error)
}

// SwapResult encapsulates the outcome of a swap operation
type SwapResult struct {
	AmountIn        *u256.Uint
	AmountOut       *u256.Uint
	Routes          []string
	Quotes          []string
	AmountSpecified *i256.Int
}

////////////////////////////////////////////////////////
// region: ExactInSwapOperation

func ExactInSwapRoute(pp ExactInParams) (string, string) {
	op := NewExactInSwapOperation(pp)

	if err := op.Validate(); err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid ExactInSwapOperation: %s", err.Error()),
		))
	}

	result, err := op.Process()
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid ExactInSwapOperation: %s", err.Error()),
		))
	}

	amountIn, amountOut := finalizeSwap(
		pp.InputToken,
		pp.OutputToken,
		result.AmountIn,
		result.AmountOut,
		ExactIn,
		u256.MustFromDecimal(pp.AmountOutMin),
		op.userBeforeWugnotBalance,
		op.userWrappedWugnot,
		// if swap type is EXACT_OUT, compare with this value to see
		// user can actually receive this amount
		result.AmountSpecified.Abs(),
	)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"ExactInSwap",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"input", pp.InputToken,
		"output", pp.OutputToken,
		"amountIn", result.AmountIn.ToString(),
		"route", pp.RouteArr,
		"quote", pp.QuoteArr,
		"internal_amountIn", result.AmountIn.ToString(),
		"internal_amountOut", result.AmountOut.ToString(),
		"internal_amountOutWithoutFee", result.AmountOut.ToString(),
	)

	return amountIn, amountOut
}

func (op *ExactInSwapOperation) Validate() error {
	// TODO (@notJoon): make as Assert function
	amountIn := i256.MustFromDecimal(op.params.AmountOutMin)
	if amountIn.IsZero() || amountIn.IsNeg() {
		return ufmt.Errorf("invalid amountInMin(%s), must be positive", amountIn.ToString())
	}

	// when `SwapType` is `ExactIn`, assign `amountSpecified` the `amountIn`
	// obtained from above.
	op.amountSpecified = amountIn

	// TODO (@notJoon): extract as function
	routes := strings.Split(op.params.RouteArr, ",")
	quotes := strings.Split(op.params.QuoteArr, ",")

	if err := validateRoutesAndQuotes(routes, quotes); err != nil {
		return err
	}

	op.routes = routes
	op.quotes = quotes

	return nil
}

func (op *ExactInSwapOperation) Process() (*SwapResult, error) {
	if err := op.handleNativeTokenWrapping(); err != nil {
		return nil, err
	}

	resultAmountIn, resultAmountOut, err := op.processRoutes()
	if err != nil {
		return nil, err
	}

	return &SwapResult{
		AmountIn:        resultAmountIn,
		AmountOut:       resultAmountOut,
		Routes:          op.routes,
		Quotes:          op.quotes,
		AmountSpecified: op.amountSpecified,
	}, nil
}

func (op *ExactInSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		ExactIn,
		op.amountSpecified,
	)
}

func (op *ExactInSwapOperation) processRoutes() (*u256.Uint, *u256.Uint, error) {
	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range op.routes {
		// calculate amount to swap for this route
		toSwap, err := op.validateRouteQuote(op.quotes[i], i)
		if err != nil {
			return nil, nil, err
		}

		amountIn, amountOut, err := op.processRoute(route, toSwap, ExactIn)
		if err != nil {
			return nil, nil, err
		}

		resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
		resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
	}

	return resultAmountIn, resultAmountOut, nil
}

////////////////////////////////////////////////////////
// region: ExactOutSwapOperation

func ExactOutSwapRoute(params ExactOutParams) (string, string) {
	op := NewExactOutSwapOperation(params)

	if err := op.Validate(); err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	result, err := op.Process()
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	amountIn, amountOut := finalizeSwap(
		params.InputToken,
		params.OutputToken,
		result.AmountIn,
		result.AmountOut,
		ExactOut,
		u256.MustFromDecimal(params.AmountInMax),
		op.userBeforeWugnotBalance,
		op.userWrappedWugnot,
		result.AmountSpecified.Abs(),
	)

	prevAddr, prevPkgPath := getPrev()

	std.Emit(
		"ExactOutSwap",
		"prevAddr", prevAddr,
		"prevRealm", prevPkgPath,
		"input", params.InputToken,
		"output", params.OutputToken,
		"amountOut", params.AmountOut,
		"route", params.RouteArr,
		"quote", params.QuoteArr,
		"internal_amountIn", result.AmountIn.ToString(),
		"internal_amountOut", result.AmountOut.ToString(),
		"internal_amountOutWithoutFee", result.AmountOut.ToString(),
	)

	return amountIn, amountOut
}

func (op *ExactOutSwapOperation) Validate() error {
	amountOut := i256.MustFromDecimal(op.params.AmountOut)
	if amountOut.IsZero() || amountOut.IsNeg() {
		return ufmt.Errorf("invalid amountOut(%s), must be positive", amountOut.ToString())
	}

	// assign a signed reversed `amountOut` to `amountSpecified`
	// when it's an ExactOut
	op.amountSpecified = new(i256.Int).Neg(amountOut)

	// TODO (@notJoon): extract as function
	routes := strings.Split(op.params.RouteArr, ",")
	quotes := strings.Split(op.params.QuoteArr, ",")

	if err := validateRoutesAndQuotes(routes, quotes); err != nil {
		return err
	}

	op.routes = routes
	op.quotes = quotes

	return nil
}

func (op *ExactOutSwapOperation) Process() (*SwapResult, error) {
	if err := op.handleNativeTokenWrapping(); err != nil {
		return nil, err
	}

	resultAmountIn, resultAmountOut, err := op.processRoutes()
	if err != nil {
		return nil, err
	}

	return &SwapResult{
		AmountIn:        resultAmountIn,
		AmountOut:       resultAmountOut,
		Routes:          op.routes,
		Quotes:          op.quotes,
		AmountSpecified: op.amountSpecified,
	}, nil
}

func (op *ExactOutSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		ExactOut,
		op.amountSpecified,
	)
}

func (op *ExactOutSwapOperation) processRoutes() (*u256.Uint, *u256.Uint, error) {
	resultAmountIn := u256.Zero()
	resultAmountOut := u256.Zero()

	for i, route := range op.routes {
		toSwap, err := op.validateRouteQuote(op.quotes[i], i)
		if err != nil {
			return nil, nil, err
		}

		// for `ExactOut`, we need to negate the amount
		toSwap = i256.Zero().Neg(toSwap)

		amountIn, amountOut, err := op.processRoute(route, toSwap, ExactOut)
		if err != nil {
			return nil, nil, err
		}

		resultAmountIn = new(u256.Uint).Add(resultAmountIn, amountIn)
		resultAmountOut = new(u256.Uint).Add(resultAmountOut, amountOut)
	}

	return resultAmountIn, resultAmountOut, nil
}

////////////////////////////////////////////////////////

func validateRoutesAndQuotes(routes, quotes []string) error {
	if len(routes) < 1 || len(routes) > 7 {
		return ufmt.Errorf("route length(%d) must be 1~7", len(routes))
	}

	if len(routes) != len(quotes) {
		return ufmt.Errorf("mismatch between routes(%d) and quotes(%d) length", len(routes), len(quotes))
	}

	var quotesSum int64
	for _, quote := range quotes {
		intQuote, _ := strconv.Atoi(quote)
		quotesSum += int64(intQuote)
	}

	if quotesSum != 100 {
		return ufmt.Errorf("quote sum(%d) must be 100", quotesSum)
	}

	return nil
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

func handleMultiSwap(swapType string, route string, numHops int, amountSpecified *i256.Int) (*u256.Uint, *u256.Uint) {
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

		return multiSwapNegative(swapParams, numHops-1, route) // iterate here

	default:
		panic(addDetailToError(
			errInvalidSwapType,
			ufmt.Sprintf("unknown swapType(%s)", swapType),
		))
	}
}

func finalizeSwap(inputToken, outputToken string, resultAmountIn, resultAmountOut *u256.Uint, swapType string, tokenAmountLimit *u256.Uint, userBeforeWugnotBalance, userWrappedWugnot uint64, amountSpecified *u256.Uint) (string, string) {
	if swapType == ExactOut && resultAmountOut.Lt(amountSpecified) {
		panic(addDetailToError(
			errSlippage,
			ufmt.Sprintf("too few received for user (expected minimum: %s, actual: %s, swapType: %s)", amountSpecified.ToString(), resultAmountOut.ToString(), swapType),
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

	// TODO (@notJoon): Is it possible for an invalid SwapType to get this point?
	// TODO(@notJoon): remove not operatior and extract as function.
	if swapType == ExactIn {
		if !tokenAmountLimit.Lte(afterFee) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("too few received for user (expected minimum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), afterFee.ToString(), swapType),
			))
		}
	} else {
		if !resultAmountIn.Lte(tokenAmountLimit) {
			panic(addDetailToError(
				errSlippage,
				ufmt.Sprintf("too much spent for user (expected maximum: %s, actual: %s, swapType: %s)", tokenAmountLimit.ToString(), resultAmountIn.ToString(), swapType),
			))
		}
	}

	intAmountOut := i256.FromUint256(afterFee)
	return resultAmountIn.ToString(), i256.Zero().Neg(intAmountOut).ToString()
}
