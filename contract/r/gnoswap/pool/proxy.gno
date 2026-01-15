package pool

// CreatePool creates a liquidity pool.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of the token0 of the pool to create.
//   - token1Path: The path of the token1 of the pool to create.
//   - fee: The fee tier of the pool. (100 = 0.01%, 500 = 0.05%, 3000 = 0.3%, 10000 = 1%)
//   - sqrtPriceX96: The starting price of the pool.
func CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	getImplementation().CreatePool(
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
	)
}

// SetPoolCreationFee modifies the Pool Creation Fee.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - fee: The amount of tokens that will be set as the new Pool Creation Fee. (the amount should be in uTokens)
func SetPoolCreationFee(cur realm, fee int64) {
	getImplementation().SetPoolCreationFee(fee)
}

// IncreaseObservationCardinalityNext increases the observation cardinality for a pool.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - cardinalityNext: new observation cardinality limit
func IncreaseObservationCardinalityNext(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	getImplementation().IncreaseObservationCardinalityNext(
		token0Path,
		token1Path,
		fee,
		cardinalityNext,
	)
}

// Mint adds liquidity to a pool. This function can only be called by the Position contract, not by users.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of token0 of the desired pool.
//   - token1Path: The path of token1 of the desired pool.
//   - fee: The fee tier of the desired pool.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - liquidityAmount: The amount of liquidity to add. This value is calculated by the Position contract based on the amounts of token0 & token1, and the price.
//   - positionCaller: The caller address from the position contract.
//
// Returns:
//   - amount0: The amount of token0 that added to the liquidity pool to mint the position.
//   - amount1: The amount of token1 that added to the liquidity pool to mint the position.
func Mint(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	return getImplementation().Mint(
		token0Path,
		token1Path,
		fee,
		tickLower,
		tickUpper,
		liquidityAmount,
		positionCaller,
	)
}

// Burn removes liquidity from a pool. This function can only be called by the Position contract, not by users.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of token0 of the desired pool.
//   - token1Path: The path of token1 of the desired pool.
//   - fee: The fee tier of the desired pool.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - liquidityAmount: The amount of liquidity to remove.
//   - positionCaller: The caller address from the position contract.
//
// Returns:
//   - amount0: The amount of token0 that was removed from the pool by burning the position.
//   - amount1: The amount of token1 that was removed from the pool by burning the position.
func Burn(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	tickLower int32,
	tickUpper int32,
	liquidityAmount string,
	positionCaller address,
) (string, string) {
	return getImplementation().Burn(
		token0Path,
		token1Path,
		fee,
		tickLower,
		tickUpper,
		liquidityAmount,
		positionCaller,
	)
}

// Collect collects swap fees in token0 and token1 accrued to a position. This function can only be called by the Position contract, not by users.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of token0 of the desired pool.
//   - token1Path: The path of token1 of the desired pool.
//   - fee: The fee tier of the desired pool.
//   - recipient: The address that will receive the collected fees.
//   - tickLower: The lower tick of the price range of the position.
//   - tickUpper: The upper tick of the price range of the position.
//   - amount0Requested: The maximum amount of token0 to collect from the pool.
//   - amount1Requested: The maximum amount of token1 to collect from the pool.
//
// Returns:
//   - amount0: The amount of token0 that was collected from the position.
//   - amount1: The amount of token1 that was collected from the position.
func Collect(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	return getImplementation().Collect(
		token0Path,
		token1Path,
		fee,
		recipient,
		tickLower,
		tickUpper,
		amount0Requested,
		amount1Requested,
	)
}

// SetWithdrawalFee modifies the Withdrawal Fee.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - fee: The rate that will be set as the new Withdrawal Fee. (the value should be in bps)
func SetWithdrawalFee(cur realm, fee uint64) {
	getImplementation().SetWithdrawalFee(fee)
}

