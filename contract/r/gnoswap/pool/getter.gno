package pool

import (
	u256 "gno.land/p/gnoswap/uint256"
)

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

// GetPoolCount returns the total number of pools.
//
// Returns:
//   - count: total number of pools
func GetPoolCount() int {
	return getImplementation().GetPoolCount()
}

// GetPoolPaths returns a paginated list of pool paths.
//
// Parameters:
//   - offset: starting index for pagination
//   - count: maximum number of pool paths to return
//
// Returns:
//   - poolPaths: pool paths for the requested page
func GetPoolPaths(offset, count int) []string {
	return getImplementation().GetPoolPaths(offset, count)
}

// ExistsPoolPath checks if a pool exists at the given path.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - exists: true if the pool exists
func ExistsPoolPath(poolPath string) bool {
	return getImplementation().ExistsPoolPath(poolPath)
}

// GetBalances returns the balances of the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - balance0: balance of token0
//   - balance1: balance of token1
func GetBalances(poolPath string) (string, string) {
	return getImplementation().GetBalanceToken0(poolPath), getImplementation().GetBalanceToken1(poolPath)
}

// GetBalanceToken0 returns the balance of token0 in the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - balance0: balance of token0
func GetBalanceToken0(poolPath string) string {
	return getImplementation().GetBalanceToken0(poolPath)
}

// GetBalanceToken1 returns the balance of token1 in the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - balance1: balance of token1
func GetBalanceToken1(poolPath string) string {
	return getImplementation().GetBalanceToken1(poolPath)
}

// GetFee returns the fee tier of the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - fee: pool fee tier
func GetFee(poolPath string) uint32 {
	return getImplementation().GetFee(poolPath)
}

// GetFeeAmountTickSpacings returns all fee tier to tick spacing mappings.
//
// Returns:
//   - feeAmountTickSpacings: mapping of fee tier to tick spacing
func GetFeeAmountTickSpacings() map[uint32]int32 {
	return getImplementation().GetFeeAmountTickSpacings()
}

// GetFeeAmountTickSpacing returns the tick spacing for a given fee tier.
//
// Parameters:
//   - fee: pool fee tier
//
// Returns:
//   - tickSpacing: tick spacing for the fee tier
func GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	return getImplementation().GetFeeAmountTickSpacing(fee)
}

// GetFeeGrowthGlobal0X128 returns the global fee growth for token0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - feeGrowthGlobal0X128: fee growth for token0 as Q128.128
func GetFeeGrowthGlobal0X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal0X128(poolPath)
}

// GetFeeGrowthGlobal1X128 returns the global fee growth for token1.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - feeGrowthGlobal1X128: fee growth for token1 as Q128.128
func GetFeeGrowthGlobal1X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal1X128(poolPath)
}

// GetFeeGrowthGlobalX128 returns the global fee growth for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - feeGrowthGlobal0X128: fee growth for token0 as Q128.128
//   - feeGrowthGlobal1X128: fee growth for token1 as Q128.128
func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	feeGrowthGlobal0, feeGrowthGlobal1 := getImplementation().GetFeeGrowthGlobalX128(poolPath)
	return feeGrowthGlobal0.Clone(), feeGrowthGlobal1.Clone()
}

// GetFeeGrowthGlobals returns the global fee growth for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - feeGrowthGlobal0X128: fee growth for token0 as Q128.128
//   - feeGrowthGlobal1X128: fee growth for token1 as Q128.128
func GetFeeGrowthGlobals(poolPath string) (string, string) {
	feeGrowthGlobal0, feeGrowthGlobal1 := getImplementation().GetFeeGrowthGlobalX128(poolPath)
	return feeGrowthGlobal0.ToString(), feeGrowthGlobal1.ToString()
}

// GetLiquidity returns the current liquidity in the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - liquidity: current liquidity as a decimal string
func GetLiquidity(poolPath string) string {
	return getImplementation().GetLiquidity(poolPath)
}

