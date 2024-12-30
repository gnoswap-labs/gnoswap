package staker

import (
	"encoding/base64"
	"std"
	"time"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

func GetPoolStakedLiquidityUpdates(poolPath string, startHeight, endHeight uint64) string {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return ""
	}

	builder := json.Builder().WriteArray("", func(ab *json.ArrayBuilder) {
		pool.stakedLiquidity.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
			ab.WriteObject(func(ob *json.NodeBuilder) {
				ob.WriteString("blockNumber", ufmt.Sprintf("%d", key))
				ob.WriteString("liquidity", value.(*u256.Uint).ToString())
			})
			return false
		})
	})

	return marshal(builder.Node())
}

// func GetPoolRewardUpdates(poolPath string, startHeight, endHeight uint64) string {
// 	pool, ok := pools.Get(poolPath)
// 	if !ok {
// 		return ""
// 	}

// 	// TODO: remove comment
// 	// if endHeight > pool.lastRewardCacheHeight {
// 	// 	poolTier.cacheReward(endHeight)
// 	// 	poolTier.cachePoolReward(pool.rewardCache, poolPath, endHeight)
// 	// }

// 	builder := json.Builder().WriteArray("", func(ab *json.ArrayBuilder) {
// 		pool.rewardCache.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
// 			ab.WriteObject(func(ob *json.NodeBuilder) {
// 				ob.WriteString("blockNumber", ufmt.Sprintf("%d", key))
// 				ob.WriteString("reward", value.(*u256.Uint).ToString())
// 			})
// 			return false
// 		})
// 	})

// 	return marshal(builder.Node())
// }

// poolsPositions
// func GetPoolsPositions() string {
// 	en.MintAndDistributeGns()

// 	// TODO: find original/modified code and remove comment
// 	if len(positionsLiquidityRatio) == 0 {
// 		return ""
// 	}

// 	builder := json.Builder().WriteArray("", func(ab *json.ArrayBuilder) {
// 		for poolPath, tokenIds := range poolsPositions {
// 			ab.WriteObject(func(ob *json.NodeBuilder) {
// 				buildPoolPosition(poolPath, tokenIds, ob)
// 			})
// 		}
// 	})

// 	return marshal(arrNode)
// }

// func buildTokenIsArray(tokenIds []uint64, ab *json.ArrayBuilder) {
// 	for _, tokenId := range tokenIds {
// 		ab.WriteString(ufmt.Sprintf("%d", tokenId))
// 	}
// }

// func buildPoolPosition(poolPath string, tokenIds []uint64, ob *json.NodeBuilder) {
// 	ob.WriteString("poolPath", poolPath)
// 	ob.WriteArray("tokenIds", func(ab *json.ArrayBuilder) {
// 		buildTokenIsArray(tokenIds, ab)
// 	})
// }

// consts.Q96
// func GetQ96() string {
// 	en.MintAndDistributeGns()

// 	return "79228162514264337593543950336"
// }

// // positionExternal
// func GetPositionExternal() string {
// 	en.MintAndDistributeGns()

// 	if len(positionExternal) == 0 {
// 		return ""
// 	}

// 	builder := json.Builder().WriteArray("", func(ab *json.ArrayBuilder) {
// 		for tokenId, externals := range positionExternal {
// 			ab.WriteObject(func(ob *json.NodeBuilder) {
// 				ob.WriteString("tokenId", ufmt.Sprintf("%d", tokenId))
// 				ob.WriteArray("externals", func(extAb *json.ArrayBuilder) {
// 					buildPositionExternals(externals, extAb)
// 				})
// 			})
// 		}
// 	})

// 	return marshal(builder.Node())
// }

