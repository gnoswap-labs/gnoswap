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
	return mustGetPool(poolPath).GetToken0Path()
}

func PoolGetToken1Path(poolPath string) string {
	return mustGetPool(poolPath).GetToken1Path()
}

func PoolGetFee(poolPath string) uint32 {
	return mustGetPool(poolPath).GetFee()
}

func PoolGetBalanceToken0(poolPath string) string {
	return mustGetPool(poolPath).GetBalanceToken0().ToString()
}

func PoolGetBalanceToken1(poolPath string) string {
	return mustGetPool(poolPath).GetBalanceToken1().ToString()
}

func PoolGetTickSpacing(poolPath string) int32 {
	return mustGetPool(poolPath).GetTickSpacing()
}

func PoolGetMaxLiquidityPerTick(poolPath string) string {
	return mustGetPool(poolPath).GetMaxLiquidityPerTick().ToString()
}

func PoolGetSlot0SqrtPriceX96(poolPath string) string {
	return mustGetPool(poolPath).GetSlot0SqrtPriceX96().ToString()
}

func PoolGetSlot0Tick(poolPath string) int32 {
	return mustGetPool(poolPath).GetSlot0Tick()
}

func PoolGetSlot0FeeProtocol(poolPath string) uint8 {
	return mustGetPool(poolPath).GetSlot0FeeProtocol()
}

func PoolGetSlot0Unlocked(poolPath string) bool {
	return mustGetPool(poolPath).GetSlot0Unlocked()
}

func PoolGetFeeGrowthGlobal0X128(poolPath string) string {
	return mustGetPool(poolPath).GetFeeGrowthGlobal0X128().ToString()
}

func PoolGetFeeGrowthGlobal1X128(poolPath string) string {
	return mustGetPool(poolPath).GetFeeGrowthGlobal1X128().ToString()
}

func PoolGetProtocolFeesToken0(poolPath string) string {
	return mustGetPool(poolPath).GetProtocolFeesToken0().ToString()
}

func PoolGetProtocolFeesToken1(poolPath string) string {
	return mustGetPool(poolPath).GetProtocolFeesToken1().ToString()
}

func PoolGetLiquidity(poolPath string) string {
	return mustGetPool(poolPath).GetLiquidity().ToString()
}

// position
func PoolGetPositionLiquidity(poolPath, key string) string {
	return mustGetPool(poolPath).GetPositionLiquidity(key).ToString()
}

func PoolGetPositionFeeGrowthInside0LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).GetPositionFeeGrowthInside0LastX128(key).ToString()
}

func PoolGetPositionFeeGrowthInside1LastX128(poolPath, key string) string {
	return mustGetPool(poolPath).GetPositionFeeGrowthInside1LastX128(key).ToString()
}

func PoolGetPositionTokensOwed0(poolPath, key string) string {
	return mustGetPool(poolPath).GetPositionTokensOwed0(key).ToString()
}

func PoolGetPositionTokensOwed1(poolPath, key string) string {
	return mustGetPool(poolPath).GetPositionTokensOwed1(key).ToString()
}

// tick
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
