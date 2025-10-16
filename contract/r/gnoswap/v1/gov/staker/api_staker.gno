package staker

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/protocol_fee"
)

// GetLockedAmount returns total locked GNS.
func GetLockedAmount() int64 {
	lockedAmount := int64(0)

	delegations.Iterate("", "", func(key string, value any) bool {
		delegation, ok := value.(*Delegation)
		if !ok {
			panic(ufmt.Sprintf("failed to cast delegations's element to *Delegation: %T", value))
		}
		lockedAmount += delegation.DelegatedAmount()
		return false
	})

	return lockedAmount
}

// GetClaimableRewardByAddress returns claimable reward for address.
func GetClaimableRewardByAddress(addr address) string {
	return GetClaimableRewardByRewardID(addr.String())
}

// GetClaimableRewardByLaunchpad returns claimable reward for launchpad.
func GetClaimableRewardByLaunchpad(addr address) string {
	return GetClaimableRewardByRewardID(makeLaunchpadRewardID(addr.String()))
}

// GetClaimableRewardByRewardID returns claimable reward by ID.
func GetClaimableRewardByRewardID(rewardID string) string {
	func(cur realm) {
		emission.MintAndDistributeGns(cross)
		protocol_fee.DistributeProtocolFee(cross)
	}(cross)

	emissionDistributedAmount := emission.GetAccuDistributedToGovStaker()
	emissionReward, err := emissionRewardManager.GetClaimableRewardAmount(emissionDistributedAmount, rewardID, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	protocolFeeDistributedAmounts := getDistributedProtocolFees()
	protocolFeeRewards, err := protocolFeeRewardManager.GetClaimableRewardAmounts(protocolFeeDistributedAmounts, rewardID, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	if emissionReward == 0 && len(protocolFeeRewards) == 0 {
		return ""
	}

	data := json.Builder().
		WriteString("height", formatInt(runtime.ChainHeight())).
		WriteString("now", formatInt(time.Now().Unix())).
		WriteString("emissionReward", formatInt(emissionReward)).
		Node()

	// Always include protocolFees array, even if empty
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

	return marshal(data)
}
