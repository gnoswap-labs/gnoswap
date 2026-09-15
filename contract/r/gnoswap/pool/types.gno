package pool

import (
	rotree "gno.land/p/nt/bptree/rotree/v0"
	bptree "gno.land/p/nt/bptree/v0"

	u256 "gno.land/p/gnoswap/uint256/v1"
)

// IPool interface defines all public methods that must be implemented by pool contract versions.
// This interface serves as the contract between the proxy layer and implementation versions,
// ensuring that all versions (v1, v2, v3, etc.) maintain the same public API.
//
// This design enables seamless upgrades while maintaining backwards compatibility.
// When upgrading from v1 to v2, the proxy simply switches the implementation pointer
// without changing the public interface, ensuring zero downtime and no breaking changes.
type IPool interface {
	IPoolManager
	IPoolPosition
	IPoolSwap
	IPoolOracle
	IPoolGetter
	Render(path string) string
}

// IPoolManager interface defines pool management operations.
// These methods handle pool creation and fee configuration.
type IPoolManager interface {
	// CreatePool creates a new concentrated liquidity pool.
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the new pool and its tick spacing.
	//   - sqrtPriceX96: Initial token1/token0 square-root price encoded as a Q96 decimal string.
	CreatePool(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		sqrtPriceX96 string,
	)

	// SetPoolCreationFee sets the pool creation fee.
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - fee: Pool-creation fee amount to store for future pool creation operations.
	SetPoolCreationFee(_ int, rlm realm, fee int64)
}

