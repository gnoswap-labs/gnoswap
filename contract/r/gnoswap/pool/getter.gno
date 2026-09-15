package pool

import (
	rotree "gno.land/p/nt/bptree/rotree/v0"
)

// GetPools returns a read-only view of every pool, keyed by pool path.
// Reading an entry yields a clone, so the view cannot mutate realm state.
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by canonical pool path; each
//     entry is cloned before it is exposed.
func GetPools() *rotree.ReadOnlyTree {
	return getImplementation().GetPools()
}

// ExistsPoolPath checks if a pool exists at the given path.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to check.
//
// Returns:
//   - bool: True when a pool is registered at poolPath; false otherwise.
func ExistsPoolPath(poolPath string) bool {
	return getImplementation().ExistsPoolPath(poolPath)
}

// GetBalances returns the balances of the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose balances are read.
//
// Returns:
//   - int64: Current token0 balance held by the pool, in token base units.
//   - int64: Current token1 balance held by the pool, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetBalances(poolPath string) (int64, int64, error) {
	bal0, err := getImplementation().GetBalanceToken0(poolPath)
	if err != nil {
		return 0, 0, err
	}
	bal1, err := getImplementation().GetBalanceToken1(poolPath)
	if err != nil {
		return 0, 0, err
	}
	return bal0, bal1, nil
}

// GetBalanceToken0 returns the balance of token0 in the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - int64: Current token0 balance held by the pool, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetBalanceToken0(poolPath string) (int64, error) {
	return getImplementation().GetBalanceToken0(poolPath)
}

// GetBalanceToken1 returns the balance of token1 in the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - int64: Current token1 balance held by the pool, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetBalanceToken1(poolPath string) (int64, error) {
	return getImplementation().GetBalanceToken1(poolPath)
}

// GetFee returns the fee tier of the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose fee tier is read.
//
// Returns:
//   - uint32: Configured fee tier for the pool.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetFee(poolPath string) (uint32, error) {
	return getImplementation().GetFee(poolPath)
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
// Returns:
//   - map[uint32]int32: Copy of the configured fee-tier-to-tick-spacing mapping.
func GetFeeAmountTickSpacings() map[uint32]int32 {
	return cloneFeeAmountTickSpacings(getImplementation().GetFeeAmountTickSpacings())
}

// GetFeeAmountTickSpacing returns the tick spacing for a given fee tier.
// Parameters:
//   - fee: Fee tier whose supported tick spacing is requested.
//
// Returns:
//   - spacing: Tick spacing configured for fee.
//   - err: Non-nil when fee is not one of the supported fee tiers.
func GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error) {
	return getImplementation().GetFeeAmountTickSpacing(fee)
}

// GetFeeGrowthGlobal0X128 returns the global fee growth for token0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Token0 global fee growth, serialized as a base-10 X128 accumulator.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetFeeGrowthGlobal0X128(poolPath string) (string, error) {
	feeGrowth, err := getImplementation().GetFeeGrowthGlobal0X128(poolPath)
	if err != nil {
		return "", err
	}
	return feeGrowth.ToString(), nil
}

// GetFeeGrowthGlobal1X128 returns the global fee growth for token1.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Token1 global fee growth, serialized as a base-10 X128 accumulator.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetFeeGrowthGlobal1X128(poolPath string) (string, error) {
	feeGrowth, err := getImplementation().GetFeeGrowthGlobal1X128(poolPath)
	if err != nil {
		return "", err
	}
	return feeGrowth.ToString(), nil
}

// GetFeeGrowthGlobalX128 returns the global fee growth for both tokens.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Token0 global fee growth, serialized as a base-10 X128 accumulator.
//   - string: Token1 global fee growth, serialized as a base-10 X128 accumulator.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetFeeGrowthGlobalX128(poolPath string) (string, string, error) {
	fg0, fg1, err := getImplementation().GetFeeGrowthGlobalX128(poolPath)
	if err != nil {
		return "", "", err
	}
	return fg0.ToString(), fg1.ToString(), nil
}

