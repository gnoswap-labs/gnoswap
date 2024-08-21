package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"

	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"

	u256 "gno.land/p/gnoswap/uint256"
)

type currentExternalInfo struct {
	height             int64
	time               int64
	externalIncentives []ExternalIncentive
}

func printExternalInfo() {
	println("***********************")
	println("> height:", std.GetHeight())
	println("> time:", time.Now().Unix())
	println()
	println("[ START ] GET_EXTERNAL INCENTIVE")
	for poolPath, externalIds := range poolIncentives {
		println(" > poolPath:", poolPath)

		for _, externalId := range externalIds {
			incentive := incentives[externalId]
			// println("  > incentiveId:", externalId)
			// println("  > targetPoolPath:", incentive.targetPoolPath)
			println("  > rewardToken:", incentive.rewardToken)
			println("  > rewardAmount:", incentive.rewardAmount.ToString())
			println("  > rewardLeft:", incentive.rewardLeft.ToString())
			println("  > startTimestamp:", incentive.startTimestamp)
			println("  > endTimestamp:", incentive.endTimestamp)
			println("  > rewardPerBlockX96:", incentive.rewardPerBlockX96.ToString())
			println("  > refundee:", incentive.refundee)
			println()
		}
		println()
	}

	println("[ END ] GET_EXTERNAL INCENTIVE")
}

type ApiExternalDebugInfo struct {
	Height   int64                      `json:"height"`
	Time     int64                      `json:"time"`
	Position []ApiExternalDebugPosition `json:"pool"`
}

type ApiExternalDebugPosition struct {
	LpTokenId       uint64                      `json:"lpTokenId"`
	StakedHeight    int64                       `json:"stakedHeight"`
	StakedTimestamp int64                       `json:"stakedTimestamp"`
	Incentive       []ApiExternalDebugIncentive `json:"incentive"`
}

type ApiExternalDebugIncentive struct {
	PoolPath          string      `json:"poolPath"`
	IncentiveId       string      `json:"incentiveId"`
	RewardToken       string      `json:"rewardToken"`
	RewardAmount      string      `json:"rewardAmount"`
	RewardLeft        string      `json:"rewardLeft"`
	StartTimestamp    int64       `json:"startTimestamp"`
	EndTimestamp      int64       `json:"endTimestamp"`
	RewardPerBlockX96 string      `json:"rewardPerBlockX96"`
	RewardPerBlock    string      `json:"rewardPerBlock"`
	Refundee          std.Address `json:"refundee"`
	// FROM positionExternal -> externalRewards
	tokenAmountX96    *u256.Uint `json:"tokenAmountX96"`
	tokenAmount       uint64     `json:"tokenAmount"`
	tokenAmountFull   uint64     `json:"tokenAmountFull"`
	tokenAmountToGive uint64     `json:"tokenAmountToGive"`
	// FROM externalWarmUpAmount
	full30  uint64 `json:"full30"`
	give30  uint64 `json:"give30"`
	full50  uint64 `json:"full50"`
	give50  uint64 `json:"give50"`
	full70  uint64 `json:"full70"`
	give70  uint64 `json:"give70"`
	full100 uint64 `json:"full100"`
}

