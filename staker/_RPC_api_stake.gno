package staker

import (
	"encoding/json"
	"std"

	"gno.land/p/demo/ufmt"
)

type LpTokenReward struct {
	LpTokenId uint64   `json:"lpTokenId"`
	Address   string   `json:"address"`
	Rewards   []Reward `json:"rewards"`
}

type Reward struct {
	IncentiveType     string `json:"incentiveType"`
	TargetPoolPath    string `json:"targetPoolPath"`
	RewardTokenPath   string `json:"rewardTokenPath"`
	RewardTokenAmount bigint `json:"rewardTokenAmount"`
}

type Stake struct {
	TokenId        uint64      `json:"tokenId"`
	Owner          std.Address `json:"owner"`
	NumberOfStakes uint64      `json:"numberOfStakes"`
	StakeTimestamp int64       `json:"stakeTimestamp"`
	TargetPoolPath string      `json:"targetPoolPath"`
}

type ResponseQueryBase struct {
	Height    int64 `json:"height"`
	Timestamp int64 `json:"timestamp"`
}

type ResponseApiGetRewards struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []LpTokenReward   `json:"response"`
}

type ResponseApiGetRewardByLpTokenId struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response LpTokenReward     `json:"response"`
}

type ResponseApiGetStakes struct {
	Stat     ResponseQueryBase `json:"stat"`
	Response []Stake           `json:"response"`
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

	qb := ResponseQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetRewards{
		Stat:     qb,
		Response: lpTokenRewards,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewards() || json marshal error: %v", err))
	}

	return string(rr)
}

func ApiGetRewardByLpTokenId(lpTokenId uint64) string {
	deposit, exist := deposits[lpTokenId]
	require(exist, ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardByLpTokenId() || lpTokenId(%d) deposit does not exist", lpTokenId))

	rewards := []Reward{}

	// get internal gns reward
	internalGNS := rewardMathComputeInternalRewardAmount(lpTokenId, deposit)
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
		externalReward := rewardMathComputeExternalRewardAmount(lpTokenId, deposit, incentives[incentiveId])
		rewards = append(rewards, Reward{
			IncentiveType:     "EXTERNAL",
			TargetPoolPath:    deposit.targetPoolPath,
			RewardTokenPath:   incentives[incentiveId].rewardToken,
			RewardTokenAmount: externalReward,
		})
	}

	lpTokenReward := LpTokenReward{
		LpTokenId: lpTokenId,
		Address:   deposit.owner.String(),
		Rewards:   rewards,
	}

	qb := ResponseQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetRewardByLpTokenId{
		Stat:     qb,
		Response: lpTokenReward,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardByLpTokenId() || json marshal error: %v", err))
	}

	return string(rr)
}

func ApiGetStakes() string {
	stakes := []Stake{}
	for tokenId, deposit := range deposits {
		stakes = append(stakes, Stake{
			TokenId:        tokenId,
			Owner:          deposit.owner,
			NumberOfStakes: deposit.numberOfStakes,
			StakeTimestamp: deposit.stakeTimestamp,
			TargetPoolPath: deposit.targetPoolPath,
		})
	}

	qb := ResponseQueryBase{
		Height:    GetHeight(),
		Timestamp: int64(GetTimestamp()),
	}

	r := ResponseApiGetStakes{
		Stat:     qb,
		Response: stakes,
	}

	rr, err := json.Marshal(r)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetStakes() || json marshal error: %v", err))
	}

	return string(rr)
}

// for off chain to check if lpTokenId is staked via RPC
func IsStaked(tokenId uint64) bool {
	_, exist := deposits[tokenId]
	return exist
}
