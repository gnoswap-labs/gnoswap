package router

type IRouter interface {
	ExactInSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)
	ExactInSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	ExactOutSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string)
	ExactOutSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool)
	SwapCallback(_ int, rlm realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error

	GetSwapFee() uint64
	SetSwapFee(_ int, rlm realm, fee uint64)
}

type IRouterStore interface {
	HasSwapFeeKey() bool
	GetSwapFee() uint64
	SetSwapFee(_ int, rlm realm, fee uint64) error
	HasPendingProtocolFeesKey() bool
	GetPendingProtocolFees() map[string]int64
	SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error
}
