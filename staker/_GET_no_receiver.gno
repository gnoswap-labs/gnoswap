package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"

	en "gno.land/r/gnoswap/v2/emission"
)

// StakerPoolIncentives returns the list of incentive IDs for a given pool
//
// Parameters:
//   - poolPath (string): The path of the pool to get incentives for
//
// Returns:
//   - A slice og incentive IDs associated with the pool
//
// Panics:
//   - If the pool incentives do not exist for the given pool path
func StakerPoolIncentives(poolPath string) []string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentives, exist := poolIncentives[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolIncentives() || poolPath(%s) incentives does not exist", poolPath))
	}

	return incentives
}

// StakerIncentiveTargetPoolPath returns the target pool path for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The target pool path (string) associated with the incentive
//
// Panics:
//   - If the incentive does nor exist for the given incentive ID
func StakerIncentiveTargetPoolPath(incentiveId string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveTargetPoolPath() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.targetPoolPath
}

// StakerIncentiveRewardToken returns the reward token for a given incentive
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - The reward token (string) associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardToken(incentiveId string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardToken() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardToken
}

// StakerIncentiveRewardAmount returns the reward amount for a given incentive as a Uint256
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - *u256.Uint: The reward amount associated with the incentive
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardAmount(incentiveId string) *u256.Uint {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount
}

// StakerIncentiveRewardAmountStr returns the reward amount for a given incentive as a string
//
// Parameters:
//   - incentiveId (string): The ID of the incentive
//
// Returns:
//   - string: The reward amount associated with the incentive as a string
//
// Panics:
//   - If the incentive does not exist for the given incentiveId
func StakerIncentiveRewardAmountStr(incentiveId string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount.ToString()
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
func StakerIncentiveStartTimestamp(incentiveId string) int64 {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveStartTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.startTimestamp
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
func StakerIncentiveEndTimestamp(incentiveId string) int64 {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveEndTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.endTimestamp
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
func StakerIncentiveRefundee(incentiveId string) std.Address {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRefundee() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.refundee
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
	en.MintAndDistributeGns()
	CalcPoolPosition()

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositOwner() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.owner
}

// StakerDepositNumberOfStakes returns the number of stakes for a given LP token ID
//
// Parameters:
//   - lpTokenId (uint64): The ID of the LP token
//
// Returns:
//   - uint64: The number of stakes for the deposit
//
// Panics:
//   - If the deposit does not exist for the given lpTokenId
func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositNumberOfStakes() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.numberOfStakes
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
	en.MintAndDistributeGns()
	CalcPoolPosition()

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositStakeTimestamp() || tokenId(%d) deposit does not exist", lpTokenId))
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
	en.MintAndDistributeGns()
	CalcPoolPosition()

	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositTargetPoolPath() || tokenId(%d) deposit does not exist", lpTokenId))
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
	internal, exist := poolTiers[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolTier() || poolPath(%s) poolTier does not exist", poolPath))
	}

	return internal.tier
}

// DEBUG INTERNAL (GNS EMISSION)
type currentInfo struct {
	height           int64
	time             int64
	gnsStaker        uint64
	gnsDevOps        uint64
	gnsCommunityPool uint64
	gnsXGNS          uint64
	gnsProtocolFee   uint64
	gnsGSA           uint64
}

func getCurrentInfo() currentInfo {
	return currentInfo{
		height:           std.GetHeight(),
		time:             time.Now().Unix(),
		gnsStaker:        gns.BalanceOf(a2u(consts.STAKER_ADDR)),
		gnsDevOps:        gns.BalanceOf(a2u(consts.DEV_OPS)),
		gnsCommunityPool: gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR)),
		gnsXGNS:          gns.BalanceOf(a2u(consts.X_GNS_ADDR)),
		gnsProtocolFee:   gns.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR)),
		gnsGSA:           gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN)),
	}
}

