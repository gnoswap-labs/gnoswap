package pool

import (
	b64 "encoding/base64"
	"encoding/json"
	"strings"

	"gno.land/p/demo/ufmt"
)

type RpcPool struct {
	PoolPath string `json:"poolPath"`

	Token0Path string `json:"token0Path"`
	Token1Path string `json:"token1Path"`

	BalancesToken0 bigint `json:"balanceToken0"`
	BalancesToken1 bigint `json:"balanceToken1"`

	// fee is the fee tier of the pool
	Fee uint16 `json:"fee"`

	// tickSpacing is the spacing between ticks
	TickSpacing int32 `json:"tickSpacing"`

	// maxLiquidityPerTick is the maximum amount of liquidity that can be added per tick
	MaxLiquidityPerTick bigint `json:"maxLiquidityPerTick"`

	// slot0 is the current tick and price of the pool
	Slot0SqrtPriceX96 bigint `json:"sqrtPriceX96"`
	Slot0Tick         int32  `json:"tick"`
	Slot0FeeProtocol  uint8  `json:"feeProtocol"`
	Slot0Unlocked     bool   `json:"unlocked"`

	FeeGrowthGlobal0X128 bigint `json:"feeGrowthGlobal0X128"`
	FeeGrowthGlobal1X128 bigint `json:"feeGrowthGlobal1X128"`

	ProtocolFeesToken0 bigint `json:"protocolFeeToken0"`
	ProtocolFeesToken1 bigint `json:"protocolFeeToken1"`

	// liquidity is the total amount of liquidity in the pool
	Liquidity bigint `json:"liquidity"`

	// ticks is a mapping from tick index to tick
	Ticks RpcTicks `json:"ticks"`

	// tickBitmaps is a mapping from tick index to tick bitmap
	TickBitmaps TickBitmaps `json:"tickBitmaps"`

	Positions []RpcPosition `json:"positions"`
}

type RpcTicks map[int32]RpcTickInfo // tick => RpcTickInfo

type RpcTickInfo struct {
	LiquidityGross bigint `json:"liquidityGross"`
	LiquidityNet   bigint `json:"liquidityNet"`

	FeeGrowthOutside0X128 bigint `json:"feeGrowthOutside0X128"`
	FeeGrowthOutside1X128 bigint `json:"feeGrowthOutside1X128"`

	TickCumulativeOutside bigint `json:"tickCumulativeOutside"`

	SecondsPerLiquidityOutsideX bigint `json:"secondsPerLiquidityOutsideX"`
	SecondsOutside              bigint `json:"secondsOutside"`

	Initialized bool `json:"initialized"`
}

type RpcPosition struct {
	Owner string `json:"owner"`

	TickLower bigint `json:"tickLower"`
	TickUpper bigint `json:"tickUpper"`

	Liquidity bigint `json:"liquidity"`

	Token0Owed bigint `json:"token0Owed"`
	Token1Owed bigint `json:"token1Owed"`
}

type ResponseQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseApiGetPools struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []RpcPool         `json:"response"`
}

func ApiGetPools() string {
	rpcPools := []RpcPool{}
	for poolPath, _ := range pools {
		rpcPool := rpcMakePool(poolPath)
		rpcPools = append(rpcPools, rpcPool)
	}

	r := ResponseApiGetPools{
		Stat: ResponseQueryBase{
			Height:    GetHeight(),
			Timestamp: GetTimestamp(),
		},
		Response: rpcPools,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] _RPC_api.gno__ApiGetPools() || %v", err))
	}

	return string(rr)
}

func rpcMakePool(poolPath string) RpcPool {
	rpcPool := RpcPool{}
	pool := GetPoolFromPoolPath(poolPath)

	rpcPool.PoolPath = poolPath

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

	Positions := pool.positions
	rpcPositions := []RpcPosition{}
	for posKey, posInfo := range Positions {
		owner, tickLower, tickUpper := posKeyDivide(posKey)

		rpcPositions = append(rpcPositions, RpcPosition{
			Owner:      owner,
			TickLower:  tickLower,
			TickUpper:  tickUpper,
			Liquidity:  posInfo.liquidity,
			Token0Owed: posInfo.tokensOwed0,
			Token1Owed: posInfo.tokensOwed1,
		})
	}
	rpcPool.Positions = rpcPositions

	return rpcPool
}

func posKeyDivide(posKey string) (string, bigint, bigint) {
	// base64 decode
	kDec, _ := b64.StdEncoding.DecodeString(posKey)
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POOL] _RPC_api.gno__posKeyDivide() || invalid posKey(%s)", posKey))
	}

	owner, tickLower, tickUpper := res[0], res[1], res[2]

	return owner, bigint(tickLower), bigint(tickUpper)
}
