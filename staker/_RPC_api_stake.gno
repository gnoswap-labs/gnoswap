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

type Reward struct {
	IncentiveType     string `json:"incentiveType"`
	TargetPoolPath    string `json:"targetPoolPath"`
	RewardTokenPath   string `json:"rewardTokenPath"`
	RewardTokenAmount uint64 `json:"rewardTokenAmount"`
}

type LpTokenReward struct {
	LpTokenId uint64   `json:"lpTokenId"`
	Address   string   `json:"address"`
	Rewards   []Reward `json:"rewards"`
}

type ResponseApiGetRewards struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []LpTokenReward `json:"data"`
	} `json:"response"`
}

func ApiGetRewards() string {
	lpTokenRewards := []LpTokenReward{}

	for tokenId, deposit := range deposits {
		rewards := []Reward{}

		// get internal gns reward
		internalGNS := rewardMathComputeInternalRewardAmount(tokenId, deposit)
		if internalGNS > 0 {
			rewards = append(rewards, Reward{
				IncentiveType:     "INTERNAL",
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   INTERNAL_REWARD_TOKEN_PATH,
				RewardTokenAmount: internalGNS,
			})
		}

		// find all external reward list for poolPath which lpTokenId is staked
		for _, incentiveId := range poolIncentives[deposit.targetPoolPath] {
			externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentives[incentiveId])
			rewards = append(rewards, Reward{
				IncentiveType:     "EXTERNAL",
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   incentives[incentiveId].rewardToken,
				RewardTokenAmount: externalReward,
			})
		}

		lpTokenReward := LpTokenReward{
			LpTokenId: tokenId,
			Address:   deposit.owner.String(),
			Rewards:   rewards,
		}
		lpTokenRewards = append(lpTokenRewards, lpTokenReward)
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetRewards{
		Stat: qb,
		Response: struct {
			Data []LpTokenReward `json:"data"`
		}{
			Data: lpTokenRewards,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetRewards() || json marshal error: %v", err))
	}

	return string(rr)
}

type ApiRewardByAddress struct {
	Address           string `json:"address"`
	LpTokenId         uint64 `json:"lpTokenId"`
	IncentiveType     string `json:"incentiveType"`
	TargetPoolPath    string `json:"targetPoolPath"`
	RewardTokenPath   string `json:"rewardTokenPath"`
	RewardTokenAmount uint64 `json:"rewardTokenAmount"`
}

type ResponseGetApiRewardByAddress struct {
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
			internalGNS = userClaimedRewardAmount(deposit.owner, "gno.land/r/demo/gns", bigint(internalGNS), false)

			if internalGNS > 0 {
				rewardList = append(rewardList, ApiRewardByAddress{
					Address:           address.String(),
					LpTokenId:         tokenId,
					IncentiveType:     "INTERNAL",
					TargetPoolPath:    poolPath,
					RewardTokenPath:   INTERNAL_REWARD_TOKEN_PATH,
					RewardTokenAmount: internalGNS,
				})
			}

			// find all external reward list for this pool
			for _, incentiveId := range poolIncentives[poolPath] {
				externalReward := rewardMathComputeExternalRewardAmount(tokenId, deposit, incentives[incentiveId])
				externalReward = userClaimedRewardAmount(deposit.owner, incentives[incentiveId].rewardToken, bigint(externalReward), false)

				if externalReward > 0 {
					rewardList = append(rewardList, ApiRewardByAddress{
						Address:           address.String(),
						LpTokenId:         tokenId,
						IncentiveType:     "EXTERNAL",
						TargetPoolPath:    poolPath,
						RewardTokenPath:   incentives[incentiveId].rewardToken,
						RewardTokenAmount: externalReward,
					})
				}
			}
		}
	}

	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseGetApiRewardByAddress{
		Stat: qb,
		Response: struct {
			Data []ApiRewardByAddress `json:"data"`
		}{
			Data: rewardList,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api.gno__ApiGetApiRewardByAddress() || json marshal error: %v", err))
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