func GetPrintExternalInfo() string {
	// TODO: LIMIT ONLY ABCI_QUERY CAN CALL THIS
	en.MintAndDistributeGns()
	CalcPoolPosition()

	updateExternalIncentiveLeftAmount()

	externalDebug := ApiExternalDebugInfo{}
	externalDebug.Height = std.GetHeight()
	externalDebug.Time = time.Now().Unix()

	externalPositions := []ApiExternalDebugPosition{}
	for lpTokenId, externals := range positionExternal {
		externalPosition := ApiExternalDebugPosition{}
		externalPosition.LpTokenId = lpTokenId
		externalPosition.StakedHeight = deposits[lpTokenId].stakeHeight
		externalPosition.StakedTimestamp = deposits[lpTokenId].stakeTimestamp

		externalIncentives := []ApiExternalDebugIncentive{}
		for incentiveId, external := range externals {
			externalIncentive := ApiExternalDebugIncentive{}

			externalIncentive.PoolPath = external.poolPath
			externalIncentive.RewardToken = external.tokenPath

			incentive := incentives[incentiveId]
			externalIncentive.IncentiveId = incentiveId
			externalIncentive.RewardAmount = incentive.rewardAmount.ToString()
			externalIncentive.RewardLeft = incentive.rewardLeft.ToString()
			externalIncentive.StartTimestamp = incentive.startTimestamp
			externalIncentive.EndTimestamp = incentive.endTimestamp
			externalIncentive.RewardPerBlockX96 = incentive.rewardPerBlockX96.ToString()
			externalIncentive.RewardPerBlock = new(u256.Uint).Div(incentive.rewardPerBlockX96, u256.MustFromDecimal(consts.Q96)).ToString()
			externalIncentive.Refundee = incentive.refundee

			externalIncentive.tokenAmountX96 = external.tokenAmountX96

			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[lpTokenId][incentiveId]
			if !exist {
				continue
			}
			fullAmount := externalWarmUpAmount.full30 + externalWarmUpAmount.full50 + externalWarmUpAmount.full70 + externalWarmUpAmount.full100
			toGive := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100

			externalIncentive.full30 = externalWarmUpAmount.full30
			externalIncentive.give30 = externalWarmUpAmount.give30
			externalIncentive.full50 = externalWarmUpAmount.full50
			externalIncentive.give50 = externalWarmUpAmount.give50
			externalIncentive.full70 = externalWarmUpAmount.full70
			externalIncentive.give70 = externalWarmUpAmount.give70
			externalIncentive.full100 = externalWarmUpAmount.full100

			externalIncentive.tokenAmountFull = fullAmount
			externalIncentive.tokenAmountToGive = toGive

			externalIncentives = append(externalIncentives, externalIncentive)
		}
		externalPosition.Incentive = externalIncentives

		externalPositions = append(externalPositions, externalPosition)
	}

	externalDebug.Position = externalPositions

	// MARSHAL
	node := json.ObjectNode("", map[string]*json.Node{
		"height":   json.NumberNode("", float64(externalDebug.Height)),
		"time":     json.NumberNode("", float64(externalDebug.Time)),
		"position": json.ArrayNode("", makeExternalPositionsNode(externalDebug.Position)),
	})

	b, err := json.Marshal(node)
	if err != nil {
		return "JSON MARSHAL ERROR"
	}

	return string(b)
}

func makeExternalPositionsNode(positions []ApiExternalDebugPosition) []*json.Node {
	externalPositions := make([]*json.Node, 0)

	for _, externalPosition := range positions {
		incentives := make([]*json.Node, 0)
		for _, incentive := range externalPosition.Incentive {

			_max := max(incentive.StartTimestamp, deposits[externalPosition.LpTokenId].stakeTimestamp)
			stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL

			incentives = append(incentives, json.ObjectNode("", map[string]*json.Node{
				"poolPath":                 json.StringNode("poolPath", incentive.PoolPath),
				"rewardToken":              json.StringNode("rewardToken", incentive.RewardToken),
				"rewardAmount":             json.StringNode("rewardAmount", incentive.RewardAmount),
				"startTimestamp":           json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
				"endTimestamp":             json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
				"rewardPerBlockX96":        json.StringNode("rewardPerBlockX96", incentive.RewardPerBlockX96),
				"stakedOrExternalDuration": json.NumberNode("stakedOrExternalDuration", float64(stakedOrExternalDuration)),
				"rewardPerBlock":           json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
				"refundee":                 json.StringNode("refundee", incentive.Refundee.String()),
				// "tokenAmountX96":           json.StringNode("tokenAmountX96", incentive.tokenAmountX96.ToString()),
				// "tokenAmount":              json.NumberNode("tokenAmount", float64(new(u256.Uint).Div(incentive.tokenAmountX96, _q96).Uint64())),
				"tokenAmountFull":   json.NumberNode("tokenAmountFull", float64(incentive.tokenAmountFull)),
				"tokenAmountToGive": json.NumberNode("tokenAmountToGive", float64(incentive.tokenAmountToGive)),
				//
				"full30":  json.NumberNode("full30", float64(incentive.full30)),
				"give30":  json.NumberNode("give30", float64(incentive.give30)),
				"full50":  json.NumberNode("full50", float64(incentive.full50)),
				"give50":  json.NumberNode("give50", float64(incentive.give50)),
				"full70":  json.NumberNode("full70", float64(incentive.full70)),
				"give70":  json.NumberNode("give70", float64(incentive.give70)),
				"full100": json.NumberNode("full100", float64(incentive.full100)),
			}))
		}

		externalPositions = append(externalPositions, json.ObjectNode("", map[string]*json.Node{
			"lpTokenId":       json.NumberNode("lpTokenId", float64(externalPosition.LpTokenId)),
			"stakedHeight":    json.NumberNode("stakedHeight", float64(externalPosition.StakedHeight)),
			"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(externalPosition.StakedTimestamp)),
			"incentive":       json.ArrayNode("", incentives),
		}))
	}

	return externalPositions
}
