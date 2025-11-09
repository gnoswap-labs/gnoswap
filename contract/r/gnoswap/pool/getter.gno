package pool

import u256 "gno.land/p/gnoswap/uint256"

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

// ExistsPoolPath checks if a pool exists at the given path.
func ExistsPoolPath(poolPath string) bool {
	return getImplementation().ExistsPoolPath(poolPath)
}

// GetPool returns a copy of the pool for the given token pair and fee tier.
func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	pool := getImplementation().GetPool(token0Path, token1Path, fee)
	if pool == nil {
		return nil
	}

	return pool.Clone()
}

// GetBalanceToken0 returns the balance of token0 in the pool.
func GetBalanceToken0(poolPath string) string {
	return getImplementation().GetBalanceToken0(poolPath)
}

// GetBalanceToken1 returns the balance of token1 in the pool.
func GetBalanceToken1(poolPath string) string {
	return getImplementation().GetBalanceToken1(poolPath)
}

// GetFee returns the fee tier of the pool.
func GetFee(poolPath string) uint32 {
	return getImplementation().GetFee(poolPath)
}

// GetFeeAmountTickSpacing returns the tick spacing for a given fee tier.
func GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	return getImplementation().GetFeeAmountTickSpacing(fee)
}

// GetFeeGrowthGlobal0X128 returns the global fee growth for token0.
func GetFeeGrowthGlobal0X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal0X128(poolPath)
}

// GetFeeGrowthGlobal1X128 returns the global fee growth for token1.
func GetFeeGrowthGlobal1X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal1X128(poolPath)
}

// GetFeeGrowthGlobalX128 returns the global fee growth for both tokens.
func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetFeeGrowthGlobalX128(poolPath)
}

// GetLiquidity returns the current liquidity in the pool.
func GetLiquidity(poolPath string) string {
	return getImplementation().GetLiquidity(poolPath)
}

// GetMaxLiquidityPerTick returns the maximum liquidity per tick for the pool.
func GetMaxLiquidityPerTick(poolPath string) string {
	return getImplementation().GetMaxLiquidityPerTick(poolPath)
}

// GetObservation returns observation data for calculating time-weighted averages.
func GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64) {
	return getImplementation().GetObservation(poolPath, secondsAgo)
}

// GetPoolCreationFee returns the current pool creation fee.
func GetPoolCreationFee() int64 {
	return getImplementation().GetPoolCreationFee()
}

// GetPositionFeeGrowthInside0LastX128 returns the last recorded fee growth inside for token0.
func GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

// GetPositionFeeGrowthInside1LastX128 returns the last recorded fee growth inside for token1.
func GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

// GetPositionFeeGrowthInsideLastX128 returns the last recorded fee growth inside for both tokens.
func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

// GetPositionLiquidity returns the liquidity of a position.
func GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return getImplementation().GetPositionLiquidity(poolPath, key)
}

// GetPositionTokensOwed0 returns the amount of token0 owed to a position.
func GetPositionTokensOwed0(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed0(poolPath, key)
}

// GetPositionTokensOwed1 returns the amount of token1 owed to a position.
func GetPositionTokensOwed1(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed1(poolPath, key)
}

// GetProtocolFeesToken0 returns accumulated protocol fees for token0.
func GetProtocolFeesToken0(poolPath string) string {
	return getImplementation().GetProtocolFeesToken0(poolPath)
}

// GetProtocolFeesToken1 returns accumulated protocol fees for token1.
func GetProtocolFeesToken1(poolPath string) string {
	return getImplementation().GetProtocolFeesToken1(poolPath)
}

// GetSlot0FeeProtocol returns the protocol fee rate from slot0.
func GetSlot0FeeProtocol(poolPath string) uint8 {
	return getImplementation().GetSlot0FeeProtocol(poolPath)
}

// GetSlot0SqrtPriceX96 returns the current sqrt price from slot0.
func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return getImplementation().GetSlot0SqrtPriceX96(poolPath)
}

// GetSlot0Tick returns the current tick from slot0.
func GetSlot0Tick(poolPath string) int32 {
	return getImplementation().GetSlot0Tick(poolPath)
}

// GetSlot0Unlocked returns the locked status from slot0.
func GetSlot0Unlocked(poolPath string) bool {
	return getImplementation().GetSlot0Unlocked(poolPath)
}

// GetTickCumulativeOutside returns the tick cumulative value outside a tick.
func GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return getImplementation().GetTickCumulativeOutside(poolPath, tick)
}

// GetTickFeeGrowthOutside0X128 returns fee growth outside for token0 at a tick.
func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside0X128(poolPath, tick)
}

// GetTickFeeGrowthOutside1X128 returns fee growth outside for token1 at a tick.
func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside1X128(poolPath, tick)
}

// GetTickFeeGrowthOutsideX128 returns fee growth outside for both tokens at a tick.
func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
}

// GetTickInitialized returns whether a tick is initialized.
func GetTickInitialized(poolPath string, tick int32) bool {
	return getImplementation().GetTickInitialized(poolPath, tick)
}

// GetTickLiquidityGross returns the total liquidity that references a tick.
func GetTickLiquidityGross(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityGross(poolPath, tick)
}

// GetTickLiquidityNet returns the net liquidity change at a tick.
func GetTickLiquidityNet(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityNet(poolPath, tick)
}

// GetTickSecondsOutside returns seconds spent outside a tick.
func GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return getImplementation().GetTickSecondsOutside(poolPath, tick)
}

// GetTickSecondsPerLiquidityOutsideX128 returns seconds per liquidity outside a tick.
func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return getImplementation().GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

// GetTickSpacing returns the tick spacing of the pool.
func GetTickSpacing(poolPath string) int32 {
	return getImplementation().GetTickSpacing(poolPath)
}

// GetToken0Path returns the path of token0 in the pool.
func GetToken0Path(poolPath string) string {
	return getImplementation().GetToken0Path(poolPath)
}

// GetToken1Path returns the path of token1 in the pool.
func GetToken1Path(poolPath string) string {
	return getImplementation().GetToken1Path(poolPath)
}

// GetWithdrawalFee returns the current withdrawal fee rate.
func GetWithdrawalFee() uint64 {
	return getImplementation().GetWithdrawalFee()
}

// ApiGetPool returns pool information as JSON.
func ApiGetPool(poolPath string) string {
	return getImplementation().ApiGetPool(poolPath)
}

// ApiGetTWAP returns the time-weighted average price for a pool.
func ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return getImplementation().ApiGetTWAP(poolPath, secondsAgo)
}
