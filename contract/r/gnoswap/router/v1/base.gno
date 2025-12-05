package v1

import (
	"chain/banker"
	"chain/runtime"
	"errors"
	"strconv"
	"strings"

	u256 "gno.land/p/gnoswap/uint256"
	"gno.land/p/nt/ufmt"

	"gno.land/r/gnoland/wugnot"
	"gno.land/r/gnoswap/common"
)

const (
	SINGLE_HOP_ROUTE int = 1

	INITIAL_WUGNOT_BALANCE int64 = 0
)

// calculateSwapAmountByQuote calculates swap amount based on quote percentage.
// This common function is used by both validateRouteQuote and ProcessSwapAmount.
func calculateSwapAmountByQuote(amountSpecified int64, quote string) (int64, error) {
	quoteInt, err := strconv.ParseInt(quote, 10, 64)
	if err != nil {
		return 0, ufmt.Errorf("invalid quote(%s)", quote)
	}

	if quoteInt < MinQuotePercentage || quoteInt > MaxQuotePercentage {
		return 0, ufmt.Errorf(ErrInvalidQuoteRange, quoteInt, MinQuotePercentage, MaxQuotePercentage)
	}

	return safeMulDivInt64(amountSpecified, quoteInt, PERCENTAGE_DENOMINATOR), nil
}

// swap can be done by multiple pools
// to separate each pool, we use POOL_SEPARATOR
const (
	POOL_SEPARATOR = "*POOL*"
	wugnotPath     = "gno.land/r/gnoland/wugnot"
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
	InputToken        string
	OutputToken       string
	RouteArr          string
	QuoteArr          string
	SqrtPriceLimitX96 *u256.Uint
	Deadline          int64
}

// common swap operation
type baseSwapOperation struct {
	sqrtPriceLimitX96       *u256.Uint
	withUnwrap              bool
	userBeforeWugnotBalance int64
	userWrappedWugnot       int64
	routes                  []string
	quotes                  []string
	amountSpecified         int64
}

// handleNativeTokenWrapping handles wrapping and unwrapping of native tokens.
func (op *baseSwapOperation) handleNativeTokenWrapping(
	inputToken string,
	outputToken string,
	specifiedAmount int64,
) error {
	isInputNativeToken := common.IsGNOTNativePath(inputToken)
	isOutputNativeToken := common.IsGNOTNativePath(outputToken)

	// no native token
	if !isInputNativeToken && !isOutputNativeToken {
		return nil
	}

	// save current user's WGNOT amount
	op.userBeforeWugnotBalance = wugnot.BalanceOf(runtime.PreviousRealm().Address())

	// Handle input token independently
	if isInputNativeToken {
		sent := banker.OriginSend()
		ugnotSentByUser := sent.AmountOf(GNOT_DENOM)

		if ugnotSentByUser != specifiedAmount {
			return ufmt.Errorf("ugnot sent by user(%d) is not equal to amountSpecified(%d)", ugnotSentByUser, specifiedAmount)
		}

		// wrap user's GNOT to WUGNOT
		if ugnotSentByUser > 0 {
			if err := wrapWithTransfer(runtime.PreviousRealm().Address(), ugnotSentByUser); err != nil {
				return err
			}
		}

		op.userWrappedWugnot = ugnotSentByUser
	}

	// Handle output token independently
	if isOutputNativeToken {
		op.withUnwrap = true
	}

	return nil
}

// validateRouteQuote validates and converts a route quote to swap amount.
func (op *baseSwapOperation) validateRouteQuote(quote string, i int) (int64, error) {
	return calculateSwapAmountByQuote(op.amountSpecified, quote)
}

// processRoutes processes all swap routes and returns total amounts.
func (op *baseSwapOperation) processRoutes(r *routerV1, swapType SwapType) (int64, int64, error) {
	resultAmountIn, resultAmountOut := int64(0), int64(0)
	remainRequestAmount := op.amountSpecified

	for i, route := range op.routes {
		toSwapAmount := int64(0)

		// if it's the last route, use the remaining amount
		isLastRoute := i == len(op.routes)-1
		if !isLastRoute {
			// calculate the amount to swap for this route
			swapAmount, err := op.validateRouteQuote(op.quotes[i], i)
			if err != nil {
				return 0, 0, err
			}

			// update the remaining amount
			remainRequestAmount = safeSubInt64(remainRequestAmount, swapAmount)
			toSwapAmount = swapAmount
		} else {
			toSwapAmount = remainRequestAmount
		}

		amountIn, amountOut, err := op.processRoute(r, route, toSwapAmount, swapType)
		if err != nil {
			return 0, 0, err
		}

		resultAmountIn = safeAddInt64(resultAmountIn, amountIn)
		resultAmountOut = safeAddInt64(resultAmountOut, amountOut)
	}

	return resultAmountIn, resultAmountOut, nil
}