func printInfo(prev currentInfo) currentInfo {
	curr := getCurrentInfo()

	println("***********************")
	println("> height:", curr.height)
	println("> height inc by:", curr.height-prev.height)
	println()
	println("> time:", curr.time)
	println("> time inc by:", curr.time-prev.time)
	println()
	println("GNS BALANCE CHANGE")
	println("> staker_bal\t\t", curr.gnsStaker)
	println("> staker_chg\t\t", int64(curr.gnsStaker-prev.gnsStaker))
	println()
	println("> dev ops\t\t", curr.gnsDevOps)
	println("> dev ops_chg\t\t", int(curr.gnsDevOps-prev.gnsDevOps))
	println()
	println("> community pool_bal\t", curr.gnsCommunityPool)
	println("> community pool_chg\t", int(curr.gnsCommunityPool-prev.gnsCommunityPool))
	println()
	println("> x_gns_bal\t\t", curr.gnsXGNS)
	println("> x_gns_chg\t\t", int(curr.gnsXGNS-prev.gnsXGNS))
	println()
	println("> protocol fee_bal\t", curr.gnsProtocolFee)
	println("> protocol fee_chg\t", int(curr.gnsProtocolFee-prev.gnsProtocolFee))
	println()
	println("> GSA_bal\t\t", curr.gnsGSA)
	println("> GSA_chg\t\t", int(curr.gnsGSA-prev.gnsGSA))
	println()
	println("GNS POOL")
	for k, v := range poolGns {
		println("> poolPath:", k, "amount:", v)
	}
	println()

	println("GNS POSITION")
	for k, v := range positionGns {
		posWarmCalc := positionsInternalWarmUpAmount[k]
		println("> tokenId:", k, "amount:", v, "warmUp:", getRewardRatio(curr.height-deposits[k].stakeHeight))
		println("> 100%", "full", posWarmCalc.full100, "give", posWarmCalc.give100)
		println("> 70%", "full", posWarmCalc.full70, "give", posWarmCalc.give70)
		println("> 50%", "full", posWarmCalc.full50, "give", posWarmCalc.give50)
		println("> 30%", "full", posWarmCalc.full30, "give", posWarmCalc.give30)
		println()
	}

	println()

	return curr
}

type ApiEmissionDebugInfo struct {
	Height           int64                  `json:"height"`
	Time             int64                  `json:"time"`
	GnsStaker        uint64                 `json:"gnsStaker"`
	GnsDevOps        uint64                 `json:"gnsDevOps"`
	GnsCommunityPool uint64                 `json:"gnsCommunityPool"`
	GnsXGNS          uint64                 `json:"gnsXGNS"`
	GnsProtocolFee   uint64                 `json:"gnsProtocolFee"`
	GnsGSA           uint64                 `json:"gnsGSA"`
	Pool             []ApiEmissionDebugPool `json:"pool"`
}

type ApiEmissionDebugPool struct {
	PoolPath          string                     `json:"poolPath"`
	Tier              uint64                     `json:"tier"`
	NumPoolInSameTier uint64                     `json:"numPoolInSameTier"`
	PoolReward        uint64                     `json:"poolReward"`
	Position          []ApiEmissionDebugPosition `json:"position"`
}

type ApiEmissionDebugPosition struct {
	LpTokenId       uint64 `json:"lpTokenId"`
	StakedHeight    int64  `json:"stakedHeight"`
	StakedTimestamp int64  `json:"stakedTimestamp"`
	StakedDuration  int64  `json:"stakedDuration"`
	FullAmount      uint64 `json:"fullAmount"`
	Ratio           uint64 `json:"ratio"`
	RatioAmount     uint64 `json:"ratioAmount"`
}

