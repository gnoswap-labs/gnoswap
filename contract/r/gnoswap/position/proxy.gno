package position

// Mint creates a new liquidity position NFT.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0: path of the first token
//   - token1: path of the second token
//   - fee: pool fee tier
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
//   - amount0Desired: desired amount of token0
//   - amount1Desired: desired amount of token1
//   - amount0Min: minimum amount of token0
//   - amount1Min: minimum amount of token1
//   - deadline: transaction deadline
//   - mintTo: recipient of the position NFT
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - uint64: position ID
//   - string: liquidity amount
//   - string: amount of token0 added
//   - string: amount of token1 added
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
	return getImplementation().Mint(token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, referrer)
}

// IncreaseLiquidity adds liquidity to an existing position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: ID of the position
//   - amount0DesiredStr: desired amount of token0
//   - amount1DesiredStr: desired amount of token1
//   - amount0MinStr: minimum amount of token0
//   - amount1MinStr: minimum amount of token1
//   - deadline: transaction deadline
//
// Returns:
//   - uint64: position ID
//   - string: liquidity amount added
//   - string: amount of token0 added
//   - string: amount of token1 added
//   - string: pool path
func IncreaseLiquidity(
	cur realm,
	positionId uint64,
	amount0DesiredStr string,
	amount1DesiredStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string) {
	return getImplementation().IncreaseLiquidity(positionId, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

// DecreaseLiquidity removes liquidity from a position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: ID of the position
//   - liquidityStr: amount of liquidity to remove
//   - amount0MinStr: minimum amount of token0
//   - amount1MinStr: minimum amount of token1
//   - deadline: transaction deadline
//
// Returns:
//   - uint64: position ID
//   - string: removed liquidity amount
//   - string: token0 fee amount collected during the decrease
//   - string: token1 fee amount collected during the decrease
//   - string: token0 principal amount collected
//   - string: token1 principal amount collected
//   - string: pool path
func DecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
) (uint64, string, string, string, string, string, string) {
	return getImplementation().DecreaseLiquidity(positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline)
}

// Reposition changes the tick range of a position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: ID of the position
//   - tickLower: new lower tick boundary
//   - tickUpper: new upper tick boundary
//   - amount0DesiredStr: desired amount of token0
//   - amount1DesiredStr: desired amount of token1
//   - amount0MinStr: minimum amount of token0
//   - amount1MinStr: minimum amount of token1
//   - deadline: transaction deadline
//
// Returns:
//   - uint64: position ID
//   - string: new liquidity amount
//   - int32: new lower tick
//   - int32: new upper tick
//   - string: amount of token0 used
//   - string: amount of token1 used
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
	return getImplementation().Reposition(positionId, tickLower, tickUpper, amount0DesiredStr, amount1DesiredStr, amount0MinStr, amount1MinStr, deadline)
}

// CollectFee collects accumulated fees from a position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: ID of the position
//
// Returns:
//   - uint64: position ID
//   - string: amount of token0 collected
//   - string: amount of token1 collected
//   - string: pool path
//   - string: raw token0 amount before withdrawal fee
//   - string: raw token1 amount before withdrawal fee
func CollectFee(
	cur realm,
	positionId uint64,
) (uint64, string, string, string, string, string) {
	return getImplementation().CollectFee(positionId)
}

// SetPositionOperator sets an operator for a position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: ID of the position
//   - operator: address of the operator
func SetPositionOperator(
	cur realm,
	positionId uint64,
	operator address,
) {
	getImplementation().SetPositionOperator(positionId, operator)
}
