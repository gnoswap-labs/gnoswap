package router

import (
	"errors"
	"strings"

	"gno.land/p/gnoswap/gnsmath"
	"gno.land/p/gnoswap/utils"
	ufmt "gno.land/p/nt/ufmt/v0"

	"gno.land/r/gnoswap/common"
)

// QuoteConstraints defines the valid range for swap quote percentages
const (
	MaxQuotePercentage     = 100
	MinQuotePercentage     = 0
	PERCENTAGE_DENOMINATOR = int64(100)
)

// ErrorMessages for DrySwapRoute operations
const (
	ErrUnknownSwapType       = "unknown swapType(%s)"
	ErrInvalidPositiveAmount = "invalid amount(%s), must be positive"
	ErrInvalidQuoteRange     = "quote(%d) must be %d~%d"
)

// SwapProcessor handles the execution of swap operations
type SwapProcessor struct {
	router *routerV1
}

// ProcessSingleSwap simulates one pool hop without executing transfers.
//
// Parameters:
//   - route: single pool path formatted as TOKEN0:TOKEN1:FEE
//   - amountSpecified: signed input or output amount for the hop
//
// Returns:
//   - amountIn: input amount the pool would receive
//   - amountOut: output amount the pool would send
//   - err: always nil when the dry pool call returns; malformed paths or pool failures panic in the underlying helpers
func (p *SwapProcessor) ProcessSingleSwap(route string, amountSpecified int64) (amountIn, amountOut int64, err error) {
	input, output, fee := getDataForSinglePath(route)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	amountIn, amountOut = p.router.singleDrySwap(&singleParams)
	return amountIn, amountOut, nil
}

// ProcessMultiSwap simulates a multi-hop route in the requested direction.
//
// Parameters:
//   - swapType: ExactIn for forward execution or ExactOut for backward quoting
//   - route: multi-hop path with POOL_SEPARATOR between hops
//   - numHops: number of pools in route
//   - amountSpecified: signed input or output amount for the route
//
// Returns:
//   - amountIn: input amount the route would consume
//   - amountOut: output amount the route would produce
//   - err: nil on successful simulation; invalid swap-type error or downstream dry-swap validation error otherwise (pool query failures panic)
func (p *SwapProcessor) ProcessMultiSwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified int64,
) (int64, int64, error) {
	pathIndex := getPathIndex(swapType, numHops)

	input, output, fee := getDataForMultiPath(route, pathIndex)
	singleParams := SingleSwapParams{
		tokenIn:         input,
		tokenOut:        output,
		fee:             fee,
		amountSpecified: amountSpecified,
	}

	switch swapType {
	case ExactIn:
		return p.router.multiDrySwap(singleParams, numHops, route)
	case ExactOut:
		return p.router.multiDrySwapNegative(singleParams, numHops, route)
	default:
		return 0, 0, ufmt.Errorf(ErrUnknownSwapType, swapType)
	}
}

// ValidateSwapResults checks simulated amounts against exactness and slippage constraints.
//
// Parameters:
//   - swapType: ExactIn or ExactOut validation direction
//   - resultAmountIn: simulated aggregate input amount
//   - resultAmountOut: simulated aggregate output amount after router fee
//   - amountSpecified: caller's exact input or output target
//   - amountLimit: minimum output or maximum input slippage bound
//   - swapCount: number of pool hops used for exact-output tolerance
//
// Returns:
//   - amountIn: resultAmountIn when validation reaches the return path
//   - amountOut: resultAmountOut when validation reaches the return path
//   - err: nil when liquidity, exactness, and slippage checks pass; relevant validation error otherwise
func (p *SwapProcessor) ValidateSwapResults(
	swapType SwapType,
	resultAmountIn, resultAmountOut int64,
	amountSpecified, amountLimit int64,
	swapCount int64,
) (amountIn, amountOut int64, err error) {
	if resultAmountIn == 0 || resultAmountOut == 0 {
		return 0, 0, errors.New(errInsufficientLiquidity)
	}

	validator := &SwapValidator{}

	if swapType == ExactOut {
		absSpecified := gnsmath.SafeAbsInt64(amountSpecified)

		if err := validator.exactOutAmount(resultAmountOut, absSpecified, swapCount); err != nil {
			return resultAmountIn, resultAmountOut, err
		}
	}

	if swapType == ExactIn {
		if err := validator.exactInAmount(resultAmountIn, amountSpecified); err != nil {
			return resultAmountIn, resultAmountOut, err
		}
	}

	if err := validator.slippage(swapType, resultAmountIn, resultAmountOut, amountLimit); err != nil {
		return resultAmountIn, resultAmountOut, err
	}

	return resultAmountIn, resultAmountOut, nil
}