// func buildExternalReward(incentiveId string, reward *externalRewards, ob *json.NodeBuilder) {
// 	ob.WriteString("incentiveId", incentiveId)
// 	ob.WriteString("poolPath", reward.poolPath)
// 	ob.WriteString("tokenPath", reward.tokenPath)
// 	ob.WriteString("tokenAmountX96", reward.tokenAmountX96.ToString())
// 	ob.WriteString("tokenAmountFull", ufmt.Sprintf("%d", reward.tokenAmountFull))
// 	ob.WriteString("tokenAmountToGive", ufmt.Sprintf("%d", reward.tokenAmountToGive))
// }

// func buildPositionExternals(externals map[string]externalRewards, ab *json.ArrayBuilder) {
// 	for incentiveId, externalRewards := range externals {
// 		ab.WriteObject(func(ob *json.NodeBuilder) {
// 			buildExternalReward(incentiveId, &externalRewards, ob)
// 		})
// 	}
// }

// positionsInternalWarmUpAmount
// func GetPositionsInternalWarmUpAmount() string {
// 	en.MintAndDistributeGns()

// 	if len(positionsInternalWarmUpAmount) == 0 {
// 		return ""
// 	}

// 	arrNode := json.ArrayNode("", []*json.Node{})
// 	for tokenId, internalWarmUpAmount := range positionsInternalWarmUpAmount {
// 		objNode := json.ObjectNode("", map[string]*json.Node{
// 			"tokenId": json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
// 			"full30":  json.StringNode("full30", ufmt.Sprintf("%d", internalWarmUpAmount.full30)),
// 			"give30":  json.StringNode("give30", ufmt.Sprintf("%d", internalWarmUpAmount.give30)),
// 			"left30":  json.StringNode("left30", ufmt.Sprintf("%d", internalWarmUpAmount.left30)),
// 			"full50":  json.StringNode("full50", ufmt.Sprintf("%d", internalWarmUpAmount.full50)),
// 			"give50":  json.StringNode("give50", ufmt.Sprintf("%d", internalWarmUpAmount.give50)),
// 			"left50":  json.StringNode("left50", ufmt.Sprintf("%d", internalWarmUpAmount.left50)),
// 			"full70":  json.StringNode("full70", ufmt.Sprintf("%d", internalWarmUpAmount.full70)),
// 			"give70":  json.StringNode("give70", ufmt.Sprintf("%d", internalWarmUpAmount.give70)),
// 			"left70":  json.StringNode("left70", ufmt.Sprintf("%d", internalWarmUpAmount.left70)),
// 			"full100": json.StringNode("full100", ufmt.Sprintf("%d", internalWarmUpAmount.full100)),
// 		})
// 		arrNode.AppendArray(objNode)
// 	}

// 	return marshal(arrNode)
// }

// positionsExternalWarmUpAmount
// func GetPositionsExternalWarmUpAmount() string {
// 	en.MintAndDistributeGns()

// 	if len(positionsExternalWarmUpAmount) == 0 {
// 		return ""
// 	}

// 	arrNode := json.ArrayNode("", []*json.Node{})
// 	for tokenId, externals := range positionsExternalWarmUpAmount {
// 		for incentiveId, externalWarmUpAmount := range externals {
// 			objNode := json.ObjectNode("", map[string]*json.Node{
// 				"tokenId":     json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
// 				"incentiveId": json.StringNode("incentiveId", incentiveId),
// 				"full30":      json.StringNode("full30", ufmt.Sprintf("%d", externalWarmUpAmount.full30)),
// 				"give30":      json.StringNode("give30", ufmt.Sprintf("%d", externalWarmUpAmount.give30)),
// 				"left30":      json.StringNode("left30", ufmt.Sprintf("%d", externalWarmUpAmount.left30)),
// 				"full50":      json.StringNode("full50", ufmt.Sprintf("%d", externalWarmUpAmount.full50)),
// 				"give50":      json.StringNode("give50", ufmt.Sprintf("%d", externalWarmUpAmount.give50)),
// 				"left50":      json.StringNode("left50", ufmt.Sprintf("%d", externalWarmUpAmount.left50)),
// 				"full70":      json.StringNode("full70", ufmt.Sprintf("%d", externalWarmUpAmount.full70)),
// 				"give70":      json.StringNode("give70", ufmt.Sprintf("%d", externalWarmUpAmount.give70)),
// 				"left70":      json.StringNode("left70", ufmt.Sprintf("%d", externalWarmUpAmount.left70)),
// 				"full100":     json.StringNode("full100", ufmt.Sprintf("%d", externalWarmUpAmount.full100)),
// 			})
// 			arrNode.AppendArray(objNode)
// 		}
// 	}

