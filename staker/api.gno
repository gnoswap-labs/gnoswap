package staker

type RewardToken struct {
	PoolPath         string   `json:"poolPath"`
	RewardsTokenList []string `json:"rewardsTokenList"`
}

type ApiExternalIncentive struct {
	IncentiveId      string `json:"incentiveId"`
	PoolPath         string `json:"poolPath"`
	RewardToken      string `json:"rewardToken"`
	RewardAmount     string `json:"rewardAmount"`
	RewardLeft       string `json:"rewardLeft"`
	StartTimestamp   int64  `json:"startTimestamp"`
	EndTimestamp     int64  `json:"endTimestamp"`
	Active           bool   `json:"active"`
	Refundee         string `json:"refundee"`
	CreatedHeight    int64  `json:"createdHeight"`
	DepositGnsAmount uint64 `json:"depositGnsAmount"`
}

type ApiInternalIncentive struct {
	PoolPath       string `json:"poolPath"`
	Tier           uint64 `json:"tier"`
	StartTimestamp int64  `json:"startTimestamp"`
	RewardPerBlock string `json:"rewardPerBlock"`
}

//
//func ApiGetRewardTokens() string {
//	en.MintAndDistributeGns()
//
//	rewardTokens := []RewardToken{}
//
//	poolList := pl.PoolGetPoolList()
//	for _, poolPath := range poolList {
//		thisPoolRewardTokens := []string{}
//
//		// HANDLE INTERNAL
//		if isExistPoolTiers(poolPath) {
//			thisPoolRewardTokens = append(thisPoolRewardTokens, consts.GNS_PATH)
//		}
//
//		// HANDLE EXTERNAL
//		ictvList, exists := poolIncentives.Get(poolPath)
//		if !exists {
//			continue
//		}
//
//		for _, incentiveId := range ictvList {
//			ictv, exist := incentives.Get(incentiveId)
//			if !exist {
//				continue
//			}
//			if ictv.RewardToken() == "" {
//				continue
//			}
//			thisPoolRewardTokens = append(thisPoolRewardTokens, ictv.RewardToken())
//		}
//
//		if len(thisPoolRewardTokens) == 0 {
//			continue
//		}
//
//		rewardTokens = append(rewardTokens, RewardToken{
//			PoolPath:         poolPath,
//			RewardsTokenList: thisPoolRewardTokens,
//		})
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, rewardToken := range rewardTokens {
//		_rewardTokenNode := json.ObjectNode("", map[string]*json.Node{
//			"poolPath": json.StringNode("poolPath", rewardToken.PoolPath),
//			"tokens":   json.ArrayNode("tokens", makeRewardTokensArray(rewardToken.RewardsTokenList)),
//		})
//		responses.AppendArray(_rewardTokenNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	rewardTokens := []RewardToken{}
//
//	poolList := pl.PoolGetPoolList()
//	for _, poolPath := range poolList {
//		if poolPath != targetPoolPath {
//			continue
//		}
//
//		thisPoolRewardTokens := []string{}
//
//		// HANDLE INTERNAL
//		if isExistPoolTiers(poolPath) {
//			thisPoolRewardTokens = append(thisPoolRewardTokens, consts.GNS_PATH)
//		}
//
//		// HANDLE EXTERNAL
//		ictvList, exists := poolIncentives.Get(poolPath)
//		if !exists {
//			continue
//		}
//
//		for _, incentiveId := range ictvList {
//			ictv, exist := incentives.Get(incentiveId)
//			if !exist {
//				continue
//			}
//			thisPoolRewardTokens = append(thisPoolRewardTokens, ictv.RewardToken())
//		}
//
//		rewardTokens = append(rewardTokens, RewardToken{
//			PoolPath:         poolPath,
//			RewardsTokenList: thisPoolRewardTokens,
//		})
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, rewardToken := range rewardTokens {
//		_rewardTokenNode := json.ObjectNode("", map[string]*json.Node{
//			"poolPath": json.StringNode("poolPath", rewardToken.PoolPath),
//			"tokens":   json.ArrayNode("tokens", makeRewardTokensArray(rewardToken.RewardsTokenList)),
//		})
//		responses.AppendArray(_rewardTokenNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetExternalIncentives() string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	updateExternalIncentiveLeftAmount()
//
//	apiExternalIncentives := []ApiExternalIncentive{}
//
//	for incentiveId, incentive := range incentives {
//		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
//			IncentiveId:      incentiveId,
//			PoolPath:         incentive.targetPoolPath,
//			RewardToken:      incentive.rewardToken,
//			RewardAmount:     incentive.rewardAmount.ToString(),
//			RewardLeft:       incentive.rewardLeft.ToString(),
//			StartTimestamp:   incentive.startTimestamp,
//			EndTimestamp:     incentive.endTimestamp,
//			Refundee:         incentive.refundee.String(),
//			CreatedHeight:    incentive.createdHeight,
//			DepositGnsAmount: incentive.depositGnsAmount,
//		})
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiExternalIncentives {
//		active := false
//		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
//			active = true
//		}
//
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"incentiveId":      json.StringNode("incentiveId", incentive.IncentiveId),
//			"poolPath":         json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":      json.StringNode("rewardToken", incentive.RewardToken),
//			"rewardAmount":     json.StringNode("rewardAmount", incentive.RewardAmount),
//			"rewardLeft":       json.StringNode("rewardLeft", incentive.RewardLeft),
//			"startTimestamp":   json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"endTimestamp":     json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
//			"active":           json.BoolNode("active", active),
//			"refundee":         json.StringNode("refundee", incentive.Refundee),
//			"createdHeight":    json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
//			"depositGnsAmount": json.NumberNode("depositGnsAmount", float64(incentive.DepositGnsAmount)),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetExternalIncentiveById(incentiveId string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	updateExternalIncentiveLeftAmount()
//
//	apiExternalIncentives := []ApiExternalIncentive{}
//
//	incentive, exist := incentives.Get(incentiveId)
//	if !exist {
//		panic(addDetailToError(
//			errDataNotFound,
//			ufmt.Sprintf("incentive(%s) not found", incentiveId),
//		))
//	}
//
//	apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
//		IncentiveId:      incentiveId,
//		PoolPath:         incentive.targetPoolPath,
//		RewardToken:      incentive.rewardToken,
//		RewardAmount:     incentive.rewardAmount.ToString(),
//		RewardLeft:       incentive.rewardLeft.ToString(),
//		StartTimestamp:   incentive.startTimestamp,
//		EndTimestamp:     incentive.endTimestamp,
//		Refundee:         incentive.refundee.String(),
//		CreatedHeight:    incentive.createdHeight,
//		DepositGnsAmount: incentive.depositGnsAmount,
//	})
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiExternalIncentives {
//		active := false
//		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
//			active = true
//		}
//
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"incentiveId":      json.StringNode("incentiveId", incentive.IncentiveId),
//			"poolPath":         json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":      json.StringNode("rewardToken", incentive.RewardToken),
//			"rewardAmount":     json.StringNode("rewardAmount", incentive.RewardAmount),
//			"rewardLeft":       json.StringNode("rewardLeft", incentive.RewardLeft),
//			"startTimestamp":   json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"endTimestamp":     json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
//			"active":           json.BoolNode("active", active),
//			"refundee":         json.StringNode("refundee", incentive.Refundee),
//			"createdHeight":    json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
//			"depositGnsAmount": json.NumberNode("depositGnsAmount", float64(incentive.DepositGnsAmount)),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	updateExternalIncentiveLeftAmount()
//
//	apiExternalIncentives := []ApiExternalIncentive{}
//
//	for incentiveId, incentive := range incentives {
//		if incentive.targetPoolPath != targetPoolPath {
//			continue
//		}
//
//		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
//			IncentiveId:      incentiveId,
//			PoolPath:         incentive.targetPoolPath,
//			RewardToken:      incentive.rewardToken,
//			RewardAmount:     incentive.rewardAmount.ToString(),
//			RewardLeft:       incentive.rewardLeft.ToString(),
//			StartTimestamp:   incentive.startTimestamp,
//			EndTimestamp:     incentive.endTimestamp,
//			Refundee:         incentive.refundee.String(),
//			CreatedHeight:    incentive.createdHeight,
//			DepositGnsAmount: incentive.depositGnsAmount,
//		})
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiExternalIncentives {
//		active := false
//		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
//			active = true
//		}
//
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"incentiveId":      json.StringNode("incentiveId", incentive.IncentiveId),
//			"poolPath":         json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":      json.StringNode("rewardToken", incentive.RewardToken),
//			"rewardAmount":     json.StringNode("rewardAmount", incentive.RewardAmount),
//			"rewardLeft":       json.StringNode("rewardLeft", incentive.RewardLeft),
//			"startTimestamp":   json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"endTimestamp":     json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
//			"active":           json.BoolNode("active", active),
//			"refundee":         json.StringNode("refundee", incentive.Refundee),
//			"createdHeight":    json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
//			"depositGnsAmount": json.NumberNode("depositGnsAmount", float64(incentive.DepositGnsAmount)),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetExternalIncentivesByRewardTokenPath(rewardTokenPath string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	updateExternalIncentiveLeftAmount()
//
//	apiExternalIncentives := []ApiExternalIncentive{}
//
//	for incentiveId, incentive := range incentives {
//		if incentive.rewardToken != rewardTokenPath {
//			continue
//		}
//
//		apiExternalIncentives = append(apiExternalIncentives, ApiExternalIncentive{
//			IncentiveId:      incentiveId,
//			PoolPath:         incentive.targetPoolPath,
//			RewardToken:      incentive.rewardToken,
//			RewardAmount:     incentive.rewardAmount.ToString(),
//			RewardLeft:       incentive.rewardLeft.ToString(),
//			StartTimestamp:   incentive.startTimestamp,
//			EndTimestamp:     incentive.endTimestamp,
//			Refundee:         incentive.refundee.String(),
//			CreatedHeight:    incentive.createdHeight,
//			DepositGnsAmount: incentive.depositGnsAmount,
//		})
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiExternalIncentives {
//		active := false
//		if time.Now().Unix() >= incentive.StartTimestamp && time.Now().Unix() <= incentive.EndTimestamp {
//			active = true
//		}
//
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"incentiveId":      json.StringNode("incentiveId", incentive.IncentiveId),
//			"poolPath":         json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":      json.StringNode("rewardToken", incentive.RewardToken),
//			"rewardAmount":     json.StringNode("rewardAmount", incentive.RewardAmount),
//			"rewardLeft":       json.StringNode("rewardLeft", incentive.RewardLeft),
//			"startTimestamp":   json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"endTimestamp":     json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
//			"active":           json.BoolNode("active", active),
//			"refundee":         json.StringNode("refundee", incentive.Refundee),
//			"createdHeight":    json.NumberNode("createdHeight", float64(incentive.CreatedHeight)),
//			"depositGnsAmount": json.NumberNode("depositGnsAmount", float64(incentive.DepositGnsAmount)),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetInternalIncentives() string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	apiInternalIncentives := []ApiInternalIncentive{}
//
//	poolTiers.Iter(func(poolPath string, internalTier InternalTier) {
//		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
//			PoolPath:       poolPath,
//			Tier:           internalTier.tier,
//			StartTimestamp: internalTier.startTimestamp,
//			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
//		})
//	})
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiInternalIncentives {
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
//			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
//			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
//			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[incentive.PoolPath])),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	apiInternalIncentives := []ApiInternalIncentive{}
//
//	poolTiers.Iter(func(poolPath string, internalTier InternalTier) {
//		if poolPath != targetPoolPath {
//			return
//		}
//
//		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
//			PoolPath:       poolPath,
//			Tier:           internalTier.tier,
//			StartTimestamp: internalTier.startTimestamp,
//			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
//		})
//	})
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiInternalIncentives {
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
//			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
//			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
//			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[targetPoolPath])),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetInternalIncentivesByTiers(targetTier uint64) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	apiInternalIncentives := []ApiInternalIncentive{}
//
//	poolTiers.Iter(func(poolPath string, internalTier InternalTier) {
//		if internalTier.tier != targetTier {
//			return
//		}
//
//		apiInternalIncentives = append(apiInternalIncentives, ApiInternalIncentive{
//			PoolPath:       poolPath,
//			Tier:           internalTier.tier,
//			StartTimestamp: internalTier.startTimestamp,
//			RewardPerBlock: calculateInternalRewardPerBlockByPoolPath(poolPath),
//		})
//	})
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, incentive := range apiInternalIncentives {
//		_incentiveNode := json.ObjectNode("", map[string]*json.Node{
//			"poolPath":       json.StringNode("poolPath", incentive.PoolPath),
//			"rewardToken":    json.StringNode("rewardToken", consts.GNS_PATH),
//			"tier":           json.NumberNode("tier", float64(incentive.Tier)),
//			"startTimestamp": json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//			"rewardPerBlock": json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
//			"accuGns":        json.NumberNode("accuGns", float64(poolAccuGns[incentive.PoolPath])),
//		})
//		responses.AppendArray(_incentiveNode)
//	}
//
//	// RETURN
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func makeRewardTokensArray(rewardsTokenList []string) []*json.Node {
//	rewardsTokenArray := make([]*json.Node, len(rewardsTokenList))
//	for i, rewardToken := range rewardsTokenList {
//		rewardsTokenArray[i] = json.StringNode("", rewardToken)
//	}
//	return rewardsTokenArray
//}
//
//func calculateInternalRewardPerBlockByPoolPath(poolPath string) string {
//	nowHeight := std.GetHeight()
//	fullGnsForThisHeight := gns.GetAmountByHeight(nowHeight)
//
//	// staker distribution pct
//	bpsPct := en.GetDistributionPct(1)
//
//	// calculate reward per block
//	stakerGns := fullGnsForThisHeight * bpsPct / 10000
//
//	tier1Amount, tier2Amount, tier3Amount := getTiersAmount(stakerGns)
//	tier1Num, tier2Num, tier3Num := getNumPoolTiers()
//
//	internalTier, exist := poolTiers.Get(poolPath)
//	if !exist {
//		return "0"
//	}
//
//	tier := internalTier.Tier()
//
//	if tier == 1 {
//		return ufmt.Sprintf("%d", tier1Amount/tier1Num)
//	} else if tier == 2 {
//		return ufmt.Sprintf("%d", tier2Amount/tier2Num)
//	} else if tier == 3 {
//		return ufmt.Sprintf("%d", tier3Amount/tier3Num)
//	}
//
//	return "0"
//}
//
//func updateExternalIncentiveLeftAmount() {
//	// external incentive reward left update
//	for _, positionWarmUpAmount := range positionsExternalWarmUpAmount {
//		for incentiveId, warmUpAmount := range positionWarmUpAmount {
//
//			full := warmUpAmount.full100 + warmUpAmount.full70 + warmUpAmount.full50 + warmUpAmount.full30
//
//			ictv, exist := incentives.Get(incentiveId)
//			if !exist {
//				continue
//			}
//			ictv.rewardLeft = new(u256.Uint).Sub(ictv.rewardLeft, u256.NewUint(full))
//			incentives.Set(incentiveId, ictv)
//		}
//	}
//}

//
//// LpTokenReward represents the rewards associated with a specific LP token
//type LpTokenReward struct {
//	LpTokenId uint64   `json:"lpTokenId"` // The ID of the LP token
//	Address   string   `json:"address"`   // The address associated with the LP token
//	Rewards   []Reward `json:"rewards"`
//}
//
//// Reward represents a single reward for a staked LP token
//type Reward struct {
//	IncentiveType     string `json:"incentiveType"`     // The type of incentive (INTERNAL or EXTERNAL)
//	IncentiveId       string `json:"incentiveId"`       // The unique identifier of the incentive
//	TargetPoolPath    string `json:"targetPoolPath"`    // The path of the target pool for the reward
//	RewardTokenPath   string `json:"rewardTokenPath"`   // The pathe of the reward token
//	RewardTokenAmount uint64 `json:"rewardTokenAmount"` // The amount of the reward token
//	StakeTimestamp    int64  `json:"stakeTimestamp"`    // The timestamp when the LP token was staked
//	StakeHeight       int64  `json:"stakeHeight"`       // The block height when the LP token was staked
//	IncentiveStart    int64  `json:"incentiveStart"`    // The timestamp when the incentive started
//}
//
//// Stake represents a single stake
//type Stake struct {
//	TokenId        uint64      `json:"tokenId"`        // The ID of the staked LP token
//	Owner          std.Address `json:"owner"`          // The address of the owner of the staked LP token
//	NumberOfStakes uint64      `json:"numberOfStakes"` // The number of times this LP token has been staked
//	StakeTimestamp int64       `json:"stakeTimestamp"` // The timestamp when the LP token was staked
//	StakeHeight    int64       `json:"stakeHeight"`    // The block height when the LP token was staked
//	TargetPoolPath string      `json:"targetPoolPath"` // The path of the target pool for the stake
//}
//
//// ResponseQueryBase contains basic information about a query response.
//type ResponseQueryBase struct {
//	Height    int64 `json:"height"`    // The block height at the time of the query
//	Timestamp int64 `json:"timestamp"` // The timestamp at the time of the query
//}
//
//// ResponseApiGetRewards represents the API response for getting rewards.
//type ResponseApiGetRewards struct {
//	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
//	Response []LpTokenReward   `json:"response"` // A slice of LpTokenReward structs
//}
//
//// ResponseApiGetRewardByLpTokenId represents the API response for getting rewards for a specific LP token.
//type ResponseApiGetRewardByLpTokenId struct {
//	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
//	Response LpTokenReward     `json:"response"` // The LpTokenReward for the specified LP token
//}
//
//// ResponseApiGetStakes represents the API response for getting stakes.
//type ResponseApiGetStakes struct {
//	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
//	Response []Stake           `json:"response"` // A slice of Stake structs
//}
//
//func ApiGetRewards() string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	lpTokenRewards := []LpTokenReward{}
//
//	// TODO: extract as function
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		rewards := []Reward{}
//
//		// get internal gns reward
//		internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
//		if !exist {
//			return
//		}
//		internalGNS := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100
//
//		if internalGNS > 0 {
//			rewards = append(rewards, Reward{
//				IncentiveType:     "INTERNAL",
//				IncentiveId:       "",
//				TargetPoolPath:    deposit.targetPoolPath,
//				RewardTokenPath:   consts.GNS_PATH,
//				RewardTokenAmount: internalGNS,
//				StakeTimestamp:    deposit.stakeTimestamp,
//				StakeHeight:       deposit.stakeHeight,
//				IncentiveStart:    deposit.stakeTimestamp,
//			})
//		}
//
//		// find all external reward list for poolPath which lpTokenId is staked
//		ictvList, exists := poolIncentives.Get(deposit.targetPoolPath)
//		if !exists {
//			return
//		}
//
//		for _, ictvId := range ictvList {
//			ictv, exists := incentives.Get(ictvId)
//			if !exists {
//				return
//			}
//
//			stakedOrCreatedAt := common.I64Max(deposit.stakeTimestamp, ictv.startTimestamp)
//			now := time.Now().Unix()
//			if now < stakedOrCreatedAt {
//				return
//			}
//
//			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][ictvId]
//			if !exist {
//				return
//			}
//			externalReward := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100
//			if externalReward >= 0 {
//				rewards = append(rewards, Reward{
//					IncentiveType:     "EXTERNAL",
//					IncentiveId:       ictvId,
//					TargetPoolPath:    deposit.targetPoolPath,
//					RewardTokenPath:   ictv.rewardToken,
//					RewardTokenAmount: externalReward,
//					StakeTimestamp:    deposit.stakeTimestamp,
//					StakeHeight:       deposit.stakeHeight,
//					IncentiveStart:    ictv.startTimestamp,
//				})
//			}
//		}
//
//		if len(rewards) > 0 {
//			lpTokenReward := LpTokenReward{
//				LpTokenId: tokenId,
//				Address:   deposit.owner.String(),
//				Rewards:   rewards,
//			}
//			lpTokenRewards = append(lpTokenRewards, lpTokenReward)
//		}
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetRewards{
//		Stat:     qb,
//		Response: lpTokenRewards,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, reward := range r.Response {
//		_rewardNode := json.ObjectNode("", map[string]*json.Node{
//			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
//			"address":   json.StringNode("address", reward.Address),
//			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
//		})
//		responses.AppendArray(_rewardNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	lpTokenRewards := []LpTokenReward{}
//
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		if tokenId != targetLpTokenId {
//			return
//		}
//
//		rewards := []Reward{}
//
//		// get internal gns reward
//		internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
//		if !exist {
//			return
//		}
//		internalGNS := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100
//
//		if internalGNS > 0 {
//			rewards = append(rewards, Reward{
//				IncentiveType:     "INTERNAL",
//				IncentiveId:       "",
//				TargetPoolPath:    deposit.targetPoolPath,
//				RewardTokenPath:   consts.GNS_PATH,
//				RewardTokenAmount: internalGNS,
//				StakeTimestamp:    deposit.stakeTimestamp,
//				StakeHeight:       deposit.stakeHeight,
//				IncentiveStart:    deposit.stakeTimestamp,
//			})
//		}
//
//		// find all external reward list for poolPath which lpTokenId is staked
//		ictvList, exists := poolIncentives.Get(deposit.targetPoolPath)
//		if !exists {
//			return
//		}
//
//		for _, ictvId := range ictvList {
//			ictv, exists := incentives.Get(ictvId)
//			if !exists {
//				return
//			}
//
//			stakedOrCreatedAt := common.I64Max(deposit.stakeTimestamp, ictv.startTimestamp)
//			now := time.Now().Unix()
//			if now < stakedOrCreatedAt {
//				return
//			}
//
//			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][ictvId]
//			if !exist {
//				return
//			}
//			externalReward := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100
//			if externalReward > 0 {
//				rewards = append(rewards, Reward{
//					IncentiveType:     "EXTERNAL",
//					IncentiveId:       ictvId,
//					TargetPoolPath:    deposit.targetPoolPath,
//					RewardTokenPath:   ictv.rewardToken,
//					RewardTokenAmount: externalReward,
//					StakeTimestamp:    deposit.stakeTimestamp,
//					StakeHeight:       deposit.stakeHeight,
//					IncentiveStart:    ictv.startTimestamp,
//				})
//			}
//		}
//
//		lpTokenReward := LpTokenReward{
//			LpTokenId: tokenId,
//			Address:   deposit.owner.String(),
//			Rewards:   rewards,
//		}
//		lpTokenRewards = append(lpTokenRewards, lpTokenReward)
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetRewards{
//		Stat:     qb,
//		Response: lpTokenRewards,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, reward := range r.Response {
//		_rewardNode := json.ObjectNode("", map[string]*json.Node{
//			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
//			"address":   json.StringNode("address", reward.Address),
//			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
//		})
//		responses.AppendArray(_rewardNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetRewardsByAddress(targetAddress string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	lpTokenRewards := []LpTokenReward{}
//
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		if deposit.owner.String() != targetAddress {
//			return
//		}
//
//		rewards := []Reward{}
//
//		// get internal gns reward
//		internalWarmUpAmount, exist := positionsInternalWarmUpAmount[tokenId]
//		if !exist {
//			return
//		}
//		internalGNS := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100
//
//		if internalGNS > 0 {
//			rewards = append(rewards, Reward{
//				IncentiveType:     "INTERNAL",
//				IncentiveId:       "",
//				TargetPoolPath:    deposit.targetPoolPath,
//				RewardTokenPath:   consts.GNS_PATH,
//				RewardTokenAmount: internalGNS,
//				StakeTimestamp:    deposit.stakeTimestamp,
//				StakeHeight:       deposit.stakeHeight,
//				IncentiveStart:    deposit.stakeTimestamp,
//			})
//		}
//
//		// find all external reward list for poolPath which lpTokenId is staked
//		ictvList, exists := poolIncentives.Get(deposit.targetPoolPath)
//		if !exists {
//			return
//		}
//
//		for _, ictvId := range ictvList {
//			ictv, exists := incentives.Get(ictvId)
//			if !exists {
//				return
//			}
//
//			stakedOrCreatedAt := common.I64Max(deposit.stakeTimestamp, ictv.startTimestamp)
//			now := time.Now().Unix()
//			if now < stakedOrCreatedAt {
//				return
//			}
//
//			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[tokenId][ictvId]
//			if !exist {
//				return
//			}
//			externalReward := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100
//			rewards = append(rewards, Reward{
//				IncentiveType:     "EXTERNAL",
//				IncentiveId:       ictvId,
//				TargetPoolPath:    deposit.targetPoolPath,
//				RewardTokenPath:   ictv.rewardToken,
//				RewardTokenAmount: externalReward,
//				StakeTimestamp:    deposit.stakeTimestamp,
//				StakeHeight:       deposit.stakeHeight,
//				IncentiveStart:    ictv.startTimestamp,
//			})
//		}
//		lpTokenReward := LpTokenReward{
//			LpTokenId: tokenId,
//			Address:   deposit.owner.String(),
//			Rewards:   rewards,
//		}
//		lpTokenRewards = append(lpTokenRewards, lpTokenReward)
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetRewards{
//		Stat:     qb,
//		Response: lpTokenRewards,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, reward := range r.Response {
//		_rewardNode := json.ObjectNode("", map[string]*json.Node{
//			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
//			"address":   json.StringNode("address", reward.Address),
//			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
//		})
//		responses.AppendArray(_rewardNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetStakes() string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	stakes := []Stake{}
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		stakes = append(stakes, Stake{
//			TokenId:        tokenId,
//			Owner:          deposit.owner,
//			NumberOfStakes: deposit.numberOfStakes,
//			StakeTimestamp: deposit.stakeTimestamp,
//			StakeHeight:    deposit.stakeHeight,
//			TargetPoolPath: deposit.targetPoolPath,
//		})
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetStakes{
//		Stat:     qb,
//		Response: stakes,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, stake := range r.Response {
//		_stakeNode := json.ObjectNode("", map[string]*json.Node{
//			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
//			"owner":          json.StringNode("owner", stake.Owner.String()),
//			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
//			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
//			"stakeHeight":    json.NumberNode("stakeHeight", float64(stake.StakeHeight)),
//			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
//		})
//		responses.AppendArray(_stakeNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	stakes := []Stake{}
//
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		if tokenId != targetLpTokenId {
//			return
//		}
//
//		stakes = append(stakes, Stake{
//			TokenId:        tokenId,
//			Owner:          deposit.owner,
//			NumberOfStakes: deposit.numberOfStakes,
//			StakeTimestamp: deposit.stakeTimestamp,
//			StakeHeight:    deposit.stakeHeight,
//			TargetPoolPath: deposit.targetPoolPath,
//		})
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetStakes{
//		Stat:     qb,
//		Response: stakes,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, stake := range r.Response {
//		_stakeNode := json.ObjectNode("", map[string]*json.Node{
//			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
//			"owner":          json.StringNode("owner", stake.Owner.String()),
//			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
//			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
//			"stakeHeight":    json.NumberNode("stakeHeight", float64(stake.StakeHeight)),
//			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
//		})
//		responses.AppendArray(_stakeNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//func ApiGetStakesByAddress(targetAddress string) string {
//	en.MintAndDistributeGns()
//	if consts.EMISSION_REFACTORED {
//		CalcPoolPositionRefactor()
//	} else {
//		CalcPoolPosition()
//	}
//
//	stakes := []Stake{}
//
//	deposits.Iter(func(tokenId uint64, deposit Deposit) {
//		if deposit.owner.String() != targetAddress {
//			return
//		}
//
//		stakes = append(stakes, Stake{
//			TokenId:        tokenId,
//			Owner:          deposit.owner,
//			NumberOfStakes: deposit.numberOfStakes,
//			StakeTimestamp: deposit.stakeTimestamp,
//			StakeHeight:    deposit.stakeHeight,
//			TargetPoolPath: deposit.targetPoolPath,
//		})
//	})
//
//	qb := ResponseQueryBase{
//		Height:    std.GetHeight(),
//		Timestamp: time.Now().Unix(),
//	}
//
//	r := ResponseApiGetStakes{
//		Stat:     qb,
//		Response: stakes,
//	}
//
//	// STAT NODE
//	_stat := json.ObjectNode("", map[string]*json.Node{
//		"height":    json.NumberNode("height", float64(std.GetHeight())),
//		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
//	})
//
//	// RESPONSE (ARRAY) NODE
//	responses := json.ArrayNode("", []*json.Node{})
//	for _, stake := range r.Response {
//		_stakeNode := json.ObjectNode("", map[string]*json.Node{
//			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
//			"owner":          json.StringNode("owner", stake.Owner.String()),
//			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
//			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
//			"stakeHeight":    json.NumberNode("stakeHeight", float64(stake.StakeHeight)),
//			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
//		})
//		responses.AppendArray(_stakeNode)
//	}
//
//	node := json.ObjectNode("", map[string]*json.Node{
//		"stat":     _stat,
//		"response": responses,
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		panic(err.Error())
//	}
//
//	return string(b)
//}
//
//// for off chain to check if lpTokenId is staked via RPC
//func IsStaked(tokenId uint64) bool {
//	_, exist := deposits[tokenId]
//	return exist
//}
//
//func makeRewardsArray(rewards []Reward) []*json.Node {
//	rewardsArray := make([]*json.Node, len(rewards))
//
//	for i, reward := range rewards {
//		rewardsArray[i] = json.ObjectNode("", map[string]*json.Node{
//			"incentiveType":     json.StringNode("incentiveType", reward.IncentiveType),
//			"incentiveId":       json.StringNode("incentiveId", reward.IncentiveId),
//			"targetPoolPath":    json.StringNode("targetPoolPath", reward.TargetPoolPath),
//			"rewardTokenPath":   json.StringNode("rewardTokenPath", reward.RewardTokenPath),
//			"rewardTokenAmount": json.NumberNode("rewardTokenAmount", float64(reward.RewardTokenAmount)),
//			"stakeTimestamp":    json.NumberNode("stakeTimestamp", float64(reward.StakeTimestamp)),
//			"stakeHeight":       json.NumberNode("stakeHeight", float64(reward.StakeHeight)),
//			"incentiveStart":    json.NumberNode("incentiveStart", float64(reward.IncentiveStart)),
//		})
//	}
//	return rewardsArray
//}
