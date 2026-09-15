package pool

// CreatePool creates a new liquidity pool for a token pair.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Token contract path supplied for token0; the pool orders the
//     pair canonically rather than preserving the supplied order.
//   - token1Path: Token contract path supplied for token1; must form a distinct
//     registered pair with token0Path.
//   - fee: Fee tier for the pool; determines its tick spacing and swap fee.
//   - sqrtPriceX96: Initial square-root price in Q64.96 fixed-point form; it is
//     inverted when the supplied token order is reversed and must be in bounds.
//
// Halt check: reverts while the Pool halt scope is active.
func CreatePool(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	sqrtPriceX96 string,
) {
	getImplementation().CreatePool(
		0,
		cur,
		token0Path,
		token1Path,
		fee,
		sqrtPriceX96,
	)
}

// SetPoolCreationFee sets the pool creation fee.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - fee: New pool creation fee, in the configured native-token base units.
//
// Halt check: reverts while the Pool halt scope is active.
func SetPoolCreationFee(cur realm, fee int64) {
	getImplementation().SetPoolCreationFee(0, cur, fee)
}

// IncreaseObservationCardinalityNext increases the observation cardinality for a pool.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - cardinalityNext: Requested maximum number of oracle observations retained
//     for the pool.
//
// Halt check: reverts while the Pool halt scope is active.
func IncreaseObservationCardinalityNext(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	cardinalityNext uint16,
) {
	getImplementation().IncreaseObservationCardinalityNext(
		0,
		cur,
		token0Path,
		token1Path,
		fee,
		cardinalityNext,
	)
}

// Mint adds liquidity to a position.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - tickLower: Lower inclusive tick boundary of the position range.
//   - tickUpper: Upper exclusive tick boundary of the position range.
//   - liquidityAmount: Decimal liquidity amount to add to the position.
//   - positionCaller: Position-contract address whose position receives the
//     liquidity.
//
// Returns:
//   - amount0: Token0 amount required for the liquidity addition, as a decimal
//     string.
//   - amount1: Token1 amount required for the liquidity addition, as a decimal
//     string.
//
// Halt check: reverts while the Pool halt scope is active.
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
		0,
		cur,
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
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - tickLower: Lower inclusive tick boundary of the position range.
//   - tickUpper: Upper exclusive tick boundary of the position range.
//   - liquidityAmount: Decimal liquidity amount to remove from the position.
//   - positionCaller: Position-contract address whose position is decreased.
//
// Returns:
//   - amount0: Token0 principal credited to the position, as a decimal string;
//     the pool operation leaves it owed until a subsequent collection.
//   - amount1: Token1 principal credited to the position, as a decimal string;
//     the pool operation leaves it owed until a subsequent collection.
//
// Halt check: reverts while the Withdraw halt scope is active.
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
		0,
		cur,
		token0Path,
		token1Path,
		fee,
		tickLower,
		tickUpper,
		liquidityAmount,
		positionCaller,
	)
}

