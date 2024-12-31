package staker

import (
	"std"
	"time"

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
		WriteNumber("height", std.GetHeight()).
		WriteNumber("now", time.Now().Unix()).
		WriteNumber("totalLocked", totalLocked).
		WriteNumber("claimableAmount", claimableAmount).
		Node()

	return marshal(data)
}

func GetClaimableRewardByAddress(addr std.Address) string {
	en.MintAndDistributeGns()
	calculateReward()

	emissionReward := userEmissionReward[addr]

	data := json.Builder().
		WriteNumber("height", std.GetHeight()).
		WriteNumber("now", time.Now().Unix()).
		WriteNumber("emissionReward", emissionReward).
		Node()

	protocolFees, exist := userProtocolFeeReward[addr]
	if exist {
		pfArr := json.ArrayNode("", nil)
		for tokenPath, amount := range protocolFees {
			if amount > 0 {
				pfObj := json.Builder().
					WriteString("tokenPath", tokenPath).
					WriteNumber("amount", amount).
					Node()
				pfArr.AppendArray(pfObj)
			}
		}

		data.AppendObject("protocolFees", pfArr)
	}

	return marshal(data)
}
