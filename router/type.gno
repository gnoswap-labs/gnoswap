package router

import "std"

// SWAP TYPE
type SwapType string // r3v4_xxx: private?

const (
	ExactIn  SwapType = "EXACT_IN"  // r3v4_xxx: private?
	ExactOut SwapType = "EXACT_OUT" // r3v4_xxx: private?
)

// PRICE
type SwapPaths map[int]string       // r3v4_xxx: private?
type TokenPairs map[string][]string // r3v4_xxx: private?
type QuoterTarget struct {          // r3v4_xxx: private?
	pct            int
	pctAmount      bigint
	targetPath     string
	resultRatioX96 bigint
}

// SINGLE SWAP
type SingleSwapParams struct { // r3v4_xxx: private?
	tokenIn         string
	tokenOut        string
	fee             uint16
	amountSpecified bigint
}

// MUTLI SWAP
type SwapParams struct { // r3v4_xxx: private?
	tokenIn         string
	tokenOut        string
	fee             uint16
	recipient       std.Address
	amountSpecified bigint
}

// SWAP DATA
type SwapCallbackData struct { // r3v4_xxx: private?
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}

// QueryPool
type QueryPool struct {
	PoolPath             string `json:"pool_path"`
	Token0Path           string `json:"token0_path"`
	Token1Path           string `json:"token1_path"`
	Token0Balance        bigint `json:"token0_balance"`
	Token1Balance        bigint `json:"token1_balance"`
	Fee                  uint16 `json:"fee"`
	TickSpacing          int32  `json:"tick_spacing"`
	CurrentTick          int32  `json:"current_tick"`
	FeeGrowthGlobal0X128 bigint `json:"fee_growth_global0_x128"`
	FeeGrowthGlobal1X128 bigint `json:"fee_growth_global1_x128"`
	SqrtPriceX96         bigint `json:"sqrt_price_x96"`
	Liquidity            bigint `json:"liquidity"`
}
