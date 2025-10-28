package pool

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

func IncreaseObservationCardinalityLimit(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	getImplementation().IncreaseObservationCardinalityLimit(
		token0Path,
		token1Path,
		fee,
		cardinalityNext,
	)
}

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

func SetWithdrawalFee(cur realm, fee uint64) {
	getImplementation().SetWithdrawalFee(fee)
}

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
	swapCallback func(cur realm, amount0Delta, amount1Delta string) error,
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

func SetSwapEndHook(cur realm, hook func(poolPath string) error) {
	getImplementation().SetSwapEndHook(hook)
}

func SetSwapStartHook(cur realm, hook func(poolPath string, timestamp int64)) {
	getImplementation().SetSwapStartHook(hook)
}

func SetTickCrossHook(cur realm, hook func(poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	getImplementation().SetTickCrossHook(hook)
}

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

func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	getImplementation().SetFeeProtocol(feeProtocol0, feeProtocol1)
}