// GetMaxLiquidityPerTick returns the maximum liquidity per tick for the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - maxLiquidityPerTick: max liquidity per tick as a decimal string
func GetMaxLiquidityPerTick(poolPath string) string {
	return getImplementation().GetMaxLiquidityPerTick(poolPath)
}

// GetObservation returns observation data for calculating time-weighted averages.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - secondsAgo: time window to look back from current block timestamp
//
// Returns:
//   - tickCumulative: tick cumulative
//   - liquidityCumulative: liquidity cumulative
//   - secondsPerLiquidityCumulativeX128: seconds per liquidity cumulative (Q128.128)
//   - blockTimestamp: block timestamp of the observation
func GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64) {
	return getImplementation().GetObservation(poolPath, secondsAgo)
}

// GetPoolCreationFee returns the current pool creation fee.
//
// Returns:
//   - poolCreationFee: pool creation fee
func GetPoolCreationFee() int64 {
	return getImplementation().GetPoolCreationFee()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - feeGrowthInside0LastX128: fee growth for token0 inside the position
func GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - feeGrowthInside1LastX128: fee growth for token1 inside the position
func GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - feeGrowthInside0LastX128: fee growth for token0 inside the position
//   - feeGrowthInside1LastX128: fee growth for token1 inside the position
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	feeGrowthInside0, feeGrowthInside1 := getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
	return feeGrowthInside0.Clone(), feeGrowthInside1.Clone()
}

// GetPositionFeeGrowthInsideLasts returns the last recorded fee growth inside for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - feeGrowthInside0LastX128: fee growth for token0 inside the position
//   - feeGrowthInside1LastX128: fee growth for token1 inside the position
func GetPositionFeeGrowthInsideLasts(poolPath, key string) (string, string) {
	feeGrowthInside0, feeGrowthInside1 := getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
	return feeGrowthInside0.ToString(), feeGrowthInside1.ToString()
}

// GetPoolPositionCount returns the number of positions in a pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - count: number of positions in the pool
func GetPoolPositionCount(poolPath string) int {
	return getImplementation().GetPoolPositionCount(poolPath)
}

// GetPoolPositionKeys returns a paginated list of position keys in a pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - offset: starting index for pagination
//   - count: maximum number of keys to return
//
// Returns:
//   - keys: position keys for the requested page
func GetPoolPositionKeys(poolPath string, offset, count int) []string {
	return getImplementation().GetPoolPositionKeys(poolPath, offset, count)
}

// GetPositionLiquidity returns the liquidity of a position.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - liquidity: position liquidity
func GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return getImplementation().GetPositionLiquidity(poolPath, key)
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - tokensOwed0: amount of token0 owed to the position
func GetPositionTokensOwed0(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed0(poolPath, key)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - tokensOwed1: amount of token1 owed to the position
func GetPositionTokensOwed1(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed1(poolPath, key)
}

// GetPositionTokensOwed returns the amount of tokens owed for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - tokensOwed0: amount of token0 owed to the position
//   - tokensOwed1: amount of token1 owed to the position
func GetPositionTokensOwed(poolPath, key string) (string, string) {
	return getImplementation().GetPositionTokensOwed0(poolPath, key), getImplementation().GetPositionTokensOwed1(poolPath, key)
}

// GetProtocolFeesToken0 returns accumulated protocol fees for token0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - protocolFeesToken0: accumulated protocol fees for token0
func GetProtocolFeesToken0(poolPath string) string {
	return getImplementation().GetProtocolFeesToken0(poolPath)
}

// GetProtocolFeesToken1 returns accumulated protocol fees for token1.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - protocolFeesToken1: accumulated protocol fees for token1
func GetProtocolFeesToken1(poolPath string) string {
	return getImplementation().GetProtocolFeesToken1(poolPath)
}

// GetProtocolFeesTokens returns the accumulated protocol fees for both tokens.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - protocolFeesToken0: accumulated protocol fees for token0
//   - protocolFeesToken1: accumulated protocol fees for token1
func GetProtocolFeesTokens(poolPath string) (string, string) {
	return getImplementation().GetProtocolFeesToken0(poolPath), getImplementation().GetProtocolFeesToken1(poolPath)
}

// GetSlot0FeeProtocol returns the protocol fee rate from slot0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - feeProtocol: protocol fee rate packed in slot0
func GetSlot0FeeProtocol(poolPath string) uint8 {
	return getImplementation().GetSlot0FeeProtocol(poolPath)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price from slot0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - sqrtPriceX96: sqrt price in Q64.96 format
func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return getImplementation().GetSlot0SqrtPriceX96(poolPath)
}

// GetSlot0Tick returns the current tick from slot0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - tick: current tick
func GetSlot0Tick(poolPath string) int32 {
	return getImplementation().GetSlot0Tick(poolPath)
}

// GetSlot0Unlocked returns the locked status from slot0.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - unlocked: true if pool is unlocked
func GetSlot0Unlocked(poolPath string) bool {
	return getImplementation().GetSlot0Unlocked(poolPath)
}

// GetTickCumulativeOutside returns the tick cumulative value outside a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - tickCumulativeOutside: tick cumulative outside the tick
func GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return getImplementation().GetTickCumulativeOutside(poolPath, tick)
}