// 	return marshal(arrNode)
// }

// positionsExternalLastCalculatedHeight
// func GetPositionsExternalLastCalculatedHeight() string {
// 	en.MintAndDistributeGns()

// 	if len(positionsExternalLastCalculatedHeight) == 0 {
// 		return ""
// 	}

// 	arrNode := json.ArrayNode("", []*json.Node{})
// 	for tokenId, externals := range positionsExternalLastCalculatedHeight {
// 		for incentiveId, lastCalculatedHeight := range externals {
// 			objNode := json.ObjectNode("", map[string]*json.Node{
// 				"tokenId":              json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
// 				"incentiveId":          json.StringNode("incentiveId", incentiveId),
// 				"lastCalculatedHeight": json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
// 			})
// 			arrNode.AppendArray(objNode)
// 		}
// 	}

// 	return marshal(arrNode)
// }

// // ETC
// func GetHeight() int64 {
// 	en.MintAndDistributeGns()

// 	return std.GetHeight()
// }

// func GetTimeNowUnix() int64 {
// 	en.MintAndDistributeGns()

// 	return time.Now().Unix()
// }

// func GetExternalGnsAmount() uint64 {
// 	en.MintAndDistributeGns()

// 	return externalGnsAmount()
// }

// func GetExternalDepositGnsAmount() uint64 {
// 	en.MintAndDistributeGns()

// 	return externalDepositGnsAmount()
// }

// func GetStakerGnsBalance() uint64 {
// 	en.MintAndDistributeGns()

// 	return gnsBalance(consts.STAKER_ADDR)
// }

// func GetStakerEmissionGnsBalance() uint64 {
// 	en.MintAndDistributeGns()

// 	return gnsBalance(consts.STAKER_ADDR) - externalGnsAmount() - externalDepositGnsAmount()
// }

// func GetLastCalculatedBalance() uint64 {
// 	en.MintAndDistributeGns()

// 	return lastCalculatedBalance
// }

// func GetLastCalculatedHeight() int64 {
// 	en.MintAndDistributeGns()

// 	return lastCalculatedHeight
// }

// func GetPositionIsInRange(tokenId uint64) bool {
// 	en.MintAndDistributeGns()

// 	return pn.PositionIsInRange(tokenId)
// }

// func GetPositionLiquidity(tokenId uint64) string {
// 	en.MintAndDistributeGns()

// 	return pn.PositionGetPositionLiquidityStr(tokenId)
// }

// func GetMintedGnsAmount() uint64 {
// 	en.MintAndDistributeGns()

// 	// not a global variable
// 	// return mintedGnsAmount

// 	// formula: stakerGnsBalance - lastCalculatedBalance
// 	return gnsBalance(consts.STAKER_ADDR) - GetLastCalculatedBalance()
// }

// func GetNumPoolTiers() string {
// 	en.MintAndDistributeGns()

// 	tier1, tier2, tier3 := getNumPoolTiers()
// 	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1, tier2, tier3)
// }

// func GetTiersRatio() string {
// 	en.MintAndDistributeGns()

// 	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()
// 	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1Ratio, tier2Ratio, tier3Ratio)
// }

// func GetTiersAmount(amount uint64) string {
// 	en.MintAndDistributeGns()

// 	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(amount)
// 	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1Amount, tier2Amount, tier3Amount)
// }

// func GetWarmUpPeriods() string {
// 	en.MintAndDistributeGns()

