package v2

import (
	"chain"
	"chain/runtime"

	"gno.land/p/nt/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

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
func (r *routerV1) ExactInSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	quoteArr string,
	amountOutMin string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouter()

	assertIsValidUserCoinSend(inputToken, amountIn)
	assertIsValidRoutePaths(routeArr, inputToken, outputToken)
	assertIsNotExpired(deadline)
	assertIsExistsPools(routeArr)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:        inputToken,
		outputToken:       outputToken,
		routeArr:          routeArr,
		quoteArr:          quoteArr,
		deadline:          deadline,
		typ:               ExactIn,
		exactAmount:       safeParseInt64(amountIn),
		limitAmount:       safeParseInt64(amountOutMin),
		sqrtPriceLimitX96: u256.Zero(), // multi-hop swap is not allowed to set sqrtPriceLimitX96
	}

	inputAmount, outputAmount := r.exactInSwapRoute(params, referrer)

	return formatInt64(inputAmount), formatInt64(outputAmount)
}

// ExactInSingleSwapRoute swaps an exact amount of input tokens for output tokens through a single route.
//
// Executes single-hop swaps through a single specified route.
// Allows price limit control via sqrtPriceLimitX96 parameter.
// Applies slippage protection via minimum output amount.
//
// Parameters:
//   - inputToken, outputToken: Token contract paths
//   - amountIn: Exact input amount to swap
//   - routeArr: Single swap route (just 1 hop)
//   - amountOutMin: Minimum acceptable output (slippage protection)
//   - sqrtPriceLimitX96: Price limit for swap execution (0 for no limit)
//   - deadline: Unix timestamp for expiration
//   - referrer: Optional referral address
//
// Route format:
//   - Single-hop: "INPUT_TOKEN:OUTPUT_TOKEN:FEE"
//
// Returns:
//   - amountIn: Actual input consumed
//   - amountOut: Actual output received
//
// Reverts the transaction if the output amount is less than amountOutMin,
// the deadline has passed, or the price limit is exceeded.
func (r *routerV1) ExactInSingleSwapRoute(
	inputToken string,
	outputToken string,
	amountIn string,
	routeArr string,
	amountOutMin string,
	sqrtPriceLimitX96 string,
	deadline int64,
	referrer string,
) (string, string) {
	halt.AssertIsNotHaltedRouter()

	assertIsValidUserCoinSend(inputToken, amountIn)
	assertIsValidSingleSwapRouteArrPath(routeArr, inputToken, outputToken)
	assertIsValidSqrtPriceLimitX96(sqrtPriceLimitX96)
	assertIsNotExpired(deadline)
	assertIsExistsPools(routeArr)

	emission.MintAndDistributeGns(cross)

	params := SwapRouteParams{
		inputToken:        inputToken,
		outputToken:       outputToken,
		routeArr:          routeArr,
		quoteArr:          "100",
		deadline:          deadline,
		typ:               ExactIn,
		exactAmount:       safeParseInt64(amountIn),
		limitAmount:       safeParseInt64(amountOutMin),
		sqrtPriceLimitX96: u256.MustFromDecimal(sqrtPriceLimitX96), // single swap is allowed to set sqrtPriceLimitX96
	}

	inputAmount, outputAmount := r.exactInSwapRoute(params, referrer)

	return formatInt64(inputAmount), formatInt64(outputAmount)
}

// exactInSwapRoute executes the swap operation and handles token transfers and referral registration.
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
func (r *routerV1) exactInSwapRoute(
	params SwapRouteParams,
	referrer string,
) (int64, int64) {
	inputAmount, outputAmount, err := r.commonSwapRoute(params)
	if err != nil {
		panic(err)
	}

	if params.IsUnwrap() {
		err = unwrapWithTransfer(runtime.PreviousRealm().Address(), outputAmount)
		if err != nil {
			panic(err)
		}
	} else {
		common.SafeGRC20Transfer(cross, params.outputToken, runtime.PreviousRealm().Address(), outputAmount)
	}

	// handle referral registration
	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()
	success := referral.TryRegister(cross, caller, referrer)
	actualReferrer := referrer
	if !success {
		actualReferrer = referral.GetReferral(caller.String())
	}

	resultInputAmount := inputAmount
	resultOutputAmount := -outputAmount

	chain.Emit(
		"ExactInSwap",
		"prevAddr", previousRealm.Address().String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", params.inputToken,
		"output", params.outputToken,
		"exactAmount", formatInt64(params.exactAmount),
		"route", params.routeArr,
		"quote", params.quoteArr,
		"resultInputAmount", formatInt64(resultInputAmount),
		"resultOutputAmount", formatInt64(resultOutputAmount),
		"referrer", actualReferrer,
	)

	return resultInputAmount, resultOutputAmount
}

type ExactInSwapOperation struct {
	baseSwapOperation
	params ExactInParams
	router *routerV1
}

func NewExactInSwapOperation(r *routerV1, pp ExactInParams) *ExactInSwapOperation {
	return &ExactInSwapOperation{
		router: r,
		params: pp,
		baseSwapOperation: baseSwapOperation{
			userWrappedWugnot: INITIAL_WUGNOT_BALANCE,
			sqrtPriceLimitX96: pp.SqrtPriceLimitX96,
		},
	}
}

// Validate validates the exact-in swap operation parameters.
func (op *ExactInSwapOperation) Validate() error {
	amountIn := op.params.AmountIn

	if amountIn <= 0 {
		return ufmt.Errorf("invalid amountIn(%d), must be positive", amountIn)
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

	resultAmountIn, resultAmountOut, err := op.processRoutes(op.router, ExactIn)
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
