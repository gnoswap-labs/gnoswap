package position

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/common"

	"gno.land/r/gnoswap/v2/consts"

	pl "gno.land/r/gnoswap/v2/pool"

	i256 "gno.land/p/gnoswap/int256"
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

type RpcUnclaimedFee struct {
	LpTokenId uint64 `json:"lpTokenId"`
	Fee0      string `json:"fee0"`
	Fee1      string `json:"fee1"`
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
	for _, position := range r.Response {
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

func ApiGetPosition(lpTokenId uint64) string {
	rpcPositions := []RpcPosition{}

	_, ok := positions[lpTokenId]
	if ok {
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
	for _, position := range r.Response {
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

func ApiGetPositionsByPoolPath(poolPath string) string {
	rpcPositions := []RpcPosition{}
	for lpTokenId, position := range positions {

		if position.poolKey != poolPath {
			continue
		}

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
	for _, position := range r.Response {
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

func ApiGetPositionsByAddress(address string) string {
	rpcPositions := []RpcPosition{}
	for lpTokenId, position := range positions {

		if position.operator.String() != address {
			continue
		}

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
	for _, position := range r.Response {
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

func ApiGetPositionsUnclaimedFee() string {
	rpcUnclaimedFee := []RpcUnclaimedFee{}
	for lpTokenId, _ := range positions {
		unclaimedFee0, unclaimedFee1 := unclaimedFee(lpTokenId)
		rpcUnclaimedFee = append(rpcUnclaimedFee, RpcUnclaimedFee{
			LpTokenId: lpTokenId,
			Fee0:      unclaimedFee0.ToString(),
			Fee1:      unclaimedFee1.ToString(),
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, unclaimedFee := range rpcUnclaimedFee {
		_unclaimedFeeNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId": json.NumberNode("lpTokenId", float64(unclaimedFee.LpTokenId)),
			"fee0":      json.StringNode("fee0", unclaimedFee.Fee0),
			"fee1":      json.StringNode("fee1", unclaimedFee.Fee1),
		})
		responses.AppendArray(_unclaimedFeeNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] _RPC_api.gno__ApiGetPositionsUnClaimedFee() || error marshalling json: %s", err.Error()))
	}

	return string(b)
}

func ApiGetPositionUnclaimedFeeByLpTokenId(lpTokenId uint64) string {
	rpcUnclaimedFee := []RpcUnclaimedFee{}

	unclaimedFee0, unclaimedFee1 := unclaimedFee(lpTokenId)
	rpcUnclaimedFee = append(rpcUnclaimedFee, RpcUnclaimedFee{
		LpTokenId: lpTokenId,
		Fee0:      unclaimedFee0.ToString(),
		Fee1:      unclaimedFee1.ToString(),
	})

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, unclaimedFee := range rpcUnclaimedFee {
		_unclaimedFeeNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId": json.NumberNode("lpTokenId", float64(unclaimedFee.LpTokenId)),
			"fee0":      json.StringNode("fee0", unclaimedFee.Fee0),
			"fee1":      json.StringNode("fee1", unclaimedFee.Fee1),
		})
		responses.AppendArray(_unclaimedFeeNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[POSITION] _RPC_api.gno__ApiGetPositionUnclaimedFeeByLpTokenId() || error marshalling json: %s", err.Error()))
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
		i256.FromUint256(position.liquidity),
	)

	unclaimedFee0 := i256.Zero()
	unclaimedFee1 := i256.Zero()
	if !burned {
		unclaimedFee0, unclaimedFee1 = unclaimedFee(lpTokenId)
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
		Token0Balance:            token0Balance,
		Token1Balance:            token1Balance,
		FeeUnclaimed0:            unclaimedFee0.ToString(),
		FeeUnclaimed1:            unclaimedFee1.ToString(),
	}
}

func unclaimedFee(tokenId uint64) (*i256.Int, *i256.Int) {
	// ref: https://blog.uniswap.org/uniswap-v3-math-primer-2#calculating-uncollected-fees

	_liquidity := positions[tokenId].liquidity // u256
	liquidity := i256.FromUint256(_liquidity)  // i256

	tickLower := positions[tokenId].tickLower
	tickUpper := positions[tokenId].tickUpper

	poolKey := positions[tokenId].poolKey
	pool := pl.GetPoolFromPoolPath(poolKey)

	currentTick := pool.PoolGetSlot0Tick()

	_feeGrowthGlobal0X128 := pool.PoolGetFeeGrowthGlobal0X128()     // u256
	feeGrowthGlobal0X128 := i256.FromUint256(_feeGrowthGlobal0X128) // i256

	_feeGrowthGlobal1X128 := pool.PoolGetFeeGrowthGlobal1X128()     // u256
	feeGrowthGlobal1X128 := i256.FromUint256(_feeGrowthGlobal1X128) // i256

	_tickUpperFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickUpper) // u256
	tickUpperFeeGrowthOutside0X128 := i256.FromUint256(_tickUpperFeeGrowthOutside0X128) // i256

	_tickUpperFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickUpper) // u256
	tickUpperFeeGrowthOutside1X128 := i256.FromUint256(_tickUpperFeeGrowthOutside1X128) // i256

	_tickLowerFeeGrowthOutside0X128 := pool.PoolGetTickFeeGrowthOutside0X128(tickLower) // u256
	tickLowerFeeGrowthOutside0X128 := i256.FromUint256(_tickLowerFeeGrowthOutside0X128) // i256

	_tickLowerFeeGrowthOutside1X128 := pool.PoolGetTickFeeGrowthOutside1X128(tickLower) // u256
	tickLowerFeeGrowthOutside1X128 := i256.FromUint256(_tickLowerFeeGrowthOutside1X128) // i256

	_feeGrowthInside0LastX128 := positions[tokenId].feeGrowthInside0LastX128 // u256
	feeGrowthInside0LastX128 := i256.FromUint256(_feeGrowthInside0LastX128)  // i256

	_feeGrowthInside1LastX128 := positions[tokenId].feeGrowthInside1LastX128 // u256
	feeGrowthInside1LastX128 := i256.FromUint256(_feeGrowthInside1LastX128)  // i256

	var tickLowerFeeGrowthBelow0, tickLowerFeeGrowthBelow1, tickUpperFeeGrowthAbove0, tickUpperFeeGrowthAbove1 *i256.Int

	if currentTick >= tickUpper {
		tickUpperFeeGrowthAbove0 = subIn256(feeGrowthGlobal0X128, tickUpperFeeGrowthOutside0X128)
		tickUpperFeeGrowthAbove1 = subIn256(feeGrowthGlobal1X128, tickUpperFeeGrowthOutside1X128)
	} else {
		tickUpperFeeGrowthAbove0 = tickUpperFeeGrowthOutside0X128
		tickUpperFeeGrowthAbove1 = tickUpperFeeGrowthOutside1X128
	}

	if currentTick >= tickLower {
		tickLowerFeeGrowthBelow0 = tickLowerFeeGrowthOutside0X128
		tickLowerFeeGrowthBelow1 = tickLowerFeeGrowthOutside1X128
	} else {
		tickLowerFeeGrowthBelow0 = subIn256(feeGrowthGlobal0X128, tickLowerFeeGrowthOutside0X128)
		tickLowerFeeGrowthBelow1 = subIn256(feeGrowthGlobal1X128, tickLowerFeeGrowthOutside1X128)
	}

	feeGrowthInside0X128 := subIn256(feeGrowthGlobal0X128, tickLowerFeeGrowthBelow0)
	feeGrowthInside0X128 = subIn256(feeGrowthInside0X128, tickUpperFeeGrowthAbove0)

	feeGrowthInside1X128 := subIn256(feeGrowthGlobal1X128, tickLowerFeeGrowthBelow1)
	feeGrowthInside1X128 = subIn256(feeGrowthInside1X128, tickUpperFeeGrowthAbove1)

	value01 := subIn256(feeGrowthInside0X128, feeGrowthInside0LastX128)
	value02 := i256.Zero().Mul(liquidity, value01)
	unclaimedFee0 := i256.Zero().Div(value02, i256.MustFromDecimal(consts.Q128))

	value11 := subIn256(feeGrowthInside1X128, feeGrowthInside1LastX128)
	value12 := i256.Zero().Mul(liquidity, value11)
	unclaimedFee1 := i256.Zero().Div(value12, i256.MustFromDecimal(consts.Q128))

	return unclaimedFee0, unclaimedFee1
}

func subIn256(x, y *i256.Int) *i256.Int {
	value := i256.Zero()
	diff := value.Sub(x, y)

	if diff.IsNeg() {
		q256 := i256.MustFromDecimal(consts.MAX_UINT256)
		return diff.Add(diff, q256)
	}

	return diff
}

func isBurned(tokenId uint64) bool {
	return positions[tokenId].burned
}
