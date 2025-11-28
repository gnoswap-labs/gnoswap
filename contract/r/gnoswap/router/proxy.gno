package router

// ExactInSwapRoute executes a multi-hop swap with exact input amount.
//
// Parameters:
//   - inputToken: path of input token
//   - outputToken: path of output token
//   - amountIn: exact input amount
//   - routeArr: encoded route array
//   - quoteArr: encoded quote array
//   - amountOutMin: minimum output amount
//   - deadline: transaction deadline
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: actual input amount
//   - string: actual output amount
func ExactInSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

// ExactInSingleSwapRoute executes a single-hop swap with exact input amount.
//
// Parameters:
//   - inputToken: path of input token
//   - outputToken: path of output token
//   - amountIn: exact input amount
//   - routeArr: encoded route
//   - amountOutMin: minimum output amount
//   - sqrtPriceLimitX96: price limit for the swap
//   - deadline: transaction deadline
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: actual input amount
//   - string: actual output amount
func ExactInSingleSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSingleSwapRoute(inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

// ExactOutSwapRoute executes a multi-hop swap with exact output amount.
//
// Parameters:
//   - inputToken: path of input token
//   - outputToken: path of output token
//   - amountOut: exact output amount
//   - routeArr: encoded route array
//   - quoteArr: encoded quote array
//   - amountInMax: maximum input amount
//   - deadline: transaction deadline
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: actual input amount
//   - string: actual output amount
func ExactOutSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSwapRoute(inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

// ExactOutSingleSwapRoute executes a single-hop swap with exact output amount.
//
// Parameters:
//   - inputToken: path of input token
//   - outputToken: path of output token
//   - amountOut: exact output amount
//   - routeArr: encoded route
//   - amountInMax: maximum input amount
//   - sqrtPriceLimitX96: price limit for the swap
//   - deadline: transaction deadline
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - string: actual input amount
//   - string: actual output amount
func ExactOutSingleSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSingleSwapRoute(inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

// DrySwapRoute simulates a swap route without executing it.
//
// Parameters:
//   - inputToken: path of input token
//   - outputToken: path of output token
//   - specifiedAmount: specified amount for the swap
//   - swapTypeStr: swap type string ("ExactIn" or "ExactOut")
//   - strRouteArr: encoded route array
//   - quoteArr: encoded quote array
//   - tokenAmountLimit: token amount limit
//
// Returns:
//   - string: estimated input amount
//   - string: estimated output amount
//   - bool: success status
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

// SwapCallback is called by pools to transfer tokens during a swap.
func SwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	return func(cur realm) error {
		return getImplementation().SwapCallback(token0Path, token1Path, amount0Delta, amount1Delta, payer)
	}(cross)
}

// GetSwapFee returns the current swap fee rate.
func GetSwapFee() uint64 {
	return getImplementation().GetSwapFee()
}

// SetSwapFee sets the swap fee rate.
//
// Parameters:
//   - fee: new swap fee in basis points
func SetSwapFee(cur realm, fee uint64) {
	getImplementation().SetSwapFee(fee)
}
