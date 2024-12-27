package router

import (
	"std"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"
)

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

func ExactInSwapRoute(
	inputToken string,
	outputToken string,
	finalAmountIn string,
	RouteArr string,
	quoteArr string,
	amountOutMin string,
) (string, string) {
	commonSwapSetup()

	baseParams := BaseSwapParams{
		InputToken:  inputToken,
		OutputToken: outputToken,
		RouteArr:    RouteArr,
		QuoteArr:    quoteArr,
	}

	pp := NewExactInParams(
		baseParams,
		finalAmountIn,
		amountOutMin,
	)

	op := NewExactInSwapOperation(pp)

	result, err := executeSwapOperation(op)
	if err != nil {
		panic(addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid ExactInSwapOperation: %s", err.Error()),
		))
	}

	finalAmountIn, finalAmountOut := finalizeSwap(
		pp.InputToken,
		pp.OutputToken,
		result.AmountIn,
		result.AmountOut,
		ExactIn,
		u256.MustFromDecimal(pp.AmountOutMin),
		op.userBeforeWugnotBalance,
		op.userWrappedWugnot,
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

	return finalAmountIn, finalAmountOut
}

func (op *ExactInSwapOperation) Validate() error {
	amountIn := i256.MustFromDecimal(op.params.AmountIn)
	if amountIn.IsZero() || amountIn.IsNeg() {
		return ufmt.Errorf("invalid amountIn(%s), must be positive", amountIn.ToString())
	}

	// when `SwapType` is `ExactIn`, assign `amountSpecified` the `amountIn`
	// obtained from above.
	op.amountSpecified = amountIn

	routes, quotes, err := tryParseRoutes(op.params.RouteArr, op.params.QuoteArr)
	if err != nil {
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

	resultAmountIn, resultAmountOut, err := op.processRoutes(ExactIn)
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
