package router

type IRouter interface {
	ExactInSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)
	ExactOutSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)
	DrySwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)

	GetSwapFee() uint64
	SetSwapFee(fee uint64)
}

type IRouterStore interface {
	HasSwapFeeKey() bool
	GetSwapFee() uint64
	SetSwapFee(fee uint64) error
}
