package staker

import (
	"encoding/base64"
	"std"
	"time"

	"gno.land/r/gnoswap/v1/consts"

	en "gno.land/r/gnoswap/v1/emission"
	pn "gno.land/r/gnoswap/v1/position"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"
)

// GETTERs ===
// poolGNS
func GetPoolGns() string {
	en.MintAndDistributeGns()

	if len(poolGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, gnsAmount := range poolGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":  json.StringNode("poolPath", poolPath),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// poolCurrentBlockGns
func GetPoolCurrentBlockGns() string {
	en.MintAndDistributeGns()

	if len(poolCurrentBlockGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, gnsAmount := range poolCurrentBlockGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":  json.StringNode("poolPath", poolPath),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// poolLastTmpGns
func GetPoolLastTmpGns() string {
	en.MintAndDistributeGns()

	if len(poolLastTmpGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, gnsAmount := range poolLastTmpGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":  json.StringNode("poolPath", poolPath),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// poolAccuGns
func GetPoolAccuGns() string {
	en.MintAndDistributeGns()

	if len(poolAccuGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, gnsAmount := range poolAccuGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":  json.StringNode("poolPath", poolPath),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionGns
func GetPositionGns() string {
	en.MintAndDistributeGns()

	if len(positionGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, gnsAmount := range positionGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":   json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionLastGns
func GetPositionLastGns() string {
	en.MintAndDistributeGns()

	if len(positionLastGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, gnsAmount := range positionLastGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":   json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"gnsAmount": json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionLastExternal
func GetPositionLastExternal() string {
	en.MintAndDistributeGns()

	if len(positionLastExternal) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, lastExternals := range positionLastExternal {
		arr2Node := json.ArrayNode("", []*json.Node{})
		for incentiveId, lastRewardAmount := range lastExternals {
			obj2Node := json.ObjectNode("", map[string]*json.Node{
				"incentiveId":      json.StringNode("incentiveId", incentiveId),
				"lastRewardAmount": json.StringNode("lastRewardAmount", lastRewardAmount.ToString()),
			})
			arr2Node.AppendArray(obj2Node)
		}

		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":       json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"lastExternals": arr2Node,
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// externalLastCalculatedTimestamp
func GetExternalLastCalculatedTimestamp() string {
	en.MintAndDistributeGns()

	if len(externalLastCalculatedTimestamp) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for incentiveId, lastCalculatedTimestamp := range externalLastCalculatedTimestamp {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"incentiveId":             json.StringNode("incentiveId", incentiveId),
			"lastCalculatedTimestamp": json.StringNode("lastCalculatedTimestamp", ufmt.Sprintf("%d", lastCalculatedTimestamp)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// externalGns
func GetExternalGns() string {
	en.MintAndDistributeGns()

	if len(externalGns) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for incentiveId, gnsAmount := range externalGns {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"incentiveId": json.StringNode("incentiveId", incentiveId),
			"gnsAmount":   json.StringNode("gnsAmount", ufmt.Sprintf("%d", gnsAmount)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// poolTotalStakedLiquidity
func GetPoolTotalStakedLiquidity() string {
	en.MintAndDistributeGns()

	if len(poolTotalStakedLiquidity) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, totalStakedLiquidity := range poolTotalStakedLiquidity {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":             json.StringNode("poolPath", poolPath),
			"totalStakedLiquidity": json.StringNode("totalStakedLiquidity", totalStakedLiquidity.ToString()),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionsLiquidityRatio
func GetPositionsLiquidityRatio() string {
	en.MintAndDistributeGns()

	if len(positionsLiquidityRatio) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, positionRatio := range positionsLiquidityRatio {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":       json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"positionRatio": json.StringNode("positionRatio", positionRatio.ToString()),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// poolsPositions
func GetPoolsPositions() string {
	en.MintAndDistributeGns()

	if len(positionsLiquidityRatio) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for poolPath, tokenIds := range poolsPositions {
		tokenIdArrNode := make([]*json.Node, 0)

		for _, tokenId := range tokenIds {
			tokenIdArrNode = append(tokenIdArrNode, json.StringNode("", ufmt.Sprintf("%d", tokenId)))
		}

		objNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath": json.StringNode("poolPath", poolPath),
			"tokenIds": json.ArrayNode("", tokenIdArrNode),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// consts.Q96
func GetQ96() string {
	en.MintAndDistributeGns()

	return "79228162514264337593543950336"
}

// positionExternal
func GetPositionExternal() string {
	en.MintAndDistributeGns()

	if len(positionExternal) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, externals := range positionExternal {
		arr2Node := json.ArrayNode("", []*json.Node{})

		for incentiveId, externalRewards := range externals {
			obj2Node := json.ObjectNode("", map[string]*json.Node{
				"incentiveId":    json.StringNode("incentiveId", incentiveId),
				"poolPath":       json.StringNode("poolPath", externalRewards.poolPath),
				"tokenPath":      json.StringNode("tokenPath", externalRewards.tokenPath),
				"tokenAmountX96": json.StringNode("tokenAmountX96", externalRewards.tokenAmountX96.ToString()),
				//
				"tokenAmountFull":   json.StringNode("tokenAmountFull", ufmt.Sprintf("%d", externalRewards.tokenAmountFull)),
				"tokenAmountToGive": json.StringNode("tokenAmountToGive", ufmt.Sprintf("%d", externalRewards.tokenAmountToGive)),
			})
			arr2Node.AppendArray(obj2Node)
		}

		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":   json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"externals": arr2Node,
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionsInternalWarmUpAmount
func GetPositionsInternalWarmUpAmount() string {
	en.MintAndDistributeGns()

	if len(positionsInternalWarmUpAmount) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, internalWarmUpAmount := range positionsInternalWarmUpAmount {
		objNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId": json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
			"full30":  json.StringNode("full30", ufmt.Sprintf("%d", internalWarmUpAmount.full30)),
			"give30":  json.StringNode("give30", ufmt.Sprintf("%d", internalWarmUpAmount.give30)),
			"left30":  json.StringNode("left30", ufmt.Sprintf("%d", internalWarmUpAmount.left30)),
			"full50":  json.StringNode("full50", ufmt.Sprintf("%d", internalWarmUpAmount.full50)),
			"give50":  json.StringNode("give50", ufmt.Sprintf("%d", internalWarmUpAmount.give50)),
			"left50":  json.StringNode("left50", ufmt.Sprintf("%d", internalWarmUpAmount.left50)),
			"full70":  json.StringNode("full70", ufmt.Sprintf("%d", internalWarmUpAmount.full70)),
			"give70":  json.StringNode("give70", ufmt.Sprintf("%d", internalWarmUpAmount.give70)),
			"left70":  json.StringNode("left70", ufmt.Sprintf("%d", internalWarmUpAmount.left70)),
			"full100": json.StringNode("full100", ufmt.Sprintf("%d", internalWarmUpAmount.full100)),
		})
		arrNode.AppendArray(objNode)
	}

	return marshal(arrNode)
}

// positionsExternalWarmUpAmount
func GetPositionsExternalWarmUpAmount() string {
	en.MintAndDistributeGns()

	if len(positionsExternalWarmUpAmount) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, externals := range positionsExternalWarmUpAmount {
		for incentiveId, externalWarmUpAmount := range externals {
			objNode := json.ObjectNode("", map[string]*json.Node{
				"tokenId":     json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
				"incentiveId": json.StringNode("incentiveId", incentiveId),
				"full30":      json.StringNode("full30", ufmt.Sprintf("%d", externalWarmUpAmount.full30)),
				"give30":      json.StringNode("give30", ufmt.Sprintf("%d", externalWarmUpAmount.give30)),
				"left30":      json.StringNode("left30", ufmt.Sprintf("%d", externalWarmUpAmount.left30)),
				"full50":      json.StringNode("full50", ufmt.Sprintf("%d", externalWarmUpAmount.full50)),
				"give50":      json.StringNode("give50", ufmt.Sprintf("%d", externalWarmUpAmount.give50)),
				"left50":      json.StringNode("left50", ufmt.Sprintf("%d", externalWarmUpAmount.left50)),
				"full70":      json.StringNode("full70", ufmt.Sprintf("%d", externalWarmUpAmount.full70)),
				"give70":      json.StringNode("give70", ufmt.Sprintf("%d", externalWarmUpAmount.give70)),
				"left70":      json.StringNode("left70", ufmt.Sprintf("%d", externalWarmUpAmount.left70)),
				"full100":     json.StringNode("full100", ufmt.Sprintf("%d", externalWarmUpAmount.full100)),
			})
			arrNode.AppendArray(objNode)
		}
	}

	return marshal(arrNode)
}

// positionsExternalLastCalculatedHeight
func GetPositionsExternalLastCalculatedHeight() string {
	en.MintAndDistributeGns()

	if len(positionsExternalLastCalculatedHeight) == 0 {
		return ""
	}

	arrNode := json.ArrayNode("", []*json.Node{})
	for tokenId, externals := range positionsExternalLastCalculatedHeight {
		for incentiveId, lastCalculatedHeight := range externals {
			objNode := json.ObjectNode("", map[string]*json.Node{
				"tokenId":              json.StringNode("tokenId", ufmt.Sprintf("%d", tokenId)),
				"incentiveId":          json.StringNode("incentiveId", incentiveId),
				"lastCalculatedHeight": json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
			})
			arrNode.AppendArray(objNode)
		}
	}

	return marshal(arrNode)
}

// ETC
func GetHeight() int64 {
	en.MintAndDistributeGns()

	return std.GetHeight()
}

func GetTimeNowUnix() int64 {
	en.MintAndDistributeGns()

	return time.Now().Unix()
}

func GetExternalGnsAmount() uint64 {
	en.MintAndDistributeGns()

	return externalGnsAmount()
}

func GetExternalDepositGnsAmount() uint64 {
	en.MintAndDistributeGns()

	return externalDepositGnsAmount()
}

func GetStakerGnsBalance() uint64 {
	en.MintAndDistributeGns()

	return gnsBalance(consts.STAKER_ADDR)
}

func GetStakerEmissionGnsBalance() uint64 {
	en.MintAndDistributeGns()

	return gnsBalance(consts.STAKER_ADDR) - externalGnsAmount() - externalDepositGnsAmount()
}

func GetLastCalculatedBalance() uint64 {
	en.MintAndDistributeGns()

	return lastCalculatedBalance
}

func GetLastCalculatedHeight() int64 {
	en.MintAndDistributeGns()

	return lastCalculatedHeight
}

func GetPositionIsInRange(tokenId uint64) bool {
	en.MintAndDistributeGns()

	return pn.PositionIsInRange(tokenId)
}

func GetPositionLiquidity(tokenId uint64) string {
	en.MintAndDistributeGns()

	return pn.PositionGetPositionLiquidityStr(tokenId)
}

func GetMintedGnsAmount() uint64 {
	en.MintAndDistributeGns()

	// not a global variable
	// return mintedGnsAmount

	// formula: stakerGnsBalance - lastCalculatedBalance
	return gnsBalance(consts.STAKER_ADDR) - GetLastCalculatedBalance()
}

func GetNumPoolTiers() string {
	en.MintAndDistributeGns()

	tier1, tier2, tier3 := getNumPoolTiers()
	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1, tier2, tier3)
}

func GetTiersRatio() string {
	en.MintAndDistributeGns()

	tier1Ratio, tier2Ratio, tier3Ratio := listTierRatio()
	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1Ratio, tier2Ratio, tier3Ratio)
}

func GetTiersAmount(amount uint64) string {
	en.MintAndDistributeGns()

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(amount)
	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d", tier1Amount, tier2Amount, tier3Amount)
}

func GetWarmUpPeriods() string {
	en.MintAndDistributeGns()

	warmUp30 := warmUp[30]
	warmUp50 := warmUp[50]
	warmUp70 := warmUp[70]
	warmUp100 := warmUp[100]

	return ufmt.Sprintf("%d*STAKER*%d*STAKER*%d*STAKER*%d", warmUp30, warmUp50, warmUp70, warmUp100)
}

// COMMON
func marshal(data *json.Node) string {
	b, err := json.Marshal(data)
	if err != nil {
		panic(err.Error())
	}

	return string(b)
}

// GetNecessary returns the all necessary data for the calculation
func GetNecessary() string {
	en.MintAndDistributeGns()

	height := std.GetHeight()
	now := time.Now().Unix()

	externalGnsBalance := GetExternalGnsAmount()
	externalDepositGnsAmount := GetExternalDepositGnsAmount()

	gnsBalance := GetStakerGnsBalance()

	numPoolTiers := GetNumPoolTiers()
	tiersRatio := GetTiersRatio()

	response := json.ObjectNode("", map[string]*json.Node{
		"height":                  json.StringNode("height", ufmt.Sprintf("%d", height)),
		"now":                     json.StringNode("now", ufmt.Sprintf("%d", now)),
		"blockGenerationInterval": json.StringNode("blockGenerationInterval", ufmt.Sprintf("%d", consts.BLOCK_GENERATION_INTERVAL)),
		"lastCalculatedHeight":    json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
		"lastCalculatedBalance":   json.StringNode("lastCalculatedBalance", ufmt.Sprintf("%d", lastCalculatedBalance)),
		"externalGnsBalance":      json.StringNode("externalGnsBalance", ufmt.Sprintf("%d", externalGnsBalance)),
		"depositGnsAmount":        json.StringNode("depositGnsAmount", ufmt.Sprintf("%d", externalDepositGnsAmount)),
		"gnsBalance":              json.StringNode("gnsBalance", ufmt.Sprintf("%d", gnsBalance)),
		"numPoolTiers":            json.StringNode("numPoolTiers", numPoolTiers),
		"tiersRatio":              json.StringNode("tiersRatio", tiersRatio),
		"warmUpPeriods":           json.StringNode("warmUpPeriods", GetWarmUpPeriods()),
		//
		"poolGns":        json.StringNode("poolGns", b64encode(GetPoolGns())),
		"poolAccuGns":    json.StringNode("poolAccuGns", b64encode(GetPoolAccuGns())),
		"poolLastTmpGns": json.StringNode("poolLastTmpGns", b64encode(GetPoolLastTmpGns())),
		//
		"positionGns":                   json.StringNode("positionGns", b64encode(GetPositionGns())),
		"positionLastGns":               json.StringNode("positionLastGns", b64encode(GetPositionLastGns())),
		"positionsInternalWarmUpAmount": json.StringNode("positionsInternalWarmUpAmount", b64encode(GetPositionsInternalWarmUpAmount())),
		//
		"positionExternal":                      json.StringNode("positionExternal", b64encode(GetPositionExternal())),
		"positionLastExternal":                  json.StringNode("positionLastExternal", b64encode(GetPositionLastExternal())),
		"positionsExternalWarmUpAmount":         json.StringNode("positionsExternalWarmUpAmount", b64encode(GetPositionsExternalWarmUpAmount())),
		"positionsExternalLastCalculatedHeight": json.StringNode("positionsExternalLastCalculatedHeight", b64encode(GetPositionsExternalLastCalculatedHeight())),
		"externalLastCalculatedTimestamp":       json.StringNode("externalLastCalculatedTimestamp", b64encode(GetExternalLastCalculatedTimestamp())),
	})

	return marshal(response)
}

// GetSingleData returns the single data for the calculation
func GetSingleData() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	externalGnsBalance := GetExternalGnsAmount()
	externalDepositGnsAmount := GetExternalDepositGnsAmount()

	gnsBalance := GetStakerGnsBalance()

	numPoolTiers := GetNumPoolTiers()
	tiersRatio := GetTiersRatio()

	response := json.ObjectNode("", map[string]*json.Node{
		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
		//
		"blockGenerationInterval": json.StringNode("blockGenerationInterval", ufmt.Sprintf("%d", consts.BLOCK_GENERATION_INTERVAL)),
		"lastCalculatedHeight":    json.StringNode("lastCalculatedHeight", ufmt.Sprintf("%d", lastCalculatedHeight)),
		"lastCalculatedBalance":   json.StringNode("lastCalculatedBalance", ufmt.Sprintf("%d", lastCalculatedBalance)),
		"externalGnsBalance":      json.StringNode("externalGnsBalance", ufmt.Sprintf("%d", externalGnsBalance)),
		"depositGnsAmount":        json.StringNode("depositGnsAmount", ufmt.Sprintf("%d", externalDepositGnsAmount)),
		"gnsBalance":              json.StringNode("gnsBalance", ufmt.Sprintf("%d", gnsBalance)),
		"numPoolTiers":            json.StringNode("numPoolTiers", numPoolTiers),
		"tiersRatio":              json.StringNode("tiersRatio", tiersRatio),
		"warmUpPeriods":           json.StringNode("warmUpPeriods", GetWarmUpPeriods()),
	})

	return marshal(response)
}

// GetPoolGnsData returns the every pool's gns related data for the calculation
func GetPoolGnsData() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	response := json.ObjectNode("", map[string]*json.Node{
		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
		//
		"poolGns":        json.StringNode("poolGns", b64encode(GetPoolGns())),
		"poolAccuGns":    json.StringNode("poolAccuGns", b64encode(GetPoolAccuGns())),
		"poolLastTmpGns": json.StringNode("poolLastTmpGns", b64encode(GetPoolLastTmpGns())),
	})

	return marshal(response)
}

// GetPositionGnsData returns the every position's gns related data for the calculation
func GetPositionGnsData() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	response := json.ObjectNode("", map[string]*json.Node{
		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
		//
		"positionGns":                   json.StringNode("positionGns", b64encode(GetPositionGns())),
		"positionLastGns":               json.StringNode("positionLastGns", b64encode(GetPositionLastGns())),
		"positionsInternalWarmUpAmount": json.StringNode("positionsInternalWarmUpAmount", b64encode(GetPositionsInternalWarmUpAmount())),
	})

	return marshal(response)
}

// GetPositionExternalData returns the every position's external related data for the calculation
func GetPositionExternalData() string {
	height := std.GetHeight()
	now := time.Now().Unix()

	response := json.ObjectNode("", map[string]*json.Node{
		"height": json.StringNode("height", ufmt.Sprintf("%d", height)),
		"now":    json.StringNode("now", ufmt.Sprintf("%d", now)),
		//
		"positionExternal":                      json.StringNode("positionExternal", b64encode(GetPositionExternal())),
		"positionLastExternal":                  json.StringNode("positionLastExternal", b64encode(GetPositionLastExternal())),
		"positionsExternalWarmUpAmount":         json.StringNode("positionsExternalWarmUpAmount", b64encode(GetPositionsExternalWarmUpAmount())),
		"positionsExternalLastCalculatedHeight": json.StringNode("positionsExternalLastCalculatedHeight", b64encode(GetPositionsExternalLastCalculatedHeight())),
		"externalLastCalculatedTimestamp":       json.StringNode("externalLastCalculatedTimestamp", b64encode(GetExternalLastCalculatedTimestamp())),
	})

	return marshal(response)
}

func b64encode(data string) string {
	return base64.StdEncoding.EncodeToString([]byte(data))
}
