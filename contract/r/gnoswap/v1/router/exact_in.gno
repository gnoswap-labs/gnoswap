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

// ExactInSwapRoute swaps an exact amount of input tokens for output tokens.
//
// Executes multi-hop swaps through specified route.
// Supports splitting across multiple paths for price optimization.
// Applies slippage protection via minimum output amount.
//
// Parameters:
//   - inputToken, outputToken: Token contract paths
//   - amountIn: Exact input amount to swap
//   - routeArr: Swap route (max 3 hops per path, multiple paths separated by comma)
//   - quoteArr: Split percentages "70,30" (must sum to 100)
//   - amountOutMin: Minimum acceptable output (slippage protection)
//   - deadline: Unix timestamp for expiration
//   - referrer: Optional referral address
//
// Route format:
//   - Single-hop: "TOKEN0:TOKEN1:FEE"
//   - Multi-hop: "TOKEN0:TOKEN1:FEE*POOL*TOKEN1:TOKEN2:FEE" (use *POOL* separator)
//   - Multi-path: "route1,route2" (use comma separator between different routes)
//
// Returns:
//   - amountIn: Actual input consumed
//   - amountOut: Actual output received
//
// Reverts if output < amountOutMin or deadline passed.
func ExactInSwapRoute(cur realm,
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouterWithVersion(1)

	assertIsValidUserCoinSend(inputToken, amountIn)
	assertIsValidRoutePaths(routeArr, inputToken, outputToken)
	assertIsNotPassedDeadline(deadline)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:  inputToken,
		outputToken: outputToken,
		routeArr:    routeArr,
		quoteArr:    quoteArr,
		deadline:    deadline,
		typ:         ExactIn,
		exactAmount: amountIn,
		limitAmount: amountOutMin,
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
		common.SafeGRC20Transfer(cross, outputToken, std.PreviousRealm().Address(), outputAmount.Int64())
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
		"ExactInSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", inputToken,
		"output", outputToken,
		"exactAmount", amountIn,
		"route", routeArr,
		"quote", quoteArr,
		"resultInputAmount", inputAmountStr,
		"resultOutputAmount", outputAmountStr,
		"referrer", actualReferrer,
	)

	return inputAmountStr, outputAmountStr
}

// Validate validates the exact-in swap operation parameters.
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

// Process executes the exact-in swap operation.
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
		WithUnwrap:      op.withUnwrap,
	}, nil
}

// handleNativeTokenWrapping handles the wrapping of native tokens if needed.
func (op *ExactInSwapOperation) handleNativeTokenWrapping() error {
	return op.baseSwapOperation.handleNativeTokenWrapping(
		op.params.InputToken,
		op.params.OutputToken,
		op.amountSpecified,
	)
}
