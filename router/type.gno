package router

import (
	"std"

	i256 "gno.land/p/gnoswap/int256"
)

// SWAP TYPE
type SwapType string

const (
	ExactIn  SwapType = "EXACT_IN"
	ExactOut SwapType = "EXACT_OUT"
)

// SINGLE SWAP
type SingleSwapParams struct {
	tokenIn  string // token to spend
	tokenOut string // token to receive
	fee      uint32 // fee of the pool used to swap

	// if positive, it's the amount of tokenIn to spend
	// if negative, it's the wanted amount of tokenOut to receive
	amountSpecified *i256.Int
}

// MUTLI SWAP
type SwapParams struct {
	tokenIn   string      // token to spend
	tokenOut  string      // token to receive
	fee       uint32      // fee of the pool used to swap
	recipient std.Address // address to receive the token

	// if positive, it's the amount of tokenIn to spend
	// if negative, it's the wanted amount of tokenOut to receive
	amountSpecified *i256.Int
}

func newSwapParams(tokenIn, tokenOut string, fee uint32, recipient std.Address, amountSpecified *i256.Int) *SwapParams {
	return &SwapParams{
		tokenIn:        tokenIn,
		tokenOut:       tokenOut,
		fee:            fee,
		recipient:      recipient,
		amountSpecified: amountSpecified,
	}
}

// SWAP DATA
type SwapCallbackData struct {
	tokenIn  string // token to spend
	tokenOut string // token to receive
	fee      uint32 // fee of the pool used to swap

	payer std.Address // address to spend the token
}