func GetPrintInfo() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	emissionDebug := ApiEmissionDebugInfo{}
	emissionDebug.Height = std.GetHeight()
	emissionDebug.Time = time.Now().Unix()
	emissionDebug.GnsStaker = gns.BalanceOf(a2u(consts.STAKER_ADDR))
	emissionDebug.GnsDevOps = gns.BalanceOf(a2u(consts.DEV_OPS))
	emissionDebug.GnsCommunityPool = gns.BalanceOf(a2u(consts.COMMUNITY_POOL_ADDR))
	emissionDebug.GnsXGNS = gns.BalanceOf(a2u(consts.X_GNS_ADDR))
	emissionDebug.GnsProtocolFee = gns.BalanceOf(a2u(consts.PROTOCOL_FEE_ADDR))
	emissionDebug.GnsGSA = gns.BalanceOf(a2u(consts.GNOSWAP_ADMIN))

	for poolPath, internal := range poolTiers {
		tier := internal.tier
		pool := ApiEmissionDebugPool{}
		pool.PoolPath = poolPath
		pool.Tier = tier

		numTier1, numTier2, numTier3 := getNumPoolTiers()
		if tier == 1 {
			pool.NumPoolInSameTier = numTier1
		} else if tier == 2 {
			pool.NumPoolInSameTier = numTier2
		} else if tier == 3 {
			pool.NumPoolInSameTier = numTier3
		}

		pool.PoolReward = poolGns[poolPath]

		for lpTokenId, deposit := range deposits {
			if deposit.targetPoolPath == poolPath {
				position := ApiEmissionDebugPosition{}
				position.LpTokenId = lpTokenId
				position.StakedHeight = deposit.stakeHeight
				position.StakedTimestamp = deposit.stakeTimestamp
				position.StakedDuration = emissionDebug.Height - deposit.stakeHeight

				position.FullAmount = positionGns[lpTokenId]
				position.Ratio = getRewardRatio(position.StakedDuration)
				position.RatioAmount = (position.FullAmount * position.Ratio) / 100

				pool.Position = append(pool.Position, position)
			}
		}

		emissionDebug.Pool = append(emissionDebug.Pool, pool)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"height": json.NumberNode("", float64(emissionDebug.Height)),
		"time":   json.NumberNode("", float64(emissionDebug.Time)),
		"gns": json.ObjectNode("", map[string]*json.Node{
			"staker":        json.NumberNode("", float64(emissionDebug.GnsStaker)),
			"devOps":        json.NumberNode("", float64(emissionDebug.GnsDevOps)),
			"communityPool": json.NumberNode("", float64(emissionDebug.GnsCommunityPool)),
			"xGNS":          json.NumberNode("", float64(emissionDebug.GnsXGNS)),
			"protocolFee":   json.NumberNode("", float64(emissionDebug.GnsProtocolFee)),
			"GnoswapAdmin":  json.NumberNode("", float64(emissionDebug.GnsGSA)),
		}),
		"pool": json.ArrayNode("", makePoolsNode(emissionDebug.Pool)),
	})

	b, err := json.Marshal(node)
	if err != nil {
		return "JSON MARSHAL ERROR"
	}

	return string(b)
}

func makePoolsNode(emissionPool []ApiEmissionDebugPool) []*json.Node {
	pools := make([]*json.Node, 0)

	for poolPath, internal := range poolTiers {
		numTier1, numTier2, numTier3 := getNumPoolTiers()
		numPoolSameTier := uint64(0)
		tier := internal.tier
		if tier == 1 {
			numPoolSameTier = numTier1
		} else if tier == 2 {
			numPoolSameTier = numTier2
		} else if tier == 3 {
			numPoolSameTier = numTier3
		}

		pools = append(pools, json.ObjectNode("", map[string]*json.Node{
			"poolPath":        json.StringNode("poolPath", poolPath),
			"startTimestamp":  json.NumberNode("startTimestamp", float64(internal.startTimestamp)),
			"tier":            json.NumberNode("tier", float64(tier)),
			"numPoolSameTier": json.NumberNode("numPoolSameTier", float64(numPoolSameTier)),
			"poolReward":      json.NumberNode("poolReward", float64(poolGns[poolPath])),
			"position":        json.ArrayNode("", makePositionsNode(poolPath)),
		}))
	}

	return pools
}

