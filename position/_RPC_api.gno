package position

import (
	"encoding/json"
	"std"
	"time"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"

	pl "gno.land/r/demo/pool"
)

type RpcPosition struct {
	LpTokenId                uint64 `json:"lpTokenId"`
	Burned                   bool   `json:"burned"`
	Operator                 string `json:"operator"`
	PoolKey                  string `json:"poolKey"`
	TickLower                int32  `json:"tickLower"`
	TickUpper                int32  `json:"tickUpper"`
	Liquidity                bigint `json:"liquidity"`
	FeeGrowthInside0LastX128 bigint `json:"feeGrowthInside0LastX128"`
	FeeGrowthInside1LastX128 bigint `json:"feeGrowthInside1LastX128"`
	TokensOwed0              bigint `json:"tokensOwed0"`
	TokensOwed1              bigint `json:"tokensOwed1"`

	Token0Balance bigint `json:"token0Balance"`
	Token1Balance bigint `json:"token1Balance"`
	FeeUnclaimed0 bigint `json:"feeUnclaimed0"`
	FeeUnclaimed1 bigint `json:"feeUnclaimed1"`
}

type ResponseQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseApiGetPositions struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []RpcPosition     `json:"response"`
}

func ApiGetPositions() string {
	rpcPositions := []RpcPosition{}
	for lpTokenId, _ := range positions {
		rpcPosition := rpcMakePosition(lpTokenId)
		rpcPositions = append(rpcPositions, rpcPosition)
	}

	r := ResponseApiGetPositions{
		Stat: ResponseQueryBase{
			Height:    std.GetHeight(),
			Timestamp: time.Now().Unix(),
		},
		Response: rpcPositions,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] _RPC_api.gno()__ApiGetPositions() || %v", err))
	}

	return string(rr)
}

func rpcMakePosition(lpTokenId uint64) RpcPosition {
	position, exist := positions[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[POSITION] getter_api.gno__rpcMakePosition() || position not found for lpTokenId(%d)", lpTokenId))
	}

	burned := isBurned(lpTokenId)

	pool := pl.GetPoolFromPoolPath(position.poolKey)
	currentX96 := pool.PoolGetSlot0SqrtPriceX96()
	lowerX96 := common.TickMathGetSqrtRatioAtTick(position.tickLower)
	upperX96 := common.TickMathGetSqrtRatioAtTick(position.tickUpper)

	token0Balance, token1Balance := common.GetAmountsForLiquidity(
		currentX96,
		lowerX96,
		upperX96,
		position.liquidity,
	)

	var unclaimedFee0, unclaimedFee1 bigint // if position is burned, unclaimedFee0 and unclaimedFee1 will be 0
	if !burned {
		unclaimedFee0, unclaimedFee1 := unclaimedFee(lpTokenId)
	}

	return RpcPosition{
		LpTokenId:                lpTokenId,
		Burned:                   burned,
		Operator:                 position.operator.String(),
		PoolKey:                  position.poolKey,
		TickLower:                position.tickLower,
		TickUpper:                position.tickUpper,
		Liquidity:                position.liquidity,
		FeeGrowthInside0LastX128: position.feeGrowthInside0LastX128,
		FeeGrowthInside1LastX128: position.feeGrowthInside1LastX128,
		TokensOwed0:              position.tokensOwed0,
		TokensOwed1:              position.tokensOwed1,
		Token0Balance:            token0Balance,
		Token1Balance:            token1Balance,
		FeeUnclaimed0:            unclaimedFee0,
		FeeUnclaimed1:            unclaimedFee1,
	}
}

func unclaimedFee(tokenId uint64) (bigint, bigint) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees

	liquidity := positions[tokenId].liquidity
	tickLower := positions[tokenId].tickLower
	tickUpper := positions[tokenId].tickUpper

	poolKey := positions[tokenId].poolKey
	pool := pl.GetPoolFromPoolPath(poolKey)

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

	unclaimedFee0 := (liquidity * (feeGrowthInside0X128 - feeGrowthInside0LastX128)) / consts.Q128
	unclaimedFee1 := (liquidity * (feeGrowthInside1X128 - feeGrowthInside1LastX128)) / consts.Q128

	return unclaimedFee0, unclaimedFee1
}

func isBurned(tokenId uint64) bool {
	return positions[tokenId].burned
}
