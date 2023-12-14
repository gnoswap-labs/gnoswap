package staker

import (
	"encoding/json"

	pl "gno.land/r/demo/pool"

	"gno.land/p/demo/ufmt"
)

const INTERNAL_REWARD_TOKEN_PATH = "gno.land/r/demo/gns"

// type ApiQueryBase struct {
// 	Height    int64 `json:"height"`
// 	Timestamp int64 `json:"timestamp"`
// }

type RewardToken struct {
	PoolPath         string   `json:"poolPath"`
	RewardsTokenList []string `json:"rewardsTokenList"`
}

type ResponseRewardTokens struct {
	Stat     ApiQueryBase `json:"stat"`
	Response struct {
		Data []RewardToken `json:"data"`
	} `json:"response"`
}

func ApiGetRewardTokens() string {
	rewardTokens := []RewardToken{}

	poolList := pl.PoolGetPoolList()
	for _, poolPath := range poolList {
		thisPoolRewardTokens := []string{}

		// HANDLE INTERNAL
		_, ok := poolTiers[poolPath]
		if ok {
			thisPoolRewardTokens = append(thisPoolRewardTokens, INTERNAL_REWARD_TOKEN_PATH)
		}

		// HANDLE EXTERNAL
		for _, incentiveId := range poolIncentives[poolPath] {
			thisPoolRewardTokens = append(thisPoolRewardTokens, incentives[incentiveId].rewardToken)
		}

		rewardTokens = append(rewardTokens, RewardToken{
			PoolPath:         poolPath,
			RewardsTokenList: thisPoolRewardTokens,
		})
	}

	// JSON
	qb := ApiQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseRewardTokens{
		Stat: qb,
		Response: struct {
			Data []RewardToken `json:"data"`
		}{
			Data: rewardTokens,
		},
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_incentive.gno__ApiGetRewardTokens() || json marshal error: %v", err))
	}

	return string(rr)
}
