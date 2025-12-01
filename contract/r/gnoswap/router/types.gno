package router

type IRouter interface {
	ExactInSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)
	ExactInSingleSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	ExactOutSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string)
	ExactOutSingleSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, bool)
	SwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error

	GetSwapFee() uint64
	SetSwapFee(fee uint64)
}

type IRouterStore interface {
	HasSwapFeeKey() bool
	GetSwapFee() uint64
	SetSwapFee(fee uint64) error
}
