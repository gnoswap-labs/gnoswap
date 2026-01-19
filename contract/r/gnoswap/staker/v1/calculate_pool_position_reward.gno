package v1

import (
	"gno.land/p/nt/avl"
	sr "gno.land/r/gnoswap/staker"
)

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

	rewardLen := len(rewards)
	externalReward := make(map[string]int64, rewardLen)
	externalPenalty := make(map[string]int64, rewardLen)

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
	rewardState := poolResolver.RewardStateOf(deposit)

	// Calculate internal rewards regardless of current tier status
	// The reward cache system will automatically handle periods with 0 rewards
	// This allows collecting rewards earned while the pool was in a tier,
	// while preventing new rewards after tier removal
	calculatedInternalRewards, calculatedInternalPenalties := rewardState.calculateInternalReward(lastCollectTime, param.CurrentTime)

	warmupLen := len(deposit.Warmups())
	rewards := make([]Reward, warmupLen)
	for i := 0; i < warmupLen; i++ {
		rewards[i] = Reward{
			Internal:        calculatedInternalRewards[i],
			InternalPenalty: calculatedInternalPenalties[i],
			External:        make(map[string]int64),
			ExternalPenalty: make(map[string]int64),
		}
	}
	rewardState.reset()

	lastExternalIncentiveUpdatedAt := depositResolver.LastExternalIncentiveUpdatedAt()

	// update deposit's incentive list with new incentives created since last update
	if lastExternalIncentiveUpdatedAt < param.CurrentTime {
		// get new incentives created since last update
		currentIncentiveIds := s.getExternalIncentiveIdsBy(poolPath, lastExternalIncentiveUpdatedAt, param.CurrentTime)

		// add new created incentives to deposit
		for _, incentiveId := range currentIncentiveIds {
			deposit.AddExternalIncentiveId(incentiveId)
		}

		deposit.SetLastExternalIncentiveUpdatedAt(param.CurrentTime)
	}

	incentivesResolver := poolResolver.IncentivesResolver()

	// Use deposit's indexed incentive IDs instead of iterating all pool incentives
	deposit.IterateExternalIncentiveIds(func(incentiveId string) bool {
		incentive, ok := incentivesResolver.Get(incentiveId)
		if !ok {
			return false
		}

		incentiveResolver := NewExternalIncentiveResolver(incentive)

		// Check if incentive is active during this specific collection period
		if !incentiveResolver.IsStarted(param.CurrentTime) {
			return false
		}

		// External incentivized pool.
		// Calculate reward for each warmup using per-incentive lastCollectTime
		externalLastCollectTime := depositResolver.ExternalRewardLastCollectTime(incentiveId)
		externalReward, externalPenalty := rewardState.calculateExternalReward(externalLastCollectTime, param.CurrentTime, incentive)

		for i := range externalReward {
			if externalReward[i] > 0 || externalPenalty[i] > 0 {
				rewards[i].External[incentiveId] = externalReward[i]
				rewards[i].ExternalPenalty[incentiveId] = externalPenalty[i]
			}
		}

		rewardState.reset()

		return false
	})

	return rewards
}

// calculates internal unclaimable reward for the pool
func (s *stakerV1) processUnClaimableReward(poolPath string, endTimestamp int64) int64 {
	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		return 0
	}
	poolResolver := NewPoolResolver(pool)
	return poolResolver.processUnclaimableReward(endTimestamp)
}

// update deposit's incentive list with new incentives created since last update
func (s *stakerV1) getExternalIncentiveIdsBy(poolPath string, startTime, endTime int64) []string {
	currentIncentiveIds := make([]string, 0)

	incentivesByTime := s.getExternalIncentivesByCreationTime()

	incentivesByTime.Iterate(startTime, endTime, func(_ int64, value any) bool {
		// Value is a slice of incentive IDs (handles timestamp collisions)
		poolIncentiveIds, ok := value.(*avl.Tree)
		if !ok {
			return false
		}

		incentiveIdsValue, exists := poolIncentiveIds.Get(poolPath)
		if !exists {
			return false
		}

		incentiveIds, ok := incentiveIdsValue.([]string)
		if !ok {
			return false
		}

		currentIncentiveIds = append(currentIncentiveIds, incentiveIds...)

		return false
	})

	return currentIncentiveIds
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
