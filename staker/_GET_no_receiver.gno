package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	u256 "gno.land/p/gnoswap/uint256"

	"gno.land/r/gnoswap/consts"
	"gno.land/r/gnoswap/gns"

	en "gno.land/r/gnoswap/emission"
)

// Incentive
func StakerPoolIncentives(poolPath string) []string {
	incentives, exist := poolIncentives[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolIncentives() || poolPath(%s) incentives does not exist", poolPath))
	}

	return incentives
}

func StakerIncentiveTargetPoolPath(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveTargetPoolPath() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.targetPoolPath
}

func StakerIncentiveRewardToken(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardToken() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardToken
}

// UINT
func StakerIncentiveRewardAmount(incentiveId string) *u256.Uint {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount
}

// STR
func StakerIncentiveRewardAmountStr(incentiveId string) string {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRewardAmount() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.rewardAmount.ToString()
}

func StakerIncentiveStartTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveStartTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.startTimestamp
}

func StakerIncentiveEndTimestamp(incentiveId string) int64 {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveEndTimestamp() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.endTimestamp
}

func StakerIncentiveRefundee(incentiveId string) std.Address {
	incentive, exist := incentives[incentiveId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerIncentiveRefundee() || incentiveId(%s) incentive does not exist", incentiveId))
	}

	return incentive.refundee
}

// Deposit
func StakerDepositOwner(lpTokenId uint64) std.Address {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositOwner() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.owner
}

func StakerDepositNumberOfStakes(lpTokenId uint64) uint64 {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositNumberOfStakes() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.numberOfStakes
}

func StakerDepositStakeTimestamp(lpTokenId uint64) int64 {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositStakeTimestamp() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.stakeTimestamp
}

func StakerDepositTargetPoolPath(lpTokenId uint64) string {
	deposit, exist := deposits[lpTokenId]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerDepositTargetPoolPath() || tokenId(%d) deposit does not exist", lpTokenId))
	}

	return deposit.targetPoolPath
}

// PoolTier
func StakerPoolTier(poolPath string) uint64 {
	internal, exist := poolTiers[poolPath]
	if !exist {
		panic(ufmt.Sprintf("[STAKER] _GET_no_receiver__StakerPoolTier() || poolPath(%s) poolTier does not exist", poolPath))
	}

	return internal.tier
}

// DEBUG
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
	println("> time:", curr.time)
	println("> time inc by:", curr.time-prev.time)
	println()
	println("GNS BALANCE CHANGE")
	println("> staker_bal\t\t", curr.gnsStaker)
	println("> staker_chg\t\t", int64(curr.gnsStaker-prev.gnsStaker))
	println("> dev ops\t\t", curr.gnsDevOps)
	println("> dev ops_chg\t\t", int(curr.gnsDevOps-prev.gnsDevOps))
	println("> community pool_bal\t", curr.gnsCommunityPool)
	println("> community pool_chg\t", int(curr.gnsCommunityPool-prev.gnsCommunityPool))
	println("> x_gns_bal\t\t", curr.gnsXGNS)
	println("> x_gns_chg\t\t", int(curr.gnsXGNS-prev.gnsXGNS))
	println("> protocol fee_bal\t", curr.gnsProtocolFee)
	println("> protocol fee_chg\t", int(curr.gnsProtocolFee-prev.gnsProtocolFee))
	println("> GSA_bal\t\t", curr.gnsGSA)
	println("> GSA_chg\t\t", int(curr.gnsGSA-prev.gnsGSA))
	println()
	println("GNS POSITION")
	for k, v := range positionGns {
		println("> tokenId:", k, "amount:", v)
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
			fullAmount := positionGns[lpTokenId]
			ratio := getRewardRatio(stakedDuration)
			ratioAmount := (fullAmount * ratio) / 100

			positions = append(positions, json.ObjectNode("", map[string]*json.Node{
				"lpTokenId":       json.NumberNode("lpTokenId", float64(lpTokenId)),
				"stakedHeight":    json.NumberNode("stakedHeight", float64(deposit.stakeHeight)),
				"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(deposit.stakeTimestamp)),
				"stakedDuration":  json.NumberNode("stakedDuration", float64(stakedDuration)),
				"fullAmount":      json.NumberNode("fullAmount", float64(fullAmount)),
				"ratio":           json.NumberNode("ratio", float64(ratio)),
				"ratioAmount":     json.NumberNode("ratioAmount", float64(ratioAmount)),
			}))
		}
	}

	return positions
}
