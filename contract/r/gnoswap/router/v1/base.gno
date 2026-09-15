package router

import (
	"errors"
	"strings"

	gnsmath "gno.land/p/gnoswap/gnsmath"
	prbac "gno.land/p/gnoswap/rbac"
	u256 "gno.land/p/gnoswap/uint256"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/access"
)

const (
	SINGLE_HOP_ROUTE int = 1
)

// swap can be done by multiple pools
// to separate each pool, we use POOL_SEPARATOR
const (
	POOL_SEPARATOR = "*POOL*"
)

type RouterOperation interface {
	// Validate checks operation parameters before processing.
	//
	// Returns:
	//   - err: nil when operation input is valid; validation error otherwise
	Validate() error
	// Process executes the operation in the propagated realm context.
	//
	// Parameters:
	//   - _: leading operation discriminator; callers pass 0
	//   - rlm: propagated current realm context used for pool interaction
	//
	// Returns:
	//   - result: swap amounts and route metadata, or nil when processing fails
	//   - err: nil on success; execution error otherwise
	Process(_ int, rlm realm) (*SwapResult, error)
}

// executeSwapOperation validates an operation and then processes it.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used by the operation
//   - op: swap operation to validate and execute
//
// Returns:
//   - result: populated swap result, or nil when validation or processing fails
//   - err: nil on success; validation or processing error otherwise
func executeSwapOperation(_ int, rlm realm, op RouterOperation) (*SwapResult, error) {
	if err := op.Validate(); err != nil {
		return nil, err
	}

	result, err := op.Process(0, rlm)
	if err != nil {
		return nil, err
	}

	return result, nil
}

type BaseSwapParams struct {
	InputToken        string
	OutputToken       string
	RouteArr          string
	QuoteArr          string
	SqrtPriceLimitX96 *u256.Uint
	Deadline          int64
}

// common swap operation
type baseSwapOperation struct {
	sqrtPriceLimitX96 *u256.Uint
	routes            []string
	quotes            []string
	amountSpecified   int64
}

// processRoutes allocates the requested amount across all route strings and aggregates results.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for each pool swap
//   - r: router implementation that executes each route
//   - swapType: ExactIn or ExactOut execution direction
//
// Returns:
//   - amountIn: aggregate input consumed by all routes
//   - amountOut: aggregate output produced by all routes
//   - err: nil on success; quote parsing or route execution error otherwise
func (op *baseSwapOperation) processRoutes(_ int, rlm realm, r *routerV1, swapType SwapType) (int64, int64, error) {
	resultAmountIn, resultAmountOut := int64(0), int64(0)
	remainRequestAmount := op.amountSpecified

	for i, route := range op.routes {
		toSwapAmount := int64(0)

		// if it's the last route, use the remaining amount
		isLastRoute := i == len(op.routes)-1
		if !isLastRoute {
			// calculate the amount to swap for this route
			swapAmount, err := calculateSwapAmountByQuote(op.amountSpecified, op.quotes[i])
			if err != nil {
				return 0, 0, err
			}

			// update the remaining amount
			remainRequestAmount = gnsmath.SafeSubInt64(remainRequestAmount, swapAmount)
			toSwapAmount = swapAmount
		} else {
			toSwapAmount = remainRequestAmount
		}

		amountIn, amountOut, err := op.processRoute(0, rlm, r, route, toSwapAmount, swapType)
		if err != nil {
			return 0, 0, err
		}

		resultAmountIn = gnsmath.SafeAddInt64(resultAmountIn, amountIn)
		resultAmountOut = gnsmath.SafeAddInt64(resultAmountOut, amountOut)
	}

	return resultAmountIn, resultAmountOut, nil
}

// processRoute executes one route, selecting single- or multi-hop processing by hop count.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for pool interaction
//   - r: router implementation that executes the route
//   - route: one route path containing one to three pool hops
//   - toSwap: signed amount assigned to this route
//   - swapType: ExactIn or ExactOut execution direction
//
// Returns:
//   - amountIn: input amount consumed by this route
//   - amountOut: output amount produced by this route
//   - err: always nil after a one-to-three-hop dispatch; an out-of-range hop count panics before returning
func (op *baseSwapOperation) processRoute(
	_ int,
	rlm realm,
	r *routerV1,
	route string,
	toSwap int64,
	swapType SwapType,
) (amountIn, amountOut int64, err error) {
	numHops := strings.Count(route, POOL_SEPARATOR) + 1
	assertHopsInRange(numHops)

	switch numHops {
	case SINGLE_HOP_ROUTE:
		amountIn, amountOut = r.handleSingleSwap(0, rlm, route, toSwap, op.sqrtPriceLimitX96)
	default:
		amountIn, amountOut = r.handleMultiSwap(0, rlm, swapType, route, numHops, toSwap)
	}

	return amountIn, amountOut, nil
}

// handleSingleSwap executes one pool swap from a route string.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for pool interaction
//   - route: single-hop token path and fee
//   - amountSpecified: signed input or output amount for the hop
//   - sqrtPriceLimitX96: optional Q64.96 price limit; zero selects a directional boundary
//
// Returns:
//   - amountIn: input amount received by the pool
//   - amountOut: output amount sent by the pool
func (r *routerV1) handleSingleSwap(_ int, rlm realm, route string, amountSpecified int64, sqrtPriceLimitX96 *u256.Uint) (int64, int64) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:           input,
		tokenOut:          output,
		fee:               fee,
		amountSpecified:   amountSpecified,
		sqrtPriceLimitX96: sqrtPriceLimitX96,
	}

	return r.singleSwap(0, rlm, &singleParams)
}

