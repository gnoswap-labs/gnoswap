package router

import "std"

// PRICE
type SwapPaths map[int]string
type TokenPairs map[string][]string
type QuoterTarget struct {
	pct            int
	pctAmount      bigint
	targetPath     string
	resultRatioX96 bigint
}

// RPC
type EstimatedRoute struct {
	Pools        string
	Quote        int
	InputAmount  bigint
	OutputAmount bigint
}

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
