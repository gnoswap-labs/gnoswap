// EXTERNAL API
package position

import (
	"encoding/json"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetPositions struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []string `json:"data"`
	} `json:"response"`
}

func ApiGetPositions() string {
	positionSize := positions.Size()
	positionList := []string{}

	for i := 0; i < positionSize; i++ {
		pk, _ := positions.GetByIndex(i)
		positionList = append(positionList, pk)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetPositions{
		Stat: qb,
		Response: struct {
			Data []string `json:"data"`
		}{
			Data: positionList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetPositions")
		panic(err)
	}

	return string(rr)
}

type SinglePosition struct {
	TokenID string `json:"token_id"`
	// Nonce     bigint `json:"nonce"`
	Operator  string `json:"operator"`
	PoolKey   string `json:"pool_key"`
	TickLower bigint `json:"tick_lower"`
	TickUpper bigint `json:"tick_upper"`
	Liquidity bigint `json:"liquidity"`
	// FeeGrowthInside0LastX128 bigint `json:"fee_growth_inside_0_last_x128"`
	// FeeGrowthInside1LastX128 bigint `json:"fee_growth_inside_1_last_x128"`
	TokensOwed0 bigint `json:"tokens_owed_0"`
	TokensOwed1 bigint `json:"tokens_owed_1"`
}

type ResponseGetPosition struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data SinglePosition `json:"data"`
	} `json:"response"`
}

func ApiGetPosition(key string) string {
	// key is tokenID
	_p, exists := positions.Get(key)
	if !exists {
		return "NO_POOL_FOUND"
	}

	p := _p.(Position)

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetPosition{
		Stat: qb,
		Response: struct {
			Data SinglePosition `json:"data"`
		}{
			Data: SinglePosition{
				TokenID:     key,
				Operator:    p.operator.String(), // string(p.operator)
				PoolKey:     p.poolKey,
				TickLower:   p.tickLower,
				TickUpper:   p.tickUpper,
				Liquidity:   p.liquidity,
				TokensOwed0: p.tokensOwed0,
				TokensOwed1: p.tokensOwed1,
			},
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetPosition")
		panic(err)
	}

	return string(rr)
}

type ApiPosition struct {
	Address     string `json:"address"`
	TokenID     string `json:"token_id"`
	PoolKey     string `json:"pool_key"`
	TickLower   bigint `json:"tick_lower"`
	TickUpper   bigint `json:"tick_upper"`
	Liquidity   bigint `json:"liquidity"`
	TokensOwed0 bigint `json:"tokens_owed_0"`
	TokensOwed1 bigint `json:"tokens_owed_1"`
}

type ResponseGetUserPositions struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []ApiPosition `json:"data"`
	} `json:"response"`
}

func ApiGetPositionByUser(addr string) string {
	userPositions := []ApiPosition{}
	for i := 0; i < positions.Size(); i++ {
		psk, pv := positions.GetByIndex(i)

		position := pv.(Position)
		plo := position.operator.String()
		if plo != addr {
			continue
		} else {
			plk := position.poolKey

			ap := ApiPosition{
				Address:     addr,
				TokenID:     psk,
				PoolKey:     plk,
				TickLower:   position.tickLower,
				TickUpper:   position.tickUpper,
				Liquidity:   position.liquidity,
				TokensOwed0: position.tokensOwed0,
				TokensOwed1: position.tokensOwed1,
			}
			userPositions = append(userPositions, ap)
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetUserPositions{
		Stat: qb,
		Response: struct {
			Data []ApiPosition `json:"data"`
		}{
			Data: userPositions,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		println("PANIC__ApiGetPositionByUser")
		panic(err)
	}

	return string(rr)
}