// IPoolPosition interface defines position management operations.
// These methods handle liquidity provision and position management.
type IPoolPosition interface {
	// Mint adds liquidity to a pool position.
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - tickLower: Lower inclusive tick of the position's price range; must align to pool spacing.
	//   - tickUpper: Upper exclusive tick of the position's price range; must align to pool spacing.
	//   - liquidityAmount: Positive decimal liquidity amount to add.
	//   - positionCaller: Position-contract address that provides tokens for the mint.
	//
	// Returns:
	//   - amount0: Token0 amount consumed, encoded as a decimal string.
	//   - amount1: Token1 amount consumed, encoded as a decimal string.
	Mint(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// Burn removes liquidity and credits principal to the pool position entry;
	// Collect later transfers that principal without a withdrawal fee.
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - tickLower: Lower tick of the position's price range; must align to pool spacing.
	//   - tickUpper: Upper tick of the position's price range; must align to pool spacing.
	//   - liquidityAmount: Non-negative decimal liquidity amount to remove.
	//   - positionCaller: Position-contract address associated with the pool position.
	//
	// Returns:
	//   - amount0: Token0 principal credited to the position, encoded as a decimal string.
	//   - amount1: Token1 principal credited to the position, encoded as a decimal string.
	Burn(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		tickLower int32,
		tickUpper int32,
		liquidityAmount string,
		positionCaller address,
	) (string, string)

	// CollectSwapFee pays accrued swap fees and applies the withdrawal fee;
	// Collect pays principal owed by Burn without that fee.
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - recipient: Nonzero address receiving collected tokens after any withdrawal fee.
	//   - tickLower: Lower tick of the position's price range.
	//   - tickUpper: Upper tick of the position's price range.
	//   - amount0Requested: Non-negative decimal amount of token0 requested; the int64 maximum requests all owed token0.
	//   - amount1Requested: Non-negative decimal amount of token1 requested; the int64 maximum requests all owed token1.
	//
	// Returns:
	//   - amount0: Token0 amount collected before withdrawal-fee deduction, as a decimal string.
	//   - amount1: Token1 amount collected before withdrawal-fee deduction, as a decimal string.
	//   - fee0: Withdrawal fee withheld from token0, as a decimal string.
	//   - fee1: Withdrawal fee withheld from token1, as a decimal string.
	CollectSwapFee(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		tickLower int32,
		tickUpper int32,
		amount0Requested string,
		amount1Requested string,
	) (amount0, amount1, fee0, fee1 string)

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - recipient: Nonzero address receiving owed principal.
	//   - tickLower: Lower tick of the position's price range.
	//   - tickUpper: Upper tick of the position's price range.
	//   - amount0Requested: Non-negative decimal amount of token0 principal requested.
	//   - amount1Requested: Non-negative decimal amount of token1 principal requested.
	//
	// Returns:
	//   - amount0: Token0 principal transferred to recipient, as a decimal string.
	//   - amount1: Token1 principal transferred to recipient, as a decimal string.
	Collect(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		tickLower int32,
		tickUpper int32,
		amount0Requested string,
		amount1Requested string,
	) (amount0, amount1 string)

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - fee: Withdrawal fee rate in basis points to apply to fee-bearing position payouts.
	SetWithdrawalFee(_ int, rlm realm, fee uint64)
}

// IPoolSwap interface defines swap and protocol fee operations.
// These methods handle token swaps and protocol fee management.
type IPoolSwap interface {
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - recipient: Nonzero address receiving swap output.
	//   - zeroForOne: Swap direction; true swaps token0 for token1, false swaps token1 for token0.
	//   - amountSpecified: Signed decimal amount; positive requests exact input and negative requests exact output.
	//   - sqrtPriceLimitX96: Q96-encoded decimal square-root price limit for the swap.
	//   - swapCallback: Callback that receives the current realm, signed token deltas, and marker, and must settle the input-token balance or return an error.
	//
	// Returns:
	//   - amount0: Signed token0 delta produced by the swap, encoded as a decimal string.
	//   - amount1: Signed token1 delta produced by the swap, encoded as a decimal string.
	Swap(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
		swapCallback func(cur realm, amount0Delta, amount1Delta int64, callbackMarker *CallbackMarker) error,
	) (string, string)

	// Parameters:
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - zeroForOne: Swap direction; true swaps token0 for token1, false swaps token1 for token0.
	//   - amountSpecified: Signed decimal amount; positive requests exact input and negative requests exact output.
	//   - sqrtPriceLimitX96: Q96-encoded decimal square-root price limit for the simulated swap.
	//
	// Returns:
	//   - amount0: Signed token0 delta predicted by the simulation, encoded as a decimal string.
	//   - amount1: Signed token1 delta predicted by the simulation, encoded as a decimal string.
	//   - err: Non-nil when parsing or swap simulation validation fails; successful simulations return nil.
	DrySwap(
		token0Path string,
		token1Path string,
		fee uint32,
		zeroForOne bool,
		amountSpecified string,
		sqrtPriceLimitX96 string,
	) (string, string, error)

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - hook: Callback invoked after a swap with the current realm and pool path; a returned error aborts the swap.
	SetSwapEndHook(_ int, rlm realm, hook func(cur realm, poolPath string) error)

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - hook: Callback invoked before a swap with the current realm, pool path, and block timestamp.
	SetSwapStartHook(_ int, rlm realm, hook func(cur realm, poolPath string, timestamp int64))

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - hook: Callback invoked when a tick is crossed, receiving current realm, pool path, tick id, direction, and timestamp.
	SetTickCrossHook(_ int, rlm realm, hook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64))

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - recipient: Nonzero address receiving collected protocol fees.
	//   - amount0Requested: Non-negative decimal amount of token0 protocol fees requested, capped by availability.
	//   - amount1Requested: Non-negative decimal amount of token1 protocol fees requested, capped by availability.
	//
	// Returns:
	//   - amount0: Token0 protocol fees transferred to recipient, encoded as a decimal string.
	//   - amount1: Token1 protocol fees transferred to recipient, encoded as a decimal string.
	CollectProtocol(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		recipient address,
		amount0Requested string,
		amount1Requested string,
	) (amount0, amount1 string)

	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - feeProtocol0: Protocol-fee denominator/configuration for token0 swaps.
	//   - feeProtocol1: Protocol-fee denominator/configuration for token1 swaps.
	SetFeeProtocol(_ int, rlm realm, feeProtocol0, feeProtocol1 uint8)
}

