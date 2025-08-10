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

// ExactOutSwapOperation handles swaps where the output amount is specified.
type ExactOutSwapOperation struct {
	baseSwapOperation
	params ExactOutParams
}

// NewExactOutSwapOperation creates a new exact-out swap operation.
func NewExactOutSwapOperation(pp ExactOutParams) *ExactOutSwapOperation {
	return &ExactOutSwapOperation{
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
		},
	}
}

// ExactOutSwapRoute swaps tokens for an exact output amount.
//
// Parameters:
//   - inputToken, outputToken: token contract paths
//   - amountOut: exact output amount
//   - routeArr: swap route "POOL_PATH,TOKEN0,TOKEN1,FEE:NEXT_POOL..."
//   - quoteArr: percentage allocation for multi-path swaps
//   - amountInMax: maximum input amount
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns amountIn, amountOut as decimal strings.
func ExactOutSwapRoute(
	cur realm,
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
		amount, err := strconv.ParseInt(outputAmount, 10, 64)
		if err != nil {
			panic(err)
		}

		if amount < 0 {
			amount = amount * -1
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

// Validate ensures the exact-out swap parameters are valid.
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

// Process executes the exact-out swap operation.
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

// handleNativeTokenWrapping manages native token wrapping for exact-out swaps.
func (op *ExactOutSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		i256.MustFromDecimal(op.params.AmountInMax),
	)
}
