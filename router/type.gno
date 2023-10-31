package router

import (
	"std"
)

/* NOT USED CURRENTLY
type SwapRoutes []SwapRoute // RETURN THIS

type SwapRoute struct {
	inputTokenPath  string
	outputTokenPath string
	swapAmount      bigint
	swapAmountRatio int // 최소 5%
	pools           []Pool
}

type Pool struct {
	poolPath        string
	token0Path      string
	token1Path      string
	fee             int
	currentPriceX96 bigint
	currentTick     int32
}
*/

type SwapCallbackData struct {
	// poolPath string
	tokenIn  string
	tokenOut string
	fee      uint16

	payer std.Address
}

type SwapPaths map[int]string
type TokenPairs map[string][]string
