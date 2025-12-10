package v1

import (
	"chain/runtime"
	"strings"

	"gno.land/p/nt/ufmt"

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
	ErrOverflowResultAmountIn      = "overflow in resultAmountIn"
	ErrOverflowResultAmountOut     = "overflow in resultAmountOut"
	ErrUnknownSwapType             = "unknown swapType(%s)"
	ErrInvalidPositiveAmount       = "invalid amount(%s), must be positive"
	ErrInvalidZeroAmountLimit      = "invalid amountLimit(%s), should not be zero"
	ErrInvalidQuoteRange           = "quote(%d) must be %d~%d"
	ErrOverflowCalculateSwapAmount = "overflow in calculateSwapAmount"
)

// SwapProcessor handles the execution of swap operations
type SwapProcessor struct {
	router *routerV1
}

// ProcessSingleSwap handles a single-hop swap simulation.
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

// ProcessMultiSwap handles a multi-hop swap simulation.
func (p *SwapProcessor) ProcessMultiSwap(
	swapType SwapType,
	route string,
	numHops int,
	amountSpecified int64,
) (int64, int64, error) {
	recipient := runtime.PreviousRealm().Address()
	pathIndex := getPathIndex(swapType, numHops)

	input, output, fee := getDataForMultiPath(route, pathIndex)
	swapParams := newSwapParams(input, output, fee, recipient, amountSpecified, false)

	switch swapType {
	case ExactIn:
		return p.router.multiDrySwap(*swapParams, numHops, route)
	case ExactOut:
		return p.router.multiDrySwapNegative(*swapParams, numHops, route)
	default:
		return 0, 0, ufmt.Errorf(ErrUnknownSwapType, swapType)
	}
}

// ValidateSwapResults checks if the swap results meet the required constraints.
func (p *SwapProcessor) ValidateSwapResults(
	swapType SwapType,
	resultAmountIn, resultAmountOut int64,
	amountSpecified, amountLimit int64,
	swapCount int64,
) (amountIn, amountOut int64, success bool) {
	if resultAmountIn == 0 || resultAmountOut == 0 {
		return 0, 0, false
	}

	switch swapType {
	case ExactIn:
		if resultAmountOut < amountLimit {
			return resultAmountIn, resultAmountOut, false
		}
		return resultAmountIn, resultAmountOut, true

	case ExactOut:
		absAmountSpecified := safeAbsInt64(amountSpecified)
		diff := int64(0)
		if resultAmountOut >= absAmountSpecified {
			diff = resultAmountOut - absAmountSpecified
		} else {
			diff = absAmountSpecified - resultAmountOut
		}
		if diff > swapCount {
			return resultAmountIn, resultAmountOut, false
		}
		if resultAmountIn > amountLimit {
			return resultAmountIn, resultAmountOut, false
		}
		return resultAmountIn, resultAmountOut, true

	default:
		// This should never happen since we validate the swap type earlier
		return 0, 0, false
	}
}

// AddSwapResults safely adds swap result amounts, checking for overflow.
func (p *SwapProcessor) AddSwapResults(
	resultAmountIn, resultAmountOut, amountIn, amountOut int64,
) (int64, int64, error) {
	newAmountIn := safeAddInt64(resultAmountIn, amountIn)
	newAmountOut := safeAddInt64(resultAmountOut, amountOut)

	return newAmountIn, newAmountOut, nil
}

// DrySwapRoute simulates a token swap route without executing the swap.
// It calculates the expected outcome based on the current state of liquidity pools.
func (r *routerV1) DrySwapRoute(
	inputToken, outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit string,
) (string, string, bool) {
	inputAmount, outputAmount, success := r.drySwapRoute(
		inputToken,
		outputToken,
		safeParseInt64(specifiedAmount),
		swapTypeStr,
		strRouteArr,
		quoteArr,
		safeParseInt64(tokenAmountLimit),
	)

	return formatInt64(inputAmount), formatInt64(outputAmount), success
}

