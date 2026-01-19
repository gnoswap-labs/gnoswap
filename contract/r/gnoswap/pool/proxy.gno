package pool

// CreatePool creates a new liquidity pool for a token pair.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - sqrtPriceX96: initial sqrt price (Q64.96 format)
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

// SetPoolCreationFee sets the pool creation fee.
func SetPoolCreationFee(cur realm, fee int64) {
	getImplementation().SetPoolCreationFee(fee)
}

// IncreaseObservationCardinalityNext increases the observation cardinality for a pool.
//
// Parameters:
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

// Mint adds liquidity to a position.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
//   - liquidityAmount: amount of liquidity to add
//   - positionCaller: caller address for the position
//
// Returns:
//   - string: amount of token0 added
//   - string: amount of token1 added
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

// Burn removes liquidity from a position.
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

// Collect transfers owed tokens from a position to recipient.
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

// SetWithdrawalFee sets the withdrawal fee rate.
//
// Parameters:
//   - fee: withdrawal fee in basis points
func SetWithdrawalFee(cur realm, fee uint64) {
	getImplementation().SetWithdrawalFee(fee)
}

// HandleWithdrawalFee processes withdrawal fees for a position.
//
// Parameters:
//   - positionId: ID of the position
//   - token0Path: path of the first token
//   - amount0: amount of token0 to withdraw
//   - token1Path: path of the second token
//   - amount1: amount of token1 to withdraw
//   - poolPath: pool identifier
//   - positionCaller: caller address for the position
//
// Returns:
//   - string: net amount of token0 after fees
//   - string: net amount of token1 after fees
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

// Swap executes a token swap in the pool.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - recipient: recipient address for output tokens
//   - zeroForOne: true if swapping token0 for token1
//   - amountSpecified: amount to swap (positive for exact input, negative for exact output)
//   - sqrtPriceLimitX96: price limit for the swap
//   - payer: address that will pay for the swap
//   - swapCallback: callback function for token transfer, callbackMarker is used to identify the callback
//
// Returns:
//   - string: amount of token0 delta
//   - string: amount of token1 delta
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
// This is a read-only operation that does not modify pool state.
// Used by router for multi-hop swap simulations and by clients for price quotes.
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
//   - string: amount of token0 delta
//   - string: amount of token1 delta
//   - bool: swap success status
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
func SetSwapEndHook(cur realm, hook func(cur realm, poolPath string) error) {
	getImplementation().SetSwapEndHook(hook)
}

// SetSwapStartHook sets the hook to be called at the start of a swap.
func SetSwapStartHook(cur realm, hook func(cur realm, poolPath string, timestamp int64)) {
	getImplementation().SetSwapStartHook(hook)
}

// SetTickCrossHook sets the hook to be called when a tick is crossed during a swap.
func SetTickCrossHook(cur realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	getImplementation().SetTickCrossHook(hook)
}

// CollectProtocol collects protocol fees from a pool.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//   - recipient: recipient address for fees
//   - amount0Requested: amount of token0 to collect
//   - amount1Requested: amount of token1 to collect
//
// Returns:
//   - string: amount of token0 collected
//   - string: amount of token1 collected
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

// SetFeeProtocol sets the protocol fee rates for a pool.
//
// Parameters:
//   - feeProtocol0: protocol fee rate for token0
//   - feeProtocol1: protocol fee rate for token1
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	getImplementation().SetFeeProtocol(feeProtocol0, feeProtocol1)
}
