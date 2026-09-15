package router

import (
	"errors"
	"strconv"

	ufmt "gno.land/p/nt/ufmt/v0"
)

// ErrorMessages define all error message templates used throughout the router
const (
	// slippage validation
	errExactInAmountMismatch  = "consumed input does not match requested (requested=%d, consumed=%d)"
	errExactOutAmountExceeded = "received more than requested in requested=%d, actual=%d"

	// route validation
	errInvalidRouteLength = "route length(%d) must be 1~7"

	// quote validation
	errRoutesQuotesMismatch = "mismatch between routes(%d) and quotes(%d) length"
	errInvalidQuote         = "invalid quote(%s) at index(%d)"
	errInvalidQuoteValue    = "quote(%s) at index(%d) must be positive value"
	errQuoteExceedsMax      = "quote(%s) at index(%d) must be less than or equal to %d"
	errQuoteSumExceedsMax   = "quote sum exceeds 100 at index(%d)"
	errInvalidQuoteSum      = "quote sum(%d) must be 100"

	// swap type validation
	errExactInTooFewReceived = "ExactIn: too few received (min:%d, got:%d)"
	errExactOutTooMuchSpent  = "ExactOut: too much spent (max:%d, used:%d)"

	// route parsing validation
	errEmptyRoutes = "routes cannot be empty"
)

// SwapValidator provides validation methods for swap operations
type SwapValidator struct{}

// exactOutAmount verifies that exact-output execution is within per-hop rounding tolerance.
//
// Parameters:
//   - resultAmount: actual output amount obtained
//   - specifiedAmount: requested output amount
//   - swapCount: number of pool hops contributing rounding tolerance
//
// Returns:
//   - err: nil when absolute difference is at most swapCount; exceeded-target error otherwise
func (v *SwapValidator) exactOutAmount(resultAmount, specifiedAmount int64, swapCount int64) error {
	diff := int64(0)

	if resultAmount >= specifiedAmount {
		diff = resultAmount - specifiedAmount
	} else {
		diff = specifiedAmount - resultAmount
	}

	if diff > swapCount {
		return ufmt.Errorf(errExactOutAmountExceeded, specifiedAmount, resultAmount)
	}

	return nil
}

// exactInAmount verifies that exact-input execution consumed the requested amount exactly.
//
// Parameters:
//   - resultAmount: actual input amount consumed
//   - specifiedAmount: requested input amount
//
// Returns:
//   - err: nil when amounts match; mismatch error otherwise
func (v *SwapValidator) exactInAmount(resultAmount, specifiedAmount int64) error {
	if resultAmount != specifiedAmount {
		return ufmt.Errorf(errExactInAmountMismatch, specifiedAmount, resultAmount)
	}

	return nil
}

// slippage checks the caller's minimum-output or maximum-input constraint.
//
// Parameters:
//   - swapType: ExactIn or ExactOut, selecting the limit comparison
//   - amountIn: actual input amount consumed
//   - amountOut: actual output amount after fees
//   - limit: minimum output for ExactIn or maximum input for ExactOut
//
// Returns:
//   - err: nil when the selected constraint passes; slippage or invalid-type error otherwise
func (v *SwapValidator) slippage(swapType SwapType, amountIn, amountOut, limit int64) error {
	switch swapType {
	case ExactIn:
		if amountOut < limit {
			return ufmt.Errorf(errExactInTooFewReceived, limit, amountOut)
		}
	case ExactOut:
		if amountIn > limit {
			return ufmt.Errorf(errExactOutTooMuchSpent, limit, amountIn)
		}
	default:
		return errors.New(errInvalidSwapType)
	}
	return nil
}

// swapType parses and validates a string swap type.
//
// Parameters:
//   - swapTypeStr: expected EXACT_IN or EXACT_OUT string
//
// Returns:
//   - swapType: parsed ExactIn or ExactOut value
//   - err: nil for a supported string; invalid-swap-type error otherwise
func (v *SwapValidator) swapType(swapTypeStr string) (SwapType, error) {
	swapType, err := trySwapTypeFromStr(swapTypeStr)
	if err != nil {
		return Unknown, errors.New(errInvalidSwapType)
	}
	return swapType, nil
}

// amount validates that an amount is strictly positive.
//
// Parameters:
//   - amount: amount to validate in token units
//
// Returns:
//   - validAmount: amount unchanged when positive, or zero on failure
//   - err: nil for a positive amount; invalid-positive-amount error otherwise
func (v *SwapValidator) amount(amount int64) (int64, error) {
	if amount <= 0 {
		return 0, ufmt.Errorf(ErrInvalidPositiveAmount, amount)
	}
	return amount, nil
}

// RouteParser handles parsing and validation of routes and quotes
type RouteParser struct{}

// NewRouteParser creates a parser for comma-separated route and quote strings.
//
// Returns:
//   - parser: new RouteParser instance
func NewRouteParser() *RouteParser {
	return &RouteParser{}
}

// ParseRoutes splits route and quote strings and validates their pairing.
//
// Parameters:
//   - routes: comma-separated route paths
//   - quotes: comma-separated route allocation percentages
//
// Returns:
//   - routePaths: parsed route path strings
//   - quoteValues: parsed quote strings corresponding one-to-one with routePaths
//   - err: nil when routes, counts, and quote sum are valid; validation error otherwise
func (p *RouteParser) ParseRoutes(routes, quotes string) ([]string, []string, error) {
	// Check for empty routes
	if routes == "" || quotes == "" {
		return nil, nil, errors.New(errEmptyRoutes)
	}

	routesArr := splitSingleChar(routes, ',')
	quotesArr := splitSingleChar(quotes, ',')

	if err := p.ValidateRoutesAndQuotes(routesArr, quotesArr); err != nil {
		return nil, nil, err
	}

	return routesArr, quotesArr, nil
}

