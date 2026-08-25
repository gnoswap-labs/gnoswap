package pool

import (
	rotree "gno.land/p/nt/bptree/v0/rotree"
)

// GetPools returns a read-only view of every pool, keyed by pool path.
// Reading an entry yields a clone, so the view cannot mutate realm state.
func GetPools() *rotree.ReadOnlyTree {
	return getImplementation().GetPools()
}

// ExistsPoolPath checks if a pool exists at the given path.
func ExistsPoolPath(poolPath string) bool {
	return getImplementation().ExistsPoolPath(poolPath)
}

// GetBalances returns the balances of the pool.
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
func GetBalanceToken0(poolPath string) (int64, error) {
	return getImplementation().GetBalanceToken0(poolPath)
}

// GetBalanceToken1 returns the balance of token1 in the pool.
func GetBalanceToken1(poolPath string) (int64, error) {
	return getImplementation().GetBalanceToken1(poolPath)
}

// GetFee returns the fee tier of the pool.
func GetFee(poolPath string) (uint32, error) {
	return getImplementation().GetFee(poolPath)
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
func GetFeeAmountTickSpacings() map[uint32]int32 {
	return cloneFeeAmountTickSpacings(getImplementation().GetFeeAmountTickSpacings())
}

// GetFeeAmountTickSpacing returns the tick spacing for a given fee tier.
func GetFeeAmountTickSpacing(fee uint32) (spacing int32, err error) {
	return getImplementation().GetFeeAmountTickSpacing(fee)
}

// GetFeeGrowthGlobal0X128 returns the global fee growth for token0.
func GetFeeGrowthGlobal0X128(poolPath string) (string, error) {
	feeGrowth, err := getImplementation().GetFeeGrowthGlobal0X128(poolPath)
	if err != nil {
		return "", err
	}
	return feeGrowth.ToString(), nil
}

// GetFeeGrowthGlobal1X128 returns the global fee growth for token1.
func GetFeeGrowthGlobal1X128(poolPath string) (string, error) {
	feeGrowth, err := getImplementation().GetFeeGrowthGlobal1X128(poolPath)
	if err != nil {
		return "", err
	}
	return feeGrowth.ToString(), nil
}

// GetFeeGrowthGlobalX128 returns the global fee growth for both tokens.
func GetFeeGrowthGlobalX128(poolPath string) (string, string, error) {
	fg0, fg1, err := getImplementation().GetFeeGrowthGlobalX128(poolPath)
	if err != nil {
		return "", "", err
	}
	return fg0.ToString(), fg1.ToString(), nil
}

// GetLiquidity returns the current liquidity in the pool.
func GetLiquidity(poolPath string) (string, error) {
	liquidity, err := getImplementation().GetLiquidity(poolPath)
	if err != nil {
		return "", err
	}
	return liquidity.ToString(), nil
}

// GetLastObservation returns the most recent observation data for calculating time-weighted averages.
func GetLastObservation(poolPath string) (tickCumulative int64, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64, err error) {
	return getImplementation().GetLastObservation(poolPath)
}

// GetPoolCreationFee returns the current pool creation fee.
func GetPoolCreationFee() int64 {
	return getImplementation().GetPoolCreationFee()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
func GetPositionFeeGrowthInside0LastX128(poolPath, key string) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
func GetPositionFeeGrowthInside1LastX128(poolPath, key string) (string, error) {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (string, string, error) {
	return getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetPoolPositions returns a read-only view of a pool's positions, keyed by
// position key. nil is returned when the pool does not exist.
func GetPoolPositions(poolPath string) *rotree.ReadOnlyTree {
	return getImplementation().GetPoolPositions(poolPath)
}

// GetPositionLiquidity returns the liquidity of a position.
func GetPositionLiquidity(poolPath, key string) (string, error) {
	return getImplementation().GetPositionLiquidity(poolPath, key)
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
func GetPositionTokensOwed0(poolPath, key string) (int64, error) {
	return getImplementation().GetPositionTokensOwed0(poolPath, key)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
func GetPositionTokensOwed1(poolPath, key string) (int64, error) {
	return getImplementation().GetPositionTokensOwed1(poolPath, key)
}

// GetPositionTokensOwedInfos returns the amount of tokens owed for both tokens.
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
func GetProtocolFeesToken0(poolPath string) (int64, error) {
	return getImplementation().GetProtocolFeesToken0(poolPath)
}

// GetProtocolFeesToken1 returns accumulated protocol fees for token1.
func GetProtocolFeesToken1(poolPath string) (int64, error) {
	return getImplementation().GetProtocolFeesToken1(poolPath)
}

// GetProtocolFeesTokens returns the accumulated protocol fees for both tokens.
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
func GetSlot0FeeProtocol(poolPath string) (uint8, error) {
	return getImplementation().GetSlot0FeeProtocol(poolPath)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price from slot0.
func GetSlot0SqrtPriceX96(poolPath string) (string, error) {
	sqrtPriceX96, err := getImplementation().GetSlot0SqrtPriceX96(poolPath)
	if err != nil {
		return "", err
	}
	return sqrtPriceX96.ToString(), nil
}

// GetSlot0Tick returns the current tick from slot0.
func GetSlot0Tick(poolPath string) (int32, error) {
	return getImplementation().GetSlot0Tick(poolPath)
}

// GetSlot0Unlocked returns the locked status from slot0.
func GetSlot0Unlocked(poolPath string) (bool, error) {
	return getImplementation().GetSlot0Unlocked(poolPath)
}

// GetSlot0 returns a safe copy of the pool's slot0 (sqrt price, tick,
// protocol fee, lock state, and oracle cursor/capacity metadata).
// The clone happens here, at the proxy boundary, so every implementation
// version can return its internal Slot0 by value without each one having to
// remember to defend against callers mutating the shared sqrtPriceX96.
func GetSlot0(poolPath string) Slot0 {
	slot0 := getImplementation().GetSlot0(poolPath)
	return slot0.Clone()
}

// GetObservationAt returns a safe copy of the observation stored at index.
// An in-range but uninitialized slot returns the zero observation, matching
// Uniswap V3's fixed observation-array getter.
//
// ref: uniswap v3 IUniswapV3PoolState.observations(uint256 index)
func GetObservationAt(poolPath string, index uint16) (Observation, error) {
	observation, err := getImplementation().GetObservationAt(poolPath, index)
	if err != nil {
		return Observation{}, err
	}

	return *observation.Clone(), nil
}

// Observe returns the tick and seconds-per-liquidity cumulatives for each
// requested lookback, matching Uniswap V3's observe(uint32[] secondsAgos).
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

// GetTickCumulativeOutside returns the tick cumulative value outside a tick.
func GetTickCumulativeOutside(poolPath string, tick int32) (int64, error) {
	return getImplementation().GetTickCumulativeOutside(poolPath, tick)
}

// GetTickFeeGrowthOutside0X128 returns fee growth outside for token0 at a tick.
func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickFeeGrowthOutside0X128(poolPath, tick)
}

// GetTickFeeGrowthOutside1X128 returns fee growth outside for token1 at a tick.
func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickFeeGrowthOutside1X128(poolPath, tick)
}

// GetTickFeeGrowthOutsideX128 returns fee growth outside for both tokens at a tick.
func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (string, string, error) {
	return getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
}

// GetTickInitialized returns whether a tick is initialized.
func GetTickInitialized(poolPath string, tick int32) (bool, error) {
	return getImplementation().GetTickInitialized(poolPath, tick)
}

// GetInitializedTicksInRange returns initialized ticks within the given range.
func GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) ([]int32, error) {
	ticks, err := getImplementation().GetInitializedTicksInRange(poolPath, tickLower, tickUpper)
	if err != nil {
		return nil, err
	}
	return cloneInt32Slice(ticks), nil
}

// GetTickLiquidityGross returns the total liquidity that references a tick.
func GetTickLiquidityGross(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickLiquidityGross(poolPath, tick)
}

// GetTickLiquidityNet returns the net liquidity change at a tick.
func GetTickLiquidityNet(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickLiquidityNet(poolPath, tick)
}

// GetTickSecondsOutside returns seconds spent outside a tick.
func GetTickSecondsOutside(poolPath string, tick int32) (uint32, error) {
	return getImplementation().GetTickSecondsOutside(poolPath, tick)
}

// GetTickSecondsPerLiquidityOutsideX128 returns seconds per liquidity outside a tick.
func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) (string, error) {
	return getImplementation().GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

// GetTickSpacing returns the tick spacing of the pool.
func GetTickSpacing(poolPath string) (int32, error) {
	return getImplementation().GetTickSpacing(poolPath)
}

// GetToken0Path returns the path of token0 in the pool.
func GetToken0Path(poolPath string) (string, error) {
	return getImplementation().GetToken0Path(poolPath)
}

// GetToken1Path returns the path of token1 in the pool.
func GetToken1Path(poolPath string) (string, error) {
	return getImplementation().GetToken1Path(poolPath)
}

// GetWithdrawalFee returns the current withdrawal fee rate.
func GetWithdrawalFee() uint64 {
	return getImplementation().GetWithdrawalFee()
}

// GetTWAP returns the time-weighted average price for a pool.
// Returns arithmetic mean tick and harmonic mean liquidity over the time period.
func GetTWAP(poolPath string, secondsAgo uint32) (int32, string, error) {
	tick, liquidity, err := getImplementation().GetTWAP(poolPath, secondsAgo)
	if err != nil {
		return 0, "", err
	}
	return tick, liquidity.ToString(), nil
}

// Structure getters

// GetTickInfo returns the tick info for a given tick.
func GetTickInfo(poolPath string, tick int32) (TickInfo, error) {
	tickInfo, err := getImplementation().GetTickInfo(poolPath, tick)
	if err != nil {
		return TickInfo{}, err
	}

	return tickInfo.Clone(), nil
}

// GetTickBitmaps returns the tick bitmap for a given word position.
func GetTickBitmaps(poolPath string, wordPos int16) (string, error) {
	return getImplementation().GetTickBitmaps(poolPath, wordPos)
}

// GetPendingProtocolFees returns the pending protocol fee amount per token path.
func GetPendingProtocolFees() map[string]int64 {
	return cloneStringInt64Map(getImplementation().GetPendingProtocolFees())
}
