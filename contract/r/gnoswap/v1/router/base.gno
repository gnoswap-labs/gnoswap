package router

import (
	"errors"
	"std"
	"strconv"
	"strings"

	"gno.land/p/nt/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoland/wugnot"
)

const (
	SINGLE_HOP_ROUTE int = 1

	INITIAL_WUGNOT_BALANCE int64 = 0
)

// swap can be done by multiple pools
// to separate each pool, we use POOL_SEPARATOR
const (
	POOL_SEPARATOR        = "*POOL*"
	gnot           string = "gnot"
	wugnotPath     string = "gno.land/r/gnoland/wugnot"
)

type RouterOperation interface {
	Validate() error
	Process() (*SwapResult, error)
}

// executeSwapOperation validates and processes a swap operation.
func executeSwapOperation(op RouterOperation) (*SwapResult, error) {
	if err := op.Validate(); err != nil {
		return nil, err
	}

	result, err := op.Process()
	if err != nil {
		return nil, err
	}

	return result, nil
}

type BaseSwapParams struct {
	InputToken  string
	OutputToken string
	RouteArr    string
	QuoteArr    string
	Deadline    int64
}

// common swap operation
type baseSwapOperation struct {
	withUnwrap              bool
	userBeforeWugnotBalance int64
	userWrappedWugnot       int64
	routes                  []string
	quotes                  []string
	amountSpecified         *i256.Int
}

// handleNativeTokenWrapping handles wrapping and unwrapping of native tokens.
func (op *baseSwapOperation) handleNativeTokenWrapping(
	inputToken string,
	outputToken string,
	specifiedAmount *i256.Int,
) error {
	// no native token
	if inputToken != gnot && outputToken != gnot {
		return nil
	}

	// save current user's WGNOT amount
	op.userBeforeWugnotBalance = wugnot.BalanceOf(std.PreviousRealm().Address())

	if outputToken == gnot {
		op.withUnwrap = true
		return nil
	}

	sent := std.OriginSend()
	ugnotSentByUser := sent.AmountOf("ugnot")
	amountSpecified := specifiedAmount.Int64()

	if ugnotSentByUser != amountSpecified {
		return ufmt.Errorf("ugnot sent by user(%d) is not equal to amountSpecified(%d)", ugnotSentByUser, amountSpecified)
	}

	// wrap user's WUGNOT
	if ugnotSentByUser > 0 {
		if err := wrapWithTransfer(std.PreviousRealm().Address(), ugnotSentByUser); err != nil {
			return err
		}
	}

	op.userWrappedWugnot = ugnotSentByUser

	return nil
}

// validateRouteQuote validates and converts a route quote to swap amount.
func (op *baseSwapOperation) validateRouteQuote(quote string, i int) (*i256.Int, error) {
	qt, err := strconv.Atoi(quote)
	if err != nil {
		return nil, ufmt.Errorf("invalid quote(%s) at index(%d)", quote, i)
	}

	// calculate amount to swap for this route
	toSwap := i256.Zero().Mul(op.amountSpecified, i256.NewInt(int64(qt)))
	toSwap = i256.Zero().Div(toSwap, PERCENTAGE_DENOMINATOR)

	return toSwap, nil
}

// processRoutes processes all swap routes and returns total amounts.
func (op *baseSwapOperation) processRoutes(swapType SwapType) (*u256.Uint, *u256.Uint, error) {
	zero := u256.Zero()
	resultAmountIn, resultAmountOut := zero, zero
	remainRequestAmount := op.amountSpecified

	for i, route := range op.routes {
		toSwapAmount := i256.Zero()

		// if it's the last route, use the remaining amount
		isLastRoute := i == len(op.routes)-1
		if !isLastRoute {
			// calculate the amount to swap for this route
			swapAmount, err := op.validateRouteQuote(op.quotes[i], i)
			if err != nil {
				return nil, nil, err
			}

			// update the remaining amount
			remainRequestAmount = i256.Zero().Sub(remainRequestAmount, swapAmount)
			toSwapAmount = swapAmount
		} else {
			toSwapAmount = remainRequestAmount
		}

		amountIn, amountOut, err := op.processRoute(route, toSwapAmount, swapType)
		if err != nil {
			return nil, nil, err
		}

		amountIn, overflow := u256.Zero().AddOverflow(resultAmountIn, amountIn)
		if overflow {
			return nil, nil, errOverFlow
		}

		amountOut, overflow = u256.Zero().AddOverflow(resultAmountOut, amountOut)
		if overflow {
			return nil, nil, errOverFlow
		}

		resultAmountIn = amountIn
		resultAmountOut = amountOut
	}

	return resultAmountIn, resultAmountOut, nil
}

