package pool

// pool
func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

func PoolGetToken0Path(poolPath string) string {
	return mustGetPool(poolPath).PoolGetToken0Path()
}

func PoolGetToken1Path(poolPath string) string {
	return mustGetPool(poolPath).PoolGetToken1Path()
}

func PoolGetFee(poolPath string) uint32 {
	return mustGetPool(poolPath).PoolGetFee()
}

func PoolGetBalanceToken0(poolPath string) string {
	return mustGetPool(poolPath).PoolGetBalanceToken0().ToString()
}

func PoolGetBalanceToken1(poolPath string) string {
	return mustGetPool(poolPath).PoolGetBalanceToken1().ToString()
}

func PoolGetTickSpacing(poolPath string) int32 {
	return mustGetPool(poolPath).PoolGetTickSpacing()
}

func PoolGetMaxLiquidityPerTick(poolPath string) string {
	return mustGetPool(poolPath).PoolGetMaxLiquidityPerTick().ToString()
}

func PoolGetSlot0SqrtPriceX96(poolPath string) string {
	return mustGetPool(poolPath).PoolGetSlot0SqrtPriceX96().ToString()
}

func PoolGetSlot0Tick(poolPath string) int32 {
	return mustGetPool(poolPath).PoolGetSlot0Tick()
}

func PoolGetSlot0FeeProtocol(poolPath string) uint8 {
	return mustGetPool(poolPath).PoolGetSlot0FeeProtocol()
}

func PoolGetSlot0Unlocked(poolPath string) bool {
	return mustGetPool(poolPath).PoolGetSlot0Unlocked()
}

func PoolGetFeeGrowthGlobal0X128(poolPath string) string {
	return mustGetPool(poolPath).PoolGetFeeGrowthGlobal0X128().ToString()
}

func PoolGetFeeGrowthGlobal1X128(poolPath string) string {
	return mustGetPool(poolPath).PoolGetFeeGrowthGlobal1X128().ToString()
}

func PoolGetProtocolFeesToken0(poolPath string) string {
	return mustGetPool(poolPath).PoolGetProtocolFeesToken0().ToString()
}

func PoolGetProtocolFeesToken1(poolPath string) string {
	return mustGetPool(poolPath).PoolGetProtocolFeesToken1().ToString()
}

func PoolGetLiquidity(poolPath string) string {
	return mustGetPool(poolPath).PoolGetLiquidity().ToString()
}

// position
func PoolGetPositionLiquidity(poolPath, key string) string {
	return mustGetPool(poolPath).PoolGetPositionLiquidity(key).ToString()
}

func PoolGetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PoolGetPositionFeeGrowthInside0LastX128(key).ToString()
}

func PoolGetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).PoolGetPositionFeeGrowthInside1LastX128(key).ToString()
}

func PoolGetPositionTokensOwed0(poolPath, key string) string {
	return mustGetPool(poolPath).PoolGetPositionTokensOwed0(key).ToString()
}

func PoolGetPositionTokensOwed1(poolPath, key string) string {
	return mustGetPool(poolPath).PoolGetPositionTokensOwed1(key).ToString()
}

// tick
func PoolGetTickLiquidityGross(poolPath string, tick int32) string {
	return mustGetPool(poolPath).PoolGetTickLiquidityGross(tick).ToString()
}

func PoolGetTickLiquidityNet(poolPath string, tick int32) string {
	return mustGetPool(poolPath).PoolGetTickLiquidityNet(tick).ToString()
}

func PoolGetTickFeeGrowthOutside0X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).PoolGetTickFeeGrowthOutside0X128(tick).ToString()
}

func PoolGetTickFeeGrowthOutside1X128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).PoolGetTickFeeGrowthOutside1X128(tick).ToString()
}

func PoolGetTickCumulativeOutside(poolPath string, tick int32) int64 {
	return mustGetPool(poolPath).PoolGetTickCumulativeOutside(tick)
}

func PoolGetTickSecondsPerLiquidityOutsideX128(poolPath string, tick int32) string {
	return mustGetPool(poolPath).PoolGetTickSecondsPerLiquidityOutsideX128(tick).ToString()
}

func PoolGetTickSecondsOutside(poolPath string, tick int32) uint32 {
	return mustGetPool(poolPath).PoolGetTickSecondsOutside(tick)
}

func PoolGetTickInitialized(poolPath string, tick int32) bool {
	return mustGetPool(poolPath).PoolGetTickInitialized(tick)
}