func makePositionsNode(poolPath string) []*json.Node {
	positions := make([]*json.Node, 0)

	for lpTokenId, deposit := range deposits {
		if deposit.targetPoolPath == poolPath {
			stakedDuration := std.GetHeight() - deposit.stakeHeight
			ratio := getRewardRatio(stakedDuration)
			fullAmount, warmUpAmount := rewardMathComputeInternalRewardAmount(lpTokenId)

			posCalcWarm := positionsInternalWarmUpAmount[lpTokenId]

			positions = append(positions, json.ObjectNode("", map[string]*json.Node{
				"lpTokenId":       json.NumberNode("lpTokenId", float64(lpTokenId)),
				"stakedHeight":    json.NumberNode("stakedHeight", float64(deposit.stakeHeight)),
				"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(deposit.stakeTimestamp)),
				"stakedDuration":  json.NumberNode("stakedDuration", float64(stakedDuration)),
				"fullAmount":      json.NumberNode("fullAmount", float64(fullAmount)),
				"ratio":           json.NumberNode("ratio", float64(ratio)),
				"warmUpAmount":    json.NumberNode("warmUpAmount", float64(warmUpAmount)),
				"full30":          json.NumberNode("full30", float64(posCalcWarm.full30)),
				"give30":          json.NumberNode("give30", float64(posCalcWarm.give30)),
				"full50":          json.NumberNode("full50", float64(posCalcWarm.full50)),
				"give50":          json.NumberNode("give50", float64(posCalcWarm.give50)),
				"full70":          json.NumberNode("full70", float64(posCalcWarm.full70)),
				"give70":          json.NumberNode("give70", float64(posCalcWarm.give70)),
				"full100":         json.NumberNode("full100", float64(posCalcWarm.full100)),
				"give100":         json.NumberNode("give100", float64(posCalcWarm.give100)),
			}))
		}
	}

	return positions
}

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
			externalIncentive.RewardAmount = incentive.rewardAmount.ToString()
			externalIncentive.RewardLeft = incentive.rewardLeft.ToString()
			externalIncentive.StartTimestamp = incentive.startTimestamp
			externalIncentive.EndTimestamp = incentive.endTimestamp
			externalIncentive.RewardPerBlockX96 = incentive.rewardPerBlockX96.ToString()
			externalIncentive.RewardPerBlock = new(u256.Uint).Div(incentive.rewardPerBlockX96, u256.MustFromDecimal(consts.Q96)).ToString()
			externalIncentive.Refundee = incentive.refundee

			externalIncentive.tokenAmountX96 = external.tokenAmountX96

			fullAmount, toGive := rewardMathComputeExternalRewardAmount(lpTokenId, incentiveId)
			externalIncentive.tokenAmountFull += fullAmount
			externalIncentive.tokenAmountActualFull += toGive

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
	_q96 := u256.MustFromDecimal(consts.Q96)

	externalPositions := make([]*json.Node, 0)

	for _, externalPosition := range positions {
		incentives := make([]*json.Node, 0)
		for _, incentive := range externalPosition.Incentive {
			incentives = append(incentives, json.ObjectNode("", map[string]*json.Node{
				"poolPath":              json.StringNode("poolPath", incentive.PoolPath),
				"rewardToken":           json.StringNode("rewardToken", incentive.RewardToken),
				"rewardAmount":          json.StringNode("rewardAmount", incentive.RewardAmount),
				"rewardLeft":            json.StringNode("rewardLeft", incentive.RewardLeft),
				"startTimestamp":        json.NumberNode("startTimestamp", float64(incentive.StartTimestamp)),
				"endTimestamp":          json.NumberNode("endTimestamp", float64(incentive.EndTimestamp)),
				"rewardPerBlockX96":     json.StringNode("rewardPerBlockX96", incentive.RewardPerBlockX96),
				"rewardPerBlock":        json.StringNode("rewardPerBlock", incentive.RewardPerBlock),
				"refundee":              json.StringNode("refundee", incentive.Refundee.String()),
				"tokenAmountX96":        json.StringNode("tokenAmountX96", incentive.tokenAmountX96.ToString()),
				"tokenAmount":           json.NumberNode("tokenAmount", float64(new(u256.Uint).Div(incentive.tokenAmountX96, _q96).Uint64())),
				"tokenAmountFull":       json.NumberNode("tokenAmountFull", float64(incentive.tokenAmountFull)),
				"tokenAmountActualFull": json.NumberNode("tokenAmountActualFull", float64(incentive.tokenAmountActualFull)),
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
	RewardToken       string      `json:"rewardToken"`
	RewardAmount      string      `json:"rewardAmount"`
	RewardLeft        string      `json:"rewardLeft"`
	StartTimestamp    int64       `json:"startTimestamp"`
	EndTimestamp      int64       `json:"endTimestamp"`
	RewardPerBlockX96 string      `json:"rewardPerBlockX96"`
	RewardPerBlock    string      `json:"rewardPerBlock"`
	Refundee          std.Address `json:"refundee"`
	// FROM externalRewards
	tokenAmountX96        *u256.Uint `json:"tokenAmountX96"`
	tokenAmount           uint64     `json:"tokenAmount"`
	tokenAmountFull       uint64     `json:"tokenAmountFull"`
	tokenAmountActualFull uint64     `json:"tokenAmountActualFull"`
}
