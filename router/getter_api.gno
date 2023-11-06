// EXTERNAL API
package router

import (
	"encoding/json"
	"strings"

	p "gno.land/r/pool"

	"gno.land/p/demo/ufmt"
)

const BASE_TOKEN = "gno.land/r/foo"

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

	ratios := getRatiosFromBase()
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
		panic(ufmt.Sprintf("[ROUTER] getter_api.gno()__ApiGetRatioFromBase || json.Marshal error with %v", err))
	}

	return string(rr)
}

func getRatiosFromBase() []map[string]bigint {
	tokenPrice := make(map[string]bigint, 0)

	// BASE
	tokenPrice[BASE_TOKEN] = Q96 // ~= 1

	// ELSE
	tokenList := getTokenList()
	for _, token := range tokenList {
		if token != BASE_TOKEN {
			swapPaths := findSwapPaths(token, BASE_TOKEN)
			numSwapPaths := len(swapPaths)

			thisTokenPriceX96 := bigint(0)
			if numSwapPaths < 1 {
				tokenPrice[token] = 0
			} else {
				for _, swapPath := range swapPaths {
					numPools := strings.Count(swapPath, ",") / 2

					switch numPools {
					case 0:
						thisTokenPriceX96 = 0
					case 1:
						priceRatio := calculateSinglePoolPrice(token, swapPath)
						thisTokenPriceX96 += priceRatio
					case 2:
						priceRatio := calculateTwoPoolPrice(token, swapPath, numPools)
						thisTokenPriceX96 += priceRatio
					case 3:
						priceRatio := calculateThreePoolPrice(token, swapPath, numPools)
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
	tokenList := []string{}
	poolList := p.GetPoolList()

	for _, poolPath := range poolList {
		token0Path, token1Path, fee := poolPathWithFeeDivide(poolPath)
		tokenList = append(tokenList, token0Path)
		tokenList = append(tokenList, token1Path)
	}

	uniqueTokenList := removeDuplicates(tokenList)
	return uniqueTokenList
}

func removeDuplicates(input []string) []string {
	seen := make(map[string]struct{})
	result := []string{}

	for _, item := range input {
		if _, ok := seen[item]; !ok {
			seen[item] = struct{}{}
			result = append(result, item)
		}
	}

	return result
}

func makePoolPath(poolPath string, poolIndex int) string {
	poolDatas := strings.Split(poolPath, ",")

	switch poolIndex {
	case 0:
		token0Path := poolDatas[0]
		token1Path := poolDatas[2]
		fee := poolDatas[1]
		if token0Path < token1Path {
			return token0Path + ":" + token1Path + ":" + fee
		} else {
			return token1Path + ":" + token0Path + ":" + fee
		}
	case 1:
		token0Path := poolDatas[2]
		token1Path := poolDatas[4]
		fee := poolDatas[3]
		if token0Path < token1Path {
			return token0Path + ":" + token1Path + ":" + fee
		} else {
			return token1Path + ":" + token0Path + ":" + fee
		}
	case 2:
		token0Path := poolDatas[4]
		token1Path := poolDatas[6]
		fee := poolDatas[5]
		if token0Path < token1Path {
			return token0Path + ":" + token1Path + ":" + fee
		} else {
			return token1Path + ":" + token0Path + ":" + fee
		}
	default:
		panic(ufmt.Sprintf("[ROUTER] getter_api.gno__makePoolPath() || unknown pool index: %d", poolIndex))
	}
}

func calculateSinglePoolPrice(token, swapPath string) bigint {
	poolPathKey := makePoolPath(swapPath, 0)
	pool := p.GetPoolFromPoolKey(poolPathKey)

	token0 := pool.GetToken0Path()
	token1 := pool.GetToken1Path()
	sqrtPriceX96 := pool.GetSlotSqrtPriceX96()

	if token0 == token && BASE_TOKEN == token1 { // token0 is token
		ratio := Q96 * Q96 / (sqrtPriceX96 * sqrtPriceX96 / Q96)
		return ratio
	} else if token1 == token && BASE_TOKEN == token0 { // token1 is token
		return sqrtPriceX96 * sqrtPriceX96 / Q96
	} else {
		panic("[ROUTER] getter_api.gno__calculateSinglePoolPrice() || wrong condition")
	}
}

func calculateTwoPoolPrice(token, swapPath string, numPools int) bigint {
	// first
	firstPoolPathKey := makePoolPath(swapPath, 0)
	firstPool := p.GetPoolFromPoolKey(firstPoolPathKey)

	firstToken0 := firstPool.GetToken0Path()
	firstToken1 := firstPool.GetToken1Path()
	firstSqrtPriceX96 := firstPool.GetSlotSqrtPriceX96()

	firstPrice := bigint(0)
	useNext := ""
	if firstToken0 == token {
		firstPrice = Q96 * Q96 / (firstSqrtPriceX96 * firstSqrtPriceX96 / Q96)
		useNext = firstToken1
	} else if firstToken1 == token {
		firstPrice = firstSqrtPriceX96 * firstSqrtPriceX96 / Q96
		useNext = firstToken0
	} else {
		panic("[ROUTER] getter_api.gno__calculateTwoPoolPrice() || wrong condition #1")
	}

	// second && last
	secondPoolPathKey := makePoolPath(swapPath, 1)
	secondPool := p.GetPoolFromPoolKey(secondPoolPathKey)

	secondToken0 := secondPool.GetToken0Path()
	secondToken1 := secondPool.GetToken1Path()
	secondSqrtPriceX96 := secondPool.GetSlotSqrtPriceX96()

	secondPrice := bigint(0)
	if secondToken0 == useNext && BASE_TOKEN == secondToken1 {
		secondPrice = Q96 * Q96 / (secondSqrtPriceX96 * secondSqrtPriceX96 / Q96)
	} else if secondToken1 == useNext && BASE_TOKEN == secondToken0 {
		secondPrice = secondSqrtPriceX96 * secondSqrtPriceX96 / Q96
	} else {
		panic("[ROUTER] getter_api.gno__calculateTwoPoolPrice() || wrong condition #2")
	}

	twoNestedPrice := firstPrice * secondPrice
	return twoNestedPrice / Q96
}

func calculateThreePoolPrice(token, swapPath string, numPools int) bigint {
	// first
	firstPoolPathKey := makePoolPath(swapPath, 0)
	firstPool := p.GetPoolFromPoolKey(firstPoolPathKey)

	firstToken0 := firstPool.GetToken0Path()
	firstToken1 := firstPool.GetToken1Path()
	firstSqrtPriceX96 := firstPool.GetSlotSqrtPriceX96()

	firstPrice := bigint(0)
	restFirst := ""
	if firstToken0 == token {
		firstPrice = Q96 * Q96 / (firstSqrtPriceX96 * firstSqrtPriceX96 / Q96)
		restFirst = firstToken1
	} else if firstToken1 == token {
		firstPrice = firstSqrtPriceX96 * firstSqrtPriceX96 / Q96
		restFirst = firstToken0
	} else {
		panic("[ROUTER] getter_api.gno__calculateThreePoolPrice() || wrong condition #1")
	}

	// second
	secondPoolPathKey := makePoolPath(swapPath, 1)
	secondPool := p.GetPoolFromPoolKey(secondPoolPathKey)

	secondToken0 := secondPool.GetToken0Path()
	secondToken1 := secondPool.GetToken1Path()
	secondSqrtPriceX96 := secondPool.GetSlotSqrtPriceX96()

	secondPrice := bigint(0)
	restSecond := ""
	if secondToken0 == restFirst {
		secondPrice = Q96 * Q96 / (secondSqrtPriceX96 * secondSqrtPriceX96 / Q96)
		restSecond = secondToken1
	} else if secondToken1 == restFirst {
		secondPrice = secondSqrtPriceX96 * secondSqrtPriceX96 / Q96
		restSecond = secondToken0
	} else {
		panic("[ROUTER] getter_api.gno__calculateThreePoolPrice() || wrong condition #2")
	}

	// third && last
	thirdPoolPathKey := makePoolPath(swapPath, 2)
	thirdPool := p.GetPoolFromPoolKey(thirdPoolPathKey)

	thirdToken0 := thirdPool.GetToken0Path()
	thirdToken1 := thirdPool.GetToken1Path()
	thirdSqrtPriceX96 := thirdPool.GetSlotSqrtPriceX96()

	thirdPrice := bigint(0)

	if thirdToken0 == restSecond && BASE_TOKEN == thirdToken1 {
		thirdPrice = Q96 * Q96 / (thirdSqrtPriceX96 * thirdSqrtPriceX96 / Q96)
	} else if thirdToken1 == restSecond && BASE_TOKEN == thirdToken0 {
		thirdPrice = thirdSqrtPriceX96 * thirdSqrtPriceX96 / Q96
	} else {
		panic("[ROUTER] getter_api.gno__calculateThreePoolPrice() || wrong condition #3")
	}

	threeNestedPrice := firstPrice * secondPrice * thirdPrice
	return threeNestedPrice / Q96 / Q96
}