// GetLiquidity returns the current liquidity in the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose liquidity is read.
//
// Returns:
//   - string: Current pool liquidity, serialized as a base-10 unsigned integer.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetLiquidity(poolPath string) (string, error) {
	liquidity, err := getImplementation().GetLiquidity(poolPath)
	if err != nil {
		return "", err
	}
	return liquidity.ToString(), nil
}

// GetPoolCreationFee returns the current pool creation fee.
// Returns:
//   - int64: Pool creation fee charged in GNS token base units (six decimal
//     places; 1 GNS = 1,000,000 base units).
func GetPoolCreationFee() int64 {
	return getImplementation().GetPoolCreationFee()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - string: Position's last token0 fee-growth-inside accumulator, serialized
//     as a base-10 X128 value.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionFeeGrowthInside0LastX128(poolPath, key string) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - string: Position's last token1 fee-growth-inside accumulator, serialized
//     as a base-10 X128 value.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionFeeGrowthInside1LastX128(poolPath, key string) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - string: Position's last token0 fee-growth-inside accumulator, serialized
//     as a base-10 X128 value.
//   - string: Position's last token1 fee-growth-inside accumulator, serialized
//     as a base-10 X128 value.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (string, string, error) {
	return getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetPoolPositions returns a read-only view of a pool's positions, keyed by
// position key. nil is returned when the pool does not exist.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose positions are read.
//
// Returns:
//   - *rotree.ReadOnlyTree: Read-only tree keyed by position key; nil when the
//     pool does not exist.
func GetPoolPositions(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolPositions(poolPath)
}

// GetPositionLiquidity returns the liquidity of a position.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - string: Position liquidity, serialized as a base-10 unsigned integer.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionLiquidity(poolPath, key string) (string, error) {
	return getImplementation().GetPositionLiquidity(poolPath, key)
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - int64: Amount of token0 owed to the position, in token base units.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionTokensOwed0(poolPath, key string) (int64, error) {
	return getImplementation().GetPositionTokensOwed0(poolPath, key)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - int64: Amount of token1 owed to the position, in token base units.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionTokensOwed1(poolPath, key string) (int64, error) {
	return getImplementation().GetPositionTokensOwed1(poolPath, key)
}

// GetPositionTokensOwedInfos returns the amount of tokens owed for both tokens.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the position.
//   - key: Position key identifying the position within the pool.
//
// Returns:
//   - int64: Amount of token0 owed to the position, in token base units.
//   - int64: Amount of token1 owed to the position, in token base units.
//   - error: Non-nil when the pool or position key cannot be found.
func GetPositionTokensOwed(poolPath, key string) (int64, int64, error) {
	tokensOwed0, err := getImplementation().GetPositionTokensOwed0(poolPath, key)
	if err != nil {
		return 0, 0, err
	}
	tokensOwed1, err := getImplementation().GetPositionTokensOwed1(poolPath, key)
	if err != nil {
		return 0, 0, err
	}
	return tokensOwed0, tokensOwed1, nil
}

// GetProtocolFeesToken0 returns accumulated protocol fees for token0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose fees are read.
//
// Returns:
//   - int64: Accumulated protocol fee for token0, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetProtocolFeesToken0(poolPath string) (int64, error) {
	return getImplementation().GetProtocolFeesToken0(poolPath)
}

// GetProtocolFeesToken1 returns accumulated protocol fees for token1.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose fees are read.
//
// Returns:
//   - int64: Accumulated protocol fee for token1, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetProtocolFeesToken1(poolPath string) (int64, error) {
	return getImplementation().GetProtocolFeesToken1(poolPath)
}

// GetProtocolFeesTokens returns the accumulated protocol fees for both tokens.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose fees are read.
//
// Returns:
//   - int64: Accumulated protocol fee for token0, in token base units.
//   - int64: Accumulated protocol fee for token1, in token base units.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetProtocolFeesTokens(poolPath string) (int64, int64, error) {
	fees0, err := getImplementation().GetProtocolFeesToken0(poolPath)
	if err != nil {
		return 0, 0, err
	}
	fees1, err := getImplementation().GetProtocolFeesToken1(poolPath)
	if err != nil {
		return 0, 0, err
	}
	return fees0, fees1, nil
}

