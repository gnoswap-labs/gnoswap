package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
	rotree "gno.land/p/nt/bptree/v0/rotree"
	ufmt "gno.land/p/nt/ufmt/v0"
	pl "gno.land/r/gnoswap/pool"
)

// GetPoolPath generates a unique pool path string based on the token paths and fee tier.
func GetPoolPath(token0Path, token1Path string, fee uint32) string {
	return pl.GetPoolPath(token0Path, token1Path, fee)
}

// GetFeeAmountTickSpacing retrieves the tick spacing associated with a given fee amount.
func (i *poolV1) GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error) {
	feeAmountTickSpacing := i.store.GetFeeAmountTickSpacing()

	spacing, exist := feeAmountTickSpacing[fee]
	if !exist {
		return 0, ufmt.Errorf("%s", newErrorWithDetail(
			errUnsupportedFeeTier,
			ufmt.Sprintf("expected fee(%d) to be one of %d, %d, %d, %d", fee, FeeTier100, FeeTier500, FeeTier3000, FeeTier10000),
		))
	}

	return spacing, nil
}

func (i *poolV1) GetToken0Path(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return pool.Token0Path(), nil
}

func (i *poolV1) GetToken1Path(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return pool.Token1Path(), nil
}

func (i *poolV1) GetFee(poolPath string) (uint32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Fee(), nil
}

func (i *poolV1) GetBalanceToken0(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.BalanceToken0(), nil
}

func (i *poolV1) GetBalanceToken1(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.BalanceToken1(), nil
}

func (i *poolV1) GetTickSpacing(poolPath string) (int32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.TickSpacing(), nil
}

func (i *poolV1) GetMaxLiquidityPerTick(poolPath string) (string, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return "", err
	}
	return calculateMaxLiquidityPerTick(pool.TickSpacing()).ToString(), nil
}

func (i *poolV1) GetSlot0FeeProtocol(poolPath string) (uint8, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Slot0FeeProtocol(), nil
}

func (i *poolV1) GetSlot0Unlocked(poolPath string) (bool, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return false, err
	}
	return pool.Slot0Unlocked(), nil
}

func (i *poolV1) GetFeeGrowthGlobal0X128(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.FeeGrowthGlobal0X128(), nil
}

func (i *poolV1) GetFeeGrowthGlobal1X128(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.FeeGrowthGlobal1X128(), nil
}

func (i *poolV1) GetProtocolFeesToken0(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.ProtocolFeesToken0(), nil
}

func (i *poolV1) GetProtocolFeesToken1(poolPath string) (int64, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.ProtocolFeesToken1(), nil
}

func (i *poolV1) GetLiquidity(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.Liquidity(), nil
}

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

func (i *poolV1) GetSlot0Tick(poolPath string) (int32, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, err
	}
	return pool.Slot0Tick(), nil
}

func (i *poolV1) GetSlot0SqrtPriceX96(poolPath string) (*u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}
	return pool.Slot0SqrtPriceX96(), nil
}

func (i *poolV1) GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, nil, err
	}
	return pool.FeeGrowthGlobal0X128(), pool.FeeGrowthGlobal1X128(), nil
}

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

func (i *poolV1) ExistsPoolPath(poolPath string) bool {
	pools := i.store.GetPools()
	return pools.Has(poolPath)
}

func (i *poolV1) GetLastObservation(poolPath string) (
	tickCumulative int64,
	secondsPerLiquidityCumulativeX128 string,
	blockTimestamp int64,
	err error,
) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, "", 0, err
	}
	observationState := pool.ObservationState()

	if observationState == nil {
		return 0, "0", 0, nil
	}

	lastObservation, err := lastObservation(observationState)
	if err != nil {
		return 0, "0", 0, nil
	}

	tickCumulative = lastObservation.TickCumulative()
	secondsPerLiquidityCumulativeX128 = lastObservation.SecondsPerLiquidityCumulativeX128()
	blockTimestamp = lastObservation.BlockTimestamp()

	return tickCumulative, secondsPerLiquidityCumulativeX128, blockTimestamp, nil
}

func (i *poolV1) GetPoolCreationFee() int64 {
	return i.store.GetPoolCreationFee()
}

func (i *poolV1) GetWithdrawalFee() uint64 {
	return i.store.GetWithdrawalFeeBPS()
}

// GetTWAP returns the time-weighted average price for a pool over a specified period
//
// Parameters:
//   - poolPath: The path of the pool (e.g., "gno.land/r/demo/bar:gno.land/r/demo/foo:500")
//   - secondsAgo: Number of seconds ago to calculate TWAP from
//
// Returns TWAP tick and error
func (i *poolV1) GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return 0, nil, err
	}

	tick, liquidity, err := getTWAP(pool, secondsAgo)
	if err != nil {
		return 0, nil, err
	}

	return tick, liquidity, nil
}

// GetPools returns a read-only view of every pool, keyed by pool path.
// Callers paginate it themselves through IterateByOffset.
func (i *poolV1) GetPools() *rotree.ReadOnlyTree {
	return rotree.Wrap(i.store.GetPools(), clonePoolEntry)
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
func (i *poolV1) GetFeeAmountTickSpacings() map[uint32]int32 {
	return i.store.GetFeeAmountTickSpacing()
}

// GetPoolPositions returns a read-only view of a pool's positions, keyed by
// position key. Callers paginate it themselves through IterateByOffset.
// nil is returned when the pool does not exist.
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
func (i *poolV1) GetTickInfo(poolPath string, tick int32) (pl.TickInfo, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return pl.NewTickInfo(), err
	}

	return pool.GetTick(tick)
}

// GetTickBitmaps returns the tick bitmap for a given word position.
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

// GetObservationState returns the observation state for a pool.
func (i *poolV1) GetObservationState(poolPath string) (*pl.ObservationState, error) {
	pool, err := i.getPool(poolPath)
	if err != nil {
		return nil, err
	}

	observationState := pool.ObservationState()
	if observationState == nil {
		return nil, makeErrorWithDetails(errDataNotFound, ufmt.Sprintf("observation state not found for pool %s", poolPath))
	}

	return observationState, nil
}
