package router

func ExactInSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

func ExactInSingleSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSingleSwapRoute(inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

func ExactOutSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSwapRoute(inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

func ExactOutSingleSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSingleSwapRoute(inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

func DrySwapRoute(
	inputToken, outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit string,
) (string, string, bool) {
	return func(cur realm) (string, string, bool) {
		return getImplementation().DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit)
	}(cross)
}

func SwapCallback(token0Path string, token1Path string, amount0Delta string, amount1Delta string, payer address) error {
	return func(cur realm) error {
		return getImplementation().SwapCallback(token0Path, token1Path, amount0Delta, amount1Delta, payer)
	}(cross)
}

func GetSwapFee() uint64 {
	return getImplementation().GetSwapFee()
}

func SetSwapFee(cur realm, fee uint64) {
	getImplementation().SetSwapFee(fee)
}