// GetSlot0FeeProtocol returns the protocol fee rate from slot0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - uint8: Packed protocol-fee denominator configuration from slot0; token0
//     occupies the low nibble and token1 the high nibble.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetSlot0FeeProtocol(poolPath string) (uint8, error) {
	return getImplementation().GetSlot0FeeProtocol(poolPath)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price from slot0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Current square-root price in Q64.96 fixed-point form, serialized
//     as a base-10 unsigned integer.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetSlot0SqrtPriceX96(poolPath string) (string, error) {
	sqrtPriceX96, err := getImplementation().GetSlot0SqrtPriceX96(poolPath)
	if err != nil {
		return "", err
	}
	return sqrtPriceX96.ToString(), nil
}

// GetSlot0Tick returns the current tick from slot0.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - int32: Current active tick index stored in slot0.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetSlot0Tick(poolPath string) (int32, error) {
	return getImplementation().GetSlot0Tick(poolPath)
}

// GetSlot0Unlocked returns the stored `Slot0.unlocked` metadata field.
// It is separate from the pool-wide `Unlocked` KV-store guard used by live
// reentrancy protection and must not be interpreted as the current lock state.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - bool: Stored `Slot0.unlocked` metadata value; not the live pool-wide lock
//     state.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetSlot0Unlocked(poolPath string) (bool, error) {
	return getImplementation().GetSlot0Unlocked(poolPath)
}

// GetSlot0 returns a safe copy of the pool's slot0 (sqrt price, tick, protocol
// fee, slot0 lock metadata, and oracle cursor/capacity metadata).
// The clone happens here, at the proxy boundary, so every implementation
// version can return its internal Slot0 by value without each one having to
// remember to defend against callers mutating the shared sqrtPriceX96.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - Slot0: Copy of the pool's slot0 state, including price, tick, protocol
//     fee, slot0 lock metadata, and observation metadata. The lock flag is
//     separate from the pool-wide `Unlocked` KV-store guard; panics if the pool
//     is missing.
func GetSlot0(poolPath string) Slot0 {
	slot0 := getImplementation().GetSlot0(poolPath)
	return slot0.Clone()
}

// GetObservationAt returns a safe copy of the observation stored at index.
// An in-range but uninitialized slot returns the zero observation, matching
// Uniswap V3's fixed observation-array getter.
//
// ref: uniswap v3 IUniswapV3PoolState.observations(uint256 index)
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the observation.
//   - index: Zero-based observation-array index; values at or above the fixed
//     cardinality bound return an error.
//
// Returns:
//   - Observation: Observation at index, or the zero observation when the slot
//     is in range but has never been written.
//   - error: Non-nil when the pool is missing or index is out of range.
func GetObservationAt(poolPath string, index uint16) (Observation, error) {
	observation, err := getImplementation().GetObservationAt(poolPath, index)
	if err != nil {
		return Observation{}, err
	}

	return observation, nil
}

// Observe returns the tick and seconds-per-liquidity cumulatives for each
// requested lookback, matching Uniswap V3's observe(uint32[] secondsAgos).
// Parameters:
//   - poolPath: Canonical pool path whose oracle history is queried.
//   - secondsAgos: Lookback intervals in seconds; one cumulative pair is returned
//     for each value, in the same order.
//
// Returns:
//   - []int64: Tick cumulative values corresponding to each requested lookback.
//   - []string: Seconds-per-liquidity cumulative X128 values, serialized as
//     base-10 strings, corresponding to each lookback.
//   - error: Non-nil when pool or observation data cannot be read.
func Observe(poolPath string, secondsAgos []uint32) ([]int64, []string, error) {
	tickCumulatives, secondsPerLiquidityCumulativeX128s, err := getImplementation().Observe(
		poolPath,
		cloneUint32Slice(secondsAgos),
	)
	if err != nil {
		return nil, nil, err
	}

	return cloneInt64Slice(tickCumulatives), cloneStringSlice(secondsPerLiquidityCumulativeX128s), nil
}

