package router

// ExactInSwapRoute runs a exact-in direction swap through the route that offers the most favorable exchange rate.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - inputToken: The path of the input token.
//   - outputToken: The path of the output token.
//   - amountIn: The amount of the input token.
//   - routeArr: The route of the swap.
//   - quoteArr: The share of each split of the route.
//   - amountOutMin: Limits the number of tokens while routing the swap. The minimum amount of tokens to receive.
//   - deadline: The timestamp for transaction to be expired.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - tokenIn: The amount sent to the pool from the user (the input of the swap).
//   - tokenOut: The amount sent to the user from the pool (the output of the swap).
func ExactInSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSwapRoute(inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

// ExactInSingleSwapRoute executes a single-hop swap with exact input amount.
//
// Parameters:
//   - cur: Pass `cross` as argument.
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
//   - amountIn: actual input amount
//   - amountOut: actual output amount
func ExactInSingleSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSingleSwapRoute(inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

// ExactOutSwapRoute runs a exact-out direction swap through the route that offers the most favorable exchange rate.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - inputToken: The path of the input token.
//   - outputToken: The path of the output token.
//   - amountOut: The amount of the output token.
//   - routeArr: The route of the swap.
//   - quoteArr: The share of each split of the route.
//   - amountInMax: Limits the number of tokens while routing the swap. The maximum amount of tokens to pay.
//   - deadline: The timestamp for transaction to be expired.
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - tokenIn: The amount sent to the pool from the user (the input of the swap).
//   - tokenOut: The amount sent to the user from the pool (the output of the swap).
func ExactOutSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSwapRoute(inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

// ExactOutSingleSwapRoute executes a single-hop swap with exact output amount.
//
// Parameters:
//   - cur: Pass `cross` as argument.
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
//   - amountIn: actual input amount
//   - amountOut: actual output amount
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
//   - amountIn: estimated input amount
//   - amountOut: estimated output amount
//   - ok: success status
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
//
// Parameters:
//   - token0Path: path of token0
//   - token1Path: path of token1
//   - amount0Delta: amount change for token0
//   - amount1Delta: amount change for token1
//   - payer: address that will pay for the swap
//
// Returns:
//   - err: error if callback fails
func SwapCallback(token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	return func(cur realm) error {
		return getImplementation().SwapCallback(token0Path, token1Path, amount0Delta, amount1Delta, payer)
	}(cross)
}

// GetSwapFee returns the current rate of the Swap Fee.
//
// Returns:
//   - swapFee: The current rate of the swap fee.
func GetSwapFee() uint64 {
	return getImplementation().GetSwapFee()
}

// SetSwapFee modifies the Swap Fee.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - fee: The rate that will be set as the new Swap Fee. (the value should be in bps)
func SetSwapFee(cur realm, fee uint64) {
	getImplementation().SetSwapFee(fee)
}
