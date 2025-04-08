package router

import (
	"std"
	"strconv"

	"gno.land/p/demo/ufmt"
	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/gnoswap/consts"
	"gno.land/r/demo/wugnot"

	en "gno.land/r/gnoswap/v1/emission"

	phalt "gno.land/p/gnoswap/halt"
	"gno.land/r/gnoswap/v1/halt"
)

var one = u256.One()

// ErrorMessages define all error message templates used throughout the router
const (
	errExactOutAmountExceeded = "Received more than requested in [EXACT_OUT] requested=%s, actual=%s"
	errRouterHalted           = "router contract operations are currently disabled"
	errInvalidRouteLength     = "route length(%d) must be 1~7"
	errRoutesQuotesMismatch   = "mismatch between routes(%d) and quotes(%d) length"
	errInvalidQuote           = "invalid quote(%s) at index(%d)"
	errInvalidQuoteSum        = "quote sum(%d) must be 100"
)

// GnotSwapHandler encapsulates methods for handling GNOT token swaps
type GnotSwapHandler struct {
	BeforeBalance uint64
	WrappedAmount uint64
	NewBalance    uint64
}

// newGnotSwapHandler creates a new handler for GNOT swaps
func newGnotSwapHandler(beforeBalance, wrappedAmount uint64) *GnotSwapHandler {
	return &GnotSwapHandler{
		BeforeBalance: beforeBalance,
		WrappedAmount: wrappedAmount,
	}
}

// UpdateNewBalance updates the current balance after swap operations
func (h *GnotSwapHandler) UpdateNewBalance() {
	h.NewBalance = wugnot.BalanceOf(std.PreviousRealm().Address())
}

// HandleInputSwap manages unwrapping logic for GNOT input tokens
// Returns error if validation fails
func (h *GnotSwapHandler) HandleInputSwap() error {
	totalBefore := h.BeforeBalance + h.WrappedAmount
	spend := totalBefore - h.NewBalance

	if spend > h.WrappedAmount {
		return ufmt.Errorf("too much wugnot spent (wrapped: %d, spend: %d)",
			h.WrappedAmount, spend)
	}

	toUnwrap := h.WrappedAmount - spend
	unwrap(toUnwrap)
	return nil
}

// HandleOutputSwap manages unwrapping logic for GNOT output tokens
func (h *GnotSwapHandler) HandleOutputSwap() {
	userRecvWugnot := h.NewBalance - h.BeforeBalance - h.WrappedAmount
	unwrap(uint64(userRecvWugnot))
}

// SwapValidator provides validation methods for swap operations
type SwapValidator struct{}

// ValidateExactOutAmount checks if output amount meets specified requirements
func (v *SwapValidator) ValidateExactOutAmount(resultAmount, specifiedAmount *u256.Uint) error {
	if resultAmount.Gte(specifiedAmount) {
		return nil
	}

	diff := u256.Zero().Sub(specifiedAmount, resultAmount)
	if diff.Gt(one) {
		return ufmt.Errorf(errExactOutAmountExceeded, specifiedAmount.ToString(), resultAmount.ToString())
	}
	return nil
}

// ValidateSlippage ensures swap amounts meet slippage requirements
func (v *SwapValidator) ValidateSlippage(swapType SwapType, amountIn, amountOut, limit *u256.Uint) error {
	switch swapType {
	case ExactIn:
		if amountOut.Lt(limit) {
			return ufmt.Errorf("ExactIn: too few received (min:%s, got:%s)",
				limit.ToString(), amountOut.ToString())
		}
	case ExactOut:
		if amountIn.Gt(limit) {
			return ufmt.Errorf("ExactOut: too much spent (max:%s, used:%s)",
				limit.ToString(), amountIn.ToString())
		}
	default:
		return ufmt.Errorf("invalid swap type")
	}
	return nil
}

// RouteParser handles parsing and validation of routes and quotes
type RouteParser struct{}

func NewRouteParser() *RouteParser {
	return &RouteParser{}
}

// ParseRoutes parses route and quote strings into slices and validates them
func (p *RouteParser) ParseRoutes(routes, quotes string) ([]string, []string, error) {
	routesArr := splitSingleChar(routes, ',')
	quotesArr := splitSingleChar(quotes, ',')

	if err := p.ValidateRoutesAndQuotes(routesArr, quotesArr); err != nil {
		return nil, nil, err
	}

	return routesArr, quotesArr, nil
}

// ValidateRoutesAndQuotes ensures routes and quotes meet required criteria
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

// ValidateQuoteSum ensures all quotes add up to 100%
func (p *RouteParser) ValidateQuoteSum(quotes []string) error {
	sum := 0

	for i, quote := range quotes {
		intQuote, err := strconv.Atoi(quote)
		if err != nil {
			return ufmt.Errorf(errInvalidQuote, quote, i)
		}

		sum += intQuote
	}

	if sum != 100 {
		return ufmt.Errorf(errInvalidQuoteSum, sum)
	}

	return nil
}

// haltCheck performs security validations before any swap operation
func haltCheck() error {
	currentLevel := halt.GetCurrentHaltLevel()

	if currentLevel != halt.LvMainnetSafeMode {
		// check for withdraw operation halt
		if err := halt.IsHalted(phalt.OpTypeWithdraw); err != nil {
			return err
		}

		// check for router contract halt
		if halt.IsContractHalted(phalt.OpTypeRouter) {
			return ufmt.Errorf(errRouterHalted)
		}
	}

	return nil
}

// commonSwapSetup performs all necessary validations and setup for a swap operation
func commonSwapSetup() error {
	if err := haltCheck(); err != nil {
		return err
	}

	assertDirectCallOnly()
	en.MintAndDistributeGns()
	return nil
}

// FinalizeSwap handles post-swap operations and validations
// Returns input and output amount strings after processing
func finalizeSwap(
	inputToken, outputToken string,
	resultAmountIn, resultAmountOut *u256.Uint,
	swapType SwapType,
	tokenAmountLimit *u256.Uint,
	userBeforeWugnotBalance, userWrappedWugnot uint64,
	amountSpecified *u256.Uint,
) (string, string) {
	validator := &SwapValidator{}

	// Validate exact out amount if applicable
	if swapType == ExactOut {
		if err := validator.ValidateExactOutAmount(resultAmountOut, amountSpecified); err != nil {
			panic(addDetailToError(errSlippage, err.Error()))
		}
	}

	// Handle swap fee
	resultAmountOutWithoutFee := handleSwapFee(outputToken, resultAmountOut)

	// Handle GNOT token swaps
	handler := newGnotSwapHandler(userBeforeWugnotBalance, userWrappedWugnot)
	handler.UpdateNewBalance()

	var err error
	if inputToken == consts.GNOT {
		err = handler.HandleInputSwap()
	} else if outputToken == consts.GNOT {
		handler.HandleOutputSwap()
	}

	if err != nil {
		panic(addDetailToError(errSlippage, err.Error()))
	}

	if err := validator.ValidateSlippage(swapType, resultAmountIn, resultAmountOutWithoutFee, tokenAmountLimit); err != nil {
		panic(addDetailToError(errSlippage, err.Error()))
	}

	// calculate final amounts
	intAmountOut := i256.FromUint256(resultAmountOutWithoutFee)
	negativeOut := i256.Zero().Neg(intAmountOut).ToString()

	return resultAmountIn.ToString(), negativeOut
}

// validateRoutesAndQuotes is a convenience function that parses and validates routes in one call
func validateRoutesAndQuotes(routes, quotes string) ([]string, []string, error) {
	return NewRouteParser().ParseRoutes(routes, quotes)
}