// GetTickFeeGrowthOutside0X128 returns fee growth outside for token0 at a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - feeGrowthOutside0X128: fee growth outside for token0 as Q128.128
func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside0X128(poolPath, tick)
}

// GetTickFeeGrowthOutside1X128 returns fee growth outside for token1 at a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - feeGrowthOutside1X128: fee growth outside for token1 as Q128.128
func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside1X128(poolPath, tick)
}

// GetTickFeeGrowthOutsideX128 returns fee growth outside for both tokens at a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - feeGrowthOutside0X128: fee growth outside for token0 as Q128.128
//   - feeGrowthOutside1X128: fee growth outside for token1 as Q128.128
func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	feeGrowthOutside0, feeGrowthOutside1 := getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
	return feeGrowthOutside0.Clone(), feeGrowthOutside1.Clone()
}

// GetTickFeeGrowthOutsides returns fee growth outside for both tokens at a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - feeGrowthOutside0X128: fee growth outside for token0 as Q128.128
//   - feeGrowthOutside1X128: fee growth outside for token1 as Q128.128
func GetTickFeeGrowthOutsides(poolPath string, tick int32) (string, string) {
	feeGrowthOutside0, feeGrowthOutside1 := getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
	return feeGrowthOutside0.ToString(), feeGrowthOutside1.ToString()
}

// GetTickInitialized returns whether a tick is initialized.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - initialized: true if the tick is initialized
func GetTickInitialized(poolPath string, tick int32) bool {
	return getImplementation().GetTickInitialized(poolPath, tick)
}

// GetInitializedTicksInRange returns initialized ticks within the given range.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tickLower: lower tick boundary
//   - tickUpper: upper tick boundary
//
// Returns:
//   - ticks: initialized tick indices within the range
func GetInitializedTicksInRange(poolPath string, tickLower, tickUpper int32) []int32 {
	return getImplementation().GetInitializedTicksInRange(poolPath, tickLower, tickUpper)
}

// GetTickLiquidityGross returns the total liquidity that references a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - liquidityGross: gross liquidity for the tick
func GetTickLiquidityGross(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityGross(poolPath, tick)
}

// GetTickLiquidityNet returns the net liquidity change at a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - liquidityNet: net liquidity change at the tick
func GetTickLiquidityNet(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityNet(poolPath, tick)
}

// GetTickSecondsOutside returns seconds spent outside a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - secondsOutside: seconds spent outside the tick
func GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return getImplementation().GetTickSecondsOutside(poolPath, tick)
}

