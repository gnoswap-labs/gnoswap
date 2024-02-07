package staker

import (
	"encoding/json"

	pl "gno.land/r/demo/pool"

	"gno.land/p/demo/ufmt"
)

const INTERNAL_REWARD_TOKEN_PATH = "gno.land/r/demo/gns"

type RewardToken struct {
	PoolPath         string   `json:"poolPath"`
	RewardsTokenList []string `json:"rewardsTokenList"`
}

type ResponseRewardTokens struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []RewardToken     `json:"response"`
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
	qb := ResponseQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseRewardTokens{
		Stat:     qb,
		Response: rewardTokens,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_incentive.gno__ApiGetRewardTokens() || json marshal error: %v", err))
	}

	return string(rr)
}
