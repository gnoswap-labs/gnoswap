package router

type IRouter interface {
	// ExactInSwapRoute executes a multi-hop exact-input swap.
	//
	// Parameters:
	//   - _: leading implementation discriminator; callers pass 0
	//   - rlm: propagated current realm context used for swap validation and transfers
	//   - inputToken: input token contract path
	//   - outputToken: output token contract path
	//   - amountIn: exact input amount encoded as a decimal string
	//   - routeArr: comma-separated route paths, each with up to three pool hops
	//   - quoteArr: comma-separated route allocation percentages summing to 100
	//   - amountOutMin: minimum net output amount encoded as a decimal string
	//   - deadline: Unix timestamp after which the swap is rejected
	//   - referrer: optional referral address used for registration
	//
	// Returns:
	//   - amountIn: actual input amount consumed, encoded as a decimal string
	//   - amountOut: net output amount after router fee, encoded as a decimal string
	ExactInSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, quoteArr string, amountOutMin string, deadline int64, referrer string) (string, string)
	// ExactInSingleSwapRoute executes an exact-input swap through one pool.
	//
	// Parameters:
	//   - _: leading implementation discriminator; callers pass 0
	//   - rlm: propagated current realm context used for swap validation and transfers
	//   - inputToken: input token contract path
	//   - outputToken: output token contract path
	//   - amountIn: exact input amount encoded as a decimal string
	//   - routeArr: single-hop route path
	//   - amountOutMin: minimum net output amount encoded as a decimal string
	//   - sqrtPriceLimitX96: optional Q64.96 square-root price limit encoded as a decimal string
	//   - deadline: Unix timestamp after which the swap is rejected
	//   - referrer: optional referral address used for registration
	//
	// Returns:
	//   - amountIn: actual input amount consumed, encoded as a decimal string
	//   - amountOut: net output amount after router fee, encoded as a decimal string
	ExactInSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountIn string, routeArr string, amountOutMin string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	// ExactOutSwapRoute executes a multi-hop swap for a requested net output.
	//
	// Parameters:
	//   - _: leading implementation discriminator; callers pass 0
	//   - rlm: propagated current realm context used for swap validation and transfers
	//   - inputToken: input token contract path
	//   - outputToken: output token contract path
	//   - amountOut: requested net output amount encoded as a decimal string
	//   - routeArr: comma-separated route paths, each with up to three pool hops
	//   - quoteArr: comma-separated route allocation percentages summing to 100
	//   - amountInMax: maximum input amount encoded as a decimal string
	//   - deadline: Unix timestamp after which the swap is rejected
	//   - referrer: optional referral address used for registration
	//
	// Returns:
	//   - amountIn: actual input amount consumed, encoded as a decimal string
	//   - amountOut: net output amount after router fee, encoded as a decimal string
	ExactOutSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, quoteArr string, amountInMax string, deadline int64, referrer string) (string, string)
	// ExactOutSingleSwapRoute executes an exact-output swap through one pool.
	//
	// Parameters:
	//   - _: leading implementation discriminator; callers pass 0
	//   - rlm: propagated current realm context used for swap validation and transfers
	//   - inputToken: input token contract path
	//   - outputToken: output token contract path
	//   - amountOut: requested net output amount encoded as a decimal string
	//   - routeArr: single-hop route path
	//   - amountInMax: maximum input amount encoded as a decimal string
	//   - sqrtPriceLimitX96: optional Q64.96 square-root price limit encoded as a decimal string
	//   - deadline: Unix timestamp after which the swap is rejected
	//   - referrer: optional referral address used for registration
	//
	// Returns:
	//   - amountIn: actual input amount consumed, encoded as a decimal string
	//   - amountOut: net output amount after router fee, encoded as a decimal string
	ExactOutSingleSwapRoute(_ int, rlm realm, inputToken string, outputToken string, amountOut string, routeArr string, amountInMax string, sqrtPriceLimitX96 string, deadline int64, referrer string) (string, string)

	// DrySwapRoute simulates a route without writing state or transferring tokens.
	//
	// Parameters:
	//   - inputToken: input token contract path
	//   - outputToken: output token contract path
	//   - specifiedAmount: exact input or output amount encoded as a decimal string
	//   - swapTypeStr: swap type string, either EXACT_IN or EXACT_OUT
	//   - strRouteArr: comma-separated encoded route paths
	//   - quoteArr: comma-separated route allocation percentages summing to 100
	//   - tokenAmountLimit: minimum output for EXACT_IN or maximum input for EXACT_OUT
	//
	// Returns:
	//   - amountIn: simulated input amount encoded as a decimal string
	//   - amountOut: simulated net output amount encoded as a decimal string
	//   - err: nil on success; validation, liquidity, or slippage error on failure
	DrySwapRoute(inputToken, outputToken, specifiedAmount, swapTypeStr, strRouteArr, quoteArr, tokenAmountLimit string) (string, string, error)
	// SwapCallback pays a pool's positive input delta during a swap.
	//
	// Parameters:
	//   - _: leading callback discriminator; callers pass 0
	//   - rlm: propagated current realm context; implementation verifies it is current
	//   - token0Path: token-0 contract path in canonical pool order
	//   - token1Path: token-1 contract path in canonical pool order
	//   - amount0Delta: signed token-0 delta; positive means the pool is owed tokens
	//   - amount1Delta: signed token-1 delta; positive means the pool is owed tokens
	//   - payer: address whose balance supplies the positive delta
	//
	// Returns:
	//   - err: nil after payment; error when realm, liquidity delta, or transfer validation fails
	SwapCallback(_ int, rlm realm, token0Path string, token1Path string, amount0Delta int64, amount1Delta int64, payer address) error
	// GetSwapFee reads the router fee rate.
	//
	// Returns:
	//   - fee: router fee in basis points
	GetSwapFee() uint64
	// SetSwapFee updates the router fee rate.
	//
	// Parameters:
	//   - _: leading call discriminator; callers pass 0
	//   - rlm: propagated current realm context used for authorized storage writes
	//   - fee: router fee in basis points
	SetSwapFee(_ int, rlm realm, fee uint64)
	// GetPendingProtocolFees reads pending protocol fees keyed by token path.
	//
	// Returns:
	//   - fees: token-path to pending-fee amount map
	GetPendingProtocolFees() map[string]int64
	Render(path string) string
}

