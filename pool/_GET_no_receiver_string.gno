package pool

import (
	"gno.land/p/demo/ufmt"
)

// Balances
func PoolGetToken0BalanceStr(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetToken0BalanceStr() || pool(%s) does not exist", poolPath))
	}

	return pool.balances.token0.ToString()
}

func PoolGetToken1BalanceStr(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetToken1BalanceStr() || pool(%s) does not exist", poolPath))
	}

	return pool.balances.token1.ToString()
}

// ProtocolFees
func PoolGetToken0ProtocolFeeStr(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetToken0ProtocolFeeStr() || pool(%s) does not exist", poolPath))
	}

	return pool.protocolFees.token0.ToString()
}

func PoolGetToken1ProtocolFeeStr(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetToken1ProtocolFeeStr() || pool(%s) does not exist", poolPath))
	}

	return pool.protocolFees.token1.ToString()
}

// PositionInfo
func PoolGetPositionLiquidityStr(poolPath, key string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionLiquidityStr() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionLiquidityStr() || position(%s) does not exist", key))
	}

	return position.liquidity.ToString()
}

func PoolGetPositionFeeGrowthInside0LastX128Str(poolPath, key string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionFeeGrowthInside0LastX128Str() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionFeeGrowthInside0LastX128Str) || position(%s) does not exist", key))
	}

	return position.feeGrowthInside0LastX128.ToString()
}

func PoolGetPositionFeeGrowthInside1LastX128Str(poolPath, key string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionFeeGrowthInside1LastX128Str() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionFeeGrowthInside1LastX128Str() || position(%s) does not exist", key))
	}

	return position.feeGrowthInside1LastX128.ToString()
}

func PoolGetPositionTokensOwed0Str(poolPath, key string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionTokensOwed0Str() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionTokensOwed0Str() || position(%s) does not exist", key))
	}

	return position.tokensOwed0.ToString()
}

func PoolGetPositionTokensOwed1Str(poolPath, key string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionTokensOwed1Str() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetPositionTokensOwed1Str() || position(%s) does not exist", key))
	}

	return position.tokensOwed1.ToString()
}

// TickInfo
func PoolGetTickLiquidityGrossStr(poolPath string, x int32) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickLiquidityGrossStr() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickLiquidityGrossStr() || tick(%d) does not exist", x))
	}

	return tick.liquidityGross.ToString()
}

func PoolGetTickLiquidityNetStr(poolPath string, x int32) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickLiquidityNetStr() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickLiquidityNetStr() || tick(%d) does not exist", x))
	}

	return tick.liquidityNet.ToString()
}

func PoolGetTickFeeGrowthOutside0X128Str(poolPath string, x int32) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickFeeGrowthOutside0X128Str() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickFeeGrowthOutside0X128Str() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside0X128.ToString()
}

func PoolGetTickFeeGrowthOutside1X128Str(poolPath string, x int32) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickFeeGrowthOutside1X128Str() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickFeeGrowthOutside1X128Str() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside1X128.ToString()
}

func PoolGetTickSecondsPerLiquidityOutsideX128Str(poolPath string, x int32) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickSecondsPerLiquidityOutsideX128Str() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickSecondsPerLiquidityOutsideX128Str() || tick(%d) does not exist", x))
	}

	return tick.secondsPerLiquidityOutsideX128.ToString()
}

// TickBitmaps
func PoolGetTickBitmapStr(poolPath string, x int16) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickBitmapStr() || pool(%s) does not exist", poolPath))
	}

	tickBitmap, exist := pool.tickBitmaps[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetTickBitmapStr() || tickBitmap(%d) does not exist", x))
	}

	return tickBitmap.ToString()
}

// Pool
func PoolGetFeeGrowthGlobal0X128Str(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetFeeGrowthGlobal0X128Str() || pool(%s) does not exist", poolPath))
	}

	return pool.feeGrowthGlobal0X128.ToString()
}

func PoolGetFeeGrowthGlobal1X128Str(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetFeeGrowthGlobal1X128Str() || pool(%s) does not exist", poolPath))
	}

	return pool.feeGrowthGlobal1X128.ToString()
}

func PoolGetLiquidityStr(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL]_GET_no_receiver_string.gno__PoolGetLiquidityStr() || pool(%s) does not exist", poolPath))
	}

	return pool.liquidity.ToString()
}
