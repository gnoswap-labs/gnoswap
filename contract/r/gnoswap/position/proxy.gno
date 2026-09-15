package position

// Mint creates a new liquidity position NFT.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - token0: path of the first token in the pool
//   - token1: path of the second token in the pool
//   - fee: pool fee tier used to identify the pool
//   - tickLower: lower tick boundary of the position's price range
//   - tickUpper: upper tick boundary of the position's price range
//   - amount0Desired: desired amount of token0 to provide
//   - amount1Desired: desired amount of token1 to provide
//   - amount0Min: minimum acceptable amount of token0 after price/slippage calculation
//   - amount1Min: minimum acceptable amount of token1 after price/slippage calculation
//   - deadline: transaction expiration timestamp
//   - mintTo: recipient address of the position NFT
//   - referrer: referrer identifier used for reward tracking
//
// Returns:
//   - positionId: newly minted position NFT token ID
//   - liquidity: liquidity minted into the position, represented as a decimal string
//   - amount0: actual amount of token0 added to the position, represented as a decimal string
//   - amount1: actual amount of token1 added to the position, represented as a decimal string
func Mint(
	cur realm,
	token0 string,
	token1 string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	amount0Desired string,
	amount1Desired string,
	amount0Min string,
	amount1Min string,
	deadline int64,
	mintTo address,
	referrer string,
) (uint64, string, string, string) {
	return getImplementation().Mint(0, cur, token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, referrer)
}

// IncreaseLiquidity adds liquidity to an existing position.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - positionId: position NFT token ID to increase
//   - amount0DesiredStr: desired token0 amount, represented as a decimal string
//   - amount1DesiredStr: desired token1 amount, represented as a decimal string
//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
//   - deadline: transaction expiration timestamp
//
// Returns:
//   - positionId: position NFT token ID that received the liquidity
//   - liquidity: liquidity amount added to the position (the delta), represented as a decimal string
//   - amount0: actual token0 amount added, represented as a decimal string
//   - amount1: actual token1 amount added, represented as a decimal string
//   - poolKey: canonical pool key for the position
func IncreaseLiquidity(
	cur realm,
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	return getImplementation().IncreaseLiquidity(0, cur, positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

// DecreaseLiquidity removes liquidity from a position.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - positionId: position NFT token ID to decrease
//   - liquidityStr: liquidity amount to remove, represented as a decimal string
//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
//   - deadline: transaction expiration timestamp
//
// The accrued swap fees are collected first, so the returned fee amounts are
// net of the withdrawal fee while the returned principal is not subject to it.
//
// Returns:
//   - positionId: position NFT token ID that had liquidity removed
//   - liquidity: removed liquidity amount, represented as a decimal string
//   - fee0: token0 fees collected, net of the withdrawal fee
//   - fee1: token1 fees collected, net of the withdrawal fee
//   - amount0: principal amount of token0 returned to the caller
//   - amount1: principal amount of token1 returned to the caller
//   - poolKey: canonical pool key for the position
func DecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string, string, string) {
	return getImplementation().DecreaseLiquidity(0, cur, positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline)
}

// Reposition changes the tick range of a position.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - positionId: position NFT token ID to reposition
//   - tickLower: new lower tick boundary of the position's price range
//   - tickUpper: new upper tick boundary of the position's price range
//   - amount0DesiredStr: desired token0 amount for the new range, represented as a decimal string
//   - amount1DesiredStr: desired token1 amount for the new range, represented as a decimal string
//   - amount0MinStr: minimum acceptable token0 amount for slippage protection
//   - amount1MinStr: minimum acceptable token1 amount for slippage protection
//   - deadline: transaction expiration timestamp
//
// Returns:
//   - positionId: position NFT token ID that was repositioned
//   - liquidity: new liquidity amount, represented as a decimal string
//   - tickLower: new lower tick boundary
//   - tickUpper: new upper tick boundary
//   - amount0: actual token0 amount added to the new range, represented as a decimal string
//   - amount1: actual token1 amount added to the new range, represented as a decimal string
func Reposition(
	cur realm,
	positionId uint64,
	tickLower int32,
	tickUpper int32,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, int32, int32, string, string) {
	return getImplementation().Reposition(0, cur, positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

// CollectFee collects accumulated fees from a position.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - positionId: position NFT token ID whose fees are collected
//
// Returns:
//   - positionId: position NFT token ID whose fees were collected
//   - tokensCollected0: token0 fees paid out to the caller, net of the withdrawal fee
//   - tokensCollected1: token1 fees paid out to the caller, net of the withdrawal fee
//   - poolKey: canonical pool key for the position
//   - totalAmount0: token0 fees collected before the withdrawal fee
//   - totalAmount1: token1 fees collected before the withdrawal fee
func CollectFee(
	cur realm,
	positionId uint64,
) (uint64, string, string, string, string, string) {
	return getImplementation().CollectFee(0, cur, positionId)
}

// SetPositionOperator sets an operator for a position.
//
// Parameters:
//   - cur: current realm context; callers use cross(cur) when crossing into this realm
//   - positionId: position NFT token ID whose operator is changed
//   - operator: operator address to approve; the zero address removes the operator
func SetPositionOperator(
	cur realm,
	positionId uint64,
	operator address,
) {
	getImplementation().SetPositionOperator(0, cur, positionId, operator)
}
