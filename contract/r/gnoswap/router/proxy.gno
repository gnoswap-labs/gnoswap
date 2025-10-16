package router

func ExactInSwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func ExactOutSwapRoute(inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSwapRoute(inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

func DrySwapRoute(inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().DrySwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func GetSwapFee() uint64 {
	return getImplementation().GetSwapFee()
}

func SetSwapFee(fee uint64) {
	getImplementation().SetSwapFee(fee)
}
