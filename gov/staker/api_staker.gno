package staker

import (
	"std"
	"strconv"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	en "gno.land/r/gnoswap/v1/emission"
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
func GetLockedInfoByAddress(addr std.Address) string {
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

	data := json.Builder().
		WriteString("height", ufmt.Sprintf("%d", std.GetHeight())).
		WriteString("now", formatUint(time.Now().Unix())).
		WriteString("totalLocked", formatUint(totalLocked)).
		WriteString("claimableAmount", formatUint(claimableAmount)).
		Node()

	return marshal(lockedObj)
}

func GetClaimableRewardByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	emissionReward := userEmissionReward[addr]

	data := json.Builder().
		WriteString("height", formatUint(std.GetHeight())).
		WriteString("now", formatUint(time.Now().Unix())).
		WriteString("emissionReward", formatUint(emissionReward)).

	protocolFees, exist := userProtocolFeeReward[addr]
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