// IPoolOracle defines the pool's Uniswap V3-aligned oracle surface.
//
// Its public methods mirror the relevant Uniswap V3 pool-state, derived-state,
// and action specifications, adapted for GnoSwap's singleton pool realm: every
// operation identifies its pool with poolPath, and uint values cross the public
// boundary using GnoSwap types or decimal strings rather than the EVM ABI.
//
// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolState.sol#L21-L32
// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol#L18-L39
type IPoolOracle interface {
	// GetSlot0 returns a safe copy of a pool's price, tick, protocol-fee, lock,
	// and oracle cursor/capacity state, corresponding to Uniswap V3 slot0().
	//
	// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolState.sol#L21-L32
	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose slot0 state is read.
	//
	// Returns:
	//   - slot0: Safe copy of the pool's price, tick, protocol-fee, lock, and oracle cursor/capacity state.
	GetSlot0(poolPath string) Slot0

	// GetObservationAt returns the observation stored at index, corresponding to
	// Uniswap V3 observations(uint256). An in-range uninitialized slot returns a
	// zero observation; an out-of-range index returns an error.
	//
	// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolState.sol#L99-L115
	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the observation.
	//   - index: uint16 observation-buffer index to read.
	//
	// Returns:
	//   - observation: Stored observation, or the zero observation for an in-range uninitialized slot.
	//   - err: Non-nil when poolPath is unknown or index is outside the pool's observation buffer.
	GetObservationAt(poolPath string, index uint16) (Observation, error)

	// Observe returns tick and seconds-per-liquidity cumulatives for every
	// requested lookback, corresponding to Uniswap V3 observe(uint32[]).
	//
	// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol#L18-L21
	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose oracle data is read.
	//   - secondsAgos: Lookback durations in seconds; one cumulative pair is returned for each entry in order.
	//
	// Returns:
	//   - tickCumulatives: Signed cumulative ticks corresponding to each requested lookback.
	//   - secondsPerLiquidityCumulativesX128: Q128-scaled seconds-per-liquidity cumulatives as decimal strings, in request order.
	//   - err: Non-nil when the pool or requested lookback cannot be served by its observations.
	Observe(poolPath string, secondsAgos []uint32) ([]int64, []string, error)

	// SnapshotCumulativesInside returns accumulators accrued while the pool price
	// was inside [tickLower, tickUpper), corresponding to Uniswap V3
	// snapshotCumulativesInside(int24,int24).
	//
	// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolDerivedState.sol#L23-L39
	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose inside accumulators are read.
	//   - tickLower: Lower boundary of the half-open tick range [tickLower, tickUpper).
	//   - tickUpper: Upper boundary of the half-open tick range [tickLower, tickUpper).
	//
	// Returns:
	//   - tickCumulativeInside: Signed tick accumulator while the price was inside the range.
	//   - secondsPerLiquidityInsideX128: Q128-scaled seconds-per-liquidity accumulator inside the range.
	//   - secondsInside: Number of seconds for which the price was inside the range.
	//   - err: Non-nil when poolPath or the requested tick range is invalid or unavailable.
	SnapshotCumulativesInside(
		poolPath string,
		tickLower int32,
		tickUpper int32,
	) (int64, *u256.Uint, uint32, error)

	// OracleConsult returns the arithmetic mean tick and harmonic mean liquidity
	// over secondsAgo, following Uniswap V3 periphery's OracleLibrary.consult.
	//
	// ref: https://github.com/Uniswap/v3-periphery/blob/0682387198a24c7cd63566a2c58398533860a5d1/contracts/libraries/OracleLibrary.sol#L16-L41
	// Parameters:
	//   - poolPath: Canonical path identifying the pool consulted for the time-weighted oracle values.
	//   - secondsAgo: Lookback duration in seconds over which the arithmetic mean tick and harmonic mean liquidity are calculated.
	//
	// Returns:
	//   - arithmeticMeanTick: Time-weighted arithmetic mean tick over secondsAgo.
	//   - harmonicMeanLiquidity: Harmonic mean liquidity over secondsAgo, represented as a u256 value.
	//   - err: Non-nil when poolPath is unknown or the requested history is unavailable.
	OracleConsult(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error)

	// IncreaseObservationCardinalityNext schedules growth of the circular
	// observation buffer, corresponding to Uniswap V3
	// increaseObservationCardinalityNext(uint16).
	//
	// ref: https://github.com/Uniswap/v3-core/blob/e3589b192d0be27e100cd0daaf6c97204fdb1899/contracts/interfaces/pool/IUniswapV3PoolActions.sol#L98-L102
	// Parameters:
	//   - _: Noncrossing implementation-call discriminator; pass 0.
	//   - rlm: Current realm context forwarded unchanged by the pool proxy.
	//   - token0Path: Registered token contract path for token0.
	//   - token1Path: Registered token contract path for token1.
	//   - fee: Fee tier identifying the pool.
	//   - cardinalityNext: Requested next observation-buffer capacity; must not exceed the implementation maximum.
	IncreaseObservationCardinalityNext(
		_ int,
		rlm realm,
		token0Path string,
		token1Path string,
		fee uint32,
		cardinalityNext uint16,
	)
}

