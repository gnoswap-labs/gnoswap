package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	en "gno.land/r/gnoswap/v2/emission"
	pl "gno.land/r/gnoswap/v2/pool"

	"gno.land/r/gnoswap/v2/consts"

	"gno.land/r/gnoswap/v2/gns"
)

type RewardToken struct {
	PoolPath         string   `json:"poolPath"`
	RewardsTokenList []string `json:"rewardsTokenList"`
}

type ApiExternalIncentive struct {
	IncentiveId    string `json:"incentiveId"`
	PoolPath       string `json:"poolPath"`
	RewardToken    string `json:"rewardToken"`
	RewardAmount   string `json:"rewardAmount"`
	RewardLeft     string `json:"rewardLeft"`
	StartTimestamp int64  `json:"startTimestamp"`
	EndTimestamp   int64  `json:"endTimestamp"`
	Active         bool   `json:"active"`
	Refundee       string `json:"refundee"`
	CreatedHeight  int64  `json:"createdHeight"`
}

type ApiInternalIncentive struct {
	PoolPath       string `json:"poolPath"`
	Tier           uint64 `json:"tier"`
	StartTimestamp int64  `json:"startTimestamp"`
	RewardPerBlock string `json:"rewardPerBlock"`
}

func ApiGetRewardTokens() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	rewardTokens := []RewardToken{}

	poolList := pl.PoolGetPoolList()
	for _, poolPath := range poolList {
		thisPoolRewardTokens := []string{}

		// HANDLE INTERNAL
		_, ok := poolTiers[poolPath]
		if ok {
			thisPoolRewardTokens = append(thisPoolRewardTokens, consts.GNS_PATH)
		}

		// HANDLE EXTERNAL
		for _, incentiveId := range poolIncentives[poolPath] {
			if incentives[incentiveId].rewardToken == "" {
				continue
			}
			thisPoolRewardTokens = append(thisPoolRewardTokens, incentives[incentiveId].rewardToken)
		}

		if len(thisPoolRewardTokens) == 0 {
			continue
		}

		rewardTokens = append(rewardTokens, RewardToken{
			PoolPath:         poolPath,
			RewardsTokenList: thisPoolRewardTokens,
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, rewardToken := range rewardTokens {
		_rewardTokenNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath": json.StringNode("poolPath", rewardToken.PoolPath),
			"tokens":   json.ArrayNode("tokens", makeRewardTokensArray(rewardToken.RewardsTokenList)),
		})
		responses.AppendArray(_rewardTokenNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardTokens() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	rewardTokens := []RewardToken{}

	poolList := pl.PoolGetPoolList()
	for _, poolPath := range poolList {
		if poolPath != targetPoolPath {
			continue
		}

		thisPoolRewardTokens := []string{}

		// HANDLE INTERNAL
		_, ok := poolTiers[poolPath]
		if ok {
			thisPoolRewardTokens = append(thisPoolRewardTokens, consts.GNS_PATH)
		}

		// HANDLE EXTERNAL
		for _, incentiveId := range poolIncentives[poolPath] {
			thisPoolRewardTokens = append(thisPoolRewardTokens, incentives[incentiveId].rewardToken)
		}

		rewardTokens = append(rewardTokens, RewardToken{
			PoolPath:         poolPath,
			RewardsTokenList: thisPoolRewardTokens,
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, rewardToken := range rewardTokens {
		_rewardTokenNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath": json.StringNode("poolPath", rewardToken.PoolPath),
			"tokens":   json.ArrayNode("tokens", makeRewardTokensArray(rewardToken.RewardsTokenList)),
		})
		responses.AppendArray(_rewardTokenNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardTokensByPoolPath() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetExternalIncentives() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	updateExternalIncentiveLeftAmount()

	apiExternalIncentives := []ApiExternalIncentive{}

	for incentiveId, incentive := range incentives {
		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
			IncentiveId:    incentiveId,
			PoolPath:       incentive.targetPoolPath,
			RewardToken:    incentive.rewardToken,
			RewardAmount:   incentive.rewardAmount.ToString(),
			RewardLeft:     incentive.rewardLeft.ToString(),
			StartTimestamp: incentive.startTimestamp,
			EndTimestamp:   incentive.endTimestamp,
			Refundee:       incentive.refundee.String(),
			CreatedHeight:  incentive.createdHeight,
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiExternalIncentives {
		active := false
		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
			active = true
		}

		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"incentiveId":    json.StringNode("incentiveId", incentive.IncentiveId),
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", incentive.RewardToken),
			"rewardAmount":   json.StringNode("rewardAmount", incentive.RewardAmount),
			"rewardLeft":     json.StringNode("rewardLeft", incentive.RewardLeft),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"endTimestamp":   json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
			"active":         json.BoolNode("active", active),
			"refundee":       json.StringNode("refundee", incentive.Refundee),
			"createdHeight":  json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetExternalIncentives() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	updateExternalIncentiveLeftAmount()

	apiExternalIncentives := []ApiExternalIncentive{}

	for incentiveId, incentive := range incentives {
		if incentive.targetPoolPath != targetPoolPath {
			continue
		}

		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
			IncentiveId:    incentiveId,
			PoolPath:       incentive.targetPoolPath,
			RewardToken:    incentive.rewardToken,
			RewardAmount:   incentive.rewardAmount.ToString(),
			RewardLeft:     incentive.rewardLeft.ToString(),
			StartTimestamp: incentive.startTimestamp,
			EndTimestamp:   incentive.endTimestamp,
			Refundee:       incentive.refundee.String(),
			CreatedHeight:  incentive.createdHeight,
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiExternalIncentives {
		active := false
		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
			active = true
		}

		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"incentiveId":    json.StringNode("incentiveId", incentive.IncentiveId),
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", incentive.RewardToken),
			"rewardAmount":   json.StringNode("rewardAmount", incentive.RewardAmount),
			"rewardLeft":     json.StringNode("rewardLeft", incentive.RewardLeft),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"endTimestamp":   json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
			"active":         json.BoolNode("active", active),
			"refundee":       json.StringNode("refundee", incentive.Refundee),
			"createdHeight":  json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetExternalIncentivesByPoolPath() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetExternalIncentivesByRewardTokenPath(rewardTokenPath string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	updateExternalIncentiveLeftAmount()

	apiExternalIncentives := []ApiExternalIncentive{}

	for incentiveId, incentive := range incentives {
		if incentive.rewardToken != rewardTokenPath {
			continue
		}

		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
			IncentiveId:    incentiveId,
			PoolPath:       incentive.targetPoolPath,
			RewardToken:    incentive.rewardToken,
			RewardAmount:   incentive.rewardAmount.ToString(),
			RewardLeft:     incentive.rewardLeft.ToString(),
			StartTimestamp: incentive.startTimestamp,
			EndTimestamp:   incentive.endTimestamp,
			Refundee:       incentive.refundee.String(),
			CreatedHeight:  incentive.createdHeight,
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiExternalIncentives {
		active := false
		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
			active = true
		}

		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"incentiveId":    json.StringNode("incentiveId", incentive.IncentiveId),
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", incentive.RewardToken),
			"rewardAmount":   json.StringNode("rewardAmount", incentive.RewardAmount),
			"rewardLeft":     json.StringNode("rewardLeft", incentive.RewardLeft),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"endTimestamp":   json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
			"active":         json.BoolNode("active", active),
			"refundee":       json.StringNode("refundee", incentive.Refundee),
			"createdHeight":  json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetExternalIncentivesByRewardTokenPath() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetInternalIncentives() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	apiInternalIncentives := []ApiInternalIncentive{}

	for poolPath, internal := range poolTiers {
		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
			PoolPath:       poolPath,
			Tier:           internal.tier,
			StartTimestamp: internal.startTimestamp,
			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiInternalIncentives {
		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[incentive.PoolPath])),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetInternalIncentives() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	apiInternalIncentives := []ApiInternalIncentive{}

	for poolPath, internal := range poolTiers {
		if poolPath != targetPoolPath {
			continue
		}

		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
			PoolPath:       poolPath,
			Tier:           internal.tier,
			StartTimestamp: internal.startTimestamp,
			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiInternalIncentives {
		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[targetPoolPath])),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetInternalIncentivesByPoolPath() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	apiInternalIncentives := []ApiInternalIncentive{}

	for poolPath, internal := range poolTiers {
		if internal.tier != targetTier {
			continue
		}

		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
			PoolPath:       poolPath,
			Tier:           internal.tier,
			StartTimestamp: internal.startTimestamp,
			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
		})
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, incentive := range apiInternalIncentives {
		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[incentive.PoolPath])),
		})
		responses.AppendArray(_incentiveNode)
	}

	// RETURN
	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetInternalIncentivesByTiers() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func makeRewardTokensArray(rewardsTokenList []string) []*json.Node {
	rewardsTokenArray := make([]*json.Node, len(rewardsTokenList))
	for i, rewardToken := range rewardsTokenList {
		rewardsTokenArray[i] = json.StringNode("", rewardToken)
	}
	return rewardsTokenArray
}

func calculateInternalRewardPerBlockByPoolPath(poolPath string) string {
	nowHeight := std.GetHeight()
	fullGnsForThisHeight := gns.GetAmountByHeight(nowHeight)

	// staker distribution pct
	bpsPct := en.GetDistributionPct(1)

	// calculate reward per block
	stakerGns := fullGnsForThisHeight * bpsPct / 10000

	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(stakerGns)
	tier1Num, tier2Num, tier3Num := getNumPoolTiers()

	tier := poolTiers[poolPath].tier

	if tier == 1 {
		return ufmt.Sprintf("%d", tier1Amount/tier1Num)
	} else if tier == 2 {
		return ufmt.Sprintf("%d", tier2Amount/tier2Num)
	} else if tier == 3 {
		return ufmt.Sprintf("%d", tier3Amount/tier3Num)
	}

	return "0"
}

func updateExternalIncentiveLeftAmount() {
	// external incentive reward left update
	for _, positionWarmUpAmount := range positionsExternalWarmUpAmount {
		for incentiveId, warmUpAmount := range positionWarmUpAmount {

			full := warmUpAmount.full100 + warmUpAmount.full70 + warmUpAmount.full50 + warmUpAmount.full30

			incentive := incentives[incentiveId]
			incentive.rewardLeft = new(u256.Uint).Sub(incentive.rewardLeft, u256.NewUint(full))
			incentives[incentiveId] = incentive
		}
	}
}
