package router

import (
	"std"

	i256 "gno.land/p/gnoswap/int256"
)

const (
	// ExactIn represents a swap type where the input amount is exact and the output amount may vary.
	// Used when a user wants to swap a specific amount of input tokens.
	ExactIn  string = "EXACT_IN"

	// ExactOut represents a swap type where the output amount is exact and the input amount may vary.
	// Used when a user wants to swap a specific amount of output tokens.
	ExactOut string = "EXACT_OUT"
)

// SingleSwapParams contains parameters for executing a single pool swap.
// It represents the simplest form of swap that occurs within a single liquidity pool.
type SingleSwapParams struct {
	tokenIn  string // token to spend
	tokenOut string // token to receive
	fee      uint32 // fee of the pool used to swap

	// Amount specified for the swap:
	//  - Positive: exact input amount (tokenIn)
	//  - Negative: exact output amount (tokenOut)
	amountSpecified *i256.Int
}

// SwapParams contains parameters for executing a multi-hop swap opration.
// It extends the `SingleSwapParams` with recipient information for more complex swaps
// that involve multiple pools.
type SwapParams struct {
	tokenIn   string      // token to being spent
	tokenOut  string      // token to being received
	fee       uint32      // fee of the pool used to swap
	recipient std.Address // address to receive the token

	// Amount specified for the swap:
	//  - Positive: exact input amount (tokenIn)
	//  - Negative: exact output amount (tokenOut)
	amountSpecified *i256.Int
}

// newSwapParams creates a new `SwapParams` instance with the provided parameters.
//
// Parameters:
//  - tokenIn: Address of the token being spent
//  - tokenOut: Address of the token being received
//  - fee: Fee tier of the pool in basis points
//  - recipient: Address that will receive the output tokens
//  - amountSpecified: Amount specified for the swap (positive for exact input, negative for exact output)
//
// Returns:
//  - *SwapParams: new `SwapParams` instance
func newSwapParams(tokenIn, tokenOut string, fee uint32, recipient std.Address, amountSpecified *i256.Int) *SwapParams {
	return &SwapParams{
		tokenIn:         tokenIn,
		tokenOut:        tokenOut,
		fee:             fee,
		recipient:       recipient,
		amountSpecified: amountSpecified,
	}
}

// SwapCallbackData contains the callback data required for swap execution.
// This type is used to pass necessary information during the swap callback process,
// ensuring proper token transfers and pool data updates.
type SwapCallbackData struct {
	tokenIn  string      // token to spend
	tokenOut string      // token to receive
	fee      uint32      // fee of the pool used to swap
	payer    std.Address // address to spend the token
}
