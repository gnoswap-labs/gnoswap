package router

import "std"

// SWAP TYPE
type SwapType string

const (
	ExactIn  SwapType = "EXACT_IN"
	ExactOut SwapType = "EXACT_OUT"
)

// SINGLE SWAP
type SingleSwapParams struct {
	tokenIn         string
	tokenOut        string
	fee             uint16
	amountSpecified bigint
}

// MUTLI SWAP
type SwapParams struct {
	tokenIn         string
	tokenOut        string
	fee             uint16
	recipient       std.Address
	amountSpecified bigint
}

// SWAP DATA
type SwapCallbackData struct {
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}
