// EXTERNAL API
package router

import (
	"encoding/json"
	"strconv"
	"strings"

	p "gno.land/r/pool"

	"gno.land/p/demo/ufmt"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseGetRatiosFromBase struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []map[string]bigint `json:"data"`
	} `json:"response"`
}

func ApiGetRatiosFromBase() string {
	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: GetTimestamp(),
	}

	ratios := getRatiosFromBase(3)
	r := ResponseGetRatiosFromBase{
		Stat: qb,
		Response: struct {
			Data []map[string]bigint `json:"data"`
		}{
			Data: ratios,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno()__ApiGetRatioFromBase || json.Marshal error with %v", err))
	}

	return string(rr)
}

func getRatiosFromBase(maxHops int) []map[string]bigint {
	tokenPrice := make(map[string]bigint, 0)

	// BASE
	tokenPrice[GNOT] = Q96 // ~= 1

	// ELSE
	tokenList := getTokenList()
	for _, token := range tokenList {
		if token != GNOT {
			_swapPaths := findSwapPaths(token, GNOT, maxHops)
			swapPaths := strings.Split(_swapPaths, "_FIN_")
			swapPaths = swapPaths[:len(swapPaths)-1]
			numSwapPaths := len(swapPaths)

			thisTokenPriceX96 := bigint(0)
			if numSwapPaths < 1 { // NO CONNECTION TO BASE
				tokenPrice[token] = 0
			} else {
				for _, swapPath := range swapPaths {
					numPools := strings.Count(swapPath, ",") / 2

					switch numPools {
					case 0:
						thisTokenPriceX96 = 0
					case 1:
						priceRatio := calculateTokenPrice(token, swapPath, numPools, 0, 1)
						thisTokenPriceX96 += priceRatio
					case 2:
						priceRatio := calculateTokenPrice(token, swapPath, numPools, 0, 1)
						thisTokenPriceX96 += priceRatio
					case 3:
						priceRatio := calculateTokenPrice(token, swapPath, numPools, 0, 1)
						thisTokenPriceX96 += priceRatio
					default:
						thisTokenPriceX96 = 0
					}
				}
				avgPriceX96 := thisTokenPriceX96 / bigint(numSwapPaths)
				tokenPrice[token] = avgPriceX96
			}
		}
		// TOKEN ENDS
	}

	var tokenPrices []map[string]bigint
	for token, price := range tokenPrice {
		tokenPrices = append(tokenPrices, map[string]bigint{token: price})
		// DEBUG
		// println("token:", token)
		// println("price:", price)
		// println()
	}

	return tokenPrices
}

func getTokenList() []string {
	seen := make(map[string]bool)
	uniqueTokenList := []string{}
	poolList := p.PoolGetPoolList()

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

func makePoolPath(poolPath string, poolIndex int) string {
	poolDatas := strings.Split(poolPath, ",")
	// Calculate the indices for token paths and fee based on poolIndex.
	baseIndex := poolIndex * 2
	if baseIndex+2 >= len(poolDatas) {
		panic(ufmt.Sprintf("[ROUTER] _RPC_api.gno__makePoolPath() || index out of range for pool index: %d", poolIndex))
	}

	token0Path := poolDatas[baseIndex]
	token1Path := poolDatas[baseIndex+2]
	fee := poolDatas[baseIndex+1]

	// Ensure the tokens are in a consistent order.
	if token0Path > token1Path {
		token0Path, token1Path = token1Path, token0Path
	}

	return token0Path + ":" + token1Path + ":" + fee
}

func calculateTokenPrice(token, swapPath string, numPools, proceed int, currentPrice bigint) bigint {
	currentPoolPathKey := makePoolPath(swapPath, proceed)
	currentPool := p.GetPoolFromPoolKey(currentPoolPathKey)

	currentToken0 := currentPool.PoolGetToken0Path()
	currentToken1 := currentPool.PoolGetToken1Path()
	currentSqrtPriceX96 := currentPool.PoolGetSlot0SqrtPriceX96()

	if currentToken0 == token {
		currentPrice *= (Q96 * Q96 / (currentSqrtPriceX96 * currentSqrtPriceX96 / Q96))
		token = currentToken1
	} else if currentToken1 == token {
		currentPrice *= (currentSqrtPriceX96 * currentSqrtPriceX96 / Q96)
		token = currentToken0
	} else {
		panic("[ROUTER] _RPC_api.gno__calculateTokenPrice() || wrong condition")
	}

	if proceed == numPools-1 {
		return currentPrice / sqrt(Q96, proceed)
	}

	return calculateTokenPrice(token, swapPath, numPools, proceed+1, currentPrice)
}

func sqrt(x bigint, n int) bigint {
	result := bigint(1)
	for i := 0; i < n; i++ {
		result *= x
	}
	return result
}

func poolPathWithFeeDivide(poolPath string) (string, string, int) {
	poolPathSplit := strings.Split(poolPath, ":")
	require(len(poolPathSplit) == 3, ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || len(poolPathSplit) != 3, poolPath: %s", poolPath))

	feeInt, err := strconv.Atoi(poolPathSplit[2])
	if err != nil {
		panic(ufmt.Sprintf("[ROUTER] util.gno__poolPathWithFeeDivide() || cannot convert fee(%s) to int", poolPathSplit[2]))
	}

	return poolPathSplit[0], poolPathSplit[1], feeInt
}

func singlePoolPathWithFeeDivide(poolPath string) (string, string) {
	singlePoolPathSplit := strings.Split(poolPath, ":")
	require(len(singlePoolPathSplit) == 2, ufmt.Sprintf("[ROUTER] util.gno__singlePoolPathWithFeeDivide || len(singlePoolPathSplit) != 2, poolPath: %s", poolPath))

	return singlePoolPathSplit[0], singlePoolPathSplit[1]
}

func removeItemFromStringArray(s []string, r string) []string {
	for i, v := range s {
		if v == r {
			return append(s[:i], s[i+1:]...)
		}
	}
	return s
}
