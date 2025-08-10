package staker

import (
	u256 "gno.land/p/gnoswap/uint256"
)

// Q96
var _q96 = u256.MustFromDecimal("79228162514264337593543950336")

func isAbleToCalculateEmissionReward(prev int64, current int64) bool {
	if prev >= current {
		return false
	}
	return true
}

// Reward is a struct for storing reward for a position.
// Internal reward is the GNS reward, external reward is the reward for other incentives.
// Penalties are the amount that is deducted from the reward due to the position's warmup.
type Reward struct {
	Internal        int64
	InternalPenalty int64
	External        map[string]int64 // Incentive ID -> TokenAmount
	ExternalPenalty map[string]int64 // Incentive ID -> TokenAmount
}

// calculate total position rewards and penalties
func calcPositionReward(currentHeight, currentTimestamp int64, positionId uint64) Reward {
	rewards := calculatePositionReward(CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTimestamp,
		Deposits:      deposits,
		Pools:         pools,
		PoolTier:      poolTier,
		PositionId:    positionId,
	})

	internal := int64(0)
	for _, reward := range rewards {
		internal += reward.Internal
	}

	internalPenalty := int64(0)
	for _, reward := range rewards {
		internalPenalty += reward.InternalPenalty
	}

	externalReward := make(map[string]int64)
	for _, reward := range rewards {
		if reward.External != nil {
			for incentive, reward := range reward.External {
				externalReward[incentive] += reward
			}
		}
	}

	externalPenalty := make(map[string]int64)
	for _, reward := range rewards {
		if reward.ExternalPenalty != nil {
			for incentive, penalty := range reward.ExternalPenalty {
				externalPenalty[incentive] += penalty
			}
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        externalReward,
		ExternalPenalty: externalPenalty,
	}
}

// CalcPositionRewardParam is a struct for calculating position reward
type CalcPositionRewardParam struct {
	// Environmental variables
	CurrentHeight int64
	CurrentTime   int64
	Deposits      *Deposits
	Pools         *Pools
	PoolTier      *PoolTier

	// Position variables
	PositionId uint64
}

func calculatePositionReward(param CalcPositionRewardParam) []Reward {
	// cache per-pool rewards in the internal incentive(tiers)
	param.PoolTier.cacheReward(param.CurrentHeight, param.CurrentTime, param.Pools)

	deposit := param.Deposits.get(param.PositionId)
	poolPath := deposit.targetPoolPath

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = NewPool(poolPath, param.CurrentTime)
		param.Pools.set(poolPath, pool)
	}

	lastCollectTime := deposit.lastCollectTime

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	internalRewards := make([]int64, len(deposit.warmups))
	internalPenalties := make([]int64, len(deposit.warmups))
	externalRewards := make([]map[string]int64, len(deposit.warmups))
	externalPenalties := make([]map[string]int64, len(deposit.warmups))

	if param.PoolTier.CurrentTier(poolPath) != 0 {
		// Internal incentivized pool.
		// Calculate reward for each warmup
		internalRewards, internalPenalties = pool.RewardStateOf(deposit).calculateInternalReward(lastCollectTime, param.CurrentTime)
	}

	// All active incentives
	allIncentives := pool.incentives.GetAllInTimestamps(lastCollectTime, param.CurrentTime)

	for i := range externalRewards {
		externalRewards[i] = make(map[string]int64)
		externalPenalties[i] = make(map[string]int64)
	}

	for incentiveId, incentive := range allIncentives {
		// External incentivized pool.
		// Calculate reward for each warmup
		externalReward, externalPenalty := pool.RewardStateOf(deposit).calculateExternalReward(lastCollectTime, param.CurrentTime, incentive)

		for i := range externalReward {
			externalRewards[i][incentiveId] = externalReward[i]
			externalPenalties[i][incentiveId] = externalPenalty[i]
		}
	}

	rewards := make([]Reward, len(internalRewards))
	for i := range internalRewards {
		rewards[i] = Reward{
			Internal:        internalRewards[i],
			InternalPenalty: internalPenalties[i],
			External:        externalRewards[i],
			ExternalPenalty: externalPenalties[i],
		}
	}

	return rewards
}

// calculates internal unclaimable reward for the pool
func processUnClaimableReward(poolPath string, endTimestamp int64) int64 {
	pool, ok := pools.Get(poolPath)
	if !ok {
		return 0
	}
	return pool.processUnclaimableReward(poolTier, endTimestamp)
}
