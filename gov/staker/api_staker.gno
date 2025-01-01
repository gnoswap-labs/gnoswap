package staker

import (
	"std"
	"time"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/json"

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

	lockeds, exist := addrLockedGns.Get(addr.String())
	if !exist {
		return ""
	}

	now := uint64(time.Now().Unix())

	totalLocked := uint64(0)
	claimableAmount := uint64(0)

	for _, locked := range lockeds.([]lockedGNS) {
		amount := locked.amount
		unlock := locked.unlock

		totalLocked += amount

		if now >= unlock {
			claimableAmount += amount
		}
	}

	data := json.Builder().
		WriteString("height", formatInt(std.GetHeight())).
		WriteString("now", formatInt(time.Now().Unix())).
		WriteString("totalLocked", formatUint(totalLocked)).
		WriteString("claimableAmount", formatUint(claimableAmount)).
		Node()

	return marshal(data)
}

func GetClaimableRewardByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	emissionReward, exist := userEmissionReward.Get(addr.String())
	if !exist {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(std.GetHeight())).
		WriteString("now", formatInt(time.Now().Unix())).
		WriteString("emissionReward", formatUint(emissionReward.(uint64))).
		Node()

	protocolFees, exist := userProtocolFeeReward.Get(addr.String())
	if exist {
		pfArr := json.ArrayNode("", nil)
		protocolFees.(*avl.Tree).Iterate("", "", func(key string, value interface{}) bool {
			amount := value.(uint64)
			if amount > 0 {
				pfObj := json.Builder().
					WriteString("tokenPath", key).
					WriteString("amount", formatUint(amount)).
					Node()
				pfArr.AppendArray(pfObj)
			}
			return false
		})

		data.AppendObject("protocolFees", pfArr)
	}

	return marshal(data)
}
