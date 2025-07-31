package router

import (
	"std"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"

	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/halt"
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

// ExactInSwapRoute is a function that performs an exact-in swap operation.
// exact-in swap means that the user wants to swap an exact amount of input tokens for output tokens.
func ExactInSwapRoute(cur realm,
	inputToken string,
	outputToken string,
	amountIn string,
	RouteArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouter()
	halt.AssertIsNotHaltedWithdraw()

	assertIsNotPassedDeadline(deadline)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:  inputToken,
		outputToken: outputToken,
		routeArr:    RouteArr,
		quoteArr:    quoteArr,
		deadline:    deadline,
		referrer:    referrer,
		typ:         ExactIn,
		exactAmount: amountIn,
		limitAmount: amountOutMin,
	}

	inputAmount, outputAmount, actualReferrer, err := commonSwapRoute(cur, params)
	if err != nil {
		panic(err)
	}

	previousRealm := std.PreviousRealm()
	std.Emit(
		"ExactInSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", inputToken,
		"output", outputToken,
		"exactAmount", amountIn,
		"route", RouteArr,
		"quote", quoteArr,
		"resultInputAmount", inputAmount,
		"resultOutputAmount", outputAmount,
		"referrer", actualReferrer,
	)

	return inputAmount, outputAmount
}

func (op *ExactInSwapOperation) Validate() error {
	amountIn := i256.MustFromDecimal(op.params.AmountIn)
	if amountIn.IsZero() || amountIn.IsNeg() {
		return ufmt.Errorf("invalid amountIn(%s), must be positive", amountIn.ToString())
	}

	// when `SwapType` is `ExactIn`, assign `amountSpecified` the `amountIn`
	// obtained from above.
	op.amountSpecified = amountIn

	routes, quotes, err := validateRoutesAndQuotes(op.params.RouteArr, op.params.QuoteArr)
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
		op.amountSpecified,
	)
}
