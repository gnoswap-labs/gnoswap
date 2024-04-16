package router

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/gnoswap/common"
	"gno.land/r/demo/gnoswap/consts"

	pl "gno.land/r/demo/pool"

	u256 "gno.land/p/demo/gnoswap/uint256"
)

type TokenRatio struct {
	Token string `json:"token"`
	Ratio string `json:"ratio"`
}

type ResponseQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetRatiosFromBase struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []TokenRatio      `json:"response"`
}

func ApiGetRatiosFromBase() string {
	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	ratios := findRatios(3)
	r := ResponseGetRatiosFromBase{
		Stat:     qb,
		Response: ratios,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for i, pool := range r.Response {
		_routerNode := json.ObjectNode("", map[string]*json.Node{
			"token": json.StringNode("token", pool.Token),
			"ratio": json.StringNode("ratio", pool.Ratio),
		})
		responses.AppendArray(_routerNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno__ApiGetRatiosFromBase() || error marshalling json: %s", err.Error()))
	}

	return string(b)
}

func findRatios(maxHops int) []TokenRatio {
	var tokenRatio = make(map[string]*u256.Uint, 0)
	// WGNOT
	tokenRatio[consts.WRAPPED_WUGNOT] = u256.MustFromDecimal(consts.Q96) // ~= 1

	tokens := getTokenList()

	pools := findCandidatePools()

	for _, token := range tokens {
		if token == consts.WRAPPED_WUGNOT {
			continue
		}

		routes := computeAllRoutes(consts.WRAPPED_WUGNOT, token, maxHops, pools)

		if len(routes) == 0 {
			// NO ROUTES FOUND => SET RATIO TO 0
			tokenRatio[token] = u256.Zero()
		} else {
			numRoutes := uint64(len(routes))

			_tokenRatioX96 := u256.Zero()

			for _, route := range routes {
				numHops := uint64(len(route.route))

				switch numHops {
				case 1, 2, 3:
					priceRatio := calculateTokenRatio(token, route.route, 0, u256.One())
					// _tokenRatioX96 += priceRatio
					_tokenRatioX96 = new(u256.Uint).Add(_tokenRatioX96, priceRatio)
				default:
					_tokenRatioX96 = u256.Zero()
				}
			}
			avgPriceX96 := new(u256.Uint).Div(_tokenRatioX96, u256.NewUint(numRoutes))
			tokenRatio[token] = avgPriceX96
		}
	}
	// LOOP FIN

	var tokenRatios = []TokenRatio{}
	for token, ratio := range tokenRatio {
		tokenRatios = append(tokenRatios, TokenRatio{
			Token: token,
			Ratio: ratio.ToString(),
		})
	}

	return tokenRatios
}

func calculateTokenRatio(currentToken string, routes []PoolWithMeta, proceed int, priceX96 *u256.Uint) *u256.Uint {
	poolPath := routes[len(routes)-proceed-1].poolPath
	pool := pl.GetPoolFromPoolPath(poolPath)

	token0Path := pool.PoolGetToken0Path()
	token1Path := pool.PoolGetToken1Path()

	if token1Path == currentToken {
		poolSqrtPriceX96 := pool.PoolGetSlot0SqrtPriceX96()

		sqrtX96X96 := new(u256.Uint).Mul(poolSqrtPriceX96, poolSqrtPriceX96)
		sqrtX96 := new(u256.Uint).Div(sqrtX96X96, u256.MustFromDecimal(consts.Q96))

		priceX96 = new(u256.Uint).Mul(priceX96, sqrtX96)
		currentToken = token0Path
	} else if token0Path == currentToken {
		poolTick := pool.PoolGetSlot0Tick()
		oppositeTick := -poolTick
		oppositeSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(oppositeTick)

		oppSqrtX96X96 := new(u256.Uint).Mul(oppositeSqrtPriceX96, oppositeSqrtPriceX96)
		oppSqrtX96 := new(u256.Uint).Div(oppSqrtX96X96, u256.MustFromDecimal(consts.Q96))

		priceX96 = new(u256.Uint).Mul(priceX96, oppSqrtX96)
		currentToken = token1Path
	} else {
		// wrong condition
		panic("[ROUTER] _RPC_api.gno__calculateTokenRatio() || wrong condition")
		return u256.Zero()
	}

	proceed += 1

	for { // remove as much X96 as possible
		tempPriceX96 := priceX96.Clone()
		priceX96 = new(u256.Uint).Div(priceX96, u256.MustFromDecimal(consts.Q96))

		if priceX96.Lt(u256.MustFromDecimal(consts.MIN_PRICE)) {
			if proceed == len(routes) {
				return tempPriceX96
			}
			return calculateTokenRatio(currentToken, routes, proceed, tempPriceX96)
		}
	}
}

func getTokenList() []string {
	seen := make(map[string]bool)
	uniqueTokenList := []string{}
	poolList := pl.PoolGetPoolList()

	for _, poolPath := range poolList {
		token0Path, token1Path, _ := poolPathWithFeeDivide(poolPath)
		if _, exists := seen[token0Path]; !exists {
			seen[token0Path] = true
			uniqueTokenList = append(uniqueTokenList, token0Path)
		}
		if _, exists := seen[token1Path]; !exists {
			seen[token1Path] = true
			uniqueTokenList = append(uniqueTokenList, token1Path)
		}
	}

	return uniqueTokenList
}
