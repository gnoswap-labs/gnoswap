package router

import (
	"chain"

	"gno.land/r/gnoswap/access"

	ufmt "gno.land/p/nt/ufmt/v0"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/gnoswap/utils"

	"gno.land/r/gnoswap/common"
	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/halt"
	"gno.land/r/gnoswap/referral"
)

// ExactOutSwapRoute swaps tokens for a requested post-router-fee output target.
//
// Executes a swap to receive the requested net output tokens.
// Calculates the required gross pool output and input working backwards
// through the route.
//
// Parameters:
//   - inputToken: Input token contract path
//   - outputToken: Output token contract path
//   - amountOut: Requested net output target
//   - routeArr: Swap routes separated by comma; each route may contain up to 3 hops joined by *POOL*
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
//   - amountOut: Net output delivered after the router fee
//
// Reverts if input > amountInMax or deadline passed.
func (r *routerV1) ExactOutSwapRoute(
	_ int,
	rlm realm,
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	quoteArr string,
	amountInMax string,
	deadline int64,
	referrer string,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedRouter()

	common.AssertIsNotHandleNativeCoin()

	assertIsValidRoutePaths(routeArr, inputToken, outputToken)
	assertIsNotExpired(deadline)
	assertIsExistsPools(routeArr)

	emission.MintAndDistributeGns(cross(rlm))

	params := SwapRouteParams{
		inputToken:        inputToken,
		outputToken:       outputToken,
		routeArr:          routeArr,
		quoteArr:          quoteArr,
		deadline:          deadline,
		typ:               ExactOut,
		exactAmount:       utils.SafeParseInt64(amountOut),
		limitAmount:       utils.SafeParseInt64(amountInMax),
		sqrtPriceLimitX96: u256.Zero(), // multi-hop swap is not allowed to set sqrtPriceLimitX96
	}

	inputAmount, outputAmount := r.exactOutSwapRoute(0, rlm, params, referrer)

	return utils.FormatInt(inputAmount), utils.FormatInt(outputAmount)
}

// ExactOutSingleSwapRoute swaps tokens for a requested post-router-fee output
// target through a single route.
//
// Executes a single-hop swap through a single specified route.
// Allows price limit control via sqrtPriceLimitX96.
// Applies slippage protection via maximum input amount.
//
// Parameters:
//   - inputToken: Input token contract path
//   - outputToken: Output token contract path
//   - amountOut: Requested net output target
//   - routeArr: Single-hop route path
//   - amountInMax: Maximum input to spend (slippage protection)
//   - sqrtPriceLimitX96: Price limit for swap execution (0 for no limit)
//   - deadline: Unix timestamp for expiration
//   - referrer: Optional referral address
//
// Route format:
//   - Single-hop: "INPUT_TOKEN:OUTPUT_TOKEN:FEE"
//
// Returns:
//   - amountIn: Actual input consumed
//   - amountOut: Net output delivered after the router fee
//
// With a nonzero price limit, the swap may stop at the limit and deliver less
// than amountOut; amountInMax and the deadline are still enforced.
func (r *routerV1) ExactOutSingleSwapRoute(
	_ int,
	rlm realm,
	inputToken string,
	outputToken string,
	amountOut string,
	routeArr string,
	amountInMax string,
	sqrtPriceLimitX96 string,
	deadline int64,
	referrer string,
) (string, string) {
	access.AssertIsRlmCurrent(0, rlm)

	halt.AssertIsNotHaltedRouter()

	common.AssertIsNotHandleNativeCoin()

	assertIsValidSingleSwapRouteArrPath(routeArr, inputToken, outputToken)
	assertIsValidSqrtPriceLimitX96(sqrtPriceLimitX96)
	assertIsNotExpired(deadline)
	assertIsExistsPools(routeArr)

	emission.MintAndDistributeGns(cross(rlm))

	params := SwapRouteParams{
		inputToken:        inputToken,
		outputToken:       outputToken,
		routeArr:          routeArr,
		quoteArr:          "100",
		deadline:          deadline,
		typ:               ExactOut,
		exactAmount:       utils.SafeParseInt64(amountOut),
		limitAmount:       utils.SafeParseInt64(amountInMax),
		sqrtPriceLimitX96: u256.MustFromDecimal(sqrtPriceLimitX96), // single swap is allowed to set sqrtPriceLimitX96
	}

	inputAmount, outputAmount := r.exactOutSwapRoute(0, rlm, params, referrer)

	return utils.FormatInt(inputAmount), utils.FormatInt(outputAmount)
}

// exactOutSwapRoute executes the swap operation and handles token transfers and referral registration.
//
// Performs the actual swap operation using commonSwapRoute and handles:
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
//   - outputAmount: Actual output amount received as string
//
// Panics if swap execution fails or token transfer fails.
func (r *routerV1) exactOutSwapRoute(
	_ int,
	rlm realm,
	params SwapRouteParams,
	referrer string,
) (int64, int64) {
	inputAmount, outputAmount, err := r.commonSwapRoute(0, rlm, params)
	if err != nil {
		panic(err)
	}

	previousRealm := rlm.Previous()
	caller := previousRealm.Address()

	common.SafeGRC20Transfer(0, rlm, params.outputToken, caller, outputAmount)

	// handle referral registration
	actualReferrer := referral.TryRegister(cross(rlm), caller, referrer)

	eventAttrs := append([]string{
		"prevAddr", caller.String(),
		"prevRealm", previousRealm.PkgPath(),
		"input", params.inputToken,
		"output", params.outputToken,
		"exactAmount", utils.FormatInt(params.exactAmount),
		"quote", params.quoteArr,
		"resultInputAmount", utils.FormatInt(inputAmount),
		"resultOutputAmount", utils.FormatInt(outputAmount),
		"referrer", actualReferrer,
	}, buildRouteEventAttrs(params.routeArr)...)

	chain.Emit(
		"ExactOutSwap",
		eventAttrs...,
	)

	return inputAmount, outputAmount
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
			sqrtPriceLimitX96: pp.SqrtPriceLimitX96,
		},
	}
}

// Validate ensures the exact-out swap parameters are valid.
func (op *ExactOutSwapOperation) Validate() error {
	amountOut := op.params.AmountOut
	if amountOut <= 0 {
		return ufmt.Errorf("invalid amountOut(%d), must be positive", amountOut)
	}

	// assign a signed reversed `amountOut` to `amountSpecified`
	// when it's an ExactOut
	op.amountSpecified = -amountOut

	routes, quotes, err := validateRoutesAndQuotes(op.params.RouteArr, op.params.QuoteArr)
	if err != nil {
		return err
	}

	op.routes = routes
	op.quotes = quotes

	return nil
}

// Process executes the exact-out swap operation.
func (op *ExactOutSwapOperation) Process(_ int, rlm realm) (*SwapResult, error) {
	resultAmountIn, resultAmountOut, err := op.processRoutes(0, rlm, op.router, ExactOut)
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
