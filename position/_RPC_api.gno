// EXTERNAL API
package position

import (
	"encoding/json"

	"gno.land/p/demo/ufmt"

	p "gno.land/r/pool"
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
	TokenID       uint64 `json:"token_id"`
	Operator      string `json:"operator"`
	PoolKey       string `json:"pool_key"`
	TickLower     int32  `json:"tick_lower"`
	TickUpper     int32  `json:"tick_upper"`
	Liquidity     bigint `json:"liquidity"`
	Token0Balance bigint `json:"token0_balance"`
	Token1Balance bigint `json:"token1_balance"`
	UnclaimedFee0 bigint `json:"unclaimed_fee0"` // only unclaimed fee
	UnclaimedFee1 bigint `json:"unclaimed_fee1"`
	TokensOwed0   bigint `json:"tokens_owed_0"` // unclaimed fee + burned liquidity
	TokensOwed1   bigint `json:"tokens_owed_1"`
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

	pool := p.GetPoolFromPoolKey(position.poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := p.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperX96 := p.TickMathGetSqrtRatioAtTick(position.tickUpper)

	token0Balance, token1Balance := liquidityAmountsGetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		position.liquidity,
	)

	unclaimedFee0, unclaimedFee1 := unclaimedFee(key)

	r := ResponseGetPosition{
		Stat: qb,
		Response: struct {
			Data SinglePosition `json:"data"`
		}{
			Data: SinglePosition{
				TokenID:       key,
				Operator:      position.operator.String(),
				PoolKey:       position.poolKey,
				TickLower:     position.tickLower,
				TickUpper:     position.tickUpper,
				Liquidity:     position.liquidity,
				Token0Balance: token0Balance,
				Token1Balance: token1Balance,
				UnclaimedFee0: unclaimedFee0,
				UnclaimedFee1: unclaimedFee1,
				TokensOwed0:   position.tokensOwed0,
				TokensOwed1:   position.tokensOwed1,
			},
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] getter_api.gno__ApiGetPosition() || %v", err))
	}

	return string(rr)
}

type ResponseGetUserPositions struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []SinglePosition `json:"data"`
	} `json:"response"`
}

func ApiGetPositionByUser(addr string) string {
	userPositions := []SinglePosition{}

	for token_id, position := range positions {
		po := position.operator.String() // position owner
		if po != addr {
			continue
		} else {
			pool := p.GetPoolFromPoolKey(position.poolKey)
			currentX96 := pool.PoolGetSlot0SqrtPriceX96()
			lowerX96 := p.TickMathGetSqrtRatioAtTick(position.tickLower)
			upperX96 := p.TickMathGetSqrtRatioAtTick(position.tickUpper)

			token0Balance, token1Balance := liquidityAmountsGetAmountsForLiquidity(
				currentX96,
				lowerX96,
				upperX96,
				position.liquidity,
			)

			unclaimedFee0, unclaimedFee1 := unclaimedFee(token_id)

			userPosition := SinglePosition{
				Operator:      addr,
				TokenID:       token_id,
				PoolKey:       position.poolKey,
				TickLower:     position.tickLower,
				TickUpper:     position.tickUpper,
				Liquidity:     position.liquidity,
				Token0Balance: token0Balance,
				Token1Balance: token1Balance,
				UnclaimedFee0: unclaimedFee0,
				UnclaimedFee1: unclaimedFee1,
				TokensOwed0:   position.tokensOwed0,
				TokensOwed1:   position.tokensOwed1,
			}
			userPositions = append(userPositions, userPosition)
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	r := ResponseGetUserPositions{
		Stat: qb,
		Response: struct {
			Data []SinglePosition `json:"data"`
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

func unclaimedFee(tokenId uint64) (bigint, bigint) {
	// preapre all data
	liquidity := positions[tokenId].liquidity
	tickLower := positions[tokenId].tickLower
	tickUpper := positions[tokenId].tickUpper

	poolKey := positions[tokenId].poolKey
	pool := p.GetPoolFromPoolKey(poolKey)

	currentTick := pool.PoolGetSlot0Tick()

	feeGrowthGlobal0X128 := pool.PoolGetFeeGrowthGlobal0X128()
	feeGrowthGlobal1X128 := pool.PoolGetFeeGrowthGlobal1X128()

	tickUpperFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickUpper)
	tickUpperFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickUpper)

	tickLowerFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickLower)
	tickLowerFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickLower)

	feeGrowthInside0LastX128 := positions[tokenId].feeGrowthInside0LastX128
	feeGrowthInside1LastX128 := positions[tokenId].feeGrowthInside1LastX128

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 bigint

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = feeGrowthGlobal0X128 - tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = feeGrowthGlobal1X128 - tickUpperFeeGrowthOutside1X128
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = feeGrowthGlobal0X128 - tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = feeGrowthGlobal1X128 - tickLowerFeeGrowthOutside1X128
	}

	feeGrowthInside0X128 := (feeGrowthGlobal0X128 - tickLowerFeeGrowthBelow0 - tickUpperFeeGrowthAbove0)
	feeGrowthInside1X128 := (feeGrowthGlobal1X128 - tickLowerFeeGrowthBelow1 - tickUpperFeeGrowthAbove1)

	unclaimedFee0 := (liquidity * (feeGrowthInside0X128 - feeGrowthInside0LastX128)) / Q128
	unclaimedFee1 := (liquidity * (feeGrowthInside1X128 - feeGrowthInside1LastX128)) / Q128

	return unclaimedFee0, unclaimedFee1
}
