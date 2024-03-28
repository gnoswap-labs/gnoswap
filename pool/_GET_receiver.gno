package pool

import (
	"gno.land/p/demo/ufmt"

	i256 "gno.land/p/demo/int256"
	u256 "gno.land/p/demo/uint256"
)

// PoolGetPoolList returns a list of all pool paths
func PoolGetPoolList() []string {
	poolPaths := []string{}
	for poolPath, _ := range pools {
		poolPaths = append(poolPaths, poolPath)
	}

	return poolPaths
}

// Slot0
func (pool *Pool) PoolGetSlot0() Slot0 {
	return pool.slot0
}

func (pool *Pool) PoolGetSlot0SqrtPriceX96() *u256.Uint {
	return pool.slot0.sqrtPriceX96
}

func (pool *Pool) PoolGetSlot0Tick() int32 {
	return pool.slot0.tick
}

func (pool *Pool) PoolGetSlot0FeeProtocol() uint8 {
	return pool.slot0.feeProtocol
}

// Balances
func (pool *Pool) PoolGetToken0Balance() *u256.Uint {
	return pool.balances.token0
}

func (pool *Pool) PoolGetToken1Balance() *u256.Uint {
	return pool.balances.token1
}

// ProtocolFees
func (pool *Pool) PoolGetToken0ProtocolFee() *u256.Uint {
	return pool.protocolFees.token0
}

func (pool *Pool) PoolGetToken1ProtocolFee() *u256.Uint {
	return pool.protocolFees.token1
}

// PositionInfo
func (pool *Pool) PoolGetPositions() Positions {
	return pool.positions
}

func (pool *Pool) PoolGetPosition(key string) PositionInfo {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPosition() || position(%s) does not exist", key))
	}

	return position
}

func (pool *Pool) PoolGetPositionLiquidity(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPositionLiquidity() || position(%s) does not exist", key))
	}

	return position.liquidity
}

func (pool *Pool) PoolGetPositionFeeGrowthInside0LastX128(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPositionFeeGrowthInside0LastX128) || position(%s) does not exist", key))
	}

	return position.feeGrowthInside0LastX128
}

func (pool *Pool) PoolGetPositionFeeGrowthInside1LastX128(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPositionFeeGrowthInside1LastX128() || position(%s) does not exist", key))
	}

	return position.feeGrowthInside1LastX128
}

func (pool *Pool) PoolGetPositionTokensOwed0(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPositionTokensOwed0() || position(%s) does not exist", key))
	}

	return position.tokensOwed0
}

func (pool *Pool) PoolGetPositionTokensOwed1(key string) *u256.Uint {
	position, exist := pool.positions[key]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetPositionTokensOwed1() || position(%s) does not exist", key))
	}

	return position.tokensOwed1
}

// TickInfo
func (pool *Pool) PoolGetTick(x int32) TickInfo {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTick() || tick(%d) does not exist", x))
	}

	return tick
}

func (pool *Pool) PoolGetTickLiquidityGross(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickLiquidityGross() || tick(%d) does not exist", x))
	}

	return tick.liquidityGross
}

func (pool *Pool) PoolGetTickLiquidityNet(x int32) *i256.Int {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickLiquidityNet() || tick(%d) does not exist", x))
	}

	return tick.liquidityNet
}

func (pool *Pool) PoolGetTickFeeGrowthOutside0X128(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickFeeGrowthOutside0X128() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside0X128
}

func (pool *Pool) PoolGetTickFeeGrowthOutside1X128(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickFeeGrowthOutside1X128() || tick(%d) does not exist", x))
	}

	return tick.feeGrowthOutside1X128
}

func (pool *Pool) PoolGetTickTickCumulativeOutside(x int32) int64 {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickTickCumulativeOutside() || tick(%d) does not exist", x))
	}

	return tick.tickCumulativeOutside
}

func (pool *Pool) PoolGetTickSecondsPerLiquidityOutsideX128(x int32) *u256.Uint {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickSecondsPerLiquidityOutsideX128() || tick(%d) does not exist", x))
	}

	return tick.secondsPerLiquidityOutsideX128
}

func (pool *Pool) PoolGetTickSecondsOutside(x int32) uint32 {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickSecondsOutside() || tick(%d) does not exist", x))
	}

	return tick.secondsOutside
}

func (pool *Pool) PoolGetTickInitialized(x int32) bool {
	tick, exist := pool.ticks[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickInitialized() || tick(%d) does not exist", x))
	}

	return tick.initialized
}

// TickBitmaps
func (pool *Pool) PoolGetTickBitmap(x int16) *u256.Uint {
	tickBitmap, exist := pool.tickBitmaps[x]
	if !exist {
		panic(ufmt.Sprintf("[POOL] _GET_receiver.gno__PoolGetTickBitmap() || tickBitmap(%d) does not exist", x))
	}

	return tickBitmap
}

// Pool
func (pool *Pool) PoolGetToken0Path() string {
	return pool.token0Path
}

func (pool *Pool) PoolGetToken1Path() string {
	return pool.token1Path
}

func (pool *Pool) PoolGetFee() uint32 {
	return pool.fee
}

func (pool *Pool) PoolGetTickSpacing() int32 {
	return pool.tickSpacing
}

func (pool *Pool) PoolGetFeeGrowthGlobal0X128() *u256.Uint {
	return pool.feeGrowthGlobal0X128
}

func (pool *Pool) PoolGetFeeGrowthGlobal1X128() *u256.Uint {
	return pool.feeGrowthGlobal1X128
}

func (pool *Pool) PoolGetLiquidity() *u256.Uint {
	return pool.liquidity
}
