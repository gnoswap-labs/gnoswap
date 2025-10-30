package v1

import (
	"chain/runtime"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"

	"gno.land/r/gnoswap/emission"
	"gno.land/r/gnoswap/protocol_fee"
	"gno.land/r/gnoswap/gov/staker"
)

// GetLockedAmount returns total locked GNS.
func (gs *govStakerV1) GetLockedAmount() int64 {
	lockedAmount := int64(0)

	delegations, err := gs.store.GetAllDelegations()
	if err != nil {
		panic(err)
	}
	delegations.Iterate("", "", func(key string, value any) bool {
		delegation, ok := value.(*staker.Delegation)
		if !ok {
			panic(ufmt.Sprintf("failed to cast delegations's element to *Delegation: %T", value))
		}
		lockedAmount += NewDelegationResolver(delegation).LockedAmount()
		return false
	})

	return lockedAmount
}

// GetClaimableRewardByAddress returns claimable reward for address.
func (gs *govStakerV1) GetClaimableRewardByAddress(addr address) string {
	return gs.GetClaimableRewardByRewardID(addr.String())
}

// GetClaimableRewardByLaunchpad returns claimable reward for launchpad.
func (gs *govStakerV1) GetClaimableRewardByLaunchpad(addr address) string {
	return gs.GetClaimableRewardByRewardID(gs.makeLaunchpadRewardID(addr.String()))
}

// GetClaimableRewardByRewardID returns claimable reward by ID.
func (gs *govStakerV1) GetClaimableRewardByRewardID(rewardID string) string {
	emission.MintAndDistributeGns(cross)
	protocol_fee.DistributeProtocolFee(cross)

	emissionDistributedAmount := emission.GetAccuDistributedToGovStaker()
	emissionRewardManager, err := gs.store.GetEmissionRewardManager()
	if err != nil {
		panic(err)
	}
	emissionResolver := NewEmissionRewardManagerResolver(emissionRewardManager)
	emissionReward, err := emissionResolver.GetClaimableRewardAmount(emissionDistributedAmount, rewardID, time.Now().Unix())
	if err != nil {
		panic(err)
	}

	protocolFeeDistributedAmounts := gs.getDistributedProtocolFees()
	protocolFeeRewardManager, err := gs.store.GetProtocolFeeRewardManager()
	if err != nil {
		panic(err)
	}
	protocolFeeResolver := NewProtocolFeeRewardManagerResolver(protocolFeeRewardManager)
	protocolFeeRewards, err := protocolFeeResolver.GetClaimableRewardAmounts(protocolFeeDistributedAmounts, rewardID, time.Now().Unix())
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
