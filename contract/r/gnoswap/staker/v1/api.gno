package v1

import (
	"chain/runtime"
	"strconv"
	"time"

	"gno.land/p/nt/ufmt"
	"gno.land/p/onbloc/json"
	sr "gno.land/r/gnoswap/staker"
)

// ApiGetRewardTokensByPoolPath returns all reward tokens for a specific pool.
func (s *stakerV1) ApiGetRewardTokensByPoolPath(targetPoolPath string) string {
	rewardTokens := []RewardToken{}

	pool, ok := s.getPools().Get(targetPoolPath)
	if !ok {
		return ""
	}

	poolResolver := NewPoolResolver(pool)

	thisPoolRewardTokens := []string{}

	poolTier := s.getPoolTier()

	// HANDLE INTERNAL
	if poolTier.IsInternallyIncentivizedPool(pool.PoolPath()) {
		thisPoolRewardTokens = append(thisPoolRewardTokens, GNS_PATH)
	}

	currentTime := time.Now().Unix()
	poolResolver.IncentivesResolver().IncentiveTrees().Iterate("", "", func(key string, value any) bool {
		ictv, ok := value.(*sr.ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}

		// Check if incentive is active and has a reward token
		incentiveResolver := NewExternalIncentiveResolver(ictv)
		if incentiveResolver.isActive(currentTime) && ictv.RewardToken() != "" {
			thisPoolRewardTokens = append(thisPoolRewardTokens, ictv.RewardToken())
		}
		return false
	})

	rt := newRewardToken(pool.PoolPath(), thisPoolRewardTokens)
	rewardTokens = append(rewardTokens, rt)

	rsps := make([]JsonResponse, len(rewardTokens))
	for i := range rewardTokens {
		rsps[i] = rewardTokens[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetExternalIncentives returns all external incentives across all pools.
func (s *stakerV1) ApiGetExternalIncentives() string {
	apiExternalIncentives := []ApiExternalIncentive{}

	s.getPools().tree.Iterate("", "", func(key string, value any) bool {
		pool, ok := value.(*sr.Pool)
		if !ok {
			panic("failed to cast value to *Pool")
		}
		poolResolver := NewPoolResolver(pool)
		poolResolver.IncentivesResolver().IncentiveTrees().Iterate("", "", func(key string, value any) bool {
			ictv, ok := value.(*sr.ExternalIncentive)
			if !ok {
				panic("failed to cast value to *ExternalIncentive")
			}
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
func (s *stakerV1) ApiGetExternalIncentiveById(poolPath, incentiveId string) string {
	apiExternalIncentives := []ApiExternalIncentive{}

	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) not found", poolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	incentive, exist := poolResolver.IncentivesResolver().Get(incentiveId)
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
func (s *stakerV1) ApiGetExternalIncentivesByPoolPath(targetPoolPath string) string {
	apiExternalIncentives := []ApiExternalIncentive{}

	pool, ok := s.getPools().Get(targetPoolPath)
	if !ok {
		panic(makeErrorWithDetails(
			errDataNotFound,
			ufmt.Sprintf("pool(%s) not found", targetPoolPath),
		))
	}

	poolResolver := NewPoolResolver(pool)
	poolResolver.IncentivesResolver().IncentiveTrees().Iterate("", "", func(key string, value any) bool {
		incentive, ok := value.(*sr.ExternalIncentive)
		if !ok {
			panic("failed to cast value to *ExternalIncentive")
		}
		if incentive.TargetPoolPath() != targetPoolPath {
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
func (s *stakerV1) ApiGetInternalIncentives() string {
	apiInternalIncentives := []ApiInternalIncentive{}

	s.getPoolTier().membership.Iterate("", "", func(key string, value any) bool {
		poolPath := key
		internalTier, ok := value.(uint64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to uint64: %T", value))
		}
		internalIctv := newApiInternalIncentive(s, poolPath, internalTier)
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
func (s *stakerV1) ApiGetInternalIncentivesByPoolPath(targetPoolPath string) string {
	apiInternalIncentives := []ApiInternalIncentive{}

	tier := s.getPoolTier().CurrentTier(targetPoolPath)
	if tier == 0 {
		return ""
	}

	internalIctv := newApiInternalIncentive(s, targetPoolPath, tier)
	apiInternalIncentives = append(apiInternalIncentives, internalIctv)

	rsps := make([]JsonResponse, len(apiInternalIncentives))
	for i := range apiInternalIncentives {
		rsps[i] = apiInternalIncentives[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetInternalIncentivesByTiers returns all internal incentives for a specific tier.
func (s *stakerV1) ApiGetInternalIncentivesByTiers(targetTier uint64) string {
	apiInternalIncentives := []ApiInternalIncentive{}

	s.getPoolTier().membership.Iterate("", "", func(key string, value any) bool {
		poolPath := key
		internalTier, ok := value.(uint64)
		if !ok {
			panic("failed to cast value to uint64")
		}
		if internalTier != targetTier {
			return false
		}

		internalIctv := newApiInternalIncentive(s, poolPath, internalTier)
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
func (s *stakerV1) calculateInternalRewardPerSecondByPoolPath(poolPath string) string {
	reward := s.getPoolTier().CurrentRewardPerPool(poolPath)
	return strconv.FormatInt(reward, 10)
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
func (s *stakerV1) ApiGetRewardsByLpTokenId(targetLpTokenId uint64) string {
	deposit := s.getDeposits().get(targetLpTokenId)

	reward := s.calcPositionReward(runtime.ChainHeight(), time.Now().Unix(), targetLpTokenId)

	rewards := []ApiReward{}

	if reward.Internal > 0 {
		rewards = append(rewards, ApiReward{
			IncentiveType:     "INTERNAL",
			IncentiveId:       "",
			TargetPoolPath:    deposit.TargetPoolPath(),
			RewardTokenPath:   GNS_PATH,
			RewardTokenAmount: reward.Internal,
			StakeTimestamp:    deposit.StakeTime(),
			StakeTime:         deposit.StakeTime(),
			IncentiveStart:    deposit.StakeTime(),
		})
	}

	for incentiveId, externalReward := range reward.External {
		if externalReward == 0 {
			continue
		}
		incentive := s.getExternalIncentives().get(incentiveId)
		if incentive == nil {
			// Incentive may have been archived/removed; skip to keep response construction robust.
			continue
		}
		rewards = append(rewards, ApiReward{
			IncentiveType:     "EXTERNAL",
			IncentiveId:       incentiveId,
			TargetPoolPath:    incentive.TargetPoolPath(),
			RewardTokenPath:   incentive.RewardToken(),
			RewardTokenAmount: externalReward,
			StakeTimestamp:    deposit.StakeTime(),
			StakeTime:         deposit.StakeTime(),
			IncentiveStart:    incentive.StartTimestamp(),
		})
	}

	rsps := make([]JsonResponse, len(rewards))
	for i := range rewards {
		rsps[i] = rewards[i]
	}

	return makeApiResponse(rsps)
}

// ApiGetStakesByLpTokenId returns stake information for a specific LP token ID.
func (s *stakerV1) ApiGetStakesByLpTokenId(targetLpTokenId uint64) string {
	stakes := []ApiStake{}

	deposit := s.getDeposits().get(targetLpTokenId)
	stk := newApiStake(targetLpTokenId, deposit)
	stakes = append(stakes, stk)

	rsps := make([]JsonResponse, len(stakes))
	for i := range stakes {
		rsps[i] = stakes[i]
	}

	return makeApiResponse(rsps)
}

// IsStaked checks if a position ID is currently staked.
func (s *stakerV1) IsStaked(positionId uint64) bool {
	return s.getDeposits().Has(positionId)
}

// formatInt formats an int64 value to string.
func formatInt(value int64) string {
	return strconv.FormatInt(value, 10)
}
