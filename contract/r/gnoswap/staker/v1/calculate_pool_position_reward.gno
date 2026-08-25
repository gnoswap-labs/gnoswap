package staker

import (
	"gno.land/p/gnoswap/gnsmath"
	ufmt "gno.land/p/nt/ufmt/v0"

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

// aggregateRewards sums the per-warmup rewards/penalties into a single Reward.
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

// calculatePositionRewardParam is a struct for calculating position reward
type calculatePositionRewardParam struct {
	// Environmental variables
	CurrentHeight int64
	CurrentTime   int64
	Deposits      *Deposits
	Pools         *Pools
	PoolTier      *PoolTier

	// Position variables
	PositionId uint64
}

// positionRewardUpdate carries the persisted-state changes produced (but not applied) by
// calculatePositionReward. They are applied by updatePositionReward, so that only the collect path
// mutates state while the calculation stays pure.
type positionRewardUpdate struct {
	poolPath    string
	pool        *sr.Pool
	poolExisted bool

	// External incentive ids discovered as newly created since the deposit's last update; they must be
	// added to the deposit's incentive index.
	newExternalIncentiveIds []string
	// Whether the deposit's LastExternalIncentiveUpdatedAt cursor should be advanced to CurrentTime.
	advanceExternalIncentiveCursor bool
}

// calculateCollectablePositionReward calculates the aggregated position reward WITHOUT mutating any persisted state.
//
// It is the shared, read-only entry point used by both the Collectable* view getters and CollectReward.
// This keeps the calculation identical for both callers and guarantees views never write.
func (s *stakerV1) calculateCollectablePositionReward(currentHeight, currentTimestamp int64, positionId uint64) (Reward, error) {
	rewards, _, err := s.calculatePositionReward(&calculatePositionRewardParam{
		CurrentHeight: currentHeight,
		CurrentTime:   currentTimestamp,
		Deposits:      s.getDeposits(),
		Pools:         s.getPools(),
		PoolTier:      s.getPoolTier(),
		PositionId:    positionId,
	})
	if err != nil {
		return Reward{}, err
	}

	return aggregateRewards(rewards), nil
}

// calculatePositionReward computes a position's per-warmup rewards WITHOUT mutating persisted state.
//
// The per-second emission-rate schedule is resolved up-front (resolveInternalRewardSegments) and fed to
// the single internal-reward calculator, so the calculation needs no reward-cache materialization.
// External incentive discovery is done into a local set rather than by mutating the deposit. All would-be
// state changes are returned as a positionRewardUpdate for the caller to apply (collect only).
func (s *stakerV1) calculatePositionReward(param *calculatePositionRewardParam) ([]Reward, positionRewardUpdate, error) {
	deposit := param.Deposits.get(param.PositionId)
	depositResolver := NewDepositResolver(deposit)
	poolPath := deposit.TargetPoolPath()

	pool, poolExisted := param.Pools.Get(poolPath)
	if !poolExisted {
		// Read-only: use an ephemeral pool; persistence is deferred to updatePositionReward.
		pool = sr.NewPool(poolPath, param.CurrentTime)
	}
	poolResolver := NewPoolResolver(pool)

	updateParams := positionRewardUpdate{
		poolPath:    poolPath,
		pool:        pool,
		poolExisted: poolExisted,
	}

	lastCollectTime := depositResolver.InternalRewardLastCollectTime()

	// Initializes reward/penalty arrays for rewards and penalties for each warmup
	rewardState := poolResolver.RewardStateOf(deposit)

	// Resolve the per-second reward-rate schedule (pure) and calculate internal rewards from it.
	internalSegments, err := poolResolver.resolveInternalRewardSegments(param.PoolTier, poolPath, lastCollectTime, param.CurrentTime)
	if err != nil {
		return nil, positionRewardUpdate{}, err
	}
	calculatedInternalRewards, calculatedInternalPenalties := rewardState.calculateInternalReward(internalSegments)

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

	// Build the effective incentive-id set (stored ∪ newly-created-since-last-update) WITHOUT mutating
	// the deposit. ExternalRewardLastCollectTime falls back to StakeTime for ids not yet persisted, so a
	// newly-discovered incentive yields the same calculation whether or not it is written to the deposit.
	seen := make(map[string]bool)
	incentiveIds := make([]string, 0)
	deposit.IterateExternalIncentiveIds(func(incentiveId string) bool {
		if !seen[incentiveId] {
			seen[incentiveId] = true
			incentiveIds = append(incentiveIds, incentiveId)
		}
		return false
	})

	lastExternalIncentiveUpdatedAt := depositResolver.LastExternalIncentiveUpdatedAt()
	if lastExternalIncentiveUpdatedAt < param.CurrentTime {
		// Discover incentives from this pool's own start-time index. Using the
		// local resolver keeps calculation read-only even for an ephemeral pool
		// that has not yet been persisted in param.Pools.
		newIds := make([]string, 0)
		poolResolver.IncentivesResolver().IterateIncentiveIdsByTime(lastExternalIncentiveUpdatedAt, param.CurrentTime, func(incentiveId string) bool {
			newIds = append(newIds, incentiveId)
			return false
		})
		updateParams.newExternalIncentiveIds = newIds
		updateParams.advanceExternalIncentiveCursor = true

		for _, incentiveId := range newIds {
			if !seen[incentiveId] {
				seen[incentiveId] = true
				incentiveIds = append(incentiveIds, incentiveId)
			}
		}
	}

	incentivesResolver := poolResolver.IncentivesResolver()
	for _, incentiveId := range incentiveIds {
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

	return rewards, updateParams, nil
}

// updatePositionReward applies the persisted-state changes produced by calculatePositionReward.
// It is called ONLY by the collect path; the Collectable* view getters discard the update.
func (s *stakerV1) updatePositionReward(param *calculatePositionRewardParam, updateParams positionRewardUpdate) {
	// Persist a lazily created pool.
	if !updateParams.poolExisted {
		param.Pools.set(updateParams.poolPath, updateParams.pool)
	}

	// Materialize the reward cache up to CurrentTime (halving boundaries). The calculation itself no
	// longer needs this, but downstream unclaimable processing (which reads CurrentReward) and off-chain
	// history rely on the cache, so it is advanced here on collect only.
	param.PoolTier.cacheRewardForPool(param.CurrentTime, param.Pools, updateParams.poolPath)

	// Persist deposit incentive-index updates discovered during calculation.
	if len(updateParams.newExternalIncentiveIds) > 0 || updateParams.advanceExternalIncentiveCursor {
		deposit := param.Deposits.get(param.PositionId)
		for _, incentiveId := range updateParams.newExternalIncentiveIds {
			deposit.AddExternalIncentiveId(incentiveId)
		}
		if updateParams.advanceExternalIncentiveCursor {
			deposit.SetLastExternalIncentiveUpdatedAt(param.CurrentTime)
		}
	}
}

// internalRewardSegment is a [start, end) span over which the per-second emission reward rate is constant.
type internalRewardSegment struct {
	start           int64
	end             int64
	rewardPerSecond int64
}

// resolveInternalRewardSegments builds the per-second reward-rate schedule over [startTime, endTime]
// WITHOUT mutating state.
//
// Persisted reward-cache entries cover the historical portion: they record tier/count changes and any
// halvings already materialized by past collects, so no un-materialized halving exists strictly between
// two persisted entries. The tail beyond the last persisted entry is split by halvings using the current
// tier ratio/count, which are necessarily constant there (a change would have written a cache entry). The
// tail rate is recomputed with the same calculatePoolReward arithmetic the cache writer uses, so a
// schedule resolved from a fully materialized cache and one resolved from the emission halvings are
// identical.
func (self *PoolResolver) resolveInternalRewardSegments(poolTier *PoolTier, poolPath string, startTime, endTime int64) ([]internalRewardSegment, error) {
	segments := make([]internalRewardSegment, 0)
	if startTime >= endTime {
		return segments, nil
	}

	currentReward := self.CurrentReward(startTime)
	cursor := startTime

	self.RewardCache().Iterate(startTime, endTime, func(key int64, value any) bool {
		reward, ok := value.(int64)
		if !ok {
			panic(ufmt.Sprintf("failed to cast value to int64: %T", value))
		}

		segments = append(segments, internalRewardSegment{start: cursor, end: key, rewardPerSecond: currentReward})
		cursor = key
		currentReward = reward
		return false
	})

	if cursor < endTime {
		var err error
		segments, err = appendInternalRewardTailSegments(segments, poolTier, poolPath, cursor, endTime, currentReward)
		if err != nil {
			return nil, err
		}
	}

	return segments, nil
}

// appendInternalRewardTailSegments appends the schedule for the tail [startTime, endTime], where no
// persisted cache entry exists beyond startTime. Over this span tier/count are constant, so the rate
// changes only at halving boundaries.
func appendInternalRewardTailSegments(segments []internalRewardSegment, poolTier *PoolTier, poolPath string, startTime, endTime, baseReward int64) ([]internalRewardSegment, error) {
	tier := poolTier.CurrentTier(poolPath)
	if tier == 0 || tier >= AllTierCount {
		// Not currently tiered: the rate cannot increase; the base is 0 after de-tier.
		return append(segments, internalRewardSegment{start: startTime, end: endTime, rewardPerSecond: baseReward}), nil
	}

	tierRatio, err := poolTier.tierRatio.Get(tier)
	if err != nil {
		panic(makeErrorWithDetails(errInvalidPoolTier, err.Error()))
	}
	tierRatioInt64 := int64(tierRatio)
	tierCount := int64(poolTier.counts[tier])

	halvingTimestamps, halvingEmissions, err := poolTier.getHalvingBlocksInRange(startTime, endTime)
	if err != nil {
		return nil, err
	}

	segStart := startTime
	rate := baseReward
	for i, hv := range halvingTimestamps {
		if hv <= segStart {
			// Halving effective at/before the segment start: only switch the rate.
			rate = calculatePoolReward(halvingEmissions[i], tierRatioInt64, tierCount)
			continue
		}
		if hv >= endTime {
			break
		}

		segments = append(segments, internalRewardSegment{start: segStart, end: hv, rewardPerSecond: rate})
		rate = calculatePoolReward(halvingEmissions[i], tierRatioInt64, tierCount)
		segStart = hv
	}

	return append(segments, internalRewardSegment{start: segStart, end: endTime, rewardPerSecond: rate}), nil
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

	pool, ok := s.getPools().Get(poolPath)
	if !ok {
		return currentIncentiveIds
	}
	poolResolver := NewPoolResolver(pool)

	// Look up the pool's own start-time index instead of a global
	// creation-time index. The index is scoped to this pool's incentives, so
	// discovery cost is bounded by the number of incentives for this pool
	// within the queried range, and no longer grows with the total number of
	// incentives system-wide.
	poolResolver.IncentivesResolver().IterateIncentiveIdsByTime(startTime, endTime, func(incentiveId string) bool {
		currentIncentiveIds = append(currentIncentiveIds, incentiveId)
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