// ValidateRoutesAndQuotes checks route count, route/quote cardinality, and quote sum.
//
// Parameters:
//   - routes: parsed route path strings
//   - quotes: parsed quote percentage strings
//
// Returns:
//   - err: nil when one to seven routes match quote count and quotes sum to 100; validation error otherwise
func (p *RouteParser) ValidateRoutesAndQuotes(routes, quotes []string) error {
	rr := len(routes)
	qq := len(quotes)

	if rr < 1 || rr > 7 {
		return ufmt.Errorf(errInvalidRouteLength, rr)
	}

	if rr != qq {
		return ufmt.Errorf(errRoutesQuotesMismatch, rr, qq)
	}

	return p.ValidateQuoteSum(quotes)
}

// ValidateQuoteSum verifies that each quote is positive, at most 100, and totals 100.
//
// Parameters:
//   - quotes: route allocation percentage strings
//
// Returns:
//   - err: nil when all quotes parse and total 100; invalid value or sum error otherwise
func (p *RouteParser) ValidateQuoteSum(quotes []string) error {
	const (
		maxQuote int8 = 100
		minQuote int8 = 0
	)

	var sum int8

	for i, quote := range quotes {
		qt, err := strconv.ParseInt(quote, 10, 8)
		if err != nil {
			return ufmt.Errorf(errInvalidQuote, quote, i)
		}
		intQuote := int8(qt)

		// Quote must be positive (> 0) as each route needs a non-zero allocation.
		// A quote of 0 would mean no swap through that route, which is invalid.
		if intQuote <= minQuote { // minQuote = 0, so this rejects quote = 0
			return ufmt.Errorf(errInvalidQuoteValue, quote, i)
		}

		if intQuote > maxQuote {
			return ufmt.Errorf(errQuoteExceedsMax, quote, i, maxQuote)
		}

		if sum > maxQuote-intQuote {
			return ufmt.Errorf(errQuoteSumExceedsMax, i)
		}

		sum += intQuote
	}

	if sum != maxQuote {
		return ufmt.Errorf(errInvalidQuoteSum, sum)
	}

	return nil
}

// finalizeSwap applies router fees and enforces exact-amount and slippage constraints.
//
// Parameters:
//   - _: leading operation discriminator; callers pass 0
//   - rlm: propagated current realm context used for fee settlement
//   - inputToken: input token contract path retained for finalization context
//   - outputToken: output token contract path whose output fee is settled
//   - resultAmountIn: aggregate input amount from pool execution
//   - resultAmountOut: aggregate output amount before router fee
//   - swapType: ExactIn or ExactOut validation direction
//   - tokenAmountLimit: minimum output or maximum input slippage bound
//   - amountSpecified: requested exact input or output amount
//   - swapCount: number of pool hops used for exact-output rounding tolerance
//   - isSetSqrtPriceLimitX96: true when a caller price limit allows partial fill
//
// Returns:
//   - amountIn: finalized input amount
//   - amountOut: output amount after router fee
func (r *routerV1) finalizeSwap(
	_ int,
	rlm realm,
	inputToken, outputToken string,
	resultAmountIn, resultAmountOut int64,
	swapType SwapType,
	tokenAmountLimit int64,
	amountSpecified int64,
	swapCount int64,
	isSetSqrtPriceLimitX96 bool,
) (int64, int64) {
	validator := &SwapValidator{}

	// Handle swap fee
	resultAmountOutWithoutFee := r.handleSwapFee(0, rlm, outputToken, resultAmountOut)

	// Validate the exact-out target when no caller price limit is set. A
	// nonzero single-hop limit permits partial output, so only the max-input
	// slippage check below remains applicable.
	if swapType == ExactOut && !isSetSqrtPriceLimitX96 {
		if err := validator.exactOutAmount(resultAmountOutWithoutFee, amountSpecified, swapCount); err != nil {
			panic(addDetailToError(errSlippage, err.Error()))
		}
	}

	// Validate exact in amount if applicable
	// If sqrtPriceLimitX96 is set, partial consumption up to the price limit is intended
	if swapType == ExactIn && !isSetSqrtPriceLimitX96 {
		if err := validator.exactInAmount(resultAmountIn, amountSpecified); err != nil {
			panic(addDetailToError(errInsufficientLiquidity, err.Error()))
		}
	}

	if err := validator.slippage(swapType, resultAmountIn, resultAmountOutWithoutFee, tokenAmountLimit); err != nil {
		panic(addDetailToError(errSlippage, err.Error()))
	}

	return resultAmountIn, resultAmountOutWithoutFee
}

// validateRoutesAndQuotes parses and validates encoded routes and quotes.
//
// Parameters:
//   - routes: comma-separated route paths
//   - quotes: comma-separated route allocation percentages
//
// Returns:
//   - routePaths: parsed route path strings
//   - quoteValues: parsed quote strings
//   - err: nil when route and quote validation succeeds; validation error otherwise
func validateRoutesAndQuotes(routes, quotes string) ([]string, []string, error) {
	return NewRouteParser().ParseRoutes(routes, quotes)
}
