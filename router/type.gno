package router

import (
	"std"

	i256 "gno.land/p/big/int256"
)

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
	fee             uint32
	amountSpecified *i256.Int
}

// MUTLI SWAP
type SwapParams struct {
	tokenIn         string
	tokenOut        string
	fee             uint32
	recipient       std.Address
	amountSpecified *i256.Int
}

// SWAP DATA
type SwapCallbackData struct {
	tokenIn  string
	tokenOut string
	fee      uint32

	payer std.Address
}
