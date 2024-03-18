package pool

import (
	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/demo/big/int256"
	u256 "gno.land/p/demo/big/uint256"
)

func PoolGetSlot0SqrtPriceX96(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetSlot0SqrtPriceX96() || pool(%s) does not exist", poolPath))
	}

	return pool.slot0.sqrtPriceX96
}

func PoolGetSlot0Tick(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetSlot0Tick() || pool(%s) does not exist", poolPath))
	}

	return pool.slot0.tick
}

func PoolGetSlot0FeeProtocol(poolPath string) uint8 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetSlot0FeeProtocol() || pool(%s) does not exist", poolPath))
	}

	return pool.slot0.feeProtocol
}

func PoolGetToken0Balance(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken0Balance() || pool(%s) does not exist", poolPath))
	}

	return pool.balances.token0
}

func PoolGetToken1Balance(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken1Balance() || pool(%s) does not exist", poolPath))
	}

	return pool.balances.token1
}

func PoolGetToken0ProtocolFee(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken0ProtocolFee() || pool(%s) does not exist", poolPath))
	}

	return pool.protocolFees.token0
}

func PoolGetToken1ProtocolFee(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken1ProtocolFee() || pool(%s) does not exist", poolPath))
	}

	return pool.protocolFees.token1
}

func PoolGetPositionLiquidity(poolPath, key string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionLiquidity() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionLiquidity() || position(%s) does not exist", key))
	}

	return position.liquidity
}

func PoolGetPositionFeeGrowthInside0LastX128(poolPath, key string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionFeeGrowthInside0LastX128() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionFeeGrowthInside0LastX128) || position(%s) does not exist", key))
	}

	return position.feeGrowthInside0LastX128
}

func PoolGetPositionFeeGrowthInside1LastX128(poolPath, key string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionFeeGrowthInside1LastX128() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionFeeGrowthInside1LastX128() || position(%s) does not exist", key))
	}

	return position.feeGrowthInside1LastX128
}

func PoolGetPositionTokensOwed0(poolPath, key string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionTokensOwed0() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionTokensOwed0() || position(%s) does not exist", key))
	}

	return position.tokensOwed0
}

func PoolGetPositionTokensOwed1(poolPath, key string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionTokensOwed1() || pool(%s) does not exist", poolPath))
	}

	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetPositionTokensOwed1() || position(%s) does not exist", key))
	}

	return position.tokensOwed1
}

func PoolGetTickLiquidityGross(poolPath string, x int32) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickLiquidityGross() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickLiquidityGross() || tick(%d) does not exist", x))
	}

	return tick.liquidityGross
}

func PoolGetTickLiquidityNet(poolPath string, x int32) *i256.Int {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickLiquidityNet() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickLiquidityNet() || tick(%d) does not exist", x))
	}

	return tick.liquidityNet
}

func PoolGetTickFeeGrowthOutside0X128(poolPath string, x int32) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickFeeGrowthOutside0X128() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickFeeGrowthOutside0X128() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside0X128
}

func PoolGetTickFeeGrowthOutside1X128(poolPath string, x int32) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickFeeGrowthOutside1X128() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickFeeGrowthOutside1X128() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside1X128
}

func PoolGetTickTickCumulativeOutside(poolPath string, x int32) int64 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickTickCumulativeOutside() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickTickCumulativeOutside() || tick(%d) does not exist", x))
	}

	return tick.tickCumulativeOutside
}

func PoolGetTickSecondsPerLiquidityOutsideX128(poolPath string, x int32) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickSecondsPerLiquidityOutsideX128() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickSecondsPerLiquidityOutsideX128() || tick(%d) does not exist", x))
	}

	return tick.secondsPerLiquidityOutsideX128
}

func PoolGetTickSecondsOutside(poolPath string, x int32) uint32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickSecondsOutside() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickSecondsOutside() || tick(%d) does not exist", x))
	}

	return tick.secondsOutside
}

func PoolGetTickInitialized(poolPath string, x int32) bool {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickInitialized() || pool(%s) does not exist", poolPath))
	}

	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickInitialized() || tick(%d) does not exist", x))
	}

	return tick.initialized
}

func PoolGetTickBitmap(poolPath string, x int16) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickBitmap() || pool(%s) does not exist", poolPath))
	}

	tickBitmap, exist := pool.tickBitmaps[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickBitmap() || tickBitmap(%d) does not exist", x))
	}

	return tickBitmap
}

func PoolGetToken0Path(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken0Path() || pool(%s) does not exist", poolPath))
	}

	return pool.token0Path
}

func PoolGetToken1Path(poolPath string) string {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetToken1Path() || pool(%s) does not exist", poolPath))
	}

	return pool.token1Path
}

func PoolGetFee(poolPath string) uint32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetFee() || pool(%s) does not exist", poolPath))
	}

	return pool.fee
}

func PoolGetTickSpacing(poolPath string) int32 {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetTickSpacing() || pool(%s) does not exist", poolPath))
	}

	return pool.tickSpacing
}

func PoolGetFeeGrowthGlobal0X128(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetFeeGrowthGlobal0X128() || pool(%s) does not exist", poolPath))
	}

	return pool.feeGrowthGlobal0X128
}

func PoolGetFeeGrowthGlobal1X128(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetFeeGrowthGlobal1X128() || pool(%s) does not exist", poolPath))
	}

	return pool.feeGrowthGlobal1X128
}

func PoolGetLiquidity(poolPath string) *u256.Uint {
	pool, exist := pools[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_no_receiver.gno__PoolGetLiquidity() || pool(%s) does not exist", poolPath))
	}

	return pool.liquidity
}