// processRoute processes a single route with specified swap amount.
func (op *baseSwapOperation) processRoute(
	route string,
	toSwap *i256.Int,
	swapType SwapType,
) (amountIn, amountOut *u256.Uint, err error) {
	numHops := strings.Count(route, POOL_SEPARATOR) + 1
	assertHopsInRange(numHops)

	switch numHops {
	case SINGLE_HOP_ROUTE:
		amountIn, amountOut = handleSingleSwap(route, toSwap, op.withUnwrap)
	default:
		amountIn, amountOut = handleMultiSwap(swapType, route, numHops, toSwap, op.withUnwrap)
	}

	if amountIn == nil || amountOut == nil {
		return nil, nil, ufmt.Errorf("swap failed to process route(%s)", route)
	}

	return amountIn, amountOut, nil
}

// handleSingleSwap executes a single-hop swap with the specified amount.
func handleSingleSwap(route string, amountSpecified *i256.Int, withUnwrap bool) (*u256.Uint, *u256.Uint) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
		withUnwrap:      withUnwrap,
	}

	return singleSwap(&singleParams)
}

// handleMultiSwap processes multi-hop swaps across multiple pools.
func handleMultiSwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified *i256.Int,
	withUnwrap bool,
) (*u256.Uint, *u256.Uint) {
	recipient := routerAddr

	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified, withUnwrap)
		return multiSwap(*sp, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified, withUnwrap)
		return multiSwapNegative(*sp, numHops, route)
	default:
		panic(errInvalidSwapType)
	}
}

// SwapRouteParams contains all parameters needed for swap route execution
type SwapRouteParams struct {
	inputToken  string
	outputToken string
	routeArr    string
	quoteArr    string
	deadline    int64
	typ         SwapType
	exactAmount string // amountIn for ExactIn, amountOut for ExactOut
	limitAmount string // amountOutMin for ExactIn, amountInMax for ExactOut
}

// IsUnwrap checks if the swap output is native token.
func (p *SwapRouteParams) IsUnwrap() bool {
	return p.outputToken == gnot
}

// createSwapOperation creates the appropriate swap operation based on swap type.
func createSwapOperation(params SwapRouteParams) (RouterOperation, error) {
	baseParams := BaseSwapParams{
		InputToken:  params.inputToken,
		OutputToken: params.outputToken,
		RouteArr:    params.routeArr,
		QuoteArr:    params.quoteArr,
	}

	switch params.typ {
	case ExactIn:
		pp := NewExactInParams(baseParams, params.exactAmount, params.limitAmount)
		return NewExactInSwapOperation(pp), nil
	case ExactOut:
		pp := NewExactOutParams(baseParams, params.exactAmount, params.limitAmount)
		return NewExactOutSwapOperation(pp), nil
	default:
		msg := addDetailToError(errInvalidSwapType, "unknown swap type")
		return nil, errors.New(msg)
	}
}

// extractSwapOperationData extracts common data from swap operation.
func extractSwapOperationData(op RouterOperation) (int64, int64, error) {
	var baseOp *baseSwapOperation
	switch typedOp := op.(type) {
	case *ExactInSwapOperation:
		baseOp = &typedOp.baseSwapOperation
	case *ExactOutSwapOperation:
		baseOp = &typedOp.baseSwapOperation
	default:
		return 0, 0, ufmt.Errorf("unexpected operation type: %T", op)
	}

	return baseOp.userBeforeWugnotBalance, baseOp.userWrappedWugnot, nil
}

// commonSwapRoute handles the common logic for both ExactIn and ExactOut swaps.
func commonSwapRoute(params SwapRouteParams) (*i256.Int, *i256.Int, error) {
	op, err := createSwapOperation(params)
	if err != nil {
		return i256.Zero(), i256.Zero(), err
	}

	result, err := executeSwapOperation(op)
	if err != nil {
		msg := addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid %s SwapOperation: %s", params.typ.String(), err.Error()),
		)
		return i256.Zero(), i256.Zero(), errors.New(msg)
	}

	userBeforeWugnotBalance, userWrappedWugnot, err := extractSwapOperationData(op)
	if err != nil {
		return i256.Zero(), i256.Zero(), err
	}

	limitValue, err := u256.FromDecimal(params.limitAmount)
	if err != nil {
		return i256.Zero(), i256.Zero(), err
	}

	inputAmount, outputAmount := finalizeSwap(
		params.inputToken,
		params.outputToken,
		result.AmountIn,
		result.AmountOut,
		params.typ,
		limitValue,
		userBeforeWugnotBalance,
		userWrappedWugnot,
		result.AmountSpecified.Abs(),
	)

	return inputAmount, outputAmount, nil
}