// AddSwapResults adds one route's amounts to accumulated totals using overflow-safe arithmetic.
//
// Parameters:
//   - resultAmountIn: accumulated input before this route
//   - resultAmountOut: accumulated output before this route
//   - amountIn: current route input amount
//   - amountOut: current route output amount
//
// Returns:
//   - newAmountIn: accumulated input after adding amountIn
//   - newAmountOut: accumulated output after adding amountOut
//   - err: always nil; overflow is raised by safe arithmetic rather than returned
func (p *SwapProcessor) AddSwapResults(
	resultAmountIn, resultAmountOut, amountIn, amountOut int64,
) (int64, int64, error) {
	newAmountIn := gnsmath.SafeAddInt64(resultAmountIn, amountIn)
	newAmountOut := gnsmath.SafeAddInt64(resultAmountOut, amountOut)

	return newAmountIn, newAmountOut, nil
}

// DrySwapRoute simulates a token swap route without executing transfers or changing state.
//
// Parameters:
//   - inputToken: input token contract path
//   - outputToken: output token contract path
//   - specifiedAmount: exact input amount for EXACT_IN or exact output amount for EXACT_OUT
//   - swapTypeStr: EXACT_IN or EXACT_OUT
//   - strRouteArr: comma-separated route paths, with at most seven route entries
//   - quoteArr: comma-separated route allocation percentages summing to 100
//   - tokenAmountLimit: minimum output for EXACT_IN or maximum input for EXACT_OUT
//
// Returns:
//   - amountIn: simulated input amount encoded as a decimal string
//   - amountOut: simulated net output amount encoded as a decimal string
//   - err: nil on success; validation, liquidity, parsing, or slippage error otherwise
func (r *routerV1) DrySwapRoute(
	inputToken, outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit string,
) (amountIn, amountOut string, err error) {
	defer func() {
		if r := recover(); r != nil {
			amountIn = "0"
			amountOut = "0"
			if recoveredErr, ok := r.(error); ok {
				err = recoveredErr
			} else {
				err = ufmt.Errorf("%v", r)
			}
		}
	}()

	inputAmount, outputAmount, err := r.drySwapRoute(
		inputToken,
		outputToken,
		utils.SafeParseInt64(specifiedAmount),
		swapTypeStr,
		strRouteArr,
		quoteArr,
		utils.SafeParseInt64(tokenAmountLimit),
	)
	return utils.FormatInt(inputAmount), utils.FormatInt(outputAmount), err
}

