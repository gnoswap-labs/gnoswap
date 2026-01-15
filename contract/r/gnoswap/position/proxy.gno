package position

// Mint adds liquidity to a pool. Internally calls the `mint` function of the pool contract.
//
// Parameters:
//   - token0: The path of the token0 of the desired pool.
//   - token1: The path of the token1 of the desired pool.
//   - fee: The fee tier of the pool.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - amount0Desired: The maximum amount of token0 to add.
//   - amount1Desired: The maximum amount of token1 to add.
//   - amount0Min: The minimum amount of token0 to add.
//   - amount1Min: The minimum amount of token1 to add.
//   - deadline: The deadline at which the transaction will expire.
//   - mintTo: The address to receive the minted position.
//   - caller: The caller address from staker (for one-click staking).
//   - referrer: The referrer address for reward tracking.
//
// Returns:
//   - positionId: The ID of the position that was minted.
//   - liquidity: The amount of liquidity added to the pool.
//   - amount0: The amount of token0 added to the pool.
//   - amount1: The amount of token1 added to the pool.
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

// IncreaseLiquidity adds additional liquidity to an existing position. Calling this function on a closed position will reopen it.
//
// Parameters:
//   - positionId: The ID of the position NFT in which to increase liquidity.
//   - amount0DesiredStr: The maximum amount of token0 to increase.
//   - amount1DesiredStr: The maximum amount of token1 to increase.
//   - amount0MinStr: The minimum amount of token0 to increase.
//   - amount1MinStr: The minimum amount of token1 to increase.
//   - deadline: The deadline at which the transaction will expire.
//
// Returns:
//   - positionId: The ID of the position that the liquidity was increased.
//   - liquidity: The amount of liquidity added to the position.
//   - amount0: The amount of token0 added to the position.
//   - amount1: The amount of token1 added to the position.
//   - poolPath: The path of the pool from which the position exists.
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

// DecreaseLiquidity decreases liquidity of an existing position.
//
// Parameters:
//   - positionId: The ID of the position to decrease liquidity from.
//   - liquidityStr: The amount of liquidity to decrease.
//   - amount0MinStr: The minimum amount of token0 to decrease.
//   - amount1MinStr: The minimum amount of token1 to decrease.
//   - deadline: The deadline at which the transaction will expire.
//   - unwrapResult: Whether or not to receive tokens in native `ugnot` if either token0 or token1 is `wugnot`.
//
// Returns:
//   - positionId: The ID of the position that the liquidity was decreased.
//   - liquidity: The amount of liquidity decreased from the position.
//   - fee0: The amount of token0 fees collected.
//   - fee1: The amount of token1 fees collected.
//   - amount0: The amount of token0 decreased from the position.
//   - amount1: The amount of token1 decreased from the position.
//   - poolPath: The path of the pool in which the position exists.
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

// Reposition modifies the price range of a closed position while maintaining the `positionId`.
//
// Parameters:
//   - positionId: The ID of the position.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - amount0DesiredStr: The maximum amount of token0 to add.
//   - amount1DesiredStr: The maximum amount of token1 to add.
//   - amount0MinStr: The minimum amount of token0 to add.
//   - amount1MinStr: The minimum amount of token1 to add.
//   - deadline: The deadline at which the transaction will expire.
//
// Returns:
//   - positionId: The ID of the position.
//   - liquidity: The new liquidity amount.
//   - tickLower: The modified lower tick.
//   - tickUpper: The modified upper tick.
//   - amount0: The amount of token0 added to the position.
//   - amount1: The amount of token1 added to the position.
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

// CollectFee collects fee accrued to a position.
//
// Parameters:
//   - positionId: The ID of the position.
//   - unwrapResult: (if position has wugnot fee) whether to receive fee in ugnot or not.
//
// Returns:
//   - positionId: The ID of the position.
//   - afterFee0: The amount of token0 that was collected.
//   - afterFee1: The amount of token1 that was collected.
//   - poolPath: The path of the pool from which the position exists.
//   - origFee0: The fee amount of token0 before taking protocol fee.
//   - origFee1: The fee amount of token1 before taking protocol fee.
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