// IPoolGetter interface defines data retrieval operations.
// These methods provide read-only access to pool state and data.
type IPoolGetter interface {
	// Parameters:
	//   - poolPath: Canonical pool path to test in the pool registry.
	//
	// Returns:
	//   - exists: True when a pool is registered at poolPath.
	ExistsPoolPath(poolPath string) bool

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token0 balance is read.
	//
	// Returns:
	//   - balanceToken0: Current internal token0 balance recorded for the pool.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetBalanceToken0(poolPath string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token1 balance is read.
	//
	// Returns:
	//   - balanceToken1: Current internal token1 balance recorded for the pool.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetBalanceToken1(poolPath string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose fee tier is read.
	//
	// Returns:
	//   - fee: Configured fee tier for the pool.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetFee(poolPath string) (uint32, error)

	// Parameters:
	//   - fee: Fee tier whose configured tick spacing is requested.
	//
	// Returns:
	//   - spacing: Tick interval associated with fee.
	//   - err: Non-nil when no tick spacing is configured for fee.
	GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token0 fee growth is read.
	//
	// Returns:
	//   - feeGrowthGlobal0X128: Token0 global fee-growth accumulator scaled by 2^128.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetFeeGrowthGlobal0X128(poolPath string) (*u256.Uint, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token1 fee growth is read.
	//
	// Returns:
	//   - feeGrowthGlobal1X128: Token1 global fee-growth accumulator scaled by 2^128.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetFeeGrowthGlobal1X128(poolPath string) (*u256.Uint, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose fee growth is read.
	//
	// Returns:
	//   - feeGrowthGlobal0X128: Token0 global fee-growth accumulator scaled by 2^128.
	//   - feeGrowthGlobal1X128: Token1 global fee-growth accumulator scaled by 2^128.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose active liquidity is read.
	//
	// Returns:
	//   - liquidity: Current active liquidity as a u256 value.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetLiquidity(poolPath string) (*u256.Uint, error)

	// Returns:
	//   - pendingProtocolFees: Map from token contract path to pending protocol-fee amount.
	GetPendingProtocolFees() map[string]int64

	// Returns:
	//   - poolCreationFee: Configured fee amount charged when creating a pool.
	GetPoolCreationFee() int64

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - feeGrowthInside0LastX128: Token0 inside-fee-growth checkpoint as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionFeeGrowthInside0LastX128(poolPath, key string) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - feeGrowthInside1LastX128: Token1 inside-fee-growth checkpoint as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionFeeGrowthInside1LastX128(poolPath, key string) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - feeGrowthInside0LastX128: Token0 inside-fee-growth checkpoint as a decimal Q128-scaled string.
	//   - feeGrowthInside1LastX128: Token1 inside-fee-growth checkpoint as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionFeeGrowthInsideLastX128(poolPath, key string) (string, string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - liquidity: Position liquidity as a decimal string.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionLiquidity(poolPath, key string) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - tokensOwed0: Token0 amount owed to the position in the pool ledger.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionTokensOwed0(poolPath, key string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the position.
	//   - key: Encoded position key identifying the position's tick range.
	//
	// Returns:
	//   - tokensOwed1: Token1 amount owed to the position in the pool ledger.
	//   - err: Non-nil when poolPath or key cannot be resolved.
	GetPositionTokensOwed1(poolPath, key string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose protocol fees are read.
	//
	// Returns:
	//   - protocolFeesToken0: Accrued token0 protocol-fee amount.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetProtocolFeesToken0(poolPath string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose protocol fees are read.
	//
	// Returns:
	//   - protocolFeesToken1: Accrued token1 protocol-fee amount.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetProtocolFeesToken1(poolPath string) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool's slot0 protocol fee configuration.
	//
	// Returns:
	//   - feeProtocol: Token-direction protocol-fee denominator/configuration stored in slot0.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetSlot0FeeProtocol(poolPath string) (uint8, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool's current square-root price.
	//
	// Returns:
	//   - sqrtPriceX96: Current square-root price encoded as a u256 Q96 value.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetSlot0SqrtPriceX96(poolPath string) (*u256.Uint, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose current tick is read.
	//
	// Returns:
	//   - tick: Current signed price tick.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetSlot0Tick(poolPath string) (int32, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose lock state is read.
	//
	// Returns:
	//   - unlocked: True when the pool is available for another state-changing operation.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetSlot0Unlocked(poolPath string) (bool, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose outside cumulative is requested.
	//
	// Returns:
	//   - tickCumulativeOutside: Signed cumulative tick value stored outside tick.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickCumulativeOutside(poolPath string, tick int32) (int64, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose token0 fee-growth outside value is requested.
	//
	// Returns:
	//   - feeGrowthOutside0X128: Token0 fee-growth outside tick, encoded as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickFeeGrowthOutside0X128(poolPath string, tick int32) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose token1 fee-growth outside value is requested.
	//
	// Returns:
	//   - feeGrowthOutside1X128: Token1 fee-growth outside tick, encoded as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickFeeGrowthOutside1X128(poolPath string, tick int32) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose outside fee growth is requested.
	//
	// Returns:
	//   - feeGrowthOutside0X128: Token0 fee-growth outside tick, encoded as a decimal Q128-scaled string.
	//   - feeGrowthOutside1X128: Token1 fee-growth outside tick, encoded as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (string, string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose initialization state is requested.
	//
	// Returns:
	//   - initialized: True when tick has initialized liquidity/fee-growth state.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickInitialized(poolPath string, tick int32) (bool, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose gross liquidity is requested.
	//
	// Returns:
	//   - liquidityGross: Gross liquidity associated with tick, encoded as a decimal string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickLiquidityGross(poolPath string, tick int32) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose net liquidity is requested.
	//
	// Returns:
	//   - liquidityNet: Signed net liquidity change at tick, encoded as a decimal string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickLiquidityNet(poolPath string, tick int32) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose elapsed outside time is requested.
	//
	// Returns:
	//   - secondsOutside: Seconds elapsed outside tick's range.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickSecondsOutside(poolPath string, tick int32) (uint32, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose outside seconds-per-liquidity value is requested.
	//
	// Returns:
	//   - secondsPerLiquidityOutsideX128: Outside seconds-per-liquidity accumulator encoded as a decimal Q128-scaled string.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose tick spacing is read.
	//
	// Returns:
	//   - tickSpacing: Configured signed tick interval for the pool.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetTickSpacing(poolPath string) (int32, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token0 path is read.
	//
	// Returns:
	//   - token0Path: Registered token contract path assigned to token0.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetToken0Path(poolPath string) (string, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose token1 path is read.
	//
	// Returns:
	//   - token1Path: Registered token contract path assigned to token1.
	//   - err: Non-nil when poolPath does not identify a registered pool.
	GetToken1Path(poolPath string) (string, error)

	// Returns:
	//   - withdrawalFeeBPS: Configured withdrawal fee in basis points.
	GetWithdrawalFee() uint64

	// Returns:
	//   - pools: Read-only tree containing registered pool entries.
	GetPools() *rotree.ReadOnlyTree
	// Returns:
	//   - feeAmountTickSpacings: Map from fee tier to configured tick spacing.
	GetFeeAmountTickSpacings() map[uint32]int32

	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose positions are viewed.
	//
	// Returns:
	//   - positions: Read-only tree containing position entries for poolPath, or nil when poolPath is not registered.
	GetPoolPositions(poolPath string) *rotree.ReadOnlyTree

	// Parameters:
	//   - poolPath: Canonical path identifying the pool to scan.
	//   - tickLower: Inclusive lower tick bound for the requested range.
	//   - tickUpper: Exclusive upper tick bound for the requested range.
	//
	// Returns:
	//   - ticks: Initialized ticks in [tickLower, tickUpper), ordered by tick.
	//   - err: Non-nil when poolPath or the requested range is invalid.
	GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) ([]int32, error)

	// Parameters:
	//   - poolPath: Canonical path identifying the pool containing the tick.
	//   - tick: Signed tick whose complete state is requested.
	//
	// Returns:
	//   - info: Tick state including initialization, liquidity, fee-growth, and oracle accumulators.
	//   - err: Non-nil when poolPath or tick cannot be resolved.
	GetTickInfo(poolPath string, tick int32) (TickInfo, error)
	// Parameters:
	//   - poolPath: Canonical path identifying the pool whose bitmap is read.
	//   - wordPos: Signed bitmap word position containing 256 tick-initialization bits.
	//
	// Returns:
	//   - bitmap: Decimal-encoded bitmap word for wordPos.
	//   - err: Non-nil when poolPath or wordPos cannot be resolved.
	GetTickBitmaps(poolPath string, wordPos int16) (string, error)
}