// 	warmUp30 := warmUp[30]
// 	warmUp50 := warmUp[50]
// 	warmUp70 := warmUp[70]
// 	warmUp100 := warmUp[100]

// 	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d*STAKER*%d", warmUp30, warmUp50, warmUp70, warmUp100)
// }

// // GetNecessary returns the all necessary data for the calculation
// func GetNecessary() string {
// 	en.MintAndDistributeGns()

// 	height := std.GetHeight()
// 	now := time.Now().Unix()

// 	externalGnsBalance := GetExternalGnsAmount()
// 	externalDepositGnsAmount := GetExternalDepositGnsAmount()

// 	gnsBalance := GetStakerGnsBalance()

// 	numPoolTiers := GetNumPoolTiers()
// 	tiersRatio := GetTiersRatio()

// 	response := json.ObjectNode("", map[string]*json.Node{
// 		"height":                  json.StringNode("height", ufmt.Sprintf("%d", height)),
// 		"now":                     json.StringNode("now", ufmt.Sprintf("%d", now)),
// 		"blockGenerationInterval": json.StringNode("blockGenerationInterval", ufmt.Sprintf("%d", consts.BLOCK_GENERATION_INTERVAL)),
// 		"lastCalculatedHeight":    json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
// 		"lastCalculatedBalance":   json.StringNode("lastCalculatedBalance", ufmt.Sprintf("%d", lastCalculatedBalance)),
// 		"externalGnsBalance":      json.StringNode("externalGnsBalance", ufmt.Sprintf("%d", externalGnsBalance)),
// 		"depositGnsAmount":        json.StringNode("depositGnsAmount", ufmt.Sprintf("%d", externalDepositGnsAmount)),
// 		"gnsBalance":              json.StringNode("gnsBalance", ufmt.Sprintf("%d", gnsBalance)),
// 		"numPoolTiers":            json.StringNode("numPoolTiers", numPoolTiers),
// 		"tiersRatio":              json.StringNode("tiersRatio", tiersRatio),
// 		"warmUpPeriods":           json.StringNode("warmUpPeriods", GetWarmUpPeriods()),
// 		//
// 		"poolGns":        json.StringNode("poolGns", b64encode(GetPoolGns())),
// 		"poolAccuGns":    json.StringNode("poolAccuGns", b64encode(GetPoolAccuGns())),
// 		"poolLastTmpGns": json.StringNode("poolLastTmpGns", b64encode(GetPoolLastTmpGns())),
// 		//
// 		"positionGns":                   json.StringNode("positionGns", b64encode(GetPositionGns())),
// 		"positionLastGns":               json.StringNode("positionLastGns", b64encode(GetPositionLastGns())),
// 		"positionsInternalWarmUpAmount": json.StringNode("positionsInternalWarmUpAmount", b64encode(GetPositionsInternalWarmUpAmount())),
// 		//
// 		"positionExternal":                      json.StringNode("positionExternal", b64encode(GetPositionExternal())),
// 		"positionLastExternal":                  json.StringNode("positionLastExternal", b64encode(GetPositionLastExternal())),
// 		"positionsExternalWarmUpAmount":         json.StringNode("positionsExternalWarmUpAmount", b64encode(GetPositionsExternalWarmUpAmount())),
// 		"positionsExternalLastCalculatedHeight": json.StringNode("positionsExternalLastCalculatedHeight", b64encode(GetPositionsExternalLastCalculatedHeight())),
// 		"externalLastCalculatedTimestamp":       json.StringNode("externalLastCalculatedTimestamp", b64encode(GetExternalLastCalculatedTimestamp())),
// 	})

// 	return marshal(response)
// }

// // GetSingleData returns the single data for the calculation
// func GetSingleData() string {
// 	height := std.GetHeight()
// 	now := time.Now().Unix()

// 	externalGnsBalance := GetExternalGnsAmount()
// 	externalDepositGnsAmount := GetExternalDepositGnsAmount()

