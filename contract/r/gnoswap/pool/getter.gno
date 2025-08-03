package pool

import "time"

func PoolGetPoolList() []string {
	poolPaths := []string{}
	pools.Iterate("", "", func(poolPath string, _ any) bool {
		poolPaths = append(poolPaths, poolPath)

		return false
	})

	return poolPaths
}

func PoolGetToken0Path(poolPath string) string {
	return mustGetPool(poolPath).Token0Path()
}

func PoolGetToken1Path(poolPath string) string {
	return mustGetPool(poolPath).Token1Path()
}

func PoolGetFee(poolPath string) uint32 {
	return mustGetPool(poolPath).Fee()
}

func PoolGetBalanceToken0(poolPath string) string {
	return mustGetPool(poolPath).BalanceToken0().ToString()
}

func PoolGetBalanceToken1(poolPath string) string {
	return mustGetPool(poolPath).BalanceToken1().ToString()
}

func PoolGetTickSpacing(poolPath string) int32 {
	return mustGetPool(poolPath).TickSpacing()
}

func PoolGetMaxLiquidityPerTick(poolPath string) string {
	return mustGetPool(poolPath).MaxLiquidityPerTick().ToString()
}

func PoolGetSlot0SqrtPriceX96(poolPath string) string {
	return mustGetPool(poolPath).Slot0SqrtPriceX96().ToString()
}

func PoolGetSlot0Tick(poolPath string) int32 {
	return mustGetPool(poolPath).Slot0Tick()
}

func PoolGetSlot0FeeProtocol(poolPath string) uint8 {
	return mustGetPool(poolPath).Slot0FeeProtocol()
}

func PoolGetSlot0Unlocked(poolPath string) bool {
	return mustGetPool(poolPath).Slot0Unlocked()
}

func PoolGetFeeGrowthGlobal0X128(poolPath string) string {
	return mustGetPool(poolPath).FeeGrowthGlobal0X128().ToString()
}

func PoolGetFeeGrowthGlobal1X128(poolPath string) string {
	return mustGetPool(poolPath).FeeGrowthGlobal1X128().ToString()
}

func PoolGetProtocolFeesToken0(poolPath string) string {
	return mustGetPool(poolPath).ProtocolFeesToken0().ToString()
}

func PoolGetProtocolFeesToken1(poolPath string) string {
	return mustGetPool(poolPath).ProtocolFeesToken1().ToString()
}

func PoolGetLiquidity(poolPath string) string {
	return mustGetPool(poolPath).Liquidity().ToString()
}

func PoolGetPositionLiquidity(poolPath, key string) string {
	return mustGetPool(poolPath).PositionLiquidity(key).ToString()
}

func PoolGetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PositionFeeGrowthInside0LastX128(key).ToString()
}

func PoolGetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PositionFeeGrowthInside1LastX128(key).ToString()
}

func PoolGetPositionTokensOwed0(poolPath, key string) string {
	return mustGetPool(poolPath).PositionTokensOwed0(key).ToString()
}

func PoolGetPositionTokensOwed1(poolPath, key string) string {
	return mustGetPool(poolPath).PositionTokensOwed1(key).ToString()
}

func PoolGetTickLiquidityGross(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickLiquidityGross(tick).ToString()
}

func PoolGetTickLiquidityNet(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickLiquidityNet(tick).ToString()
}

func PoolGetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickFeeGrowthOutside0X128(tick).ToString()
}

func PoolGetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickFeeGrowthOutside1X128(tick).ToString()
}

func PoolGetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return mustGetPool(poolPath).GetTickCumulativeOutside(tick)
}

func PoolGetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).GetTickSecondsPerLiquidityOutsideX128(tick).ToString()
}

func PoolGetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return mustGetPool(poolPath).GetTickSecondsOutside(tick)
}

func PoolGetTickInitialized(poolPath string, tick int32) bool {
	return mustGetPool(poolPath).GetTickInitialized(tick)
}

// TWAP related getter functions
func GetPriceObserve(poolPath string, secondsAgo int64) string {
	pool := mustGetPool(poolPath)
	currentTime := time.Now().Unix()
	twapPrice, err := pool.observe(secondsAgo, currentTime)
	if err != nil {
		return "0"
	}
	return twapPrice.ToString()
}

func GetSlot0PriceOracle(poolPath string) (int64, string, string) {
	pool := mustGetPool(poolPath)
	currentTime := time.Now().Unix()
	lastCumulativeUpdateTime, sqrtPriceCumulativeX96, liquidityCumulative := pool.slot0PriceOracle(currentTime)
	return lastCumulativeUpdateTime, sqrtPriceCumulativeX96.ToString(), liquidityCumulative.ToString()
} 