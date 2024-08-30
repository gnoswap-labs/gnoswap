package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"

	"gno.land/r/gnoswap/v2/consts"
	"gno.land/r/gnoswap/v2/gns"

	en "gno.land/r/gnoswap/v2/emission"
)

// DEBUG INTERNAL (GNS EMISSION)
type currentInfo struct {
	height           int64
	time             int64
	gnsStaker        uint64
	gnsDevOps        uint64
	gnsCommunityPool uint64
	gnsGovStaker     uint64
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
		gnsGovStaker:     gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR)),
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
	println("> gov_staker_bal\t\t", curr.gnsGovStaker)
	println("> gov_staker_chg\t\t", int(curr.gnsGovStaker-prev.gnsGovStaker))
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
		println("> 100%", "full", posWarmCalc.full100, "give", posWarmCalc.full100)
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
	GnsGovStaker     uint64                 `json:"gnsGovStaker"`
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
	emissionDebug.GnsGovStaker = gns.BalanceOf(a2u(consts.GOV_STAKER_ADDR))
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
			"govStaker":     json.NumberNode("", float64(emissionDebug.GnsGovStaker)),
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

			internalWarmUpAmount, exist := positionsInternalWarmUpAmount[lpTokenId]
			if !exist {
				continue
			}
			fullAmount := internalWarmUpAmount.full30 + internalWarmUpAmount.full50 + internalWarmUpAmount.full70 + internalWarmUpAmount.full100
			warmUpAmount := internalWarmUpAmount.give30 + internalWarmUpAmount.give50 + internalWarmUpAmount.give70 + internalWarmUpAmount.full100

			positions = append(positions, json.ObjectNode("", map[string]*json.Node{
				"lpTokenId":       json.NumberNode("lpTokenId", float64(lpTokenId)),
				"stakedHeight":    json.NumberNode("stakedHeight", float64(deposit.stakeHeight)),
				"stakedTimestamp": json.NumberNode("stakedTimestamp", float64(deposit.stakeTimestamp)),
				"stakedDuration":  json.NumberNode("stakedDuration", float64(stakedDuration)),
				"fullAmount":      json.NumberNode("fullAmount", float64(fullAmount)),
				"ratio":           json.NumberNode("ratio", float64(ratio)),
				"warmUpAmount":    json.NumberNode("warmUpAmount", float64(warmUpAmount)),
				"full30":          json.NumberNode("full30", float64(internalWarmUpAmount.full30)),
				"give30":          json.NumberNode("give30", float64(internalWarmUpAmount.give30)),
				"full50":          json.NumberNode("full50", float64(internalWarmUpAmount.full50)),
				"give50":          json.NumberNode("give50", float64(internalWarmUpAmount.give50)),
				"full70":          json.NumberNode("full70", float64(internalWarmUpAmount.full70)),
				"give70":          json.NumberNode("give70", float64(internalWarmUpAmount.give70)),
				"full100":         json.NumberNode("full100", float64(internalWarmUpAmount.full100)),
			}))
		}
	}

	return positions
}
