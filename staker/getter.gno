package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/ufmt"
	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v1/consts"
	"gno.land/r/gnoswap/v1/gns"
)

//! TODO: Change function names to follow a naming convention

// GetPoolByPoolPath retrieves the pool's path using the provided pool path.
//
// Parameters:
// - poolPath (string): The path of the pool to retrieve.
//
// Returns:
// - string: The `poolPath` of the found pool.
//
// Panics:
// - If the pool corresponding to the given `poolPath` does not exist in the `pools` collection.
func GetPoolByPoolPath(poolPath string) *Pool {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath)),
		)
	}

	return pool
}

// GetPoolIncentiveIdList returns the list of incentive IDs for a given pool
//
// Parameters:
//   - poolPath (string): The path of the pool to get incentives for
//
// Returns:
//   - A slice og incentive IDs associated with the pool
//
// Panics:
//   - If the pool incentives do not exist for the given pool path
func GetPoolIncentiveIdList(poolPath string) []string {
	pool := GetPoolByPoolPath(poolPath)

	ids := []string{}
	pool.incentives.byTime.Iterate("", "", func(key string, value interface{}) bool {
		ids = append(ids, key)
		return true
	})

	return ids
}

// GetIncentive retrieves an external incentive by its ID from a specified pool.
//
// This function searches for an incentive within the specified pool's incentives,
// identified by the given `incentiveId`. If the pool or the incentive does not exist,
// the function panics with an appropriate error message.
//
// Parameters:
// - poolPath (string): The path of the pool containing the incentive.
// - incentiveId (string): The ID of the incentive to retrieve.
//
// Returns:
// - *ExternalIncentive: A pointer to the retrieved ExternalIncentive.
//
// Panics:
// - If the pool corresponding to the given `poolPath` does not exist.
// - If the incentive with the specified `incentiveId` does not exist.
func GetIncentive(poolPath string, incentiveId string) *ExternalIncentive {
	pool := GetPoolByPoolPath(poolPath)

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive)
}

// GetTargetPoolPathByIncentiveId returns the target pool path for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The target pool path (string) associated with the incentive
//
// Panics:
//   - If the incentive does nor exist for the given incentive ID
func GetTargetPoolPathByIncentiveId(incentiveId string, poolPath string) string {
	incentive := GetIncentive(poolPath, incentiveId)

	return incentive.targetPoolPath
}

// GetIncentiveRewardToken returns the reward token for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The reward token (string) associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func GetIncentiveRewardToken(incentiveId string, poolPath string) string {
	incentive := GetIncentive(poolPath, incentiveId)

	return incentive.rewardToken
}

// GetIncentiveRewardAmount returns the reward amount for a given incentive as a Uint256
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - *u256.Uint: The reward amount associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func GetIncentiveRewardAmount(incentiveId string, poolPath string) *u256.Uint {
	incentive := GetIncentive(poolPath, incentiveId)

	return u256.NewUint(incentive.rewardAmount)
}

// GetIncentiveRewardAmountAsString returns the reward amount for a given incentive as a string
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - string: The reward amount associated with the incentive as a string
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func GetIncentiveRewardAmountAsString(incentiveId string, poolPath string) string {
	rewardAmount := GetIncentiveRewardAmount(incentiveId, poolPath)

	return rewardAmount.ToString()
}

// StakerIncentiveStartTimestamp returns the start timestamp for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - int64: The start timestamp of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveStartTimestamp(incentiveId string, poolPath string) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).startTimestamp
}

// StakerIncentiveEndTimestamp returns the end timestamp for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - int64: The end timestamp of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveEndTimestamp(incentiveId string, poolPath string) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).endTimestamp
}

// StakerIncentiveRefundee returns the refundee address for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - std.Address: The refundee address of the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRefundee(incentiveId string, poolPath string) std.Address {
	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(ufmt.Sprintf("poolPath(%s) pool does not exist", poolPath))
	}

	incentive, exist := pool.incentives.byTime.Get(incentiveId)
	if !exist {
		panic(ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.(*ExternalIncentive).refundee
}

// StakerDepositOwner returns the owner address of a deposit for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - std.Address: The owner address of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositOwner(lpTokenId uint64) std.Address {
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.owner
}

// StakerDepositStakeTimestamp returns the stake timestamp for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - int64: The stake timestamp of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.stakeTimestamp
}