// IPoolStore interface defines the storage abstraction for pool data.
// This interface provides a clean separation between business logic and storage,
// allowing different implementations to use the same storage interface.
//
// All pool implementations (v1, v2, etc.) use this interface to access
// and modify pool state, ensuring data consistency across versions.
type IPoolStore interface {
	// Returns:
	//   - exists: True when the backing pool registry tree has been initialized.
	HasPools() bool
	// Returns:
	//   - pools: Stored B+tree containing pool state entries; the implementation panics if the KV value is unreadable, wrongly typed, or nil.
	GetPools() *bptree.BPTree
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - pools: B+tree replacing the stored pool registry.
	//
	// Returns:
	//   - err: Nil after storing pools; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetPools(_ int, rlm realm, pools *bptree.BPTree) error

	// Returns:
	//   - exists: True when the backing observation registry tree has been initialized.
	HasObservations() bool
	// Returns:
	//   - observations: Stored B+tree containing pool observation trees; the implementation panics if the KV value is unreadable, wrongly typed, or nil.
	GetObservations() *bptree.BPTree
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - observations: B+tree replacing the stored observation registry.
	//
	// Returns:
	//   - err: Nil after storing observations; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetObservations(_ int, rlm realm, observations *bptree.BPTree) error

	// Returns:
	//   - exists: True when the fee-to-tick-spacing map has been initialized.
	HasFeeAmountTickSpacing() bool
	// Returns:
	//   - feeAmountTickSpacing: Stored fee-tier to tick-spacing map; the implementation panics if the KV value is unreadable, wrongly typed, or nil.
	GetFeeAmountTickSpacing() map[uint32]int32
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - feeAmountTickSpacing: Map replacing the configured fee-tier to tick-spacing values.
	//
	// Returns:
	//   - err: Nil after storing the mapping; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetFeeAmountTickSpacing(_ int, rlm realm, feeAmountTickSpacing map[uint32]int32) error

	// Returns:
	//   - exists: True when the slot0 protocol-fee configuration has been initialized.
	HasSlot0FeeProtocol() bool
	// Returns:
	//   - slot0FeeProtocol: Stored packed protocol-fee denominator configuration; the implementation panics if the KV value is unreadable or wrongly typed.
	GetSlot0FeeProtocol() uint8
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - slot0FeeProtocol: Protocol-fee denominator/configuration to store in slot0.
	//
	// Returns:
	//   - err: Nil after storing the value; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetSlot0FeeProtocol(_ int, rlm realm, slot0FeeProtocol uint8) error

	// Returns:
	//   - exists: True when a pool-creation fee has been initialized.
	HasPoolCreationFee() bool
	// Returns:
	//   - poolCreationFee: Stored pool-creation charge in the chain's smallest currency unit; the implementation panics if the KV value is unreadable or wrongly typed.
	GetPoolCreationFee() int64
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - poolCreationFee: Pool-creation fee amount to store.
	//
	// Returns:
	//   - err: Nil after storing the fee; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetPoolCreationFee(_ int, rlm realm, poolCreationFee int64) error

	// Returns:
	//   - exists: True when the pending protocol-fee map has been initialized.
	HasPendingProtocolFees() bool
	// Returns:
	//   - pendingProtocolFees: Stored token-path map of pending protocol-fee amounts in the chain's smallest currency unit; the implementation panics if the KV value is unreadable or wrongly typed.
	GetPendingProtocolFees() map[string]int64
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - pendingProtocolFees: Map replacing all pending protocol-fee balances.
	//
	// Returns:
	//   - err: Nil after storing the map; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetPendingProtocolFees(_ int, rlm realm, pendingProtocolFees map[string]int64) error
	// Parameters:
	//   - tokenPath: Registered token contract path whose pending protocol fee is read.
	//
	// Returns:
	//   - amount: Pending protocol-fee amount recorded for tokenPath, or zero when none is stored.
	GetPendingProtocolFee(tokenPath string) int64
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - tokenPath: Registered token contract path whose pending fee is updated.
	//   - amount: Pending protocol-fee amount to store for tokenPath.
	//
	// Returns:
	//   - err: Nil after storing the amount; non-nil for a non-current rlm, unauthorized code-realm write, or underlying authorization failure.
	SetPendingProtocolFee(_ int, rlm realm, tokenPath string, amount int64) error
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - tokenPath: Registered token contract path whose pending fee entry is removed.
	//
	// Returns:
	//   - err: Nil after removing the entry; non-nil for a non-current rlm, unauthorized code-realm write, or underlying authorization failure.
	RemovePendingProtocolFee(_ int, rlm realm, tokenPath string) error

	// Returns:
	//   - exists: True when a withdrawal-fee basis-point value has been initialized.
	HasWithdrawalFeeBPS() bool
	// Returns:
	//   - withdrawalFeeBPS: Stored withdrawal fee in basis points.
	GetWithdrawalFeeBPS() uint64
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - withdrawalFeeBPS: Withdrawal fee rate in basis points to store.
	//
	// Returns:
	//   - err: Nil after storing the rate; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetWithdrawalFeeBPS(_ int, rlm realm, withdrawalFeeBPS uint64) error

	// Returns:
	//   - exists: True when the pool unlocked flag has been initialized.
	HasUnlocked() bool
	// Returns:
	//   - unlocked: Persisted global reentrancy-lock state; true means pool operations may proceed without the lock, and malformed/missing storage panics.
	GetUnlocked() bool
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - unlocked: Lock flag to store; false marks the pool as locked.
	//
	// Returns:
	//   - err: Nil after storing the flag; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetUnlocked(_ int, rlm realm, unlocked bool) error

	// Returns:
	//   - exists: True when a swap-start hook has been initialized.
	HasSwapStartHook() bool
	// Returns:
	//   - swapStartHook: Stored callback receiving current realm, pool path, and timestamp; callers should check HasSwapStartHook before retrieving it.
	GetSwapStartHook() func(cur realm, poolPath string, timestamp int64)
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - swapStartHook: Callback invoked with current realm, pool path, and timestamp before swaps.
	//
	// Returns:
	//   - err: Nil after storing the hook; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetSwapStartHook(_ int, rlm realm, swapStartHook func(cur realm, poolPath string, timestamp int64)) error

	// Returns:
	//   - exists: True when a swap-end hook has been initialized.
	HasSwapEndHook() bool
	// Returns:
	//   - swapEndHook: Stored callback receiving current realm and pool path and returning a hook error; callers should check HasSwapEndHook before retrieving it.
	GetSwapEndHook() func(cur realm, poolPath string) error
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - swapEndHook: Callback invoked with current realm and pool path after swaps; it may return an error.
	//
	// Returns:
	//   - err: Nil after storing the hook; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetSwapEndHook(_ int, rlm realm, swapEndHook func(cur realm, poolPath string) error) error

	// Returns:
	//   - exists: True when a tick-cross hook has been initialized.
	HasTickCrossHook() bool
	// Returns:
	//   - tickCrossHook: Stored callback receiving current realm, pool path, crossed tick, direction, and timestamp; callers should check HasTickCrossHook before retrieving it.
	GetTickCrossHook() func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)
	// Parameters:
	//   - _: Leading integer discriminator forwarded to the storage setter; pass 0.
	//   - rlm: Propagated realm context; the setter rejects a context that is not current.
	//   - tickCrossHook: Callback invoked with current realm, pool path, crossed tick, direction, and timestamp.
	//
	// Returns:
	//   - err: Nil after storing the hook; non-nil for a non-current rlm or an underlying KV-store write failure.
	SetTickCrossHook(_ int, rlm realm, tickCrossHook func(cur realm, poolPath string, tickId int32, zeroForOne bool, timestamp int64)) error
}

type CallbackMarker struct{}

// NewCallbackMarker allocates a CallbackMarker in the pool realm.
// Construction must happen here because /r/-declared types can only be
// allocated in their owning realm (interrealm v2 checkConstructionTime).
// Callers in other realms (e.g. pool/v1 impl) borrow into pool via
// borrow rule #1 (function defined in /r/ package).
// Returns:
//   - marker: New marker value allocated in the pool realm for swap-callback validation.
func NewCallbackMarker() *CallbackMarker {
	return &CallbackMarker{}
}
