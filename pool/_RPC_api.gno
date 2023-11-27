package pool

import (
	b64 "encoding/base64"

	"encoding/json"
	"strings"

	"gno.land/p/demo/ufmt"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetPools struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []string `json:"data"`
	} `json:"response"`
}

func ApiGetPools() string {
	poolPathList := []string{}

	for k, _ := range pools {
		poolPathList = append(poolPathList, k)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetPools{
		Stat: qb,
		Response: struct {
			Data []string `json:"data"`
		}{
			Data: poolPathList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__ApiGetPools() || %v", err))
	}

	return string(rr)
}

type ApiPositionInfo struct {
	Owner     string `json:"owner"`
	TickLower bigint `json:"tick_lower"`
	TickUpper bigint `json:"tick_upper"`

	Liquidity bigint `json:"liquidity"`
	T0Owed    bigint `json:"token0_owed"`
	T1Owed    bigint `json:"token1_owed"`
}

type SinglePool struct {
	PoolPath            string            `json:"pool_path"`
	Token0Path          string            `json:"token0_path"`
	Token1Path          string            `json:"token1_path"`
	Fee                 uint16            `json:"fee"`
	Token0Balance       bigint            `json:"token0_balance"`
	Token1Balance       bigint            `json:"token1_balance"`
	TickSpacing         int32             `json:"tick_spacing"`
	MaxLiquidityPerTick bigint            `json:"max_liquidity_per_tick"`
	SqrtPriceX96        bigint            `json:"sqrt_price_x96"` // slot0
	Tick                int32             `json:"tick"`           // slot0
	FeeProtocol         uint8             `json:"fee_protocol"`   // slot0
	T0ProtocolFee       bigint            `json:"token0_protocol_fee"`
	T1ProtocolFee       bigint            `json:"token1_protocol_fee"`
	Liquidity           bigint            `json:"liquidity"`
	Ticks               []int32           `json:"ticks"`
	TickBitmaps         map[int16]bigint  `json:"tick_bitmaps"`
	Positions           []ApiPositionInfo `json:"positions"`
}

type ResponseGetPool struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data SinglePool `json:"data"`
	} `json:"response"`
}

func ApiGetPool(key string) string {
	singlePool := handleSinglePool(key)

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetPool{
		Stat: qb,
		Response: struct {
			Data SinglePool `json:"data"`
		}{
			Data: singlePool,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__ApiGetPool() || %v", err))
	}

	return string(rr)
}

func posKeyDivide(posKey string) (string, bigint, bigint) {
	// base64 decode
	kDec, _ := b64.StdEncoding.DecodeString(posKey)
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic(ufmt.Sprintf("[POOL] getter_api.gno__posKeyDivide() || invalid posKey(%s)", posKey))
	}

	owner, tickLower, tickUpper := res[0], res[1], res[2]

	return owner, bigint(tickLower), bigint(tickUpper)
}

func handleSinglePool(poolPath string) SinglePool {
	pool, exist := pools[poolPath]
	if !exist {
		return SinglePool{}
	}

	ticks := pool.ticks
	tickList := []int32{}
	for k, _ := range ticks {
		tickList = append(tickList, k)
	}

	positions := pool.positions
	positionList := []ApiPositionInfo{}
	for k, v := range positions {
		owner, tl, th := posKeyDivide(k)

		posInfo := ApiPositionInfo{
			Owner:     owner,
			TickLower: tl,
			TickUpper: th,
			Liquidity: v.liquidity,
			T0Owed:    v.tokensOwed0,
			T1Owed:    v.tokensOwed1,
		}
		positionList = append(positionList, posInfo)
	}

	return SinglePool{
		PoolPath:            poolPath,
		Token0Path:          pool.token0Path,
		Token1Path:          pool.token1Path,
		Fee:                 pool.fee,
		Token0Balance:       pool.balances.token0,
		Token1Balance:       pool.balances.token1,
		TickSpacing:         pool.tickSpacing,
		MaxLiquidityPerTick: pool.maxLiquidityPerTick,
		SqrtPriceX96:        pool.slot0.sqrtPriceX96,
		Tick:                pool.slot0.tick,
		FeeProtocol:         pool.slot0.feeProtocol,
		T0ProtocolFee:       pool.protocolFees.token0,
		T1ProtocolFee:       pool.protocolFees.token1,
		Liquidity:           pool.liquidity,
		Ticks:               tickList,
		TickBitmaps:         pool.tickBitmaps,
		Positions:           positionList,
	}
}