// handleMultiSwap executes a multi-hop route in the direction selected by swapType.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for pool interaction
//   - swapType: ExactIn for forward execution or ExactOut for backward quoting
//   - route: multi-hop path separated by POOL_SEPARATOR
//   - numHops: number of pool hops in route
//   - amountSpecified: signed amount assigned to the route
//
// Returns:
//   - amountIn: input amount consumed by the route
//   - amountOut: output amount produced by the route
func (r *routerV1) handleMultiSwap(
	_ int,
	rlm realm,
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified int64,
) (int64, int64) {
	recipient := access.MustGetAddress(prbac.ROLE_ROUTER.String())

	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified)
		return r.multiSwap(0, rlm, *sp, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified)
		return r.multiSwapNegative(0, rlm, *sp, numHops, route)
	default:
		panic(errors.New(errInvalidSwapType))
	}
}

// SwapRouteParams contains all parameters needed for swap route execution
type SwapRouteParams struct {
	inputToken        string
	outputToken       string
	routeArr          string
	quoteArr          string
	deadline          int64
	typ               SwapType
	exactAmount       int64      // amountIn for ExactIn, amountOut for ExactOut
	limitAmount       int64      // amountOutMin for ExactIn, amountInMax for ExactOut
	sqrtPriceLimitX96 *u256.Uint // if sqrtPriceLimitX96 is zero string, it will be set to MIN_PRICE or MAX_PRICE
}

// ExactAmount returns the requested exact input or output amount.
//
// Returns:
//   - amount: exactAmount configured for the route
func (p *SwapRouteParams) ExactAmount() int64 {
	return p.exactAmount
}

// ExpectedExactAmountByFee returns the amount needed by pool execution after router-fee adjustment.
//
// Parameters:
//   - feeBps: router fee in basis points
//
// Returns:
//   - amount: exact input amount for ExactIn, or gross pool amount for ExactOut
func (p *SwapRouteParams) ExpectedExactAmountByFee(feeBps uint64) int64 {
	if p.typ == ExactIn {
		return p.exactAmount
	}

	return calculateExactOutWithRouterFee(p.exactAmount, feeBps)
}

// SwapCount counts pool hops across all comma-separated routes.
//
// Returns:
//   - count: total number of pool swaps represented by routeArr
func (p *SwapRouteParams) SwapCount() int64 {
	swapCount := int64(0)

	for _, route := range strings.Split(p.routeArr, ",") {
		swapCount += int64(strings.Count(route, POOL_SEPARATOR) + 1)
	}

	return swapCount
}

func buildRouteEventAttrs(routeArr string) []string {
	routes := strings.Split(routeArr, ",")
	routeEventAttrs := make([]string, 0, len(routes)*2)

	for index, route := range routes {
		routeEventAttrs = append(routeEventAttrs, ufmt.Sprintf("routes[%d]", index))
		routeEventAttrs = append(routeEventAttrs, route)
	}

	return routeEventAttrs
}

// IsSetSqrtPriceLimitX96 reports whether a nonzero caller price limit is configured.
//
// Returns:
//   - set: true when sqrtPriceLimitX96 is non-nil and nonzero
func (p *SwapRouteParams) IsSetSqrtPriceLimitX96() bool {
	return p.sqrtPriceLimitX96 != nil && !p.sqrtPriceLimitX96.IsZero()
}

// createSwapOperation constructs the exact-in or exact-out operation for params.
//
// Parameters:
//   - r: router implementation used by the operation
//   - params: validated route settings and exact amount/limit configuration
//
// Returns:
//   - op: exact-in or exact-out operation selected by params.typ
//   - err: nil for a supported swap type; invalid-swap-type error otherwise
func createSwapOperation(r *routerV1, params SwapRouteParams) (RouterOperation, error) {
	baseParams := BaseSwapParams{
		InputToken:        params.inputToken,
		OutputToken:       params.outputToken,
		RouteArr:          params.routeArr,
		QuoteArr:          params.quoteArr,
		SqrtPriceLimitX96: params.sqrtPriceLimitX96,
		Deadline:          params.deadline,
	}

	switch params.typ {
	case ExactIn:
		pp := NewExactInParams(baseParams, params.ExactAmount(), params.limitAmount)
		return NewExactInSwapOperation(r, pp), nil
	case ExactOut:
		routerFee := r.store.GetSwapFee()
		pp := NewExactOutParams(baseParams, params.ExpectedExactAmountByFee(routerFee), params.limitAmount)
		return NewExactOutSwapOperation(r, pp), nil
	default:
		msg := addDetailToError(errInvalidSwapType, "unknown swap type")
		return nil, errors.New(msg)
	}
}

// commonSwapRoute executes and finalizes either an exact-in or exact-out route.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for swaps and fee settlement
//   - params: route tokens, quotes, amounts, deadline, type, and price limit
//
// Returns:
//   - amountIn: input amount consumed across routes
//   - amountOut: net output after router fee
//   - err: nil on success; operation validation or execution error otherwise
func (r *routerV1) commonSwapRoute(_ int, rlm realm, params SwapRouteParams) (int64, int64, error) {
	op, err := createSwapOperation(r, params)
	if err != nil {
		return 0, 0, err
	}

	result, err := executeSwapOperation(0, rlm, op)
	if err != nil {
		msg := addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid %s SwapOperation: %s", params.typ.String(), err.Error()),
		)
		return 0, 0, errors.New(msg)
	}

	inputAmount, outputAmount := r.finalizeSwap(
		0,
		rlm,
		params.inputToken,
		params.outputToken,
		result.AmountIn,
		result.AmountOut,
		params.typ,
		params.limitAmount,
		params.ExactAmount(),
		params.SwapCount(),
		params.IsSetSqrtPriceLimitX96(),
	)

	return inputAmount, outputAmount, nil
}
