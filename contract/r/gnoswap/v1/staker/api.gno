package staker

import (
	"std"
	"time"

	"gno.land/p/onbloc/json"
	"gno.land/p/nt/ufmt"
)

// ApiGetRewardTokensByPoolPath returns all reward tokens for a specific pool.
func ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	rewardTokens := []RewardToken{}

	pool, ok := pools.Get(targetPoolPath)
	if !ok {
		return ""
	}

	thisPoolRewardTokens := []string{}

	// HANDLE INTERNAL
	if poolTier.IsInternallyIncentivizedPool(pool.poolPath) {
		thisPoolRewardTokens = append(thisPoolRewardTokens, GNS_PATH)
	}

	// HANDLE EXTERNAL
	if pool.IsExternallyIncentivizedPool() {
		pool.incentives.incentives.Iterate("", "", func(key string, value any) bool {
			ictv := value.(*ExternalIncentive)
			if ictv.RewardToken() == "" {
				return false
			}
			thisPoolRewardTokens = append(thisPoolRewardTokens, ictv.RewardToken())
			return false
		})
	}

	rt := newRewardToken(pool.poolPath, thisPoolRewardTokens)
	rewardTokens = append(rewardTokens, rt)

	rsps := make([]JsonResponse, len(rewardTokens))
	for i := range rewardTokens {
		rsps[i] = rewardTokens[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetExternalIncentives returns all external incentives across all pools.
func ApiGetExternalIncentives() string {
	apiExternalIncentives := []ApiExternalIncentive{}

	pools.tree.Iterate("", "", func(key string, value any) bool {
		pool := value.(*Pool)
		pool.incentives.incentives.Iterate("", "", func(key string, value any) bool {
			ictv := value.(*ExternalIncentive)
			externalIctv := newApiExternalIncentive(ictv)
			apiExternalIncentives = append(apiExternalIncentives, externalIctv)
			return false
		})
		return false
	})

	rsps := make([]JsonResponse, len(apiExternalIncentives))
	for i := range apiExternalIncentives {
		rsps[i] = apiExternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetExternalIncentiveById returns a specific external incentive by pool path and incentive ID.
func ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	apiExternalIncentives := []ApiExternalIncentive{}

	pool, ok := pools.Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) not found", poolPath),
		))
	}

	incentive, exist := pool.incentives.GetByIncentiveId(incentiveId)
	if !exist {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("incentive(%s) not found", incentiveId),
		))
	}

	externalictv := newApiExternalIncentive(incentive)
	apiExternalIncentives = append(apiExternalIncentives, externalictv)

	rsps := make([]JsonResponse, len(apiExternalIncentives))
	for i := range apiExternalIncentives {
		rsps[i] = apiExternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetExternalIncentivesByPoolPath returns all external incentives for a specific pool.
func ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	apiExternalIncentives := []ApiExternalIncentive{}

	pool, ok := pools.Get(targetPoolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) not found", targetPoolPath),
		))
	}

	pool.incentives.incentives.Iterate("", "", func(key string, value any) bool {
		incentive, ok := value.(*ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}
		if incentive.targetPoolPath != targetPoolPath {
			return false
		}

		externalIctv := newApiExternalIncentive(incentive)
		apiExternalIncentives = append(apiExternalIncentives, externalIctv)

		return false
	})

	rsps := make([]JsonResponse, len(apiExternalIncentives))
	for i := range apiExternalIncentives {
		rsps[i] = apiExternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetInternalIncentives returns all internal incentives across all pools.
func ApiGetInternalIncentives() string {
	apiInternalIncentives := []ApiInternalIncentive{}

	poolTier.membership.Iterate("", "", func(key string, value any) bool {
		poolPath := key
		internalTier, ok := value.(uint64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to uint64: %T", value))
		}
		internalIctv := newApiInternalIncentive(poolPath, internalTier)
		apiInternalIncentives = append(apiInternalIncentives, internalIctv)
		return false
	})

	rsps := make([]JsonResponse, len(apiInternalIncentives))
	for i := range apiInternalIncentives {
		rsps[i] = apiInternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetInternalIncentivesByPoolPath returns internal incentives for a specific pool.
func ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	apiInternalIncentives := []ApiInternalIncentive{}

	tier := poolTier.CurrentTier(targetPoolPath)
	if tier == 0 {
		return ""
	}

	internalIctv := newApiInternalIncentive(targetPoolPath, tier)
	apiInternalIncentives = append(apiInternalIncentives, internalIctv)

	rsps := make([]JsonResponse, len(apiInternalIncentives))
	for i := range apiInternalIncentives {
		rsps[i] = apiInternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetInternalIncentivesByTiers returns all internal incentives for a specific tier.
func ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	apiInternalIncentives := []ApiInternalIncentive{}

	poolTier.membership.Iterate("", "", func(key string, value any) bool {
		poolPath := key
		internalTier := value.(uint64)
		if internalTier != targetTier {
			return false
		}

		internalIctv := newApiInternalIncentive(poolPath, internalTier)
		apiInternalIncentives = append(apiInternalIncentives, internalIctv)

		return false
	})

	rsps := make([]JsonResponse, len(apiInternalIncentives))
	for i := range apiInternalIncentives {
		rsps[i] = apiInternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// makeRewardTokensArray creates a JSON array of reward tokens.
func makeRewardTokensArray(rewardsTokenList []string) []*json.Node {
	rewardsTokenArray := make([]*json.Node, len(rewardsTokenList))
	for i, rewardToken := range rewardsTokenList {
		rewardsTokenArray[i] = json.StringNode("", rewardToken)
	}
	return rewardsTokenArray
}

// calculateInternalRewardPerSecondByPoolPath calculates the internal reward per second for a pool.
func calculateInternalRewardPerSecondByPoolPath(poolPath string) string {
	reward := poolTier.CurrentRewardPerPool(poolPath)
	return ufmt.Sprintf("%d", reward)
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

// ApiGetRewardsByLpTokenId returns all rewards for a specific LP token ID.
func ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	deposit := deposits.get(targetLpTokenId)

	reward := calcPositionReward(std.ChainHeight(), time.Now().Unix(), targetLpTokenId)

	rewards := []ApiReward{}

	if reward.Internal > 0 {
		rewards = append(rewards, ApiReward{
			IncentiveType:     "INTERNAL",
			IncentiveId:       "",
			TargetPoolPath:    deposit.targetPoolPath,
			RewardTokenPath:   GNS_PATH,
			RewardTokenAmount: reward.Internal,
			StakeTimestamp:    deposit.stakeTimestamp,
			StakeTime:         deposit.stakeTime,
			IncentiveStart:    deposit.stakeTimestamp,
		})
	}

	for incentiveId, externalReward := range reward.External {
		if externalReward == 0 {
			continue
		}
		incentive := externalIncentives.get(incentiveId)
		rewards = append(rewards, ApiReward{
			IncentiveType:     "EXTERNAL",
			IncentiveId:       incentiveId,
			TargetPoolPath:    incentive.targetPoolPath,
			RewardTokenPath:   incentive.rewardToken,
			RewardTokenAmount: externalReward,
			StakeTimestamp:    deposit.stakeTimestamp,
			StakeTime:         deposit.stakeTime,
			IncentiveStart:    incentive.startTimestamp,
		})
	}

	rsps := make([]JsonResponse, len(rewards))
	for i := range rewards {
		rsps[i] = rewards[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetStakesByLpTokenId returns stake information for a specific LP token ID.
func ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	stakes := []ApiStake{}

	deposit := deposits.get(targetLpTokenId)
	stk := newApiStake(targetLpTokenId, deposit)
	stakes = append(stakes, stk)

	rsps := make([]JsonResponse, len(stakes))
	for i := range stakes {
		rsps[i] = stakes[i]
	}

	return makeApiResponse(rsps)
}

// IsStaked checks if a position ID is currently staked.
func IsStaked(positionId uint64) bool {
	return deposits.Has(positionId)
}

// formatInt formats an int64 value to string.
func formatInt(value int64) string {
	return ufmt.Sprintf("%d", value)
}