// HandleWithdrawalFee handles withdrawal protocol fee for a position.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - positionId: The ID of position which being handled to withdrawal protocol fee.
//   - token0Path: The path of token0 of the position.
//   - amount0: The amount of token0 to calculate withdrawal fee.
//   - token1Path: The path of token1 of the position.
//   - amount1: The amount of token1 to calculate withdrawal fee.
//   - poolPath: The path of pool of the position was minted.
//   - positionCaller: The caller address from position contract.
//
// Returns:
//   - amount0: The remaining amount of token0 after the protocol fee has been withdrawn.
//   - amount1: The remaining amount of token1 after the protocol fee has been withdrawn.
func HandleWithdrawalFee(
	cur realm,
	positionId uint64,
	token0Path string,
	amount0 string,
	token1Path string,
	amount1 string,
	poolPath string,
	positionCaller address,
) (string, string) {
	return getImplementation().HandleWithdrawalFee(
		positionId,
		token0Path,
		amount0,
		token1Path,
		amount1,
		poolPath,
		positionCaller,
	)
}

// Swap swaps tokens from a pool from token0 to token1, or vice versa. This function can only be called by the Router contract, not by users.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of token0 of the desired pool.
//   - token1Path: The path of token1 of the desired pool.
//   - fee: The fee tier of the desired pool.
//   - recipient: The address that will receive the output of the swap.
//   - zeroForOne: The direction of the swap. Set to true for swapping token0 to token1, and false for vice versa.
//   - amountSpecified: The amount of tokens to swap. Set to a positive value for an exact input, and a negative value for an exact output.
//   - sqrtPriceLimitX96: The maximum price to accept for the swap.
//   - payer: The address from which to send the output tokens. (Relates to the Router contract)
//   - swapCallback: The callback function for token transfer.
//
// Returns:
//   - amount0: The change in the amount of token0 as the result of the swap.
//   - amount1: The change in the amount of token1 as the result of the swap.
func Swap(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	payer address,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64, callbackMarker *CallbackMarker) error,
) (string, string) {
	return getImplementation().Swap(
		token0Path,
		token1Path,
		fee,
		recipient,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
		payer,
		swapCallback,
	)
}

// DrySwap simulates a swap without executing it, returning the expected output.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - zeroForOne: true if swapping token0 for token1
//   - amountSpecified: amount to swap
//   - sqrtPriceLimitX96: price limit for the swap
//
// Returns:
//   - amount0Delta: amount of token0 delta
//   - amount1Delta: amount of token1 delta
//   - ok: swap success status
func DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string, bool) {
	return getImplementation().DrySwap(token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

// SetSwapEndHook sets the hook to be called at the end of a swap.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - hook: callback invoked after a swap completes for a pool path
func SetSwapEndHook(cur realm, hook func(cur realm, poolPath string) error) {
	getImplementation().SetSwapEndHook(hook)
}

// SetSwapStartHook sets the hook to be called at the start of a swap.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - hook: callback invoked before a swap starts for a pool path
func SetSwapStartHook(cur realm, hook func(cur realm, poolPath string, timestamp int64)) {
	getImplementation().SetSwapStartHook(hook)
}

// SetTickCrossHook sets the hook to be called when a tick is crossed during a swap.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - hook: callback invoked when a swap crosses a tick within a pool
func SetTickCrossHook(cur realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	getImplementation().SetTickCrossHook(hook)
}

// CollectProtocol collects the Protocol Fee claimable from a pool.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - token0Path: The path of token0 of the desired pool.
//   - token1Path: The path of token1 of the desired pool.
//   - fee: The fee tier of the desired pool.
//   - recipient: The address that will receive the collected Protocol Fee.
//   - amount0Requested: The maximum amount of token0 to collect from the pool.
//   - amount1Requested: The maximum amount of token1 to collect from the pool.
//
// Returns:
//   - amount0: The amount of token0 that was collected from the pool.
//   - amount1: The amount of token1 that was collected from the pool.
func CollectProtocol(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	amount0Requested string,
	amount1Requested string,
) (string, string) {
	return getImplementation().CollectProtocol(
		token0Path,
		token1Path,
		fee,
		recipient,
		amount0Requested,
		amount1Requested,
	)
}

// SetFeeProtocol sets the Protocol Fee that is applied to all swaps.
//
// Parameters:
//   - cur: Pass `cross` as argument.
//   - feeProtocol0: The Protocol Fee for token0 of the desired pool.
//   - feeProtocol1: The Protocol Fee for token1 of the desired pool.
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	getImplementation().SetFeeProtocol(feeProtocol0, feeProtocol1)
}
