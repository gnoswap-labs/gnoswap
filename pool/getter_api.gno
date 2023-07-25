// EXTERNAL API
package gnoswap

import (
	b64 "encoding/base64"
	"encoding/json"
	"std"
	"strings"

	"gno.land/p/demo/grc/grc20"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetPools struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Length int      `json:"length"`
		Data   []string `json:"data"`
	} `json:"response"`
}

func ApiGetPools() string {
	poolSize := pools.Size()
	poolList := []string{}

	for i := 0; i < poolSize; i++ {
		pk, _ := pools.GetByIndex(i)
		poolList = append(poolList, pk)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetPools{
		Stat: qb,
		Response: struct {
			Length int      `json:"length"`
			Data   []string `json:"data"`
		}{
			Length: poolSize,
			Data:   poolList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetPools")
		panic(err)
	}

	return string(rr)
}

type ApiPositionInfo struct {
	Owner     string `json:"owner"`
	TickLower bigint `json:"tick_lower"`
	TickUpper bigint `json:"tick_upper"`

	Liquidity bigint `json:"liquidity"`
	// FeeGrowthInside0LastX128 bigint
	// FeeGrowthInside1LastX128 bigint
	T0Owed bigint `json:"token0_owed"`
	T1Owed bigint `json:"token1_owed"`
}

type SinglePool struct {
	// T0Name string `json:"token0_name"`
	// T1Name string `json:"token1_name"`
	T0Bal bigint `json:"token0_balance"`
	T1Bal bigint `json:"token1_balance"`
	// Fee                 bigint `json:"fee"`
	TickSpacing         bigint `json:"tick_spacing"`
	MaxLiquidityPerTick bigint `json:"max_liquidity_per_tick"`
	// slot0               Slot0  `json:"slot0"`
	// protocolFees ProtocolFees `json:"protocol_fees"`
	Liquidity bigint `json:"liquidity"`
	Position  []ApiPositionInfo
}

type ResponseGetPool struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data SinglePool `json:"data"`
	} `json:"response"`
}

func ApiGetPool(key string) string {
	_p, exists := pools.Get(key) // value interface{}, exists bool
	if !exists {
		// that key does not exist
		return ""
	}

	p := _p.(*Pool)
	_positions := p.positions
	posSize := _positions.Size()
	posList := []ApiPositionInfo{}

	for i := 0; i < posSize; i++ {
		posKey, _posValue := _positions.GetByIndex(i)

		posValue := _posValue.(PositionInfo)
		owner, tl, th := posKeyDivide(posKey)

		posInfo := ApiPositionInfo{
			Owner:     owner,
			TickLower: tl,
			TickUpper: th,
			Liquidity: posValue.liquidity,
			T0Owed:    posValue.tokensOwed0,
			T1Owed:    posValue.tokensOwed1,
		}
		posList = append(posList, posInfo)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetPool{
		Stat: qb,
		Response: struct {
			Data SinglePool `json:"data"`
		}{
			Data: SinglePool{
				T0Bal: p.balances.token0,
				T1Bal: p.balances.token1,
				// Fee:                 p.fee,
				TickSpacing:         p.tickSpacing,
				MaxLiquidityPerTick: p.maxLiquidityPerTick,
				Liquidity:           p.liquidity,
				Position:            posList,
			},
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetPool")
		panic(err)
	}

	return string(rr)
}

func posKeyDivide(posKey string) (string, bigint, bigint) {
	// base64 decode
	kDec, _ := b64.StdEncoding.DecodeString(posKey)
	posKey = string(kDec)

	res := strings.Split(posKey, "__")
	if len(res) != 3 {
		panic("posKeyDevidie: invalid posKey")
	}

	owner, tickLower, tickUpper := res[0], res[1], res[2]

	return owner, bigint(tickLower), bigint(tickUpper)
}