// drySwapRoute is a function for applying cross realm.
func (r *routerV1) drySwapRoute(
	inputToken, outputToken string,
	specifiedAmount int64,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit int64,
) (int64, int64, bool) {
	common.MustRegistered(inputToken, outputToken)
	// initialize components
	validator := &SwapValidator{}
	processor := &SwapProcessor{router: r}

	// validate and parse inputs
	swapType, err := validator.swapType(swapTypeStr)
	if err != nil {
		panic(addDetailToError(errInvalidSwapType, err.Error()))
	}

	amountSpecified, err := validator.amount(specifiedAmount)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	amountLimit, err := validator.amountLimit(tokenAmountLimit)
	if err != nil {
		panic(addDetailToError(errInvalidInput, err.Error()))
	}

	routes, quotes, err := NewRouteParser().ParseRoutes(strRouteArr, quoteArr)
	if err != nil {
		panic(addDetailToError(errInvalidRoutesAndQuotes, err.Error()))
	}

	swapCount := calculateSwapCount(strRouteArr)

	swapFee := r.store.GetSwapFee()

	// Store original amount for validation (before router fee adjustment)
	originalAmountSpecified := amountSpecified

	// adjust amount sign for exact out swaps
	if swapType == ExactOut {
		amountSpecifiedWithRouterFee := calculateExactOutWithRouterFee(safeAbsInt64(amountSpecified), swapFee)
		amountSpecified = -amountSpecifiedWithRouterFee
	}

	// initialize accumulators for swap results
	resultAmountIn, resultAmountOut := int64(0), int64(0)
	remainRequestAmount := amountSpecified

	// Process each route
	for i, route := range routes {
		toSwapAmount := int64(0)

		// if it's the last route, use the remaining amount
		isLastRoute := i == len(routes)-1
		if !isLastRoute {
			// calculate the amount to swap for this route
			swapAmount, err := calculateSwapAmountByQuote(amountSpecified, quotes[i])
			if err != nil {
				return 0, 0, false
			}

			// update the remaining amount
			resultRemainRequestAmount := safeSubInt64(remainRequestAmount, swapAmount)

			remainRequestAmount = resultRemainRequestAmount
			toSwapAmount = swapAmount
		} else {
			toSwapAmount = remainRequestAmount
		}

		// determine the number of hops and validate
		numHops := strings.Count(route, POOL_SEPARATOR) + 1
		assertHopsInRange(numHops)

		// execute the appropriate swap type
		var amountIn, amountOut int64
		if numHops == 1 {
			amountIn, amountOut, err = processor.ProcessSingleSwap(route, toSwapAmount)
		} else {
			amountIn, amountOut, err = processor.ProcessMultiSwap(swapType, route, numHops, toSwapAmount)
		}

		if err != nil {
			panic(addDetailToError(errInvalidSwapType, err.Error()))
		}

		if amountIn == 0 || amountOut == 0 {
			return 0, 0, false
		}

		// update accumulated results
		resultAmountIn, resultAmountOut, err = processor.AddSwapResults(resultAmountIn, resultAmountOut, amountIn, amountOut)
		if err != nil {
			panic(addDetailToError(errInvalidInput, err.Error()))
		}
	}

	// simulate deduct router fee
	feeAmountInt64 := calculateRouterFee(resultAmountOut, swapFee)

	resultAmountOut = safeSubInt64(resultAmountOut, feeAmountInt64)

	return processor.ValidateSwapResults(swapType, resultAmountIn, resultAmountOut, originalAmountSpecified, amountLimit, swapCount)
}

// calculateSwapCount calculates the total number of swaps across all routes.
func calculateSwapCount(routeArr string) int64 {
	swapCount := int64(0)

	for _, route := range strings.Split(routeArr, ",") {
		swapCount += int64(strings.Count(route, POOL_SEPARATOR) + 1)
	}

	return swapCount
}

// getPathIndex returns the path index based on swap type and number of hops.
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