// SnapshotCumulativesInside returns the tick, seconds-per-liquidity, and
// seconds cumulatives accrued while the pool price was inside
// [tickLower, tickUpper). Both boundary ticks must be initialized.
//
// Snapshots are only comparable across an interval during which a position in
// the range existed, matching Uniswap V3's snapshotCumulativesInside.
// Parameters:
//   - poolPath: Canonical pool path whose oracle snapshot is queried.
//   - tickLower: Lower inclusive tick boundary of the position range.
//   - tickUpper: Upper exclusive tick boundary of the position range; both
//     boundary ticks must be initialized.
//
// Returns:
//   - int64: Tick cumulative accrued while the price was inside the range.
//   - string: Seconds-per-liquidity-inside X128 accumulator, serialized as a
//     base-10 string.
//   - uint32: Seconds accrued while the price was inside the range.
//   - error: Non-nil when the pool, observations, or initialized boundaries are
//     unavailable.
func SnapshotCumulativesInside(
	poolPath string,
	tickLower int32,
	tickUpper int32,
) (int64, string, uint32, error) {
	tickCumulativeInside, secondsPerLiquidityInsideX128, secondsInside, err := getImplementation().SnapshotCumulativesInside(
		poolPath,
		tickLower,
		tickUpper,
	)
	if err != nil {
		return 0, "", 0, err
	}

	return tickCumulativeInside, secondsPerLiquidityInsideX128.ToString(), secondsInside, nil
}

// GetTickCumulativeOutside returns the tick cumulative value outside a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside tick cumulative is requested.
//
// Returns:
//   - int64: Tick cumulative recorded outside tick.
//   - error: Non-nil when the pool or tick is not found.
func GetTickCumulativeOutside(poolPath string, tick int32) (int64, error) {
	return getImplementation().GetTickCumulativeOutside(poolPath, tick)
}

// GetTickFeeGrowthOutside0X128 returns fee growth outside for token0 at a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside fee growth is requested.
//
// Returns:
//   - string: Token0 fee growth outside tick, serialized as a base-10 X128
//     accumulator.
//   - error: Non-nil when the pool or tick is not found.
func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickFeeGrowthOutside0X128(poolPath, tick)
}

// GetTickFeeGrowthOutside1X128 returns fee growth outside for token1 at a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside fee growth is requested.
//
// Returns:
//   - string: Token1 fee growth outside tick, serialized as a base-10 X128
//     accumulator.
//   - error: Non-nil when the pool or tick is not found.
func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickFeeGrowthOutside1X128(poolPath, tick)
}

// GetTickFeeGrowthOutsideX128 returns fee growth outside for both tokens at a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside fee growth is requested.
//
// Returns:
//   - string: Token0 fee growth outside tick, serialized as a base-10 X128
//     accumulator.
//   - string: Token1 fee growth outside tick, serialized as a base-10 X128
//     accumulator.
//   - error: Non-nil when the pool or tick is not found.
func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (string, string, error) {
	return getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
}

// GetTickInitialized returns whether a tick is initialized.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose initialization flag is requested.
//
// Returns:
//   - bool: True when the tick has initialized liquidity and outside accumulators.
//   - error: Non-nil when the pool or tick is not found.
func GetTickInitialized(poolPath string, tick int32) (bool, error) {
	return getImplementation().GetTickInitialized(poolPath, tick)
}

// GetInitializedTicksInRange returns initialized ticks within the given range.
// Parameters:
//   - poolPath: Canonical pool path whose ticks are enumerated.
//   - tickLower: Lower inclusive tick bound for enumeration.
//   - tickUpper: Upper bound for enumeration; ticks are selected through the
//     pool's range iterator.
//
// Returns:
//   - []int32: Tick indices that are initialized in the requested range.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) ([]int32, error) {
	ticks, err := getImplementation().GetInitializedTicksInRange(poolPath, tickLower, tickUpper)
	if err != nil {
		return nil, err
	}
	return cloneInt32Slice(ticks), nil
}

// GetTickLiquidityGross returns the total liquidity that references a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose gross liquidity is requested.
//
// Returns:
//   - string: Gross liquidity referencing the tick, serialized as a base-10
//     unsigned integer.
//   - error: Non-nil when the pool or tick is not found.
func GetTickLiquidityGross(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickLiquidityGross(poolPath, tick)
}

