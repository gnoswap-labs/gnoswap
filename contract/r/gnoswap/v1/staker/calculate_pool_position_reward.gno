package staker

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
		internal = safeAddInt64(internal, reward.Internal)
	}

	internalPenalty := int64(0)
	for _, reward := range rewards {
		internalPenalty = safeAddInt64(internalPenalty, reward.InternalPenalty)
	}

	externalReward := make(map[string]int64)
	for _, reward := range rewards {
		if reward.External != nil {
			for incentive, reward := range reward.External {
				externalReward[incentive] = safeAddInt64(externalReward[incentive], reward)
			}
		}
	}

	externalPenalty := make(map[string]int64)
	for _, reward := range rewards {
		if reward.ExternalPenalty != nil {
			for incentive, penalty := range reward.ExternalPenalty {
				externalPenalty[incentive] = safeAddInt64(externalPenalty[incentive], penalty)
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

	lastCollectTime := deposit.InternalRewardLastCollectTime()

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

	// Process each external incentive with lazy initialization:
	// When a new incentive is created, we don't iterate through all deposits for performance.
	//
	// Instead, we determine the appropriate lastCollectTime here:
	// - If a deposit already has a lastCollectTime for an incentive, use it
	// - If not (first time collecting), use max(deposit.stakeTime, incentive.startTimestamp)
	//
	// This avoids O(n) iteration on every incentive creation while ensuring correct reward calculation.
	for incentiveId, incentive := range allIncentives {
		externalLastCollectTime := deposit.ExternalRewardLastCollectTime(incentiveId)

		// Check if incentive is active during this specific collection period
		if !incentive.IsStarted(param.CurrentTime) || incentive.startTimestamp >= param.CurrentTime {
			continue
		}

		// External incentivized pool.
		// Calculate reward for each warmup using per-incentive lastCollectTime
		externalReward, externalPenalty := pool.RewardStateOf(deposit).calculateExternalReward(externalLastCollectTime, param.CurrentTime, incentive)

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

// getInitialCollectTime determines the initial collection time for an incentive
// by taking the maximum of the deposit's stake time and the incentive's start time.
// This ensures rewards are only calculated from when both conditions are met:
// - The position must be staked (deposit.stakeTime)
// - The incentive must be active (incentive.startTimestamp)
//
// This function is used for lazy initialization when a position collects
// from an incentive for the first time, avoiding the need to iterate through
// all deposits when a new incentive is created.
func getInitialCollectTime(deposit *Deposit, incentive *ExternalIncentive) int64 {
	if deposit.stakeTime > incentive.startTimestamp {
		return deposit.stakeTime
	}
	return incentive.startTimestamp
}
