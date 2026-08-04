package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	bptree "gno.land/p/nt/bptree/v0"
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

	return aggregateRewards(rewards)
}

// calcPositionRewardReadOnly calculates total position rewards and penalties
// WITHOUT writing any state to storage. It mirrors calcPositionReward but drives
// every computation through pure read-only paths (reward segments, in-memory
// incentive-id union). Safe to call from getters.
func (s *stakerV1) calcPositionRewardReadOnly(currentHeight, currentTimestamp int64, positionId uint64) Reward {
	rewards := s.calculatePositionRewardReadOnly(&CalcPositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTimestamp,
		Deposits:      s.getDeposits(),
		Pools:         s.getPools(),
		PoolTier:      s.getPoolTier(),
		PositionId:    positionId,
	})

	return aggregateRewards(rewards)
}

func aggregateRewards(rewards []Reward) Reward {
	internal := int64(0)
	internalPenalty := int64(0)

	rewardLen := len(rewards)
	externalReward := make(map[string]int64, rewardLen)
	externalPenalty := make(map[string]int64, rewardLen)

	for _, reward := range rewards {
		internal = gnsmath.SafeAddInt64(internal, reward.Internal)
		internalPenalty = gnsmath.SafeAddInt64(internalPenalty, reward.InternalPenalty)

		for incentive, amount := range reward.External {
			externalReward[incentive] = gnsmath.SafeAddInt64(externalReward[incentive], amount)
		}

		for incentive, penalty := range reward.ExternalPenalty {
			externalPenalty[incentive] = gnsmath.SafeAddInt64(externalPenalty[incentive], penalty)
		}
	}

	return Reward{
		Internal:        internal,
		InternalPenalty: internalPenalty,
		External:        externalReward,
		ExternalPenalty: externalPenalty,
	}
}

// CalcPositionRewardParam is internal parameters for calculating position reward
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
	deposit := param.Deposits.get(param.PositionId)
	depositResolver := NewDepositResolver(deposit)
	poolPath := deposit.TargetPoolPath()

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		pool = sr.NewPool(poolPath, param.CurrentTime)
		param.Pools.set(poolPath, pool)
	}
	poolResolver := NewPoolResolver(pool)

	// Cache reward/accumulators only for the pool we are currently calculating.
	param.PoolTier.cacheRewardForPool(param.CurrentTime, param.Pools, poolPath)

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

// calculatePositionRewardReadOnly is the pure, read-only counterpart of
// calculatePositionReward. It produces the identical reward/penalty result as
// the write path but performs NO storage writes:
//
//  1. The pool is read but never created (a missing pool yields zero rewards).
//  2. cacheRewardForPool is replaced by PoolTier.rewardSegmentsForPool, which
//     reconstructs the reward-cache intervals in memory.
//  3. The deposit's external incentive list is not synced; the union of the
//     already-indexed incentive ids and the ids created since the last sync is
//     computed in memory instead.
//
// It is safe to call from any getter.
func (s *stakerV1) calculatePositionRewardReadOnly(param *CalcPositionRewardParam) []Reward {
	deposit := param.Deposits.get(param.PositionId)
	depositResolver := NewDepositResolver(deposit)
	poolPath := deposit.TargetPoolPath()

	pool, ok := param.Pools.Get(poolPath)
	if !ok {
		// A pool that was never created cannot have earned any rewards.
		// (The write path would create an empty pool here; we skip the write.)
		return make([]Reward, len(deposit.Warmups()))
	}
	poolResolver := NewPoolResolver(pool)

	// Reconstruct the reward-cache intervals in memory, without persisting them.
	segments := param.PoolTier.rewardSegmentsForPool(param.CurrentTime, param.Pools, poolPath)

	lastCollectTime := depositResolver.InternalRewardLastCollectTime()

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	rewardState := poolResolver.RewardStateOf(deposit)

	// Calculate internal rewards regardless of current tier status
	// (identical semantics to the write path)
	calculatedInternalRewards, calculatedInternalPenalties := rewardState.calculateInternalRewardReadOnly(lastCollectTime, param.CurrentTime, segments)

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

	incentivesResolver := poolResolver.IncentivesResolver()

	// Build the effective set of incentive ids WITHOUT writing to the deposit:
	// already-indexed ids + ids created since the deposit's last sync.
	effectiveIncentiveIds := make(map[string]bool)
	deposit.IterateExternalIncentiveIds(func(incentiveId string) bool {
		effectiveIncentiveIds[incentiveId] = true
		return false
	})

	if lastExternalIncentiveUpdatedAt < param.CurrentTime {
		newIncentiveIds := s.getExternalIncentiveIdsBy(poolPath, lastExternalIncentiveUpdatedAt, param.CurrentTime)
		for _, incentiveId := range newIncentiveIds {
			effectiveIncentiveIds[incentiveId] = true
		}
	}

	// Use the effective incentive ids instead of iterating all pool incentives
	for incentiveId := range effectiveIncentiveIds {
		incentive, ok := incentivesResolver.Get(incentiveId)
		if !ok {
			continue
		}

		incentiveResolver := NewExternalIncentiveResolver(incentive)

		// Check if incentive is active during this specific collection period
		if !incentiveResolver.IsStarted(param.CurrentTime) {
			continue
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

	return poolResolver.processUnclaimableReward(endTimestamp)
}

// update deposit's incentive list with new incentives created since last update
func (s *stakerV1) getExternalIncentiveIdsBy(poolPath string, startTime, endTime int64) []string {
	currentIncentiveIds := make([]string, 0)

	incentivesByTime := s.getExternalIncentivesByCreationTime()

	incentivesByTime.Iterate(startTime, endTime, func(_ int64, value any) bool {
		// Value is a slice of incentive IDs (handles timestamp collisions)
		poolIncentiveIds, ok := value.(*bptree.BPTree)
		if !ok {
			return false
		}

		incentiveIdsValue := poolIncentiveIds.Get(poolPath)
		if incentiveIdsValue == nil {
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