// GetTickSecondsPerLiquidityOutsideX128 returns seconds per liquidity outside a tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - secondsPerLiquidityOutsideX128: seconds per liquidity outside the tick as Q128.128
func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return getImplementation().GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

// GetTickSpacing returns the tick spacing of the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - tickSpacing: tick spacing
func GetTickSpacing(poolPath string) int32 {
	return getImplementation().GetTickSpacing(poolPath)
}

// GetToken0Path returns the path of token0 in the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - token0Path: token0 path
func GetToken0Path(poolPath string) string {
	return getImplementation().GetToken0Path(poolPath)
}

// GetToken1Path returns the path of token1 in the pool.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - token1Path: token1 path
func GetToken1Path(poolPath string) string {
	return getImplementation().GetToken1Path(poolPath)
}

// GetWithdrawalFee returns the current withdrawal fee rate.
//
// Returns:
//   - withdrawalFee: withdrawal fee in basis points
func GetWithdrawalFee() uint64 {
	return getImplementation().GetWithdrawalFee()
}

// GetTWAP returns the time-weighted average price for a pool.
// Returns arithmetic mean tick and harmonic mean liquidity over the time period.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - secondsAgo: lookback window in seconds
//
// Returns:
//   - meanTick: arithmetic mean tick
//   - meanLiquidity: harmonic mean liquidity
//   - err: non-nil on failure
func GetTWAP(poolPath string, secondsAgo uint32) (int32, *u256.Uint, error) {
	return getImplementation().GetTWAP(poolPath, secondsAgo)
}

// Structure getters

// GetPool returns a copy of the pool for the given token pair and fee tier.
//
// Parameters:
//   - token0Path: path of the first token
//   - token1Path: path of the second token
//   - fee: pool fee tier
//
// Returns:
//   - pool: cloned pool state
//   - err: non-nil if the pool does not exist
func GetPool(token0Path, token1Path string, fee uint32) (*Pool, error) {
	pool, err := getImplementation().GetPool(token0Path, token1Path, fee)
	if err != nil {
		return nil, err
	}

	return pool.Clone(), nil
}

// GetTickInfo returns the tick info for a given tick.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - tick: tick index
//
// Returns:
//   - tickInfo: tick info copy
//   - err: non-nil if the tick cannot be loaded
func GetTickInfo(poolPath string, tick int32) (TickInfo, error) {
	tickInfo, err := getImplementation().GetTickInfo(poolPath, tick)
	if err != nil {
		return TickInfo{}, err
	}

	return cloneTickInfo(tickInfo), nil
}

// GetTickBitmaps returns the tick bitmap for a given word position.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - wordPos: bitmap word position
//
// Returns:
//   - tickBitmap: tick bitmap copy
//   - err: non-nil if the bitmap cannot be loaded
func GetTickBitmaps(poolPath string, wordPos int16) (*u256.Uint, error) {
	tickBitmap, err := getImplementation().GetTickBitmaps(poolPath, wordPos)
	if err != nil {
		return nil, err
	}

	return tickBitmap.Clone(), nil
}

// GetPosition returns the position info for a given key.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//   - key: position key
//
// Returns:
//   - positionInfo: position info copy
//   - err: non-nil if the position cannot be loaded
func GetPosition(poolPath, key string) (PositionInfo, error) {
	positionInfo, err := getImplementation().GetPosition(poolPath, key)
	if err != nil {
		return PositionInfo{}, err
	}

	return clonePositionInfo(positionInfo), nil
}

// GetObservationState returns the observation state for a given pool path.
//
// Parameters:
//   - poolPath: pool identifier in token0:token1:fee form
//
// Returns:
//   - observationState: observation state copy
//   - err: non-nil if the state cannot be loaded
func GetObservationState(poolPath string) (*ObservationState, error) {
	observationState, err := getImplementation().GetObservationState(poolPath)
	if err != nil {
		return nil, err
	}

	return observationState.Clone(), nil
}