// drySwapRoute runs the internal integer-valued simulation used by DrySwapRoute.
//
// Parameters:
//   - inputToken: input token contract path
//   - outputToken: output token contract path
//   - specifiedAmount: positive exact input or output amount in token units
//   - swapTypeStr: EXACT_IN or EXACT_OUT
//   - strRouteArr: comma-separated route paths
//   - quoteArr: comma-separated route allocation percentages
//   - tokenAmountLimit: minimum output or maximum input in token units
//
// Returns:
//   - amountIn: simulated aggregate input amount
//   - amountOut: simulated aggregate output after router fee
//   - err: nil on successful validation and simulation; input, liquidity, or slippage error otherwise
func (r *routerV1) drySwapRoute(
	inputToken, outputToken string,
	specifiedAmount int64,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit int64,
) (int64, int64, error) {
	if err := common.ValidateRegistered(inputToken, outputToken); err != nil {
		return 0, 0, err
	}

	assertIsValidRoutePaths(strRouteArr, inputToken, outputToken)
	assertIsExistsPools(strRouteArr)

	// initialize components
	validator := &SwapValidator{}
	processor := &SwapProcessor{router: r}

	// validate and parse inputs
	swapType, err := validator.swapType(swapTypeStr)
	if err != nil {
		return 0, 0, makeErrorWithDetails(errInvalidSwapType, err.Error())
	}

	amountSpecified, err := validator.amount(specifiedAmount)
	if err != nil {
		return 0, 0, makeErrorWithDetails(errInvalidInput, err.Error())
	}

	routes, quotes, err := NewRouteParser().ParseRoutes(strRouteArr, quoteArr)
	if err != nil {
		return 0, 0, makeErrorWithDetails(errInvalidRoutesAndQuotes, err.Error())
	}

	swapFee := r.store.GetSwapFee()

	// Store original amount for validation (before router fee adjustment)
	originalAmountSpecified := amountSpecified

	// adjust amount sign for exact out swaps
	if swapType == ExactOut {
		absSpecified := gnsmath.SafeAbsInt64(amountSpecified)
		amountSpecifiedWithRouterFee := calculateExactOutWithRouterFee(absSpecified, swapFee)
		amountSpecified = -amountSpecifiedWithRouterFee
	}

	// initialize accumulators for swap results
	resultAmountIn, resultAmountOut := int64(0), int64(0)
	remainRequestAmount := amountSpecified
	swapCount := int64(0)

	// Process each route
	for i, route := range routes {
		toSwapAmount := int64(0)

		// if it's the last route, use the remaining amount
		isLastRoute := i == len(routes)-1
		if !isLastRoute {
			// calculate the amount to swap for this route
			swapAmount, err := calculateSwapAmountByQuote(amountSpecified, quotes[i])
			if err != nil {
				return 0, 0, err
			}

			// update the remaining amount
			resultRemainRequestAmount := gnsmath.SafeSubInt64(remainRequestAmount, swapAmount)

			remainRequestAmount = resultRemainRequestAmount
			toSwapAmount = swapAmount
		} else {
			toSwapAmount = remainRequestAmount
		}

		// determine the number of hops and validate
		numHops := strings.Count(route, POOL_SEPARATOR) + 1
		assertHopsInRange(numHops)

		// accumulate total swap count for validation
		swapCount += int64(numHops)

		// execute the appropriate swap type
		var amountIn, amountOut int64
		if numHops == 1 {
			amountIn, amountOut, err = processor.ProcessSingleSwap(route, toSwapAmount)
		} else {
			amountIn, amountOut, err = processor.ProcessMultiSwap(swapType, route, numHops, toSwapAmount)
		}

		if err != nil {
			return 0, 0, err
		}

		if amountIn == 0 || amountOut == 0 {
			return 0, 0, errors.New(errInsufficientLiquidity)
		}

		// update accumulated results
		resultAmountIn, resultAmountOut, err = processor.AddSwapResults(resultAmountIn, resultAmountOut, amountIn, amountOut)
		if err != nil {
			return 0, 0, err
		}
	}

	// simulate deduct router fee
	feeAmountInt64 := calculateRouterFee(resultAmountOut, swapFee)

	resultAmountOut = gnsmath.SafeSubInt64(resultAmountOut, feeAmountInt64)

	return processor.ValidateSwapResults(swapType, resultAmountIn, resultAmountOut, originalAmountSpecified, tokenAmountLimit, swapCount)
}

// getPathIndex selects the first hop for ExactIn or last hop for ExactOut.
//
// Parameters:
//   - swapType: ExactIn or ExactOut direction
//   - numHops: number of pools in the route
//
// Returns:
//   - index: zero-based hop index used to initialize the simulation
func getPathIndex(swapType SwapType, numHops int) int {
	switch swapType {
	case ExactIn:
		// first data for exact input swaps
		return 0
	case ExactOut:
		// last data for exact output swaps
		return numHops - 1
	default:
		panic("should not happen")
	}
}
