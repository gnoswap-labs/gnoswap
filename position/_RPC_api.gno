// EXTERNAL API
package position

import (
	"encoding/json"

	"gno.land/p/demo/ufmt"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetPositions struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []uint64 `json:"data"`
	} `json:"response"`
}

func ApiGetPositions() string {
	positionList := []uint64{}

	for k, _ := range positions {
		positionList = append(positionList, k)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetPositions{
		Stat: qb,
		Response: struct {
			Data []uint64 `json:"data"`
		}{
			Data: positionList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] getter_api.gno()__ApiGetPositions() || %v", err))
	}

	return string(rr)
}

type SinglePosition struct {
	TokenID                  uint64 `json:"token_id"`
	Operator                 string `json:"operator"`
	PoolKey                  string `json:"pool_key"`
	TickLower                int32  `json:"tick_lower"`
	TickUpper                int32  `json:"tick_upper"`
	Liquidity                bigint `json:"liquidity"`
	FeeGrowthInside0LastX128 bigint `json:"fee_growth_inside_0_last_x128"`
	FeeGrowthInside1LastX128 bigint `json:"fee_growth_inside_1_last_x128"`
	TokensOwed0              bigint `json:"tokens_owed_0"`
	TokensOwed1              bigint `json:"tokens_owed_1"`
}

type ResponseGetPosition struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data SinglePosition `json:"data"`
	} `json:"response"`
}

func ApiGetPosition(key uint64) string { // key is tokenId
	position, exist := positions[key]
	if !exist {
		return "NO_POSITION_FOUND"
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetPosition{
		Stat: qb,
		Response: struct {
			Data SinglePosition `json:"data"`
		}{
			Data: SinglePosition{
				TokenID:                  key,
				Operator:                 position.operator.String(),
				PoolKey:                  position.poolKey,
				TickLower:                position.tickLower,
				TickUpper:                position.tickUpper,
				Liquidity:                position.liquidity,
				FeeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
				FeeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
				TokensOwed0:              position.tokensOwed0,
				TokensOwed1:              position.tokensOwed1,
			},
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] getter_api.gno__ApiGetPosition() || %v", err))
	}

	return string(rr)
}

type ApiPosition struct {
	Address     string `json:"address"`
	TokenID     uint64 `json:"token_id"`
	PoolKey     string `json:"pool_key"`
	TickLower   int32  `json:"tick_lower"`
	TickUpper   int32  `json:"tick_upper"`
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

	for k, v := range positions {
		plo := v.operator.String()
		if plo != addr {
			continue
		} else {
			plk := v.poolKey

			ap := ApiPosition{
				Address:     addr,
				TokenID:     k,
				PoolKey:     plk,
				TickLower:   v.tickLower,
				TickUpper:   v.tickUpper,
				Liquidity:   v.liquidity,
				TokensOwed0: v.tokensOwed0,
				TokensOwed1: v.tokensOwed1,
			}
			userPositions = append(userPositions, ap)
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
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
		panic(ufmt.Sprintf("[POSITION] getter_api.gno__ApiGetPositionByUser() || %v", err))
	}

	return string(rr)
}
