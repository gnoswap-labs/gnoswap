package router

import (
	"std"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
	"gno.land/r/gnoswap/v1/common"
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
// Executes swap to receive exact output tokens.
// Calculates required input working backwards through route.
// Useful for buying specific amounts regardless of price.
//
// Parameters:
//   - inputToken, outputToken: Token contract paths
//   - amountOut: Exact output amount desired
//   - routeArr: Swap route "TOKEN0:TOKEN1:FEE,TOKEN1:TOKEN2:FEE" (max 7 hops)
//   - quoteArr: Split percentages "70,30" (must sum to 100)
//   - amountInMax: Maximum input to spend (slippage protection)
//   - deadline: Unix timestamp for expiration
//   - referrer: Optional referral address
//
// Route calculation:
//   - Works backwards from output to input
//   - Each hop increases required input
//   - Multi-path aggregates total input
//
// Returns:
//   - amountIn: Actual input consumed
//   - amountOut: Exact output received
//
// Reverts if input > amountInMax or deadline passed.
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
		err = unwrapWithTransfer(std.PreviousRealm().Address(), outputAmount.Int64())
		if err != nil {
			panic(err)
		}
	} else {
		common.Transfer(cross, outputToken, std.PreviousRealm().Address(), outputAmount.Int64())
	}

	// handle referral registration
	previousRealm := std.PreviousRealm()
	caller := previousRealm.Address()
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	inputAmountStr := inputAmount.ToString()
	outputAmountStr := i256.Zero().Neg(outputAmount).ToString()

	std.Emit(
		"ExactOutSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", inputToken,
		"output", outputToken,
		"exactAmount", amountOut,
		"route", routeArr,
		"quote", quoteArr,
		"resultInputAmount", inputAmountStr,
		"resultOutputAmount", outputAmountStr,
		"referrer", actualReferrer,
	)

	return inputAmountStr, outputAmountStr
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
