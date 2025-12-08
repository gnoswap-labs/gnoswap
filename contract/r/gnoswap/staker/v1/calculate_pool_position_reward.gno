package v1

import sr "gno.land/r/gnoswap/staker"

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
func (s *stakerV1) calcPositionReward(currentHeight, currentTimestamp int64, positionId uint64) Reward {
	rewards := s.calculatePositionReward(&CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTimestamp,
		Deposits:      s.getDeposits(),
		Pools:         s.getPools(),
		PoolTier:      s.getPoolTier(),
		PositionId:    positionId,
	})

	internal := int64(0)
	internalPenalty := int64(0)
	externalReward := make(map[string]int64, len(rewards))
	externalPenalty := make(map[string]int64, len(rewards))

	for _, reward := range rewards {
		internal = safeAddInt64(internal, reward.Internal)
		internalPenalty = safeAddInt64(internalPenalty, reward.InternalPenalty)

		for incentive, amount := range reward.External {
			externalReward[incentive] = safeAddInt64(externalReward[incentive], amount)
		}

		for incentive, penalty := range reward.ExternalPenalty {
			externalPenalty[incentive] = safeAddInt64(externalPenalty[incentive], penalty)
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

func (s *stakerV1) calculatePositionReward(param *CalcPositionRewardParam) []Reward {
	// cache per-pool rewards in the internal incentive(tiers)
	param.PoolTier.cacheReward(param.CurrentHeight, param.CurrentTime, param.Pools)
	s.updatePoolTier(param.PoolTier)

	deposit := param.Deposits.get(param.PositionId)
	depositResolver := NewDepositResolver(deposit)
	poolPath := deposit.TargetPoolPath()

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = sr.NewPool(poolPath, param.CurrentTime)
		param.Pools.set(poolPath, pool)
	}
	poolResolver := NewPoolResolver(pool)

	lastCollectTime := depositResolver.InternalRewardLastCollectTime()

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	warmups := len(deposit.Warmups())
	internalRewards := make([]int64, warmups)
	internalPenalties := make([]int64, warmups)
	externalRewards := make([]map[string]int64, warmups)
	externalPenalties := make([]map[string]int64, warmups)
	rewardState := poolResolver.RewardStateOf(deposit)

	// Calculate internal rewards regardless of current tier status
	// The reward cache system will automatically handle periods with 0 rewards
	// This allows collecting rewards earned while the pool was in a tier,
	// while preventing new rewards after tier removal
	calculatedInternalRewards, calculatedInternalPenalties := rewardState.calculateInternalReward(lastCollectTime, param.CurrentTime)
	copy(internalRewards, calculatedInternalRewards)
	copy(internalPenalties, calculatedInternalPenalties)
	rewardState.reset()

	// Initialize maps for external rewards
	for i := range externalRewards {
		externalRewards[i] = make(map[string]int64)
		externalPenalties[i] = make(map[string]int64)
	}

	// Query incentives only for the time window this position could actually earn rewards.
	// Using the position's stake time as the lower bound avoids scanning incentives that ended
	// before the deposit existed, and capping at current time prevents unbounded lookups.
	allIncentives := poolResolver.IncentivesResolver().GetAllInTimestamps(depositResolver.StakeTime(), param.CurrentTime)

	// Process each external incentive with lazy initialization:
	// When a new incentive is created, we don't iterate through all deposits for performance.
	//
	// Instead, we determine the appropriate lastCollectTime here:
	// - If a deposit already has a lastCollectTime for an incentive, use it
	// - If not (first time collecting), use max(deposit.stakeTime, incentive.startTimestamp)
	//
	// This avoids O(n) iteration on every incentive creation while ensuring correct reward calculation.
	for incentiveId, incentive := range allIncentives {
		externalLastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)

		incentiveResolver := NewExternalIncentiveResolver(incentive)
		// Check if incentive is active during this specific collection period
		if !incentiveResolver.IsStarted(param.CurrentTime) || incentiveResolver.StartTimestamp() >= param.CurrentTime {
			continue
		}

		// External incentivized pool.
		// Calculate reward for each warmup using per-incentive lastCollectTime
		externalReward, externalPenalty := rewardState.calculateExternalReward(externalLastCollectTime, param.CurrentTime, incentive)

		for i := range externalReward {
			externalRewards[i][incentiveId] = externalReward[i]
			externalPenalties[i][incentiveId] = externalPenalty[i]
		}

		rewardState.reset()
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
func (s *stakerV1) processUnClaimableReward(poolPath string, endTimestamp int64) int64 {
	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		return 0
	}
	poolResolver := NewPoolResolver(pool)
	return poolResolver.processUnclaimableReward(s.getPoolTier(), endTimestamp)
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
func getInitialCollectTime(deposit *sr.Deposit, incentive *sr.ExternalIncentive) int64 {
	if deposit.StakeTime() > incentive.StartTimestamp() {
		return deposit.StakeTime()
	}
	return incentive.StartTimestamp()
}
