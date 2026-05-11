package v1

import (
	"chain"
	"chain/runtime"

	ufmt "gno.land/p/nt/ufmt/v0"

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
//   - inputToken: Input token contract path
//   - outputToken: Output token contract path
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

	common.AssertIsNotHandleNativeCoin()

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
// Executes a single-hop swap through a single specified route.
// Allows price limit control via sqrtPriceLimitX96 parameter.
// Applies slippage protection via minimum output amount.
//
// Parameters:
//   - inputToken: Input token contract path
//   - outputToken: Output token contract path
//   - amountIn: Exact input amount to swap
//   - routeArr: Single-hop route path
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

	common.AssertIsNotHandleNativeCoin()

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

	previousRealm := runtime.PreviousRealm()
	caller := previousRealm.Address()

	common.SafeGRC20Transfer(cross, params.outputToken, caller, outputAmount)

	// handle referral registration
	actualReferrer := referral.TryRegister(cross, caller, referrer)

	resultInputAmount := inputAmount
	resultOutputAmount := -outputAmount

	chain.Emit(
		"ExactInSwap",
		"prevAddr", caller.String(),
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
	}, nil
}
