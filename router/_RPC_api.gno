package router

import (
	"encoding/json"
	"strconv"
	"strings"

	"gno.land/p/demo/common"
	"gno.land/p/demo/ufmt"

	"gno.land/r/demo/consts"
	pl "gno.land/r/demo/pool"
)

type TokenRatio struct {
	Token string `json:"token"`
	Ratio bigint `json:"ratio"`
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
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	ratios := findRatios(3)
	r := ResponseGetRatiosFromBase{
		Stat:     qb,
		Response: ratios,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno()__ApiGetRatioFromBase || json.Marshal error with %v", err))
	}

	return string(rr)
}

func findRatios(maxHops int) []TokenRatio {
	var tokenRatio = make(map[string]bigint, 0)
	// WGNOT
	tokenRatio[consts.WRAPPED_WUGNOT] = consts.Q96 // ~= 1

	tokens := getTokenList()

	pools := findCandidatePools()

	for _, token := range tokens {
		if token == consts.WRAPPED_WUGNOT {
			continue
		}

		routes := computeAllRoutes(consts.WRAPPED_WUGNOT, token, maxHops, pools)

		if len(routes) == 0 {
			// NO ROUTES FOUND => SET RATIO TO 0
			tokenRatio[token] = 0
		} else {
			numRoutes := len(routes)

			var _tokenRatioX96 bigint

			for _, route := range routes {
				numHops := len(route.route)

				switch numHops {
				case 1, 2, 3:
					priceRatio := calculateTokenRatio(token, route.route, 0, 1)
					_tokenRatioX96 += priceRatio
				default:
					_tokenRatioX96 = 0
				}
			}
			avgPriceX96 := _tokenRatioX96 / bigint(numRoutes)
			tokenRatio[token] = avgPriceX96

		}
	}
	// LOOP FIN

	var tokenRatios = []TokenRatio{}
	for token, ratio := range tokenRatio {
		tokenRatios = append(tokenRatios, TokenRatio{
			Token: token,
			Ratio: ratio,
		})
	}

	return tokenRatios
}

func calculateTokenRatio(currentToken string, routes []PoolWithMeta, proceed int, priceX96 bigint) bigint {
	poolPath := routes[len(routes)-proceed-1].poolPath
	pool := pl.GetPoolFromPoolPath(poolPath)

	token0Path := pool.PoolGetToken0Path()
	token1Path := pool.PoolGetToken1Path()

	if token1Path == currentToken {
		poolSqrtPriceX96 := pool.PoolGetSlot0SqrtPriceX96()

		priceX96 *= poolSqrtPriceX96 * poolSqrtPriceX96
		currentToken = token0Path
	} else if token0Path == currentToken {
		poolTick := pool.PoolGetSlot0Tick()
		oppositeTick := -poolTick
		oppositeSqrtPriceX96 := common.TickMathGetSqrtRatioAtTick(oppositeTick)

		priceX96 *= oppositeSqrtPriceX96 * oppositeSqrtPriceX96
		currentToken = token1Path
	} else {
		// wrong condition
		// panic("[ROUTER] _RPC_api.gno__calculateTokenRatio() || wrong condition")
		return 0

	}

	proceed += 1

	if proceed == len(routes) { // numHops
		for { // remove as much X96 as possible
			tempPriceX96 := priceX96
			priceX96 /= consts.Q96

			if priceX96 < consts.MIN_PRICE {
				return tempPriceX96
			}
		}
	}

	return calculateTokenRatio(currentToken, routes, proceed, priceX96)
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

func poolPathWithFeeDivide(poolPath string) (string, string, int) {
	poolPathSplit := strings.Split(poolPath, ":")
	require(len(poolPathSplit) == 3, ufmt.Sprintf("[ROUTER] _RPC_api.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], feeInt
}
