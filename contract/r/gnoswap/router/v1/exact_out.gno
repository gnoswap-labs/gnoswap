package v1

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	i256 "gno.land/p/gnoswap/int256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

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
func (r *routerV1) ExactOutSwapRoute(
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	quoteArr string,
	amountInMax string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouterWithVersion(1)

	assertIsValidUserCoinSend(inputToken, amountInMax)
	assertIsValidRoutePaths(routeArr, inputToken, outputToken)
	assertIsNotPassedDeadline(deadline)
	assertIsExistsPools(routeArr)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:        inputToken,
		outputToken:       outputToken,
		routeArr:          routeArr,
		quoteArr:          quoteArr,
		deadline:          deadline,
		typ:               ExactOut,
		exactAmount:       amountOut,
		limitAmount:       amountInMax,
		sqrtPriceLimitX96: zeroString, // multi-hop swap is not allowed to set sqrtPriceLimitX96
	}

	return r.exactOutSwapRoute(params, referrer)
}

// exactOutSwapRoute executes the swap operation and handles token transfers and referral registration.
//
// Performs the actual swap operation using commonSwapRoute and handles:
// - Token unwrapping for native tokens (WUGNOT -> UGNOT)
// - Safe token transfers to the caller
// - Referral registration and tracking
// - Event emission for swap completion
//
// Parameters:
//   - params: SwapRouteParams containing all swap configuration
//   - referrer: Referral address for registration
//
// Returns:
//   - inputAmount: Actual input amount consumed as string
//   - outputAmount: Actual output amount received as string (negative value)
//
// Panics if swap execution fails or token transfer fails.
func (r *routerV1) exactOutSwapRoute(
	params SwapRouteParams,
	referrer string,
) (string, string) {
	inputAmount, outputAmount, err := r.commonSwapRoute(params)
	if err != nil {
		panic(err)
	}

	if params.IsUnwrap() {
		err = unwrapWithTransfer(runtime.PreviousRealm().Address(), outputAmount.Int64())
		if err != nil {
			panic(err)
		}
	} else {
		common.SafeGRC20Transfer(cross, params.outputToken, runtime.PreviousRealm().Address(), outputAmount.Int64())
	}

	// handle referral registration
	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	inputAmountStr := inputAmount.ToString()
	outputAmountStr := i256.Zero().Neg(outputAmount).ToString()

	chain.Emit(
		"ExactOutSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", params.inputToken,
		"output", params.outputToken,
		"exactAmount", params.exactAmount,
		"route", params.routeArr,
		"quote", params.quoteArr,
		"resultInputAmount", inputAmountStr,
		"resultOutputAmount", outputAmountStr,
		"referrer", actualReferrer,
	)

	return inputAmountStr, outputAmountStr
}

// ExactOutSwapOperation handles swaps where the output amount is specified.
type ExactOutSwapOperation struct {
	router *routerV1
	baseSwapOperation
	params ExactOutParams
}

// NewExactOutSwapOperation creates a new exact-out swap operation.
func NewExactOutSwapOperation(r *routerV1, pp ExactOutParams) *ExactOutSwapOperation {
	return &ExactOutSwapOperation{
		router: r,
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
			sqrtPriceLimitX96: pp.SqrtPriceLimitX96,
		},
	}
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

	resultAmountIn, resultAmountOut, err := op.processRoutes(op.router, ExactOut)
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