// CollectSwapFee pays accrued swap fees for a position out to recipient,
// net of the withdrawal fee.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - recipient: Non-zero address receiving the collected token amounts after
//     withdrawal-fee deduction.
//   - tickLower: Lower inclusive tick boundary of the position range.
//   - tickUpper: Upper exclusive tick boundary of the position range.
//   - amount0Requested: Decimal token0 amount requested; the configured maximum
//     value requests all token0 fees owed.
//   - amount1Requested: Decimal token1 amount requested; the configured maximum
//     value requests all token1 fees owed.
//
// Returns:
//   - amount0: Collected token0 amount before withdrawal-fee deduction, as a
//     decimal string.
//   - amount1: Collected token1 amount before withdrawal-fee deduction, as a
//     decimal string.
//   - fee0: Withdrawal fee withheld from token0, as a decimal string.
//   - fee1: Withdrawal fee withheld from token1, as a decimal string.
//
// Halt check: reverts while the Withdraw halt scope is active.
func CollectSwapFee(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	tickLower int32,
	tickUpper int32,
	amount0Requested string,
	amount1Requested string,
) (amount0, amount1, fee0, fee1 string) {
	return getImplementation().CollectSwapFee(
		0,
		cur,
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

// Collect pays tokens owed to a position out to recipient in full. No
// withdrawal fee is charged on this path; see CollectSwapFee for the
// fee-bearing path.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - recipient: Non-zero address receiving the owed token amounts.
//   - tickLower: Lower inclusive tick boundary of the position range.
//   - tickUpper: Upper exclusive tick boundary of the position range.
//   - amount0Requested: Decimal token0 amount requested from the position's
//     accrued principal.
//   - amount1Requested: Decimal token1 amount requested from the position's
//     accrued principal.
//
// Returns:
//   - amount0: Token0 principal transferred to recipient, as a decimal string.
//   - amount1: Token1 principal transferred to recipient, as a decimal string.
//
// Halt check: reverts while the Withdraw halt scope is active.
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
		0,
		cur,
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
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - fee: Withdrawal fee in basis points; zero disables the fee.
//
// Halt check: reverts while the Pool halt scope is active.
func SetWithdrawalFee(cur realm, fee uint64) {
	getImplementation().SetWithdrawalFee(0, cur, fee)
}

// Swap executes a token swap in the pool.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - recipient: Address receiving output tokens.
//   - zeroForOne: True to sell token0 for token1; false to sell token1 for
//     token0.
//   - amountSpecified: Decimal signed amount; positive requests exact input and
//     negative requests exact output.
//   - sqrtPriceLimitX96: Price boundary in Q64.96 fixed-point form at which the
//     swap must stop.
//   - swapCallback: Callback invoked with the current realm, signed token
//     deltas, and a callback marker; it must settle the input token and return a
//     non-nil error to abort settlement.
//
// Returns:
//   - amount0: Signed token0 delta for the swap, as a decimal string.
//   - amount1: Signed token1 delta for the swap, as a decimal string.
//
// Halt check: reverts while the Pool halt scope is active.
func Swap(
	cur realm,
	token0Path string,
	token1Path string,
	fee uint32,
	recipient address,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
	swapCallback func(cur realm, amount0Delta, amount1Delta int64, callbackMarker *CallbackMarker) error,
) (string, string) {
	return getImplementation().Swap(
		0,
		cur,
		token0Path,
		token1Path,
		fee,
		recipient,
		zeroForOne,
		amountSpecified,
		sqrtPriceLimitX96,
		swapCallback,
	)
}

// DrySwap simulates a swap without executing it, returning the expected output.
//
// This is a read-only operation that does not modify pool state.
// Used by router for multi-hop swap simulations and by clients for price quotes.
//
// Parameters:
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - zeroForOne: True to sell token0 for token1; false to sell token1 for
//     token0.
//   - amountSpecified: Decimal signed amount; positive requests exact input and
//     negative requests exact output.
//   - sqrtPriceLimitX96: Price boundary in Q64.96 fixed-point form at which the
//     simulation must stop.
//
// Returns:
//   - amount0: Simulated signed token0 delta, as a decimal string; "0" on an
//     unsuccessful simulation.
//   - amount1: Simulated signed token1 delta, as a decimal string; "0" on an
//     unsuccessful simulation.
//   - error: Nil when the simulation succeeds; non-nil when validation,
//     computation, or pool-balance checks fail.
func DrySwap(
	token0Path string,
	token1Path string,
	fee uint32,
	zeroForOne bool,
	amountSpecified string,
	sqrtPriceLimitX96 string,
) (string, string, error) {
	return getImplementation().DrySwap(token0Path, token1Path, fee, zeroForOne, amountSpecified, sqrtPriceLimitX96)
}

// SetSwapEndHook sets the hook to be called at the end of a swap.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - hook: Callback invoked with the current realm and pool path after swap
//     settlement; its error is propagated to abort the swap.
func SetSwapEndHook(cur realm, hook func(cur realm, poolPath string) error) {
	getImplementation().SetSwapEndHook(0, cur, hook)
}

// SetSwapStartHook sets the hook to be called at the start of a swap.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - hook: Callback invoked with the current realm, pool path, and swap
//     timestamp before swap computation.
func SetSwapStartHook(cur realm, hook func(cur realm, poolPath string, timestamp int64)) {
	getImplementation().SetSwapStartHook(0, cur, hook)
}

// SetTickCrossHook sets the hook to be called when a tick is crossed during a swap.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - hook: Callback invoked with the current realm, pool path, crossed tick
//     index, swap direction, and block timestamp.
func SetTickCrossHook(cur realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) {
	getImplementation().SetTickCrossHook(0, cur, hook)
}

// CollectProtocol collects protocol fees from a pool.
//
// Parameters:
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - token0Path: Path of the first token in the pool pair.
//   - token1Path: Path of the second token in the pool pair.
//   - fee: Fee tier identifying the pool.
//   - recipient: Address receiving the collected protocol fees.
//   - amount0Requested: Decimal token0 protocol-fee amount requested; collection
//     is capped at the available amount.
//   - amount1Requested: Decimal token1 protocol-fee amount requested; collection
//     is capped at the available amount.
//
// Returns:
//   - amount0: Token0 protocol fee transferred to recipient, as a decimal string.
//   - amount1: Token1 protocol fee transferred to recipient, as a decimal string.
//
// Halt check: reverts while the Withdraw halt scope is active.
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
		0,
		cur,
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
//   - cur: Current realm context; callers use cross(cur) when crossing into this
//     realm.
//   - feeProtocol0: Token0 protocol-fee denominator; zero disables it, while
//     non-zero supported values route the corresponding fraction to protocol.
//   - feeProtocol1: Token1 protocol-fee denominator; zero disables it, while
//     non-zero supported values route the corresponding fraction to protocol.
//
// Halt check: reverts while the Pool halt scope is active.
func SetFeeProtocol(cur realm, feeProtocol0, feeProtocol1 uint8) {
	getImplementation().SetFeeProtocol(0, cur, feeProtocol0, feeProtocol1)
}
