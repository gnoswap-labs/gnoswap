package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/r/gnoswap/v1/emission"
	"gno.land/r/gnoswap/v1/protocol_fee"
)

// GetLockedAmount gets the total locked amount of GNS.
func GetLockedAmount() int64 {
	lockedAmount := int64(0)

	delegations.Iterate("", "", func(key string, value interface{}) bool {
		delegation := value.(*Delegation)
		lockedAmount += delegation.DelegatedAmount()
		return false
	})

	return lockedAmount
}

// GetClaimableRewardByAddress gets the claimable reward of an address.
func GetClaimableRewardByAddress(addr std.Address) string {
	return GetClaimableRewardByRewardID(addr.String())
}

// GetClaimableRewardByAddress gets the claimable reward of an address.
func GetClaimableRewardByLaunchpad(addr std.Address) string {
	return GetClaimableRewardByRewardID(makeLaunchpadRewardID(addr.String()))
}

// GetClaimableRewardByRewardID gets the claimable reward of an address.
func GetClaimableRewardByRewardID(rewardID string) string {
	func(cur realm) {
		emission.MintAndDistributeGns(cross)
		protocol_fee.DistributeProtocolFee(cross)
	}(cross)

	emissionDistributedAmount := emission.GetAccuDistributedToGovStaker()
	emissionReward := emissionRewardManager.GetClaimableRewardAmount(emissionDistributedAmount, rewardID, std.ChainHeight())

	protocolFeeDistributedAmounts := getDistributedProtocolFees()
	protocolFeeRewards := protocolFeeRewardManager.GetClaimableRewardAmounts(protocolFeeDistributedAmounts, rewardID, std.ChainHeight())

	if emissionReward == 0 && len(protocolFeeRewards) == 0 {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(std.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix())).
		WriteString("emissionReward", formatInt(emissionReward)).
		Node()

	if len(protocolFeeRewards) > 0 {
		pfArr := json.ArrayNode("", nil)
		for tokenPath, protocolFeeReward := range protocolFeeRewards {
			if protocolFeeReward > 0 {
				pfObj := json.Builder().
					WriteString("tokenPath", tokenPath).
					WriteString("amount", formatInt(protocolFeeReward)).
					Node()
				pfArr.AppendArray(pfObj)
			}
		}

		data.AppendObject("protocolFees", pfArr)
	}

	return marshal(data)
}
