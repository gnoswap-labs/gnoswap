package router

import (
	"std"

	i256 "gno.land/p/gnoswap/int256"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/p/nt/ufmt"
)

const (
	rawUnknown  = "UNKNOWN"
	rawExactIn  = "EXACT_IN"
	rawExactOut = "EXACT_OUT"
)

type SwapType string

const (
	Unknown SwapType = rawUnknown
	// ExactIn represents a swap type where the input amount is exact and the output amount may vary.
	// Used when a user wants to swap a specific amount of input tokens.
	ExactIn SwapType = rawExactIn

	// ExactOut represents a swap type where the output amount is exact and the input amount may vary.
	// Used when a user wants to swap a specific amount of output tokens.
	ExactOut SwapType = rawExactOut
)

// trySwapTypeFromStr attempts to convert a string into a SwapType.
// It validates and converts string representations of swap types into their corresponding enum values.
func trySwapTypeFromStr(swapType string) (SwapType, error) {
	switch swapType {
	case rawExactIn:
		return ExactIn, nil
	case rawExactOut:
		return ExactOut, nil
	default:
		return "", ufmt.Errorf("unknown swapType: expected ExactIn or ExactOut, got %s", swapType)
	}
}

// String returns the string representation of SwapType.
func (s SwapType) String() string {
	switch s {
	case ExactIn:
		return rawExactIn
	case ExactOut:
		return rawExactOut
	default:
		return ""
	}
}

// SingleSwapParams contains parameters for executing a single pool swap.
// It represents the simplest form of swap that occurs within a single liquidity pool.
type SingleSwapParams struct {
	tokenIn    string // token to spend
	tokenOut   string // token to receive
	fee        uint32 // fee of the pool used to swap
	withUnwrap bool   // whether to unwrap the token

	// Amount specified for the swap:
	//  - Positive: exact input amount (tokenIn)
	//  - Negative: exact output amount (tokenOut)
	amountSpecified *i256.Int
}

// TokenIn returns the input token address.
func (p SingleSwapParams) TokenIn() string { return p.tokenIn }

// TokenOut returns the output token address.
func (p SingleSwapParams) TokenOut() string { return p.tokenOut }

// Fee returns the pool fee tier.
func (p SingleSwapParams) Fee() uint32 { return p.fee }

// SwapParams contains parameters for executing a multi-hop swap operation.
type SwapParams struct {
	SingleSwapParams
	recipient  std.Address // address to receive the token
	withUnwrap bool        // whether to unwrap the token
}

// TokenIn returns the input token address.
func (p SwapParams) TokenIn() string { return p.tokenIn }

// TokenOut returns the output token address.
func (p SwapParams) TokenOut() string { return p.tokenOut }

// Fee returns the pool fee tier.
func (p SwapParams) Fee() uint32 { return p.fee }

// Recipient returns the recipient address.
func (p SwapParams) Recipient() std.Address { return p.recipient }

// newSwapParams creates a new SwapParams instance with the provided parameters.
func newSwapParams(tokenIn, tokenOut string, fee uint32, recipient std.Address, amountSpecified *i256.Int, withUnwrap bool) *SwapParams {
	return &SwapParams{
		SingleSwapParams: SingleSwapParams{
			tokenIn:         tokenIn,
			tokenOut:        tokenOut,
			fee:             fee,
			amountSpecified: amountSpecified,
		},
		withUnwrap: withUnwrap,
		recipient:  recipient,
	}
}

// SwapResult encapsulates the outcome of a swap operation.
type SwapResult struct {
	Routes          []string
	Quotes          []string
	AmountIn        *u256.Uint
	AmountOut       *u256.Uint
	AmountSpecified *i256.Int
	WithUnwrap      bool
}

// SwapParamsI defines the common interface for swap parameters.
type SwapParamsI interface {
	TokenIn() string
	TokenOut() string
	Fee() uint32
}

// SwapCallbackData contains the callback data required for swap execution.
// This type is used to pass necessary information during the swap callback process,
// ensuring proper token transfers and pool data updates.
type SwapCallbackData struct {
	tokenIn  string      // token to spend
	tokenOut string      // token to receive
	fee      uint32      // fee of the pool used to swap
	payer    std.Address // address to spend the token
	hasNext  bool        // whether there is a next swap
}

// newSwapCallbackData creates a new SwapCallbackData from a SwapParamsI.
func newSwapCallbackData(params SwapParamsI, payer std.Address, hasNext bool) SwapCallbackData {
	return SwapCallbackData{
		tokenIn:  params.TokenIn(),
		tokenOut: params.TokenOut(),
		fee:      params.Fee(),
		payer:    payer,
		hasNext:  hasNext,
	}
}

// ExactInParams contains parameters for exact input swaps.
type ExactInParams struct {
	BaseSwapParams
	AmountIn     string
	AmountOutMin string
}

// NewExactInParams creates a new ExactInParams instance.
func NewExactInParams(
	baseParams BaseSwapParams,
	amountIn string,
	amountOutMin string,
) ExactInParams {
	return ExactInParams{
		BaseSwapParams: baseParams,
		AmountIn:       amountIn,
		AmountOutMin:   amountOutMin,
	}
}

// ExactOutParams contains parameters for exact output swaps.
type ExactOutParams struct {
	BaseSwapParams
	AmountOut   string
	AmountInMax string
}

// NewExactOutParams creates a new ExactOutParams instance.
func NewExactOutParams(
	baseParams BaseSwapParams,
	amountOut string,
	amountInMax string,
) ExactOutParams {
	return ExactOutParams{
		BaseSwapParams: baseParams,
		AmountOut:      amountOut,
		AmountInMax:    amountInMax,
	}
}
