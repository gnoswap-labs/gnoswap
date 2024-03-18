package pool

import (
	b64 "encoding/base64"
	"encoding/json"
	"std"
	"strconv"
	"strings"
	"time"

	"gno.land/p/demo/ufmt"
)

type RpcPool struct {
	PoolPath string `json:"poolPath"`

	Token0Path string `json:"token0Path"`
	Token1Path string `json:"token1Path"`

	BalancesToken0 string `json:"balanceToken0"`
	BalancesToken1 string `json:"balanceToken1"`

	Fee uint32 `json:"fee"`

	TickSpacing int32 `json:"tickSpacing"`

	MaxLiquidityPerTick string `json:"maxLiquidityPerTick"`

	Slot0SqrtPriceX96 string `json:"sqrtPriceX96"`
	Slot0Tick         int32  `json:"tick"`
	Slot0FeeProtocol  uint8  `json:"feeProtocol"`
	Slot0Unlocked     bool   `json:"unlocked"`

	FeeGrowthGlobal0X128 string `json:"feeGrowthGlobal0X128"`
	FeeGrowthGlobal1X128 string `json:"feeGrowthGlobal1X128"`

	ProtocolFeesToken0 string `json:"protocolFeeToken0"`
	ProtocolFeesToken1 string `json:"protocolFeeToken1"`

	Liquidity string `json:"liquidity"`

	Ticks RpcTicks `json:"ticks"`

	TickBitmaps RpcTickBitmaps `json:"tickBitmaps"`

	Positions []RpcPosition `json:"positions"`
}

type RpcTickBitmaps map[int16]string // tick(wordPos) => bitmap(tickWord ^ mask)

type RpcTicks map[int32]RpcTickInfo // tick => RpcTickInfo

type RpcTickInfo struct {
	LiquidityGross string `json:"liquidityGross"`
	LiquidityNet   string `json:"liquidityNet"`

	FeeGrowthOutside0X128 string `json:"feeGrowthOutside0X128"`
	FeeGrowthOutside1X128 string `json:"feeGrowthOutside1X128"`

	TickCumulativeOutside int64 `json:"tickCumulativeOutside"`

	SecondsPerLiquidityOutsideX string `json:"secondsPerLiquidityOutsideX"`
	SecondsOutside              uint32 `json:"secondsOutside"`

	Initialized bool `json:"initialized"`
}

type RpcPosition struct {
	Owner string `json:"owner"`

	TickLower int32 `json:"tickLower"`
	TickUpper int32 `json:"tickUpper"`

	Liquidity string `json:"liquidity"`

	Token0Owed string `json:"token0Owed"`
	Token1Owed string `json:"token1Owed"`
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
			Height:    std.GetHeight(),
			Timestamp: time.Now().Unix(),
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

	rpcPool.BalancesToken0 = pool.balances.token0.ToString()
	rpcPool.BalancesToken1 = pool.balances.token1.ToString()

	rpcPool.Fee = pool.fee

	rpcPool.TickSpacing = pool.tickSpacing

	rpcPool.MaxLiquidityPerTick = pool.maxLiquidityPerTick.ToString()

	rpcPool.Slot0SqrtPriceX96 = pool.slot0.sqrtPriceX96.ToString()
	rpcPool.Slot0Tick = pool.slot0.tick
	rpcPool.Slot0FeeProtocol = pool.slot0.feeProtocol
	rpcPool.Slot0Unlocked = pool.slot0.unlocked

	rpcPool.FeeGrowthGlobal0X128 = pool.feeGrowthGlobal0X128.ToString()
	rpcPool.FeeGrowthGlobal1X128 = pool.feeGrowthGlobal1X128.ToString()

	rpcPool.ProtocolFeesToken0 = pool.protocolFees.token0.ToString()
	rpcPool.ProtocolFeesToken1 = pool.protocolFees.token1.ToString()

	rpcPool.Liquidity = pool.liquidity.ToString()

	rpcPool.Ticks = RpcTicks{}
	for tick, tickInfo := range pool.ticks {
		rpcPool.Ticks[tick] = RpcTickInfo{
			LiquidityGross:              tickInfo.liquidityGross.ToString(),
			LiquidityNet:                tickInfo.liquidityNet.ToString(),
			FeeGrowthOutside0X128:       tickInfo.feeGrowthOutside0X128.ToString(),
			FeeGrowthOutside1X128:       tickInfo.feeGrowthOutside1X128.ToString(),
			TickCumulativeOutside:       tickInfo.tickCumulativeOutside,
			SecondsPerLiquidityOutsideX: tickInfo.secondsPerLiquidityOutsideX128.ToString(),
			SecondsOutside:              tickInfo.secondsOutside,
			Initialized:                 tickInfo.initialized,
		}
	}

	rpcPool.TickBitmaps = RpcTickBitmaps{}
	for tick, tickBitmap := range pool.tickBitmaps {
		rpcPool.TickBitmaps[tick] = tickBitmap.ToString()
	}

	Positions := pool.positions
	rpcPositions := []RpcPosition{}
	for posKey, posInfo := range Positions {
		owner, tickLower, tickUpper := posKeyDivide(posKey)

		rpcPositions = append(rpcPositions, RpcPosition{
			Owner:      owner,
			TickLower:  tickLower,
			TickUpper:  tickUpper,
			Liquidity:  posInfo.liquidity.ToString(),
			Token0Owed: posInfo.tokensOwed0.ToString(),
			Token1Owed: posInfo.tokensOwed1.ToString(),
		})
	}
	rpcPool.Positions = rpcPositions

	return rpcPool
}

func posKeyDivide(posKey string) (string, int32, int32) {
	// base64 decode
	kDec, _ := b64.StdEncoding.DecodeString(posKey)
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POOL] _RPC_api.gno__posKeyDivide() || invalid posKey(%s)", posKey))
	}

	owner, _tickLower, _tickUpper := res[0], res[1], res[2]

	tickLower, _ := strconv.Atoi(_tickLower)
	tickUpper, _ := strconv.Atoi(_tickUpper)

	return owner, int32(tickLower), int32(tickUpper)
}
