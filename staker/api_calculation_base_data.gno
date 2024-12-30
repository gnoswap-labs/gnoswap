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

func GetPoolRewardUpdates(poolPath string, startHeight, endHeight uint64) string {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return ""
	}

	builder := json.Builder().WriteArray("", func(ab *json.ArrayBuilder) {
		pool.rewardCache.Iterate(startHeight, endHeight, func(key uint64, value interface{}) bool {
			ab.WriteObject(func(ob *json.NodeBuilder) {
				ob.WriteString("blockNumber", ufmt.Sprintf("%d", key))
				ob.WriteString("reward", value.(*u256.Uint).ToString())
			})
			return false
		})
	})

	return marshal(builder.Node())
}

// consts.Q96
func GetQ96() string {
	en.MintAndDistributeGns()

	return "79228162514264337593543950336"
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

// func GetExternalGnsAmount() uint64 {
// 	en.MintAndDistributeGns()

// 	return externalGnsAmount()
// }

func GetStakerGnsBalance() uint64 {
	en.MintAndDistributeGns()

	return gnsBalance(consts.STAKER_ADDR)
}

func GetPositionIsInRange(tokenId uint64) bool {
	en.MintAndDistributeGns()

	return pn.PositionIsInRange(tokenId)
}

func GetPositionLiquidity(tokenId uint64) string {
	en.MintAndDistributeGns()

	return pn.PositionGetPositionLiquidityStr(tokenId)
}

func GetWarmUpPeriods() string {
	en.MintAndDistributeGns()

	warmups := InstantiateWarmup(std.GetHeight())

	result := ""
	for i, warmup := range warmups {
		if i > 0 {
			result += "*STAKER*"
		}
		result += ufmt.Sprintf("%d", warmup.WarmupRatio)
	}

	return result
}

// GetPositionExternalData returns the every position's external related data for the calculation
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
