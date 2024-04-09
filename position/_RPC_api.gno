package position

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/common"

	"gno.land/r/gnoswap/consts"

	pl "gno.land/r/demo/pool"

	u256 "gno.land/p/demo/gnoswap/uint256"
)

type RpcPosition struct {
	LpTokenId                uint64 `json:"lpTokenId"`
	Burned                   bool   `json:"burned"`
	Operator                 string `json:"operator"`
	PoolKey                  string `json:"poolKey"`
	TickLower                int32  `json:"tickLower"`
	TickUpper                int32  `json:"tickUpper"`
	Liquidity                string `json:"liquidity"`
	FeeGrowthInside0LastX128 string `json:"feeGrowthInside0LastX128"`
	FeeGrowthInside1LastX128 string `json:"feeGrowthInside1LastX128"`
	TokensOwed0              string `json:"token0Owed"`
	TokensOwed1              string `json:"token1Owed"`

	Token0Balance string `json:"token0Balance"`
	Token1Balance string `json:"token1Balance"`
	FeeUnclaimed0 string `json:"fee0Unclaimed"`
	FeeUnclaimed1 string `json:"fee1Unclaimed"`
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

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for i, position := range r.Response {
		_positionNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId":                json.NumberNode("lpTokenId", float64(position.LpTokenId)),
			"burned":                   json.BoolNode("burned", position.Burned),
			"operator":                 json.StringNode("operator", position.Operator),
			"poolKey":                  json.StringNode("poolKey", position.PoolKey),
			"tickLower":                json.NumberNode("tickLower", float64(position.TickLower)),
			"tickUpper":                json.NumberNode("tickUpper", float64(position.TickUpper)),
			"liquidity":                json.StringNode("liquidity", position.Liquidity),
			"feeGrowthInside0LastX128": json.StringNode("feeGrowthInside0LastX128", position.FeeGrowthInside0LastX128),
			"feeGrowthInside1LastX128": json.StringNode("feeGrowthInside1LastX128", position.FeeGrowthInside1LastX128),
			"token0Owed":               json.StringNode("token0Owed", position.TokensOwed0),
			"token1Owed":               json.StringNode("token1Owed", position.TokensOwed1),
			"token0Balance":            json.StringNode("token0Balance", position.Token0Balance),
			"token1Balance":            json.StringNode("token1Balance", position.Token1Balance),
			"fee0Unclaimed":            json.StringNode("fee0Unclaimed", position.FeeUnclaimed0),
			"fee1Unclaimed":            json.StringNode("fee1Unclaimed", position.FeeUnclaimed1),
		})
		responses.AppendArray(_positionNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] _RPC_api.gno__ApiGetPositions() || error marshalling json: %s", err.Error()))
	}

	return string(b)
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

	unclaimedFee0 := u256.Zero()
	unclaimedFee1 := u256.Zero()
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
		Liquidity:                position.liquidity.ToString(),
		FeeGrowthInside0LastX128: position.feeGrowthInside0LastX128.ToString(),
		FeeGrowthInside1LastX128: position.feeGrowthInside1LastX128.ToString(),
		TokensOwed0:              position.tokensOwed0.ToString(),
		TokensOwed1:              position.tokensOwed1.ToString(),
		Token0Balance:            token0Balance.ToString(),
		Token1Balance:            token1Balance.ToString(),
		FeeUnclaimed0:            unclaimedFee0.ToString(),
		FeeUnclaimed1:            unclaimedFee1.ToString(),
	}
}

func unclaimedFee(tokenId uint64) (*u256.Uint, *u256.Uint) {
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

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 *u256.Uint

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = new(u256.Uint).Sub(feeGrowthGlobal0X128, tickUpperFeeGrowthOutside0X128)
		tickUpperFeeGrowthAbove1 = new(u256.Uint).Sub(feeGrowthGlobal1X128, tickUpperFeeGrowthOutside1X128)
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = new(u256.Uint).Sub(feeGrowthGlobal0X128, tickLowerFeeGrowthOutside0X128)
		tickLowerFeeGrowthBelow1 = new(u256.Uint).Sub(feeGrowthGlobal1X128, tickLowerFeeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := new(u256.Uint).Sub(feeGrowthGlobal0X128, tickLowerFeeGrowthBelow0)
	feeGrowthInside0X128 = new(u256.Uint).Sub(feeGrowthInside0X128, tickUpperFeeGrowthAbove0)

	feeGrowthInside1X128 := new(u256.Uint).Sub(feeGrowthGlobal1X128, tickLowerFeeGrowthBelow1)
	feeGrowthInside1X128 = new(u256.Uint).Sub(feeGrowthInside1X128, tickUpperFeeGrowthAbove1)

	value01 := new(u256.Uint).Sub(feeGrowthInside0X128, feeGrowthInside0LastX128)
	value02 := new(u256.Uint).Mul(liquidity, value01)
	unclaimedFee0 := new(u256.Uint).Div(value02, u256.MustFromDecimal(consts.Q128))

	value11 := new(u256.Uint).Sub(feeGrowthInside1X128, feeGrowthInside1LastX128)
	value12 := new(u256.Uint).Mul(liquidity, value11)
	unclaimedFee1 := new(u256.Uint).Div(value12, u256.MustFromDecimal(consts.Q128))

	return unclaimedFee0, unclaimedFee1
}

func isBurned(tokenId uint64) bool {
	return positions[tokenId].burned
}