// GetTickLiquidityNet returns the net liquidity change at a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose net liquidity change is requested.
//
// Returns:
//   - string: Signed net liquidity change at the tick, serialized as a base-10
//     integer.
//   - error: Non-nil when the pool or tick is not found.
func GetTickLiquidityNet(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickLiquidityNet(poolPath, tick)
}

// GetTickSecondsOutside returns seconds spent outside a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside time is requested.
//
// Returns:
//   - uint32: Seconds accumulated outside the tick.
//   - error: Non-nil when the pool or tick is not found.
func GetTickSecondsOutside(poolPath string, tick int32) (uint32, error) {
	return getImplementation().GetTickSecondsOutside(poolPath, tick)
}

// GetTickSecondsPerLiquidityOutsideX128 returns seconds per liquidity outside a tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose outside accumulator is requested.
//
// Returns:
//   - string: Seconds-per-liquidity outside tick in X128 precision, serialized
//     as a base-10 unsigned integer.
//   - error: Non-nil when the pool or tick is not found.
func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

// GetTickSpacing returns the tick spacing of the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool whose spacing is read.
//
// Returns:
//   - int32: Tick spacing associated with the pool's fee tier.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetTickSpacing(poolPath string) (int32, error) {
	return getImplementation().GetTickSpacing(poolPath)
}

// GetToken0Path returns the path of token0 in the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Canonical token0 contract path stored by the pool.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetToken0Path(poolPath string) (string, error) {
	return getImplementation().GetToken0Path(poolPath)
}

// GetToken1Path returns the path of token1 in the pool.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool to query.
//
// Returns:
//   - string: Canonical token1 contract path stored by the pool.
//   - error: Non-nil when poolPath does not identify an existing pool.
func GetToken1Path(poolPath string) (string, error) {
	return getImplementation().GetToken1Path(poolPath)
}

// GetWithdrawalFee returns the current withdrawal fee rate.
// Returns:
//   - uint64: Withdrawal fee rate in basis points; zero means no withdrawal
//     fee is charged.
func GetWithdrawalFee() uint64 {
	return getImplementation().GetWithdrawalFee()
}

// OracleConsult returns the arithmetic mean tick and harmonic mean liquidity
// over a lookback, following Uniswap V3 OracleLibrary's consult convention.
// Parameters:
//   - poolPath: Canonical pool path whose oracle data is queried.
//   - secondsAgo: Lookback duration in seconds used to compute the time-weighted
//     values.
//
// Returns:
//   - int32: Arithmetic mean tick over the requested lookback.
//   - string: Harmonic mean liquidity over the lookback, serialized as a base-10
//     unsigned integer.
//   - error: Non-nil when the pool or required observation history is unavailable.
func OracleConsult(poolPath string, secondsAgo uint32) (int32, string, error) {
	tick, liquidity, err := getImplementation().OracleConsult(poolPath, secondsAgo)
	if err != nil {
		return 0, "", err
	}
	return tick, liquidity.ToString(), nil
}

// Structure getters

// GetTickInfo returns the tick info for a given tick.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the tick.
//   - tick: Tick index whose complete state is requested.
//
// Returns:
//   - TickInfo: Safe copy of the requested tick's liquidity and oracle/fee
//     accumulator fields.
//   - error: Non-nil when the pool or tick is not found.
func GetTickInfo(poolPath string, tick int32) (TickInfo, error) {
	tickInfo, err := getImplementation().GetTickInfo(poolPath, tick)
	if err != nil {
		return TickInfo{}, err
	}

	return tickInfo.Clone(), nil
}

// GetTickBitmaps returns the tick bitmap for a given word position.
// Parameters:
//   - poolPath: Canonical pool path identifying the pool containing the bitmap.
//   - wordPos: Signed bitmap word position to read.
//
// Returns:
//   - string: Bitmap word serialized as a base-10 unsigned integer.
//   - error: Non-nil when the pool or bitmap word is not found.
func GetTickBitmaps(poolPath string, wordPos int16) (string, error) {
	return getImplementation().GetTickBitmaps(poolPath, wordPos)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
// Returns:
//   - map[string]int64: Copy of pending protocol fees keyed by token contract path,
//     with amounts in token base units.
func GetPendingProtocolFees() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetPendingProtocolFees())
}
