package router

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/gnoswap/int256"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

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

// ExactOutSwapRoute is a function that performs an exact-out swap operation.
// exact-out swap means that the user wants to swap an exact amount of output tokens for input tokens.
func ExactOutSwapRoute(cur realm,
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	quoteArr string,
	amountInMax string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouter()

	assertIsNotPassedDeadline(deadline)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:  inputToken,
		outputToken: outputToken,
		routeArr:    routeArr,
		quoteArr:    quoteArr,
		deadline:    deadline,
		typ:         ExactOut,
		exactAmount: amountOut,
		limitAmount: amountInMax,
	}

	inputAmount, outputAmount, err := commonSwapRoute(params)
	if err != nil {
		panic(err)
	}

	if params.IsUnwrap() {
		amount, err := strconv.ParseInt(params.exactAmount, 10, 64)
		if err != nil {
			panic(err)
		}

		err = unwrapWithTransfer(std.PreviousRealm().Address(), amount)
		if err != nil {
			panic(err)
		}
	}

	// handle referral registration
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	std.Emit(
		"ExactOutSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", inputToken,
		"output", outputToken,
		"exactAmount", amountOut,
		"route", routeArr,
		"quote", quoteArr,
		"resultInputAmount", inputAmount,
		"resultOutputAmount", outputAmount,
		"referrer", actualReferrer,
	)

	return inputAmount, outputAmount
}

func (op *ExactOutSwapOperation) Validate() error {
	amountOut := i256.MustFromDecimal(op.params.AmountOut)
	if amountOut.IsZero() || amountOut.IsNeg() {
		return ufmt.Errorf("invalid amountOut(%s), must be positive", amountOut.ToString())
	}

	// assign a signed reversed `amountOut` to `amountSpecified`
	// when it's an ExactOut
	op.amountSpecified = i256.Zero().Neg(amountOut)

	routes, quotes, err := validateRoutesAndQuotes(op.params.RouteArr, op.params.QuoteArr)
	if err != nil {
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

	resultAmountIn, resultAmountOut, err := op.processRoutes(ExactOut)
	if err != nil {
		return nil, err
	}

	return &SwapResult{
		AmountIn:        resultAmountIn,
		AmountOut:       resultAmountOut,
		Routes:          op.routes,
		Quotes:          op.quotes,
		AmountSpecified: op.amountSpecified,
		WithUnwrap:      op.withUnwrap,
	}, nil
}

func (op *ExactOutSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		i256.MustFromDecimal(op.params.AmountInMax),
	)
}
