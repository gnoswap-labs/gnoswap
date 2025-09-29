package staker

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
	warmups := len(deposit.warmups)
	internalRewards := make([]int64, warmups)
	internalPenalties := make([]int64, warmups)
	externalRewards := make([]map[string]int64, warmups)
	externalPenalties := make([]map[string]int64, warmups)

	// Calculate internal rewards regardless of current tier status
	// The reward cache system will automatically handle periods with 0 rewards
	// This allows collecting rewards earned while the pool was in a tier,
	// while preventing new rewards after tier removal
	internalRewards, internalPenalties = pool.RewardStateOf(deposit).calculateInternalReward(lastCollectTime, param.CurrentTime)

	// Initialize maps for external rewards
	for i := range externalRewards {
		externalRewards[i] = make(map[string]int64)
		externalPenalties[i] = make(map[string]int64)
	}

	// Get all incentives using a wide time range to ensure we get all possible incentives
	// We'll filter them individually based on their specific lastCollectTime
	allIncentives := pool.incentives.GetAllInTimestamps(0, param.CurrentTime*2)

	for incentiveId, incentive := range allIncentives {
		// Use per-incentive lastCollectTime if available, otherwise use the general lastCollectTime
		incentiveLastCollectTime := lastCollectTime
		if deposit.externalLastCollectTimes != nil {
			if specificTime, exists := deposit.externalLastCollectTimes[incentiveId]; exists {
				incentiveLastCollectTime = specificTime
			}
		}

		// Skip if incentive hasn't started yet or if we've already collected up to current time
		if incentiveLastCollectTime >= param.CurrentTime {
			continue
		}

		// Only process incentives that were active during the collection period
		if incentive.endTimestamp <= incentiveLastCollectTime {
			continue
		}

		// Check if incentive is active during this specific collection period
		if !incentive.IsStarted(param.CurrentTime) || incentive.startTimestamp >= param.CurrentTime {
			continue
		}

		// External incentivized pool.
		// Calculate reward for each warmup using per-incentive lastCollectTime
		externalReward, externalPenalty := pool.RewardStateOf(deposit).calculateExternalReward(incentiveLastCollectTime, param.CurrentTime, incentive)

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
