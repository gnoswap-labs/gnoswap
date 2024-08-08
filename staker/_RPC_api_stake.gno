package staker

import (
	"std"
	"time"

	"gno.land/p/demo/json"
	"gno.land/p/demo/ufmt"

	"gno.land/r/gnoswap/v2/consts"

	en "gno.land/r/gnoswap/v2/emission"
)

// LpTokenReward represents the rewards associated with a specific LP token
type LpTokenReward struct {
	LpTokenId uint64   `json:"lpTokenId"` // The ID of the LP token
	Address   string   `json:"address"`   // The address associated with the LP token
	Rewards   []Reward `json:"rewards"`
}

// Reward represents a single reward for a staked LP token
type Reward struct {
	IncentiveType     string `json:"incentiveType"`     // The type of incentive (INTERNAL or EXTERNAL)
	IncentiveId       string `json:"incentiveId"`       // The unique identifier of the incentive
	TargetPoolPath    string `json:"targetPoolPath"`    // The path of the target pool for the reward
	RewardTokenPath   string `json:"rewardTokenPath"`   // The pathe of the reward token
	RewardTokenAmount uint64 `json:"rewardTokenAmount"` // The amount of the reward token
	StakeTimestamp    int64  `json:"stakeTimestamp"`    // The timestamp when the LP token was staked
	StakeHeight       int64  `json:"stakeHeight"`       // The block height when the LP token was staked
	IncentiveStart    int64  `json:"incentiveStart"`    // The timestamp when the incentive started
}

// Stake represents a single stake
type Stake struct {
	TokenId        uint64      `json:"tokenId"`        // The ID of the staked LP token
	Owner          std.Address `json:"owner"`          // The address of the owner of the staked LP token
	NumberOfStakes uint64      `json:"numberOfStakes"` // The number of times this LP token has been staked
	StakeTimestamp int64       `json:"stakeTimestamp"` // The timestamp when the LP token was staked
	StakeHeight    int64       `json:"stakeHeight"`    // The block height when the LP token was staked
	TargetPoolPath string      `json:"targetPoolPath"` // The path of the target pool for the stake
}

// ResponseQueryBase contains basic information about a query response.
type ResponseQueryBase struct {
	Height    int64 `json:"height"`    // The block height at the time of the query
	Timestamp int64 `json:"timestamp"` // The timestamp at the time of the query
}

// ResponseApiGetRewards represents the API response for getting rewards.
type ResponseApiGetRewards struct {
	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
	Response []LpTokenReward   `json:"response"` // A slice of LpTokenReward structs
}

// ResponseApiGetRewardByLpTokenId represents the API response for getting rewards for a specific LP token.
type ResponseApiGetRewardByLpTokenId struct {
	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
	Response LpTokenReward     `json:"response"` // The LpTokenReward for the specified LP token
}

// ResponseApiGetStakes represents the API response for getting stakes.
type ResponseApiGetStakes struct {
	Stat     ResponseQueryBase `json:"stat"`     // Basic query information
	Response []Stake           `json:"response"` // A slice of Stake structs
}

