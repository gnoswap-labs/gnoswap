package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v2/emission"
)

// GetLockedAmount gets the total locked amount of GNS.
func GetLockedAmount() uint64 {
	en.MintAndDistributeGns()
	calculateReward()

	return lockedAmount
}

// GetLockedInfoByAddress gets the locked info of an address.
// - total locked amount
// - claimable amount
func GetLockedInfoByAddress(addr string) string {
	en.MintAndDistributeGns()
	calculateReward()

	lockeds, exist := addrLockedGns[addr]
	if !exist {
		return ""
	}

	now := uint64(time.Now().Unix())

	totalLocked := uint64(0)
	claimableAmount := uint64(0)

	for _, locked := range lockeds {
		amount := locked.amount
		unlock := locked.unlock

		totalLocked += amount

		if now >= unlock {
			claimableAmount += amount
		}
	}

	lockedObj := json.ObjectNode("", nil)
	lockedObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	lockedObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	lockedObj.AppendObject("totalLocked", json.StringNode("totalLocked", ufmt.Sprintf("%d", totalLocked)))
	lockedObj.AppendObject("claimableAmount", json.StringNode("claimableAmount", ufmt.Sprintf("%d", claimableAmount)))

	return marshal(lockedObj)
}

func GetClaimableRewardByAddress(addr string) string {
	en.MintAndDistributeGns()
	calculateReward()

	emissionReward := userEmissionReward[addr]

	rewardObj := json.ObjectNode("", nil)
	rewardObj.AppendObject("height", json.StringNode("height", ufmt.Sprintf("%d", std.GetHeight())))
	rewardObj.AppendObject("now", json.StringNode("now", ufmt.Sprintf("%d", time.Now().Unix())))
	rewardObj.AppendObject("emissionReward", json.StringNode("emissionReward", ufmt.Sprintf("%d", emissionReward)))

	protocolFees, exist := userProtocolFeeReward[addr]
	println("GetClaimableRewardByAddress_PF", protocolFees)
	if exist {
		pfArr := json.ArrayNode("", nil)
		for tokenPath, amount := range protocolFees {
			if amount > 0 {
				pfObj := json.ObjectNode("", nil)
				pfObj.AppendObject("tokenPath", json.StringNode("tokenPath", tokenPath))
				pfObj.AppendObject("amount", json.StringNode("amount", ufmt.Sprintf("%d", amount)))
				pfArr.AppendArray(pfObj)
			}
		}

		rewardObj.AppendObject("protocolFees", pfArr)
	}

	return marshal(rewardObj)
}
