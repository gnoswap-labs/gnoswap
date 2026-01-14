package position

// Mint creates a new liquidity position NFT.
//
// Parameters:
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
//   - mintTo: recipient address for the position NFT
//   - caller: caller address
//   - referrer: referrer address for reward tracking
//
// Returns:
//   - positionId: position ID
//   - liquidity: liquidity amount
//   - amount0: amount of token0 added
//   - amount1: amount of token1 added
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
	caller address,
	referrer string,
) (uint64, string, string, string) {
	return getImplementation().Mint(token0, token1, fee, tickLower, tickUpper, amount0Desired, amount1Desired, amount0Min, amount1Min, deadline, mintTo, caller, referrer)
}

// IncreaseLiquidity adds liquidity to an existing position.
//
// Parameters:
//   - positionId: ID of the position
//   - amount0DesiredStr: desired amount of token0
//   - amount1DesiredStr: desired amount of token1
//   - amount0MinStr: minimum amount of token0
//   - amount1MinStr: minimum amount of token1
//   - deadline: transaction deadline
//
// Returns:
//   - positionId: position ID
//   - liquidity: new liquidity amount
//   - amount0: amount of token0 added
//   - amount1: amount of token1 added
//   - poolPath: pool path
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
//   - positionId: ID of the position
//   - liquidityStr: amount of liquidity to remove
//   - amount0MinStr: minimum amount of token0
//   - amount1MinStr: minimum amount of token1
//   - deadline: transaction deadline
//   - unwrapResult: whether to unwrap WGNOT to GNOT
//
// Returns:
//   - positionId: position ID
//   - liquidity: removed liquidity amount
//   - amount0: amount of token0 removed
//   - amount1: amount of token1 removed
//   - poolPath: pool path
//   - amount0AfterFee: net amount of token0 after fees
//   - amount1AfterFee: net amount of token1 after fees
func DecreaseLiquidity(
	cur realm,
	positionId uint64,
	liquidityStr string,
	amount0MinStr string,
	amount1MinStr string,
	deadline int64,
	unwrapResult bool,
) (uint64, string, string, string, string, string, string) {
	return getImplementation().DecreaseLiquidity(positionId, liquidityStr, amount0MinStr, amount1MinStr, deadline, unwrapResult)
}

// Reposition changes the tick range of a position.
//
// Parameters:
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
//   - positionId: position ID
//   - liquidity: new liquidity amount
//   - tickLower: new lower tick
//   - tickUpper: new upper tick
//   - amount0: amount of token0 used
//   - amount1: amount of token1 used
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
//   - positionId: ID of the position
//   - unwrapResult: whether to unwrap WGNOT to GNOT
//
// Returns:
//   - positionId: position ID
//   - amount0: amount of token0 collected
//   - amount1: amount of token1 collected
//   - poolPath: pool path
//   - token0Path: token0 path
//   - token1Path: token1 path
func CollectFee(
	cur realm,
	positionId uint64,
	unwrapResult bool,
) (uint64, string, string, string, string, string) {
	return getImplementation().CollectFee(positionId, unwrapResult)
}

// SetPositionOperator sets an operator for a position.
//
// Parameters:
//   - positionId: ID of the position
//   - operator: address of the operator
func SetPositionOperator(
	cur realm,
	positionId uint64,
	operator address,
) {
	getImplementation().SetPositionOperator(positionId, operator)
}
