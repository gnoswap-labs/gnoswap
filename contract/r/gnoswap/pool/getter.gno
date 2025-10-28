package pool

import u256 "gno.land/p/gnoswap/uint256"

// DrySwap proxies to the current pool implementation.
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

func ExistsPoolPath(poolPath string) bool {
	return getImplementation().ExistsPoolPath(poolPath)
}

func GetPool(token0Path, token1Path string, fee uint32) *Pool {
	pool := getImplementation().GetPool(token0Path, token1Path, fee)
	if pool == nil {
		return nil
	}

	return pool.Clone()
}

func GetBalanceToken0(poolPath string) string {
	return getImplementation().GetBalanceToken0(poolPath)
}

func GetBalanceToken1(poolPath string) string {
	return getImplementation().GetBalanceToken1(poolPath)
}

func GetFee(poolPath string) uint32 {
	return getImplementation().GetFee(poolPath)
}

func GetFeeAmountTickSpacing(fee uint32) (spacing int32) {
	return getImplementation().GetFeeAmountTickSpacing(fee)
}

func GetFeeGrowthGlobal0X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal0X128(poolPath)
}

func GetFeeGrowthGlobal1X128(poolPath string) string {
	return getImplementation().GetFeeGrowthGlobal1X128(poolPath)
}

func GetFeeGrowthGlobalX128(poolPath string) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetFeeGrowthGlobalX128(poolPath)
}

func GetLiquidity(poolPath string) string {
	return getImplementation().GetLiquidity(poolPath)
}

func GetMaxLiquidityPerTick(poolPath string) string {
	return getImplementation().GetMaxLiquidityPerTick(poolPath)
}

func GetObservation(poolPath string, secondsAgo int64) (tickCumulative int64, liquidityCumulative, secondsPerLiquidityCumulativeX128 string, blockTimestamp int64) {
	return getImplementation().GetObservation(poolPath, secondsAgo)
}

func GetPoolCreationFee() int64 {
	return getImplementation().GetPoolCreationFee()
}

func GetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside0LastX128(poolPath, key)
}

func GetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return getImplementation().GetPositionFeeGrowthInside1LastX128(poolPath, key)
}

func GetPositionFeeGrowthInsideLastX128(poolPath, key string) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetPositionFeeGrowthInsideLastX128(poolPath, key)
}

func GetPositionLiquidity(poolPath, key string) *u256.Uint {
	return getImplementation().GetPositionLiquidity(poolPath, key)
}

func GetPositionTokensOwed0(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed0(poolPath, key)
}

func GetPositionTokensOwed1(poolPath, key string) string {
	return getImplementation().GetPositionTokensOwed1(poolPath, key)
}

func GetProtocolFeesToken0(poolPath string) string {
	return getImplementation().GetProtocolFeesToken0(poolPath)
}

func GetProtocolFeesToken1(poolPath string) string {
	return getImplementation().GetProtocolFeesToken1(poolPath)
}

func GetSlot0FeeProtocol(poolPath string) uint8 {
	return getImplementation().GetSlot0FeeProtocol(poolPath)
}

func GetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	return getImplementation().GetSlot0SqrtPriceX96(poolPath)
}

func GetSlot0Tick(poolPath string) int32 {
	return getImplementation().GetSlot0Tick(poolPath)
}

func GetSlot0Unlocked(poolPath string) bool {
	return getImplementation().GetSlot0Unlocked(poolPath)
}

func GetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return getImplementation().GetTickCumulativeOutside(poolPath, tick)
}

func GetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside0X128(poolPath, tick)
}

func GetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return getImplementation().GetTickFeeGrowthOutside1X128(poolPath, tick)
}

func GetTickFeeGrowthOutsideX128(poolPath string, tick int32) (*u256.Uint, *u256.Uint) {
	return getImplementation().GetTickFeeGrowthOutsideX128(poolPath, tick)
}

func GetTickInitialized(poolPath string, tick int32) bool {
	return getImplementation().GetTickInitialized(poolPath, tick)
}

func GetTickLiquidityGross(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityGross(poolPath, tick)
}

func GetTickLiquidityNet(poolPath string, tick int32) string {
	return getImplementation().GetTickLiquidityNet(poolPath, tick)
}

func GetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return getImplementation().GetTickSecondsOutside(poolPath, tick)
}

func GetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return getImplementation().GetTickSecondsPerLiquidityOutsideX128(poolPath, tick)
}

func GetTickSpacing(poolPath string) int32 {
	return getImplementation().GetTickSpacing(poolPath)
}

func GetToken0Path(poolPath string) string {
	return getImplementation().GetToken0Path(poolPath)
}

func GetToken1Path(poolPath string) string {
	return getImplementation().GetToken1Path(poolPath)
}

func GetWithdrawalFee() uint64 {
	return getImplementation().GetWithdrawalFee()
}

func ApiGetPool(poolPath string) string {
	return getImplementation().ApiGetPool(poolPath)
}

func ApiGetTWAP(poolPath string, secondsAgo uint32) string {
	return getImplementation().ApiGetTWAP(poolPath, secondsAgo)
}