// StakerDepositTargetPoolPath returns the target pool path for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - string: The target pool path of the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositTargetPoolPath(lpTokenId uint64) string {
	deposit := deposits.Get(lpTokenId)
	if deposit == nil {
		panic(ufmt.Sprintf("lpTokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.targetPoolPath
}

// StakerPoolTier returns the tier of a given pool
//
// Parameters:
//   - poolPath (string): The path of the pool
//
// Returns:
//   - uint64: The tier of the pool
//
// Panics:
//   - If the pool tier does not exist for the given poolPath
func StakerPoolTier(poolPath string) uint64 {
	return poolTier.CurrentTier(poolPath, uint64(std.GetHeight()))
}

type currentExternalInfo struct {
	height             int64
	time               int64
	externalIncentives []ExternalIncentive
}

func printExternalInfo(poolPath string) {
	currentHeight := std.GetHeight()
	println("***********************")
	println("> height:", currentHeight)
	println("> time:", time.Now().Unix())
	println("[ START ] GET_EXTERNAL INCENTIVE")
	pool, ok := pools.Get(poolPath)
	if !ok {
		println(" > pool not found")
		return
	}
	if pool.IsExternallyIncentivizedPool(uint64(currentHeight)) {
		pool.incentives.byHeight.Iterate("", "", func(key string, value interface{}) bool {
			incentive := value.(*ExternalIncentive)
			println(" > incentiveId:", incentive.incentiveId)
			println(" > targetPoolPath:", incentive.targetPoolPath)
			println(" > rewardToken:", incentive.rewardToken)
			println(" > rewardAmount:", strconv.FormatUint(incentive.rewardAmount, 10))
			println(" > startTimestamp:", strconv.FormatInt(incentive.startTimestamp, 10))
			println(" > endTimestamp:", strconv.FormatInt(incentive.endTimestamp, 10))
			rewardPerBlockU256 := u256.MustFromDecimal(strconv.FormatUint(incentive.rewardPerBlock, 10))
			q96 := u256.MustFromDecimal(consts.Q96)
			rewardPerBlockX96 := u256.Zero().Mul(rewardPerBlockU256, q96)
			println(" > rewardPerBlockX96:", rewardPerBlockX96.ToString())
			println(" > rewardLeft:", strconv.FormatUint(incentive.rewardLeft, 10))
			println(" > refundee:", incentive.refundee.String())
			return false
		})
	} else {
		println(" > pool is not externally incentivized")
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

func GetExternalIncentive(incentiveId string) *ExternalIncentive {
	incentive, exist := externalIncentives.tree.Get(incentiveId)
	if !exist {
		panic(addDetailToError(
			errDataNotFound,
			ufmt.Sprintf("incentiveId(%s) incentive does not exist", incentiveId)),
		)
	}

	return incentive.(*ExternalIncentive)
}

func GetExternalIncentiveByPoolPath(poolPath string) []ExternalIncentive {
	incentives := []ExternalIncentive{}
	externalIncentives.tree.Iterate("", "", func(key string, value interface{}) bool {
		incentive := value.(*ExternalIncentive)
		if incentive.targetPoolPath == poolPath {
			incentives = append(incentives, *incentive)
		}
		return false
	})

	return incentives
}

//
//func GetPrintExternalInfoByPoolPath(poolPath string) string {
//	updateExternalIncentiveLeftAmount()
//
//	currentHeight := std.GetHeight()
//	now := time.Now().Unix()
//
//	externalDebug := ApiExternalDebugInfo{}
//	externalDebug.Height = currentHeight
//	externalDebug.Time = now
//
//	externalPositions := []ApiExternalDebugPosition{}
//
//	externalPosition := ApiExternalDebugPosition{}
//	deposits.Iterate(uint64(0), uint64(deposits.Size()), func(tokenId uint64, deposit *Deposit) bool {
//		externalPosition.LpTokenId = tokenId
//		externalPosition.StakedHeight = deposit.stakeHeight
//		externalPosition.StakedTimestamp = deposit.stakeTimestamp
//
//		externalIncentivesList := []ApiExternalDebugIncentive{}
//		externalIncentives.tree.Iterate("", "", func(key string, value interface{}) bool {
//			incentive := value.(*ExternalIncentive)
//			if incentive.targetPoolPath == poolPath {
//				externalIncentive := ApiExternalDebugIncentive{}
//				externalIncentive.PoolPath = incentive.targetPoolPath
//				externalIncentive.RewardToken = incentive.rewardToken
//				externalIncentive.IncentiveId = incentive.incentiveId
//				externalIncentive.RewardAmount = strconv.FormatUint(incentive.rewardAmount, 10)
//				externalIncentive.RewardLeft = strconv.FormatUint(incentive.rewardLeft, 10)
//				externalIncentive.StartTimestamp = incentive.startTimestamp
//				externalIncentive.EndTimestamp = incentive.endTimestamp
//				rewardPerBlockU256 := u256.MustFromDecimal(strconv.FormatUint(incentive.rewardPerBlock, 10))
//				q96 := u256.MustFromDecimal(consts.Q96)
//				rewardPerBlockX96 := u256.Zero().Mul(rewardPerBlockU256, q96)
//				externalIncentive.RewardPerBlockX96 = rewardPerBlockX96.ToString()
//				externalIncentive.RewardPerBlock = new(u256.Uint).Div(rewardPerBlockX96, q96).ToString()
//				externalIncentive.Refundee = incentive.refundee
//				externalIncentive.tokenAmountX96 = incentive.tokenAmountX96
//				externalIncentive.tokenAmount = incentive.tokenAmount
//				externalIncentive.tokenAmountFull = incentive.tokenAmountFull
//				externalIncentive.tokenAmountToGive = incentive.tokenAmountToGive
//				externalIncentive.full30 = incentive.full30
//				externalIncentive.give30 = incentive.give30
//				externalIncentive.full50 = incentive.full50
//				externalIncentive.give50 = incentive.give50
//				externalIncentive.full70 = incentive.full70
//				externalIncentive.give70 = incentive.give70
//				externalIncentive.full100 = incentive.full100
//				externalIncentivesList = append(externalIncentivesList, externalIncentive)
//			}
//			return false
//		})
//
//		return false
//	})
//
//	externalIncentive := ApiExternalDebugIncentive{}
//	externalIncentive.PoolPath = external.poolPath
//	externalIncentive.RewardToken = external.tokenPath
//
//	incentive := incentives[incentiveId]
//	externalIncentive.IncentiveId = incentiveId
//	externalIncentive.RewardAmount = incentive.rewardAmount.ToString()
//	externalIncentive.RewardLeft = incentive.rewardLeft.ToString()
//	externalIncentive.StartTimestamp = incentive.startTimestamp
//	externalIncentive.EndTimestamp = incentive.endTimestamp
//	externalIncentive.RewardPerBlockX96 = incentive.rewardPerBlockX96.ToString()
//	externalIncentive.RewardPerBlock = new(u256.Uint).Div(incentive.rewardPerBlockX96, u256.MustFromDecimal(consts.Q96)).ToString()
//	externalIncentive.Refundee = incentive.refundee
//
//	externalIncentive.tokenAmountX96 = external.tokenAmountX96
//
//	return ""
//}

//
//func GetPrintExternalInfo() string {
//	// TODO: LIMIT ONLY ABCI_QUERY CAN CALL THIS
//
//	updateExternalIncentiveLeftAmount()
//
//	externalDebug := ApiExternalDebugInfo{}
//	externalDebug.Height = std.GetHeight()
//	externalDebug.Time = time.Now().Unix()
//
//	externalPositions := []ApiExternalDebugPosition{}
//	for lpTokenId, externals := range positionExternal {
//		externalPosition := ApiExternalDebugPosition{}
//		externalPosition.LpTokenId = lpTokenId
//		deposit, _ := deposits.get(lpTokenId)
//		externalPosition.StakedHeight = deposit.stakeHeight
//		externalPosition.StakedTimestamp = deposit.stakeTimestamp
//
//		externalIncentives := []ApiExternalDebugIncentive{}
//		for incentiveId, external := range externals {
//			externalIncentive := ApiExternalDebugIncentive{}
//
//			externalIncentive.PoolPath = external.poolPath
//			externalIncentive.RewardToken = external.tokenPath
//
//			incentive := incentives[incentiveId]
//			externalIncentive.IncentiveId = incentiveId
//			externalIncentive.RewardAmount = incentive.rewardAmount.ToString()
//			externalIncentive.RewardLeft = incentive.rewardLeft.ToString()
//			externalIncentive.StartTimestamp = incentive.startTimestamp
//			externalIncentive.EndTimestamp = incentive.endTimestamp
//			externalIncentive.RewardPerBlockX96 = incentive.rewardPerBlockX96.ToString()
//			externalIncentive.RewardPerBlock = new(u256.Uint).Div(incentive.rewardPerBlockX96, u256.MustFromDecimal(consts.Q96)).ToString()
//			externalIncentive.Refundee = incentive.refundee
//
//			externalIncentive.tokenAmountX96 = external.tokenAmountX96
//
//			externalWarmUpAmount, exist := positionsExternalWarmUpAmount[lpTokenId][incentiveId]
//			if !exist {
//				continue
//			}
//			fullAmount := externalWarmUpAmount.full30 + externalWarmUpAmount.full50 + externalWarmUpAmount.full70 + externalWarmUpAmount.full100
//			toGive := externalWarmUpAmount.give30 + externalWarmUpAmount.give50 + externalWarmUpAmount.give70 + externalWarmUpAmount.full100
//
//			externalIncentive.full30 = externalWarmUpAmount.full30
//			externalIncentive.give30 = externalWarmUpAmount.give30
//			externalIncentive.full50 = externalWarmUpAmount.full50
//			externalIncentive.give50 = externalWarmUpAmount.give50
//			externalIncentive.full70 = externalWarmUpAmount.full70
//			externalIncentive.give70 = externalWarmUpAmount.give70
//			externalIncentive.full100 = externalWarmUpAmount.full100
//
//			externalIncentive.tokenAmountFull = fullAmount
//			externalIncentive.tokenAmountToGive = toGive
//
//			externalIncentives = append(externalIncentives, externalIncentive)
//		}
//		externalPosition.Incentive = externalIncentives
//
//		externalPositions = append(externalPositions, externalPosition)
//	}
//
//	externalDebug.Position = externalPositions
//
//	// MARSHAL
//	node := json.ObjectNode("", map[string]*json.Node{
//		"height":   json.NumberNode("", float64(externalDebug.Height)),
//		"time":     json.NumberNode("", float64(externalDebug.Time)),
//		"position": json.ArrayNode("", makeExternalPositionsNode(externalDebug.Position)),
//	})
//
//	b, err := json.Marshal(node)
//	if err != nil {
//		return "JSON MARSHAL ERROR"
//	}
//
//	return string(b)
//
//	panic("SHOULD BE REIMPLEMENTED BEFORE MERGING")
//}
//
//func makeExternalPositionsNode(positions []ApiExternalDebugPosition) []*json.Node {
//	externalPositions := make([]*json.Node, 0)
//
//	for _, externalPosition := range positions {
//		incentives := make([]*json.Node, 0)
//		for _, incentive := range externalPosition.Incentive {
//			deposit, _ := deposits.get(externalPosition.LpTokenId)
//			_max := common.I64Max(incentive.StartTimestamp, deposit.stakeTimestamp)
//			stakedOrExternalDuration := (time.Now().Unix() - _max) / consts.BLOCK_GENERATION_INTERVAL
//
//			incentives = append(incentives, json.ObjectNode("", map[string]*json.Node{
//				"poolPath":                 json.StringNode("poolPath", incentive.PoolPath),
//				"rewardToken":              json.StringNode("rewardToken", incentive.RewardToken),
//				"rewardAmount":             json.StringNode("rewardAmount", incentive.RewardAmount),
//				"startTimestamp":           json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
//				"endTimestamp":             json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
//				"rewardPerBlockX96":        json.StringNode("rewardPerBlockX96", incentive.RewardPerBlockX96),
//				"stakedOrExternalDuration": json.NumberNode("stakedOrExternalDuration", float64(stakedOrExternalDuration)),
//				"rewardPerBlock":           json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
//				"refundee":                 json.StringNode("refundee", incentive.Refundee.String()),
//				// "tokenAmountX96":           json.StringNode("tokenAmountX96", incentive.tokenAmountX96.ToString()),
//				// "tokenAmount":              json.NumberNode("tokenAmount", float64(new(u256.Uint).Div(incentive.tokenAmountX96, _q96).Uint64())),
//				"tokenAmountFull":   json.NumberNode("tokenAmountFull", float64(incentive.tokenAmountFull)),
//				"tokenAmountToGive": json.NumberNode("tokenAmountToGive", float64(incentive.tokenAmountToGive)),
//				//
//				"full30":  json.NumberNode("full30", float64(incentive.full30)),
//				"give30":  json.NumberNode("give30", float64(incentive.give30)),
//				"full50":  json.NumberNode("full50", float64(incentive.full50)),
//				"give50":  json.NumberNode("give50", float64(incentive.give50)),
//				"full70":  json.NumberNode("full70", float64(incentive.full70)),
//				"give70":  json.NumberNode("give70", float64(incentive.give70)),
//				"full100": json.NumberNode("full100", float64(incentive.full100)),
//			}))
//		}
//
//		externalPositions = append(externalPositions, json.ObjectNode("", map[string]*json.Node{
//			"lpTokenId":       json.NumberNode("lpTokenId", float64(externalPosition.LpTokenId)),
//			"stakedHeight":    json.NumberNode("stakedHeight", float64(externalPosition.StakedHeight)),
//			"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(externalPosition.StakedTimestamp)),
//			"incentive":       json.ArrayNode("", incentives),
//		}))
//	}
//
//	return externalPositions
//}

// DEBUG INTERNAL (GNS EMISSION)
type currentInfo struct {
	height           int64
	time             int64
	gnsStaker        uint64
	gnsDevOps        uint64
	gnsCommunityPool uint64
	gnsGovStaker     uint64
	gnsProtocolFee   uint64
	gnsADMIN         uint64
}

func getCurrentInfo() currentInfo {
	return currentInfo{
		height:           std.GetHeight(),
		time:             time.Now().Unix(),
		gnsStaker:        gns.BalanceOf(a2u(consts.STAKER_ADDR)),
		gnsDevOps:        gns.BalanceOf(a2u(consts.DEV_OPS)),
		gnsCommunityPool: gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)),
		gnsGovStaker:     gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR)),
		gnsProtocolFee:   gns.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)),
		gnsADMIN:         gns.BalanceOf(a2u(consts.ADMIN)),
	}
}

