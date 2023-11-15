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
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetRewardByAddress() || json marshal error: %v", err))
	}

	return string(rr)
}

type ApiStakes struct {
	TokenId        uint64      `json:"tokenId"`
	Owner          std.Address `json:"owner"`
	NumberOfStakes uint64      `json:"numberOfStakes"`
	StakeTimestamp int64       `json:"stakeTimestamp"`
	TargetPoolPath string      `json:"targetPoolPath"`
}

type ResponseGetStakes struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []ApiStakes `json:"data"`
	} `json:"response"`
}

func ApiGetStakes() string {
	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	stakes := []ApiStakes{}
	for tokenId, deposit := range deposits {
		stakes = append(stakes, ApiStakes{
			TokenId:        tokenId,
			Owner:          deposit.owner,
			NumberOfStakes: deposit.numberOfStakes,
			StakeTimestamp: deposit.stakeTimestamp,
			TargetPoolPath: deposit.targetPoolPath,
		})
	}

	r := ResponseGetStakes{
		Stat: qb,
		Response: struct {
			Data []ApiStakes `json:"data"`
		}{
			Data: stakes,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetStakes() || json marshal error: %v", err))
	}

	return string(rr)
}

type ApiStakeByPool struct {
	TokenId        uint64      `json:"tokenId"`
	Owner          std.Address `json:"owner"`
	NumberOfStakes uint64      `json:"numberOfStakes"`
	StakeTimestamp int64       `json:"stakeTimestamp"`
}

type ResponseApiGetStakeByPool struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data map[string][]ApiStakeByPool `json:"data"`
	} `json:"response"`
}

func ApiGetStakeByPool() string {
	stakeByPool := make(map[string][]ApiStakeByPool)

	for tokenId, deposit := range deposits {
		stakeByPool[deposit.targetPoolPath] = append(stakeByPool[deposit.targetPoolPath], ApiStakeByPool{
			TokenId:        tokenId,
			Owner:          deposit.owner,
			NumberOfStakes: deposit.numberOfStakes,
			StakeTimestamp: deposit.stakeTimestamp,
		})
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetStakeByPool{
		Stat: qb,
		Response: struct {
			Data map[string][]ApiStakeByPool `json:"data"`
		}{
			Data: stakeByPool,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetStakeByPool() || json marshal error: %v", err))
	}

	return string(rr)
}

type ApiStakeByAddress struct {
	TokenId        uint64 `json:"tokenId"`
	NumberOfStakes uint64 `json:"numberOfStakes"`
	StakeTimestamp int64  `json:"stakeTimestamp"`
	TargetPoolPath string `json:"targetPoolPath"`
}

type ResponseApiGetStakeByAddress struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data [](map[string][]ApiStakeByAddress) `json:"data"`
	} `json:"response"`
}

func ApiGetStakeByAddress() string {
	stakeByAddress := make([](map[string][]ApiStakeByAddress), 0)

	for tokenId, deposit := range deposits {
		stakeByAddress = append(stakeByAddress, map[string][]ApiStakeByAddress{
			deposit.owner.String(): []ApiStakeByAddress{
				{
					TokenId:        tokenId,
					NumberOfStakes: deposit.numberOfStakes,
					StakeTimestamp: deposit.stakeTimestamp,
					TargetPoolPath: deposit.targetPoolPath,
				},
			},
		})
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetStakeByAddress{
		Stat: qb,
		Response: struct {
			Data []map[string][]ApiStakeByAddress `json:"data"`
		}{
			Data: stakeByAddress,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetStakeByAddress() || json marshal error: %v", err))
	}

	return string(rr)
}
