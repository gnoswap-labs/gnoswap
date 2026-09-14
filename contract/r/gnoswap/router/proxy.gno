package router

// ExactInSwapRoute executes a multi-hop swap for an exact input amount.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - inputToken: input token path
//   - outputToken: output token path
//   - amountIn: exact input amount
//   - routeArr: encoded route
//   - quoteArr: encoded quotes
//   - amountOutMin: minimum output amount
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns:
//   - amountIn: input amount consumed
//   - amountOut: output amount delivered
func ExactInSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSwapRoute(0, cur, inputToken, outputToken, amountIn, routeArr, quoteArr, amountOutMin, deadline, referrer)
}

// ExactInSingleSwapRoute executes a single-hop swap for an exact input amount.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - inputToken: input token path
//   - outputToken: output token path
//   - amountIn: exact input amount
//   - routeArr: encoded route
//   - amountOutMin: minimum output amount
//   - sqrtPriceLimitX96: Q64.96 price limit
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns:
//   - amountIn: input amount consumed
//   - amountOut: output amount delivered
func ExactInSingleSwapRoute(cur realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactInSingleSwapRoute(0, cur, inputToken, outputToken, amountIn, routeArr, amountOutMin, sqrtPriceLimitX96, deadline, referrer)
}

// ExactOutSwapRoute executes a multi-hop swap for an exact output amount.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - inputToken: input token path
//   - outputToken: output token path
//   - amountOut: exact output amount
//   - routeArr: encoded route
//   - quoteArr: encoded quotes
//   - amountInMax: maximum input amount
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns:
//   - amountIn: input amount consumed
//   - amountOut: output amount delivered
func ExactOutSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSwapRoute(0, cur, inputToken, outputToken, amountOut, routeArr, quoteArr, amountInMax, deadline, referrer)
}

// ExactOutSingleSwapRoute executes a single-hop swap for an exact output amount.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - inputToken: input token path
//   - outputToken: output token path
//   - amountOut: exact output amount
//   - routeArr: encoded route
//   - amountInMax: maximum input amount
//   - sqrtPriceLimitX96: Q64.96 price limit
//   - deadline: transaction deadline
//   - referrer: referral address
//
// Returns:
//   - amountIn: input amount consumed
//   - amountOut: output amount delivered
func ExactOutSingleSwapRoute(cur realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string) {
	return getImplementation().ExactOutSingleSwapRoute(0, cur, inputToken, outputToken, amountOut, routeArr, amountInMax, sqrtPriceLimitX96, deadline, referrer)
}

// DrySwapRoute simulates a swap route without changing state.
//
// Parameters:
//   - inputToken: input token path
//   - outputToken: output token path
//   - specifiedAmount: exact input or output amount
//   - swapTypeStr: `ExactIn` or `ExactOut`
//   - strRouteArr: encoded route
//   - quoteArr: encoded quotes
//   - tokenAmountLimit: minimum output or maximum input amount
//
// Returns:
//   - amountIn: estimated input amount
//   - amountOut: estimated output amount
//   - err: non-nil when route validation or simulation fails
func DrySwapRoute(
	inputToken, outputToken string,
	specifiedAmount string,
	swapTypeStr string,
	strRouteArr, quoteArr string,
	tokenAmountLimit string,
) (string, string, error) {
	return getImplementation().DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit)
}

// SwapCallback transfers amounts owed by a pool during a swap.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - token0Path: token0 path
//   - token1Path: token1 path
//   - amount0Delta: token0 amount owed to or by the pool
//   - amount1Delta: token1 amount owed to or by the pool
//   - payer: address that supplies positive deltas
//
// Returns:
//   - err: non-nil when payment validation or transfer fails
func SwapCallback(cur realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error {
	return getImplementation().SwapCallback(0, cur, token0Path, token1Path, amount0Delta, amount1Delta, payer)
}

// GetSwapFee returns the current router fee rate.
//
// Returns:
//   - fee: fee rate in basis points
func GetSwapFee() uint64 {
	return getImplementation().GetSwapFee()
}

// SetSwapFee sets the router fee rate.
//
// Parameters:
//   - cur: pass `cross` as argument
//   - fee: fee rate in basis points
func SetSwapFee(cur realm, fee uint64) {
	getImplementation().SetSwapFee(0, cur, fee)
}

// GetPendingProtocolFees returns a copy of uncollected protocol fees by token.
//
// Returns:
//   - fees: pending protocol fee amount keyed by token path
func GetPendingProtocolFees() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetPendingProtocolFees())
}
