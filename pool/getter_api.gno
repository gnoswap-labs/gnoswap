// EXTERNAL API
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
	T0Bal               bigint `json:"token0_balance"`
	T1Bal               bigint `json:"token1_balance"`
	TickSpacing         int32  `json:"tick_spacing"`
	MaxLiquidityPerTick bigint `json:"max_liquidity_per_tick"`
	SqrtPriceX96        bigint `json:"sqrt_price_x96"`
	Tick                int32  `json:"tick"`
	Liquidity           bigint `json:"liquidity"`
	Position            []ApiPositionInfo
}

type ResponseGetPool struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data SinglePool `json:"data"`
	} `json:"response"`
}

func ApiGetPool(key string) string {
	pool, exist := pools[key]
	if !exist {
		return "NO_POOL_FOUND"
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

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetPool{
		Stat: qb,
		Response: struct {
			Data SinglePool `json:"data"`
		}{
			Data: SinglePool{
				T0Bal:               pool.balances.token0,
				T1Bal:               pool.balances.token1,
				TickSpacing:         pool.tickSpacing,
				MaxLiquidityPerTick: pool.maxLiquidityPerTick,
				SqrtPriceX96:        pool.slot0.sqrtPriceX96,
				Tick:                pool.slot0.tick,
				Liquidity:           pool.liquidity,
				Position:            positionList,
			},
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