func ApiGetRewards() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	lpTokenRewards := []LpTokenReward{}

	for tokenId, deposit := range deposits {
		rewards := []Reward{}

		// get internal gns reward
		_, internalGNS := rewardMathComputeInternalRewardAmount(tokenId)
		if internalGNS > 0 {
			rewards = append(rewards, Reward{
				IncentiveType:     "INTERNAL",
				IncentiveId:       "",
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   consts.GNS_PATH,
				RewardTokenAmount: internalGNS,
				StakeTimestamp:    deposit.stakeTimestamp,
				StakeHeight:       deposit.stakeHeight,
				IncentiveStart:    deposit.stakeTimestamp,
			})
		}

		// find all external reward list for poolPath which lpTokenId is staked
		for _, incentiveId := range poolIncentives[deposit.targetPoolPath] {
			incentive := incentives[incentiveId]

			stakedOrCreatedAt := max(deposit.stakeTimestamp, incentive.startTimestamp)
			now := time.Now().Unix()
			if now < stakedOrCreatedAt {
				continue
			}

			_, externalReward := rewardMathComputeExternalRewardAmount(tokenId, incentiveId)
			if externalReward >= 0 {
				rewards = append(rewards, Reward{
					IncentiveType:     "EXTERNAL",
					IncentiveId:       incentiveId,
					TargetPoolPath:    deposit.targetPoolPath,
					RewardTokenPath:   incentives[incentiveId].rewardToken,
					RewardTokenAmount: externalReward,
					StakeTimestamp:    deposit.stakeTimestamp,
					StakeHeight:       deposit.stakeHeight,
					IncentiveStart:    incentive.startTimestamp,
				})
			}
		}

		if len(rewards) > 0 {
			lpTokenReward := LpTokenReward{
				LpTokenId: tokenId,
				Address:   deposit.owner.String(),
				Rewards:   rewards,
			}
			lpTokenRewards = append(lpTokenRewards, lpTokenReward)
		}
	}

	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetRewards{
		Stat:     qb,
		Response: lpTokenRewards,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, reward := range r.Response {
		_rewardNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
			"address":   json.StringNode("address", reward.Address),
			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
		})
		responses.AppendArray(_rewardNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewards() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	lpTokenRewards := []LpTokenReward{}

	for tokenId, deposit := range deposits {
		if tokenId != targetLpTokenId {
			continue
		}

		rewards := []Reward{}

		// get internal gns reward
		_, internalGNS := rewardMathComputeInternalRewardAmount(tokenId)
		if internalGNS > 0 {
			rewards = append(rewards, Reward{
				IncentiveType:     "INTERNAL",
				IncentiveId:       "",
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   consts.GNS_PATH,
				RewardTokenAmount: internalGNS,
				StakeTimestamp:    deposit.stakeTimestamp,
				StakeHeight:       deposit.stakeHeight,
				IncentiveStart:    deposit.stakeTimestamp,
			})
		}

		// find all external reward list for poolPath which lpTokenId is staked
		for _, incentiveId := range poolIncentives[deposit.targetPoolPath] {
			incentive := incentives[incentiveId]

			stakedOrCreatedAt := max(deposit.stakeTimestamp, incentive.startTimestamp)
			now := time.Now().Unix()
			if now < stakedOrCreatedAt {
				continue
			}

			_, externalReward := rewardMathComputeExternalRewardAmount(tokenId, incentiveId)
			if externalReward > 0 {
				rewards = append(rewards, Reward{
					IncentiveType:     "EXTERNAL",
					IncentiveId:       incentiveId,
					TargetPoolPath:    deposit.targetPoolPath,
					RewardTokenPath:   incentives[incentiveId].rewardToken,
					RewardTokenAmount: externalReward,
					StakeTimestamp:    deposit.stakeTimestamp,
					StakeHeight:       deposit.stakeHeight,
					IncentiveStart:    incentive.startTimestamp,
				})
			}
		}

		lpTokenReward := LpTokenReward{
			LpTokenId: tokenId,
			Address:   deposit.owner.String(),
			Rewards:   rewards,
		}
		lpTokenRewards = append(lpTokenRewards, lpTokenReward)
	}

	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetRewards{
		Stat:     qb,
		Response: lpTokenRewards,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, reward := range r.Response {
		_rewardNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
			"address":   json.StringNode("address", reward.Address),
			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
		})
		responses.AppendArray(_rewardNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardsByLpTokenId() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetRewardsByAddress(targetAddress string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	lpTokenRewards := []LpTokenReward{}

	for tokenId, deposit := range deposits {
		if deposit.owner.String() != targetAddress {
			continue
		}

		rewards := []Reward{}

		// get internal gns reward
		_, internalGNS := rewardMathComputeInternalRewardAmount(tokenId)
		if internalGNS > 0 {
			rewards = append(rewards, Reward{
				IncentiveType:     "INTERNAL",
				IncentiveId:       "",
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   consts.GNS_PATH,
				RewardTokenAmount: internalGNS,
				StakeTimestamp:    deposit.stakeTimestamp,
				StakeHeight:       deposit.stakeHeight,
				IncentiveStart:    deposit.stakeTimestamp,
			})
		}

		// find all external reward list for poolPath which lpTokenId is staked
		for _, incentiveId := range poolIncentives[deposit.targetPoolPath] {
			incentive := incentives[incentiveId]

			stakedOrCreatedAt := max(deposit.stakeTimestamp, incentive.startTimestamp)
			now := time.Now().Unix()
			if now < stakedOrCreatedAt {
				continue
			}

			_, externalReward := rewardMathComputeExternalRewardAmount(tokenId, incentiveId)
			rewards = append(rewards, Reward{
				IncentiveType:     "EXTERNAL",
				IncentiveId:       incentiveId,
				TargetPoolPath:    deposit.targetPoolPath,
				RewardTokenPath:   incentives[incentiveId].rewardToken,
				RewardTokenAmount: externalReward,
				StakeTimestamp:    deposit.stakeTimestamp,
				StakeHeight:       deposit.stakeHeight,
				IncentiveStart:    incentive.startTimestamp,
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
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetRewards{
		Stat:     qb,
		Response: lpTokenRewards,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, reward := range r.Response {
		_rewardNode := json.ObjectNode("", map[string]*json.Node{
			"lpTokenId": json.NumberNode("lpTokenId", float64(reward.LpTokenId)),
			"address":   json.StringNode("address", reward.Address),
			"rewards":   json.ArrayNode("rewards", makeRewardsArray(reward.Rewards)),
		})
		responses.AppendArray(_rewardNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetRewardsByAddress() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetStakes() string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

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
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetStakes{
		Stat:     qb,
		Response: stakes,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, stake := range r.Response {
		_stakeNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
			"owner":          json.StringNode("owner", stake.Owner.String()),
			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
		})
		responses.AppendArray(_stakeNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetStakes() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	stakes := []Stake{}

	for tokenId, deposit := range deposits {
		if tokenId != targetLpTokenId {
			continue
		}

		stakes = append(stakes, Stake{
			TokenId:        tokenId,
			Owner:          deposit.owner,
			NumberOfStakes: deposit.numberOfStakes,
			StakeTimestamp: deposit.stakeTimestamp,
			TargetPoolPath: deposit.targetPoolPath,
		})
	}

	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetStakes{
		Stat:     qb,
		Response: stakes,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, stake := range r.Response {
		_stakeNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
			"owner":          json.StringNode("owner", stake.Owner.String()),
			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
		})
		responses.AppendArray(_stakeNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetStakes() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

func ApiGetStakesByAddress(targetAddress string) string {
	en.MintAndDistributeGns()
	CalcPoolPosition()

	stakes := []Stake{}

	for tokenId, deposit := range deposits {
		if deposit.owner.String() != targetAddress {
			continue
		}

		stakes = append(stakes, Stake{
			TokenId:        tokenId,
			Owner:          deposit.owner,
			NumberOfStakes: deposit.numberOfStakes,
			StakeTimestamp: deposit.stakeTimestamp,
			TargetPoolPath: deposit.targetPoolPath,
		})
	}

	qb := ResponseQueryBase{
		Height:    std.GetHeight(),
		Timestamp: time.Now().Unix(),
	}

	r := ResponseApiGetStakes{
		Stat:     qb,
		Response: stakes,
	}

	// STAT NODE
	_stat := json.ObjectNode("", map[string]*json.Node{
		"height":    json.NumberNode("height", float64(std.GetHeight())),
		"timestamp": json.NumberNode("timestamp", float64(time.Now().Unix())),
	})

	// RESPONSE (ARRAY) NODE
	responses := json.ArrayNode("", []*json.Node{})
	for _, stake := range r.Response {
		_stakeNode := json.ObjectNode("", map[string]*json.Node{
			"tokenId":        json.NumberNode("tokenId", float64(stake.TokenId)),
			"owner":          json.StringNode("owner", stake.Owner.String()),
			"numberOfStakes": json.NumberNode("numberOfStakes", float64(stake.NumberOfStakes)),
			"stakeTimestamp": json.NumberNode("stakeTimestamp", float64(stake.StakeTimestamp)),
			"targetPoolPath": json.StringNode("targetPoolPath", stake.TargetPoolPath),
		})
		responses.AppendArray(_stakeNode)
	}

	node := json.ObjectNode("", map[string]*json.Node{
		"stat":     _stat,
		"response": responses,
	})

	b, err := json.Marshal(node)
	if err != nil {
		panic(ufmt.Sprintf("[STAKER] _RPC_api_stake.gno__ApiGetStakes() || json marshal error: %s", err.Error()))
	}

	return string(b)
}

// for off chain to check if lpTokenId is staked via RPC
func IsStaked(tokenId uint64) bool {
	_, exist := deposits[tokenId]
	return exist
}

func makeRewardsArray(rewards []Reward) []*json.Node {
	rewardsArray := make([]*json.Node, len(rewards))

	for i, reward := range rewards {
		rewardsArray[i] = json.ObjectNode("", map[string]*json.Node{
			"incentiveType":     json.StringNode("incentiveType", reward.IncentiveType),
			"incentiveId":       json.StringNode("incentiveId", reward.IncentiveId),
			"targetPoolPath":    json.StringNode("targetPoolPath", reward.TargetPoolPath),
			"rewardTokenPath":   json.StringNode("rewardTokenPath", reward.RewardTokenPath),
			"rewardTokenAmount": json.NumberNode("rewardTokenAmount", float64(reward.RewardTokenAmount)),
			"stakeTimestamp":    json.NumberNode("stakeTimestamp", float64(reward.StakeTimestamp)),
			"stakeHeight":       json.NumberNode("stakeHeight", float64(reward.StakeHeight)),
			"incentiveStart":    json.NumberNode("incentiveStart", float64(reward.IncentiveStart)),
		})
	}
	return rewardsArray
}
