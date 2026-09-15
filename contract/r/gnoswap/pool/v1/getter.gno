package pool

import (
	"errors"
	"time"

	u256 "gno.land/p/gnoswap/uint256/v1"
	rotree "gno.land/p/nt/bptree/rotree/v0"
	ufmt "gno.land/p/nt/ufmt/v0"
	pl "gno.land/r/gnoswap/pool"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
// Parameters:
//   - token0Path: first token contract path; pool paths canonicalize token order.
//   - token1Path: second token contract path; pool paths canonicalize token order.
//   - fee: fee tier encoded in the pool identifier.
//
// Returns:
//   - poolPath: canonical token0:token1:fee pool identifier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pl.GetPoolPath(token0Path, token1Path, fee)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
// Parameters:
//   - fee: fee tier whose configured tick spacing is requested.
//
// Returns:
//   - spacing: configured signed tick interval for fee.
//   - err: nil when fee is configured; an unsupported-fee error otherwise.
func (i *poolV1) GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error) {
	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()

	spacing, exist := feeAmountTickSpacing[fee]
	if !exist {
		return 0, errors.New(newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	return spacing, nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - token0Path: canonical token0 contract path stored in the pool.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetToken0Path(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return pool.Token0Path(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - token1Path: canonical token1 contract path stored in the pool.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetToken1Path(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return pool.Token1Path(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - fee: configured fee tier stored in the pool.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetFee(poolPath string) (uint32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Fee(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - balanceToken0: pool-held token0 balance in the token's smallest unit.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetBalanceToken0(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.BalanceToken0(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - balanceToken1: pool-held token1 balance in the token's smallest unit.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetBalanceToken1(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.BalanceToken1(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - tickSpacing: configured signed interval between usable initialized ticks.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetTickSpacing(poolPath string) (int32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.TickSpacing(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - maxLiquidity: decimal representation of the maximum liquidity permitted
//     at one tick for the pool's tick spacing.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetMaxLiquidityPerTick(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return calculateMaxLiquidityPerTick(pool.TickSpacing()).ToString(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - feeProtocol: packed token0/token1 protocol-fee denominator configuration
//     stored in slot0.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetSlot0FeeProtocol(poolPath string) (uint8, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Slot0FeeProtocol(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - unlocked: true when the pool's slot0 reentrancy lock is open.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetSlot0Unlocked(poolPath string) (bool, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return false, err
	}
	return pool.Slot0Unlocked(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - slot0: current pool price, tick, observation, and lock metadata; panics
//     when poolPath does not identify an existing pool.
func (i *poolV1) GetSlot0(poolPath string) pl.Slot0 {
	return i.mustGetPool(poolPath).Slot0()
}

// Parameters:
//   - poolPath: canonical pool identifier containing the observation ring.
//   - index: observation slot index; in-range unwritten slots return a default
//     observation, while indices at or above maxObservationCardinality error.
//
// Returns:
//   - observation: observation stored at index, or the default zero observation
//     for an in-range slot that has never been written.
//   - err: nil for a valid pool and index; a pool, observation, or range error
//     otherwise.
func (i *poolV1) GetObservationAt(poolPath string, index uint16) (pl.Observation, error) {
	if _, err := i.getPool(poolPath); err != nil {
		return pl.DefaultObservation(), err
	}

	// Uniswap's observations(uint256) getter is backed by a fixed-size array:
	// an in-range but never-written slot returns the zero observation, while an
	// out-of-range index reverts.
	if index >= maxObservationCardinality {
		return pl.DefaultObservation(), makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("observation index %d out of range", index))
	}

	observations, err := i.getObservations(poolPath)
	if err != nil {
		return pl.DefaultObservation(), err
	}

	observation, ok := observations.Get(index)
	if !ok {
		return pl.DefaultObservation(), nil
	}

	return observation, nil
}

// Observe returns the tick and seconds-per-liquidity cumulatives for each
// requested lookback. It reads the current block timestamp once and never
// writes an observation, matching Uniswap V3's view-only observe call.
// Parameters:
//   - poolPath: canonical pool identifier whose observation history is queried.
//   - secondsAgos: lookback durations in seconds; one cumulative pair is
//     produced for each entry, with zero meaning the current cumulative value.
//
// Returns:
//   - tickCumulatives: cumulative tick values aligned by index with secondsAgos.
//   - secondsPerLiquidityCumulativeX128s: cumulative seconds-per-liquidity
//     values aligned with secondsAgos and scaled by 2^128 as decimal strings.
//   - err: nil when every requested lookback can be resolved; an observation
//     history, epoch, cardinality, or interpolation error otherwise.
func (i *poolV1) Observe(poolPath string, secondsAgos []uint32) ([]int64, []string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, nil, err
	}

	observations, err := i.getObservations(poolPath)
	if err != nil {
		return nil, nil, err
	}

	slot0 := pool.Slot0()
	return observe(
		observations,
		time.Now().Unix(),
		secondsAgos,
		slot0.Tick(),
		slot0.ObservationIndex(),
		pool.Liquidity(),
		slot0.ObservationCardinality(),
	)
}

// SnapshotCumulativesInside returns the oracle accumulators that accrued while
// the pool price was inside [tickLower, tickUpper).
// Parameters:
//   - poolPath: canonical pool identifier whose oracle accumulators are queried.
//   - tickLower: inclusive lower tick boundary of the range.
//   - tickUpper: exclusive upper tick boundary of the range.
//
// Returns:
//   - tickCumulativeInside: cumulative tick value accrued while price was
//     inside [tickLower, tickUpper).
//   - secondsPerLiquidityInsideX128: seconds-per-liquidity accumulator accrued
//     inside the range, scaled by 2^128.
//   - secondsInside: number of seconds during which price was inside the range.
//   - err: nil when bounds, boundary ticks, and observations are valid; the
//     corresponding validation or observation error otherwise.
func (i *poolV1) SnapshotCumulativesInside(
	poolPath string,
	tickLower int32,
	tickUpper int32,
) (int64, *u256.Uint, uint32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, nil, 0, err
	}

	observations, err := i.getObservations(poolPath)
	if err != nil {
		return 0, nil, 0, err
	}

	return snapshotCumulativesInside(pool, observations, tickLower, tickUpper)
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - feeGrowthGlobal0X128: global token0 fee-growth accumulator scaled by 2^128.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetFeeGrowthGlobal0X128(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.FeeGrowthGlobal0X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - feeGrowthGlobal1X128: global token1 fee-growth accumulator scaled by 2^128.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetFeeGrowthGlobal1X128(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.FeeGrowthGlobal1X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - protocolFeesToken0: protocol fees accrued in token0's smallest unit.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetProtocolFeesToken0(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.ProtocolFeesToken0(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - protocolFeesToken1: protocol fees accrued in token1's smallest unit.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetProtocolFeesToken1(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.ProtocolFeesToken1(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - liquidity: current active pool liquidity as a u256 integer.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetLiquidity(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.Liquidity(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - position: pointer to a copy of the stored position information; panics
//     when the pool or position is absent or has an unexpected type.
func (i *poolV1) MustGetPosition(poolPath, key string) *pl.PositionInfo {
	pool := i.mustGetPool(poolPath)

	positions := pool.Positions()

	result := positions.Get(key)
	if result == nil {
		panic(newErrorWithDetail(
			errDataNotFound,
			ufmt.Sprintf("expected position(%s) to exist", key),
		))
	}

	position, ok := result.(pl.PositionInfo)
	if !ok {
		panic("failed to cast position to PositionInfo")
	}

	return &position
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - feeGrowthInside0LastX128: token0 fee-growth-inside value last accounted
//     for the position, encoded as a decimal integer scaled by 2^128.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionFeeGrowthInside0LastX128(poolPath, key string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return "", err
	}
	return position.FeeGrowthInside0LastX128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - feeGrowthInside1LastX128: token1 fee-growth-inside value last accounted
//     for the position, encoded as a decimal integer scaled by 2^128.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionFeeGrowthInside1LastX128(poolPath, key string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return "", err
	}
	return position.FeeGrowthInside1LastX128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - tokensOwed0: token0 fees owed to the position in token0's smallest unit.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionTokensOwed0(poolPath, key string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return 0, err
	}
	return position.TokensOwed0(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - tokensOwed1: token1 fees owed to the position in token1's smallest unit.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionTokensOwed1(poolPath, key string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return 0, err
	}
	return position.TokensOwed1(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose gross liquidity is requested.
//
// Returns:
//   - liquidityGross: total liquidity referencing the tick, encoded as a decimal
//     integer string.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickLiquidityGross(poolPath string, tick int32) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", err
	}
	return tickInfo.LiquidityGross(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose net liquidity change is requested.
//
// Returns:
//   - liquidityNet: signed net liquidity change applied when crossing the tick,
//     encoded as a decimal integer string.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickLiquidityNet(poolPath string, tick int32) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", err
	}
	return tickInfo.LiquidityNet(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose token0 fee-growth-outside value is requested.
//
// Returns:
//   - feeGrowthOutside0X128: token0 fee-growth-outside accumulator scaled by
//     2^128, encoded as a decimal string.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickFeeGrowthOutside0X128(poolPath string, tick int32) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", err
	}
	return tickInfo.FeeGrowthOutside0X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose token1 fee-growth-outside value is requested.
//
// Returns:
//   - feeGrowthOutside1X128: token1 fee-growth-outside accumulator scaled by
//     2^128, encoded as a decimal string.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickFeeGrowthOutside1X128(poolPath string, tick int32) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", err
	}
	return tickInfo.FeeGrowthOutside1X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose token fee-growth-outside values are requested.
//
// Returns:
//   - feeGrowthOutside0X128: token0 fee-growth-outside accumulator scaled by 2^128,
//     encoded as a decimal string.
//   - feeGrowthOutside1X128: token1 fee-growth-outside accumulator scaled by 2^128,
//     encoded as a decimal string.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (string, string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", "", err
	}

	return tickInfo.FeeGrowthOutside0X128(), tickInfo.FeeGrowthOutside1X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose cumulative tick-outside value is requested.
//
// Returns:
//   - tickCumulativeOutside: cumulative tick value recorded outside the tick's
//     active range.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickCumulativeOutside(poolPath string, tick int32) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return 0, err
	}
	return tickInfo.TickCumulativeOutside(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose seconds-per-liquidity accumulator is
//     requested.
//
// Returns:
//   - secondsPerLiquidityOutsideX128: seconds-per-liquidity-outside accumulator
//     encoded as a decimal integer scaled by 2^128.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return "", err
	}
	return tickInfo.SecondsPerLiquidityOutsideX128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose seconds-outside accumulator is requested.
//
// Returns:
//   - secondsOutside: seconds elapsed outside the tick's side of the active
//     range, as recorded by the pool.
//   - err: nil when pool and tick exist; the lookup error otherwise.
func (i *poolV1) GetTickSecondsOutside(poolPath string, tick int32) (uint32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return 0, err
	}
	return tickInfo.SecondsOutside(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose initialization flag is requested.
//
// Returns:
//   - initialized: true when the tick has been initialized in the pool.
//   - err: nil when pool and tick can be read; the lookup error otherwise.
func (i *poolV1) GetTickInitialized(poolPath string, tick int32) (bool, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return false, err
	}

	tickInfo, err := pool.GetTick(tick)
	if err != nil {
		return false, err
	}
	return tickInfo.Initialized(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - tick: current signed slot0 tick.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetSlot0Tick(poolPath string) (int32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Slot0Tick(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - sqrtPriceX96: current square-root price as a u256 Q64.96 integer.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetSlot0SqrtPriceX96(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.Slot0SqrtPriceX96(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier to look up.
//
// Returns:
//   - feeGrowthGlobal0X128: global token0 fee-growth accumulator scaled by 2^128.
//   - feeGrowthGlobal1X128: global token1 fee-growth accumulator scaled by 2^128.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, nil, err
	}
	return pool.FeeGrowthGlobal0X128(), pool.FeeGrowthGlobal1X128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - feeGrowthInside0LastX128: token0 fee-growth-inside value last accounted
//     for the position, encoded as a decimal integer scaled by 2^128.
//   - feeGrowthInside1LastX128: token1 fee-growth-inside value last accounted
//     for the position, encoded as a decimal integer scaled by 2^128.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionFeeGrowthInsideLastX128(poolPath, key string) (string, string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", "", err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return "", "", err
	}
	return position.FeeGrowthInside0LastX128(),
		position.FeeGrowthInside1LastX128(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier containing the position.
//   - key: position key identifying its lower and upper tick range.
//
// Returns:
//   - liquidity: position liquidity encoded as a decimal integer string.
//   - err: nil when pool and position exist; the lookup error otherwise.
func (i *poolV1) GetPositionLiquidity(poolPath, key string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	position, err := pool.GetPosition(key)
	if err != nil {
		return "", err
	}
	return position.Liquidity(), nil
}

// Parameters:
//   - poolPath: canonical pool identifier whose existence is checked.
//
// Returns:
//   - exists: true when the pool tree contains poolPath.
func (i *poolV1) ExistsPoolPath(poolPath string) bool {
	pools := i.store.GetPools()
	return pools.Has(poolPath)
}

// Returns:
//   - poolCreationFee: configured pool-creation charge in the chain's smallest
//     currency unit.
func (i *poolV1) GetPoolCreationFee() int64 {
	return i.store.GetPoolCreationFee()
}

// Returns:
//   - withdrawalFeeBPS: configured withdrawal fee in basis points, where 100
//     basis points equals one percent.
func (i *poolV1) GetWithdrawalFee() uint64 {
	return i.store.GetWithdrawalFeeBPS()
}

// OracleConsult returns the time-weighted average price for a pool over a specified period.
//
// Parameters:
//   - poolPath: canonical pool identifier whose observations are consulted.
//   - secondsAgo: lookback duration in seconds for the time-weighted query.
//
// Returns:
//   - arithmeticMeanTick: arithmetic mean tick over the requested lookback.
//   - harmonicMeanLiquidity: harmonic mean active liquidity as a u256 integer.
//   - err: nil when the pool history covers secondsAgo; an observation or
//     lookback error otherwise.
func (i *poolV1) OracleConsult(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, nil, err
	}

	observations, err := i.getObservations(poolPath)
	if err != nil {
		return 0, nil, err
	}

	tick, liquidity, err := oracleConsult(pool, observations, secondsAgo)
	if err != nil {
		return 0, nil, err
	}

	return tick, liquidity, nil
}

// GetPools returns a read-only view of every pool, keyed by pool path.
// Callers paginate it themselves through IterateByOffset.
// Returns:
//   - pools: read-only tree keyed by canonical pool path; entries are exposed
//     through safe read-only wrappers and callers paginate the tree themselves.
func (i *poolV1) GetPools() *rotree.ReadOnlyTree {
	return rotree.Wrap(i.store.GetPools(), clonePoolEntry)
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
// Returns:
//   - feeAmountTickSpacings: copy of the configured fee-tier to tick-spacing
//     mapping.
func (i *poolV1) GetFeeAmountTickSpacings() map[uint32]int32 {
	return i.store.GetFeeAmountTickSpacing()
}

// GetPoolPositions returns a read-only view of a pool's positions, keyed by
// position key. Callers paginate it themselves through IterateByOffset.
// nil is returned when the pool does not exist.
// Parameters:
//   - poolPath: canonical pool identifier whose positions are exposed.
//
// Returns:
//   - positions: read-only tree keyed by position key, or nil when poolPath
//     does not identify an existing pool.
func (i *poolV1) GetPoolPositions(poolPath string) *rotree.ReadOnlyTree {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil
	}

	// makeEntrySafeFn is a function that makes an entry safe to read.
	// But PositionInfo is immutable, so we can just return the entry as is.
	return rotree.Wrap(pool.Positions(), nil)
}

// Tick enumeration

// GetInitializedTicksInRange returns initialized ticks within the given range.
// Parameters:
//   - poolPath: canonical pool identifier whose initialized ticks are listed.
//   - tickLower: inclusive lower tick bound for enumeration.
//   - tickUpper: inclusive upper tick bound for enumeration.
//
// Returns:
//   - ticks: initialized tick indices in the requested inclusive range, in
//     encoded tree order; empty when no ticks are initialized there.
//   - err: nil when the pool exists; the pool lookup error otherwise.
func (i *poolV1) GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) ([]int32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}

	ticks := make([]int32, 0)

	pool.IterateTicks(tickLower, tickUpper, func(tick int32, _ pl.TickInfo) bool {
		ticks = append(ticks, tick)
		return false
	})

	return ticks, nil
}

// Structure getters

// GetTickInfo returns the tick info for a given tick.
// Parameters:
//   - poolPath: canonical pool identifier containing the tick.
//   - tick: signed tick index whose full state is requested.
//
// Returns:
//   - tickInfo: initialized state and outside accumulators for tick.
//   - err: nil when the pool and tick can be read; the corresponding lookup
//     error otherwise.
func (i *poolV1) GetTickInfo(poolPath string, tick int32) (pl.TickInfo, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return pl.NewTickInfo(), err
	}

	return pool.GetTick(tick)
}

// GetTickBitmaps returns the tick bitmap for a given word position.
// Parameters:
//   - poolPath: canonical pool identifier whose bitmap map is queried.
//   - wordPos: signed bitmap-word position to retrieve.
//
// Returns:
//   - bitmap: decimal string encoding the initialized-tick bitmap word at
//     wordPos.
//   - err: nil when the pool and bitmap word exist; the pool lookup or missing
//     bitmap error otherwise.
func (i *poolV1) GetTickBitmaps(poolPath string, wordPos int16) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}

	tickBitmap, ok := pool.TickBitmaps()[wordPos]
	if !ok {
		return "", ufmt.Errorf("tick bitmap %d not found", wordPos)
	}

	return tickBitmap, nil
}
