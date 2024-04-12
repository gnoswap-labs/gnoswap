package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	pl "gno.land/r/demo/pool"

	"gno.land/r/demo/gnoswap/consts"
)

type RewardToken struct {
	PoolPath         string   `json:"poolPath"`
	RewardsTokenList []string `json:"rewardsTokenList"`
}

type ApiExternalIncentive struct {
	PoolPath       string `json:"poolPath"`
	RewardToken    string `json:"rewardToken"`
	RewardAmount   string `json:"rewardAmount"`
	StartTimestamp int64  `json:"startTimestamp"`
	EndTimestamp   int64  `json:"endTimestamp"`
	Active         bool   `json:"active"`
	Refundee       string `json:"refundee"`
}

type ApiInternalIncentive struct {
	PoolPath string `json:"poolPath"`
	Tier     uint64 `json:"tier"`
}

func ApiGetRewardTokens() string {
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
	for i, rewardToken := range rewardTokens {
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

func ApiGetExternalIncentives() string {
	apiExternalIncentives := []ApiExternalIncentive{}

	for _, incentive := range incentives {
		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
			PoolPath:       incentive.targetPoolPath,
			RewardToken:    incentive.rewardToken,
			RewardAmount:   incentive.rewardAmount.ToString(),
			StartTimestamp: incentive.startTimestamp,
			EndTimestamp:   incentive.endTimestamp,
			Refundee:       incentive.refundee.String(),
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
			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken":    json.StringNode("rewardToken", incentive.RewardToken),
			"rewardAmount":   json.StringNode("rewardAmount", incentive.RewardAmount),
			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
			"endTimestamp":   json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
			"active":         json.BoolNode("active", active),
			"refundee":       json.StringNode("refundee", incentive.Refundee),
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

func ApiGetInternalIncentives() string {
	apiInternalIncentives := []ApiInternalIncentive{}

	for poolPath, tier := range poolTiers {
		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
			PoolPath: poolPath,
			Tier:     tier,
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
			"poolPath":    json.StringNode("poolPath", incentive.PoolPath),
			"rewardToken": json.StringNode("rewardToken", consts.GNS_PATH),
			"tier":        json.NumberNode("tier", float64(incentive.Tier)),
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

func makeRewardTokensArray(rewardsTokenList []string) []*json.Node {
	rewardsTokenArray := make([]*json.Node, len(rewardsTokenList))
	for i, rewardToken := range rewardsTokenList {
		rewardsTokenArray[i] = json.StringNode("", rewardToken)
	}
	return rewardsTokenArray
}
