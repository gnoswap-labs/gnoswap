package staker

import (
	"encoding/json"
	"std"

	"gno.land/p/demo/ufmt"
)

type ApiQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ApiRewardByAddress struct {
	Type   string `json:"type"`
	Token  string `json:"token"`
	Reward uint64 `json:"reward"`
}

type ResponseGetRewardByAddress struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []ApiRewardByAddress `json:"data"`
	} `json:"response"`
}

func ApiGetRewardByAddress(address std.Address) string {
	rewardList := []ApiRewardByAddress{}

	// all staked token by address
	for tokenId, deposit := range deposits {
		if deposit.owner == address {
			poolPath := deposit.targetPoolPath

			// get internal gns reward
			internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
			rewardList = append(rewardList, ApiRewardByAddress{
				Type:   "Internal",
				Token:  "GNS",
				Reward: internalGNS,
			})

			// find all external reward list for this pool
			for _, incentiveId := range poolIncentives[poolPath] {
				externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentives[incentiveId])
				rewardList = append(rewardList, ApiRewardByAddress{
					Type:   "External",
					Token:  incentives[incentiveId].rewardToken,
					Reward: externalReward,
				})
			}
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetRewardByAddress{
		Stat: qb,
		Response: struct {
			Data []ApiRewardByAddress `json:"data"`
		}{
			Data: rewardList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] getter_api.gno__ApiGetRewardByAddress() || %v", err))
	}

	return string(rr)
}