// processRoute processes a single route with specified swap amount.
func (op *baseSwapOperation) processRoute(
	r *routerV1,
	route string,
	toSwap int64,
	swapType SwapType,
) (amountIn, amountOut int64, err error) {
	numHops := strings.Count(route, POOL_SEPARATOR) + 1
	assertHopsInRange(numHops)

	switch numHops {
	case SINGLE_HOP_ROUTE:
		amountIn, amountOut = r.handleSingleSwap(route, toSwap, op.withUnwrap, op.sqrtPriceLimitX96)
	default:
		amountIn, amountOut = r.handleMultiSwap(swapType, route, numHops, toSwap, op.withUnwrap)
	}

	return amountIn, amountOut, nil
}

// handleSingleSwap executes a single-hop swap with the specified amount.
func (r *routerV1) handleSingleSwap(route string, amountSpecified int64, withUnwrap bool, sqrtPriceLimitX96 *u256.Uint) (int64, int64) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:           input,
		tokenOut:          output,
		fee:               fee,
		amountSpecified:   amountSpecified,
		withUnwrap:        withUnwrap,
		sqrtPriceLimitX96: sqrtPriceLimitX96,
	}

	return r.singleSwap(&singleParams)
}

// handleMultiSwap processes multi-hop swaps across multiple pools.
func (r *routerV1) handleMultiSwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified int64,
	withUnwrap bool,
) (int64, int64) {
	recipient := routerAddr

	switch swapType {
	case ExactIn:
		input, output, fee := getDataForMultiPath(route, 0) // first data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified, withUnwrap)
		return r.multiSwap(*sp, numHops, route)
	case ExactOut:
		input, output, fee := getDataForMultiPath(route, numHops-1) // last data
		sp := newSwapParams(input, output, fee, recipient, amountSpecified, withUnwrap)
		return r.multiSwapNegative(*sp, numHops, route)
	default:
		panic(errInvalidSwapType)
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

func (p *SwapRouteParams) ExactAmount() int64 {
	return p.exactAmount
}

// when exact out, calculate amount to fetch from pool including router fee
func (p *SwapRouteParams) ExpectedExactAmountByFee(feeBps uint64) int64 {
	if p.typ == ExactIn {
		return p.exactAmount
	}

	return calculateExactOutWithRouterFee(p.exactAmount, feeBps)
}

// IsUnwrap checks if the swap output is native token.
func (p *SwapRouteParams) IsUnwrap() bool {
	return p.outputToken == GNOT_DENOM
}

func (p *SwapRouteParams) SwapCount() int64 {
	swapCount := int64(0)

	for _, route := range strings.Split(p.routeArr, ",") {
		swapCount += int64(strings.Count(route, POOL_SEPARATOR) + 1)
	}

	return swapCount
}

func (p *SwapRouteParams) IsSetSqrtPriceLimitX96() bool {
	return p.sqrtPriceLimitX96 != nil && !p.sqrtPriceLimitX96.IsZero()
}

// createSwapOperation creates the appropriate swap operation based on swap type.
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
func (r *routerV1) commonSwapRoute(params SwapRouteParams) (int64, int64, error) {
	op, err := createSwapOperation(r, params)
	if err != nil {
		return 0, 0, err
	}

	result, err := executeSwapOperation(op)
	if err != nil {
		msg := addDetailToError(
			errInvalidInput,
			ufmt.Sprintf("invalid %s SwapOperation: %s", params.typ.String(), err.Error()),
		)
		return 0, 0, errors.New(msg)
	}

	userBeforeWugnotBalance, userWrappedWugnot, err := extractSwapOperationData(op)
	if err != nil {
		return 0, 0, err
	}

	inputAmount, outputAmount := r.finalizeSwap(
		params.inputToken,
		params.outputToken,
		result.AmountIn,
		result.AmountOut,
		params.typ,
		params.limitAmount,
		userBeforeWugnotBalance,
		userWrappedWugnot,
		params.ExactAmount(),
		params.SwapCount(),
		params.IsSetSqrtPriceLimitX96(),
	)

	return inputAmount, outputAmount, nil
}