type IRouterStore interface {
	// HasSwapFeeKey reports whether a stored router fee exists.
	//
	// Returns:
	//   - exists: true when the swap-fee key is present
	HasSwapFeeKey() bool
	// GetSwapFee reads the stored router fee.
	//
	// Returns:
	//   - fee: configured router fee in basis points
	GetSwapFee() uint64
	// SetSwapFee persists the router fee.
	//
	// Parameters:
	//   - _: leading call discriminator; callers pass 0
	//   - rlm: propagated current realm context; storage validates current-frame status
	//   - fee: router fee in basis points
	//
	// Returns:
	//   - err: nil on success; storage or realm-validation error otherwise
	SetSwapFee(_ int, rlm realm, fee uint64) error
	// HasPendingProtocolFeesKey reports whether a stored pending-fees map exists.
	//
	// Returns:
	//   - exists: true when the pending-fees key is present
	HasPendingProtocolFeesKey() bool
	// GetPendingProtocolFees reads all pending protocol fees.
	//
	// Returns:
	//   - fees: token-path to pending-fee amount map
	GetPendingProtocolFees() map[string]int64
	// SetPendingProtocolFees replaces all pending protocol fees.
	//
	// Parameters:
	//   - _: leading call discriminator; callers pass 0
	//   - rlm: propagated current realm context; storage validates current-frame status
	//   - fees: token-path to pending-fee amount map to persist
	//
	// Returns:
	//   - err: nil on success; storage or realm-validation error otherwise
	SetPendingProtocolFees(_ int, rlm realm, fees map[string]int64) error
	// GetPendingProtocolFee reads one token's pending fee.
	//
	// Parameters:
	//   - tokenPath: token contract path to query
	//
	// Returns:
	//   - amount: pending amount for tokenPath, or zero if absent
	GetPendingProtocolFee(tokenPath string) int64
	// SetPendingProtocolFee updates one token's pending fee.
	//
	// Parameters:
	//   - _: leading call discriminator; callers pass 0
	//   - rlm: propagated current realm context; storage validates current-frame and write authorization
	//   - tokenPath: token contract path to update
	//   - amount: pending amount to record
	//
	// Returns:
	//   - err: nil on success; realm or storage authorization error otherwise
	SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error
	// RemovePendingProtocolFee deletes one token's pending fee.
	//
	// Parameters:
	//   - _: leading call discriminator; callers pass 0
	//   - rlm: propagated current realm context; storage validates current-frame and write authorization
	//   - tokenPath: token contract path to remove
	//
	// Returns:
	//   - err: nil on success; realm or storage authorization error otherwise
	RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error
}