// 	gnsBalance := GetStakerGnsBalance()

// 	numPoolTiers := GetNumPoolTiers()
// 	tiersRatio := GetTiersRatio()

// 	response := json.ObjectNode("", map[string]*json.Node{
// 		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
// 		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
// 		//
// 		"blockGenerationInterval": json.StringNode("blockGenerationInterval", ufmt.Sprintf("%d", consts.BLOCK_GENERATION_INTERVAL)),
// 		"lastCalculatedHeight":    json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
// 		"lastCalculatedBalance":   json.StringNode("lastCalculatedBalance", ufmt.Sprintf("%d", lastCalculatedBalance)),
// 		"externalGnsBalance":      json.StringNode("externalGnsBalance", ufmt.Sprintf("%d", externalGnsBalance)),
// 		"depositGnsAmount":        json.StringNode("depositGnsAmount", ufmt.Sprintf("%d", externalDepositGnsAmount)),
// 		"gnsBalance":              json.StringNode("gnsBalance", ufmt.Sprintf("%d", gnsBalance)),
// 		"numPoolTiers":            json.StringNode("numPoolTiers", numPoolTiers),
// 		"tiersRatio":              json.StringNode("tiersRatio", tiersRatio),
// 		"warmUpPeriods":           json.StringNode("warmUpPeriods", GetWarmUpPeriods()),
// 	})

// 	return marshal(response)
// }

// // GetPoolGnsData returns the every pool's gns related data for the calculation
// func GetPoolGnsData() string {
// 	height := std.GetHeight()
// 	now := time.Now().Unix()

// 	response := json.ObjectNode("", map[string]*json.Node{
// 		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
// 		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
// 		//
// 		"poolGns":        json.StringNode("poolGns", b64encode(GetPoolGns())),
// 		"poolAccuGns":    json.StringNode("poolAccuGns", b64encode(GetPoolAccuGns())),
// 		"poolLastTmpGns": json.StringNode("poolLastTmpGns", b64encode(GetPoolLastTmpGns())),
// 	})

// 	return marshal(response)
// }

// // GetPositionGnsData returns the every position's gns related data for the calculation
// func GetPositionGnsData() string {
// 	height := std.GetHeight()
// 	now := time.Now().Unix()

// 	response := json.ObjectNode("", map[string]*json.Node{
// 		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
// 		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
// 		//
// 		"positionGns":                   json.StringNode("positionGns", b64encode(GetPositionGns())),
// 		"positionLastGns":               json.StringNode("positionLastGns", b64encode(GetPositionLastGns())),
// 		"positionsInternalWarmUpAmount": json.StringNode("positionsInternalWarmUpAmount", b64encode(GetPositionsInternalWarmUpAmount())),
// 	})

// 	return marshal(response)
// }

// // GetPositionExternalData returns the every position's external related data for the calculation
// func GetPositionExternalData() string {
// 	height := std.GetHeight()
// 	now := time.Now().Unix()

// 	response := json.ObjectNode("", map[string]*json.Node{
// 		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
// 		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
// 		//
// 		"positionExternal":                      json.StringNode("positionExternal", b64encode(GetPositionExternal())),
// 		"positionLastExternal":                  json.StringNode("positionLastExternal", b64encode(GetPositionLastExternal())),
// 		"positionsExternalWarmUpAmount":         json.StringNode("positionsExternalWarmUpAmount", b64encode(GetPositionsExternalWarmUpAmount())),
// 		"positionsExternalLastCalculatedHeight": json.StringNode("positionsExternalLastCalculatedHeight", b64encode(GetPositionsExternalLastCalculatedHeight())),
// 		"externalLastCalculatedTimestamp":       json.StringNode("externalLastCalculatedTimestamp", b64encode(GetExternalLastCalculatedTimestamp())),
// 	})

// 	return marshal(response)
// }

// func b64encode(data string) string {
// 	return base64.StdEncoding.EncodeToString([]byte(data))
// }

func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}