func printInfo(prev currentInfo) currentInfo {
	curr := getCurrentInfo()
	/*
		println("***********************")
		println("> height:", curr.height)
		println("> height inc by:", curr.height-prev.height)
		println("> time:", curr.time)
		println("> time inc by:", curr.time-prev.time)
		println("GNS BALANCE CHANGE")
		println("> staker_bal\t\t", curr.gnsStaker)
		println("> staker_chg\t\t", int64(curr.gnsStaker-prev.gnsStaker))
		println("> dev ops\t\t", curr.gnsDevOps)
		println("> dev ops_chg\t\t", int(curr.gnsDevOps-prev.gnsDevOps))
		println("> community pool_bal\t", curr.gnsCommunityPool)
		println("> community pool_chg\t", int(curr.gnsCommunityPool-prev.gnsCommunityPool))
		println("> gov_staker_bal\t\t", curr.gnsGovStaker)
		println("> gov_staker_chg\t\t", int(curr.gnsGovStaker-prev.gnsGovStaker))
		println("> protocol fee_bal\t", curr.gnsProtocolFee)
		println("> protocol fee_chg\t", int(curr.gnsProtocolFee-prev.gnsProtocolFee))
		println("> ADMIN_bal\t\t", curr.gnsADMIN)
		println("> ADMIN_chg\t\t", int(curr.gnsADMIN-prev.gnsADMIN))
		println("GNS POOL")
		for k, v := range poolGns {
			println("> poolPath:", k, "amount:", v)
		}


		println("GNS POSITION")
		for k, v := range positionGns {
			posWarmCalc := positionsInternalWarmUpAmount[k]
			println("> tokenId:", k, "amount:", v, "warmUp:", getRewardRatio(curr.height-deposits[k].stakeHeight))
			println("> 100%", "full", posWarmCalc.full100, "give", posWarmCalc.full100)
			println("> 70%", "full", posWarmCalc.full70, "give", posWarmCalc.give70)
			println("> 50%", "full", posWarmCalc.full50, "give", posWarmCalc.give50)
			println("> 30%", "full", posWarmCalc.full30, "give", posWarmCalc.give30)
		}
	*/
	//panic("SHOULD BE REIMPLEMENTED BEFORE MERGING")

	return curr
}
