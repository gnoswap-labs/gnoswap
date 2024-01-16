package pool

import (
	"encoding/json"

	"gno.land/p/demo/ufmt"
)

func RpcGetPools() string {
	poolsDetail := []SinglePool{}

	for poolPath, pool := range pools {
		singlePool := handleSinglePool(poolPath)
		poolsDetail = append(poolsDetail, singlePool)
	}

	rr, err := json.Marshal(poolsDetail)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__RpcGetPools() || %v", err))
	}

	return string(rr)
}

func RpcMakePool(poolKey string) string {
	rpcPool := RpcPool{}
	pool := GetPoolFromPoolKey(poolKey)

	rpcPool.Token0Path = pool.token0Path
	rpcPool.Token1Path = pool.token1Path

	rpcPool.BalancesToken0 = pool.balances.token0
	rpcPool.BalancesToken1 = pool.balances.token1

	rpcPool.Fee = pool.fee

	rpcPool.TickSpacing = pool.tickSpacing

	rpcPool.MaxLiquidityPerTick = pool.maxLiquidityPerTick

	rpcPool.Slot0SqrtPriceX96 = pool.slot0.sqrtPriceX96
	rpcPool.Slot0Tick = pool.slot0.tick
	rpcPool.Slot0FeeProtocol = pool.slot0.feeProtocol
	rpcPool.Slot0Unlocked = pool.slot0.unlocked

	rpcPool.FeeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128
	rpcPool.FeeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128

	rpcPool.ProtocolFeesToken0 = pool.protocolFees.token0
	rpcPool.ProtocolFeesToken1 = pool.protocolFees.token1

	rpcPool.Liquidity = pool.liquidity

	rpcPool.Ticks = RpcTicks{}
	for tick, tickInfo := range pool.ticks {
		rpcPool.Ticks[tick] = RpcTickInfo{
			LiquidityGross:              tickInfo.liquidityGross,
			LiquidityNet:                tickInfo.liquidityNet,
			FeeGrowthOutside0X128:       tickInfo.feeGrowthOutside0X128,
			FeeGrowthOutside1X128:       tickInfo.feeGrowthOutside1X128,
			TickCumulativeOutside:       tickInfo.tickCumulativeOutside,
			SecondsPerLiquidityOutsideX: tickInfo.secondsPerLiquidityOutsideX128,
			SecondsOutside:              tickInfo.secondsOutside,
			Initialized:                 tickInfo.initialized,
		}
	}

	rpcPool.TickBitmaps = pool.tickBitmaps

	rr, err := json.Marshal(rpcPool)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__RpcMakePool() || %v", err))
	}

	return string(rr)
}

type RpcPool struct {
	Token0Path string `json:"token0_path"`
	Token1Path string `json:"token1_path"`

	BalancesToken0 bigint `json:"token0_balance"`
	BalancesToken1 bigint `json:"token1_balance"`

	// fee is the fee tier of the pool
	Fee uint16 `json:"fee"`

	// tickSpacing is the spacing between ticks
	TickSpacing int32 `json:"tick_spacing"`

	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	MaxLiquidityPerTick bigint `json:"max_liquidity_per_tick"`

	// slot0 is the current tick and price of the pool
	Slot0SqrtPriceX96 bigint `json:"sqrt_price_x96"`
	Slot0Tick         int32  `json:"tick"`
	Slot0FeeProtocol  uint8  `json:"fee_protocol"`
	Slot0Unlocked     bool   `json:"unlocked"`

	FeeGrowthGlobal0X128 bigint `json:"global0_fee_growth_x128"`
	FeeGrowthGlobal1X128 bigint `json:"global1_fee_growth_x128"`

	ProtocolFeesToken0 bigint `json:"token0_protocol_fee"`
	ProtocolFeesToken1 bigint `json:"token1_protocol_fee"`

	// liquidity is the total amount of liquidity in the pool
	Liquidity bigint `json:"liquidity"`

	// ticks is a mapping from tick index to tick
	Ticks RpcTicks `json:"ticks"`

	// tickBitmaps is a mapping from tick index to tick bitmap
	TickBitmaps TickBitmaps `json:"tick_bitmaps"`
}

type RpcTicks map[int32]RpcTickInfo // tick => RpcTickInfo
type RpcTickInfo struct {
	LiquidityGross bigint `json:"liquidity_gross"`
	LiquidityNet   bigint `json:"liquidity_net"`

	FeeGrowthOutside0X128 bigint `json:"outside0_fee_growth_x128"`
	FeeGrowthOutside1X128 bigint `json:"outside1_fee_growth_x128"`

	TickCumulativeOutside bigint `json:"tick_cumulative_outside"`

	SecondsPerLiquidityOutsideX bigint `json:"seconds_per_liquidity_outside_x"`
	SecondsOutside              bigint `json:"seconds_outside"`

	Initialized bool `json:"initialized"`
}
